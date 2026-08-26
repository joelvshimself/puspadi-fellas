-- ==========================================================================
-- Stop a merge from moving a photo onto the wrong building (2026-08-26)
--
-- The duplicate merge folded each absorbed row's image_url into the seeded
-- row, on the reasoning that an already-downloaded image is expensive and must
-- not be lost. That reasoning was wrong about images specifically.
--
-- An absorbed row exists BECAUSE its coordinate had drifted, by up to ~600m.
-- Its Mapillary photo was fetched for that drifted coordinate — a photo of
-- whatever is at that spot, which is a street, an alley, somebody's parked
-- scooter. Inheriting it pins that photo to the mall. Measured on the live
-- rows after the merge:
--
--   Park23             photo captured 580m away  -> a residential alley
--   Mall Bali Galeria  photo captured 560m away
--   Beachwalk Bali     photo captured  15m away  -> correct, keep
--   Discovery Mall     photo captured  15m away  -> correct, keep
--
-- So the rule is not "never inherit" but "inherit only from close by". The
-- image is the one field where the absorbed row's drift makes the data wrong
-- rather than merely stale; a Google accessibility answer or an OSM tag is
-- about the venue and survives the drift, which is why those still fold in.
--
-- 150m: comfortably covers the couple-of-metres jitter of a genuine re-read of
-- the same venue, and excludes anything far enough away to be a different
-- building. Mapillary itself is queried with a 100m radius, so a photo more
-- than 150m from the anchor cannot be of the anchor.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Clean up what the merge already moved
--
-- The Storage path embeds the place_id the download was made for
-- ("…/place-images/loc_<lat>_<lng>.jpg"), so where each photo was actually
-- captured is recoverable from the URL. Clear only the ones that are too far
-- from the row now holding them — a correct photo is expensive and stays.
--
-- fetched_at goes with it: it is what gates re-enrichment, so leaving it set
-- would keep the place photoless until the 90-day TTL instead of letting the
-- next viewer trigger a fresh Mapillary fetch at the true coordinate.
-- --------------------------------------------------------------------------

do $$
declare
  cleared integer;
begin
  with parsed as (
    select
      pc.place_id,
      ST_Distance(
        pc.geog,
        ST_SetSRID(
          ST_MakePoint(
            (regexp_match(pc.image_url, 'loc_(-?[0-9]+\.[0-9]+)_(-?[0-9]+\.[0-9]+)'))[2]::double precision,
            (regexp_match(pc.image_url, 'loc_(-?[0-9]+\.[0-9]+)_(-?[0-9]+\.[0-9]+)'))[1]::double precision
          ),
          4326
        )::geography
      ) as photo_offset_m
    from public.place_cache pc
    where pc.is_seeded
      and pc.image_url is not null
      and pc.geog is not null
      -- Anchored to the exact `loc_<lat>_<lng>` shape. A looser [0-9.]+ class
      -- is greedy across the dot before the file extension, captures
      -- "115.1697." and fails the cast — which is how this was caught.
      and pc.image_url ~ 'loc_-?[0-9]+\.[0-9]+_-?[0-9]+\.[0-9]+'
  )
  update public.place_cache pc
  set image_url         = null,
      image_attribution = null,
      fetched_at        = null
  from parsed p
  where pc.place_id = p.place_id
    and p.photo_offset_m > 150;

  get diagnostics cleared = row_count;
  raise notice 'cleared % mismatched place photo(s); those places re-fetch at their true coordinate on next view', cleared;
end $$;

-- --------------------------------------------------------------------------
-- 2. Stop it happening on the next merge
--
-- Same function as before in every respect except the image, which now comes
-- only from an absorbed row within 150m of the seed. Everything else about a
-- venue — Google's accessibility answer, OSM tags, the Google place id — is
-- true of the venue wherever the reading was taken from, so those still fold.
-- --------------------------------------------------------------------------

create or replace function public.absorb_alias_duplicates(radius_meters integer default 1000)
returns table (absorbed_id text, absorbed_into text, absorbed_name text)
language plpgsql
as $$
begin
  create temp table _absorb on commit drop as
  select dup.place_id as old_id, dup.name as old_name, s.place_id as new_id
  from public.place_cache dup
  cross join lateral (
    select seed.place_id
    from public.place_cache seed
    join public.place_aliases a on a.place_id = seed.place_id
    where seed.is_seeded
      and seed.geog is not null
      and a.normalized_name = lower(regexp_replace(dup.name, '[^a-zA-Z0-9]+', '', 'g'))
      and ST_DWithin(dup.geog, seed.geog, radius_meters)
    order by dup.geog <-> seed.geog
    limit 1
  ) s
  where not dup.is_seeded
    and dup.name is not null
    and dup.geog is not null
    and dup.place_id <> s.place_id;

  create index on _absorb (old_id);

  with folded as (
    select
      ab.new_id,
      (array_agg(pc.google_accessibility order by pc.fetched_at desc nulls last)
         filter (where pc.google_accessibility is not null
                    and pc.google_accessibility <> '{}'::jsonb))[1] as google_accessibility,
      (array_agg(pc.osm_accessibility order by pc.fetched_at desc nulls last)
         filter (where pc.osm_accessibility is not null))[1]        as osm_accessibility,
      (array_agg(pc.google_place_id order by pc.fetched_at desc nulls last)
         filter (where pc.google_place_id is not null))[1]          as google_place_id,
      -- The image, and ONLY the image, is filtered by distance: it depicts the
      -- absorbed row's drifted coordinate, not the venue.
      (array_agg(pc.image_url order by pc.fetched_at desc nulls last)
         filter (where pc.image_url is not null
                   and ST_DWithin(pc.geog, seed.geog, 150)))[1]     as image_url,
      (array_agg(pc.image_attribution order by pc.fetched_at desc nulls last)
         filter (where pc.image_attribution is not null
                   and ST_DWithin(pc.geog, seed.geog, 150)))[1]     as image_attribution,
      max(pc.fetched_at)                                            as fetched_at
    from _absorb ab
    join public.place_cache pc   on pc.place_id = ab.old_id
    join public.place_cache seed on seed.place_id = ab.new_id
    group by ab.new_id
  )
  update public.place_cache seed
  set google_accessibility = coalesce(seed.google_accessibility, f.google_accessibility),
      osm_accessibility    = coalesce(seed.osm_accessibility, f.osm_accessibility),
      google_place_id      = coalesce(seed.google_place_id, f.google_place_id),
      image_url            = coalesce(seed.image_url, f.image_url),
      image_attribution    = coalesce(seed.image_attribution, f.image_attribution),
      -- Only claim freshness if something actually came across. Inheriting a
      -- fetched_at while inheriting no image would suppress the Mapillary
      -- fetch that the seeded row still needs.
      fetched_at           = case
                               when coalesce(seed.image_url, f.image_url) is null
                                 and coalesce(seed.google_accessibility, f.google_accessibility) is null
                               then null
                               else coalesce(seed.fetched_at, f.fetched_at)
                             end
  from folded f
  where seed.place_id = f.new_id;

  delete from public.accessibility_signals a
  using public.accessibility_signals b
  where a.id <> b.id
    and coalesce((select x.new_id from _absorb x where x.old_id = a.place_id), a.place_id)
      = coalesce((select x.new_id from _absorb x where x.old_id = b.place_id), b.place_id)
    and a.feature = b.feature
    and a.source = b.source
    and a.user_id is not distinct from b.user_id
    and (greatest(a.updated_at, a.created_at), a.id)
        < (greatest(b.updated_at, b.created_at), b.id);

  update public.accessibility_signals s
  set place_id = ab.new_id
  from _absorb ab
  where s.place_id = ab.old_id;

  update public.reviews r
  set place_id = ab.new_id
  from _absorb ab
  where r.place_id = ab.old_id;

  delete from public.saved_places a
  using public.saved_places b
  where a.id <> b.id
    and a.user_id = b.user_id
    and coalesce((select x.new_id from _absorb x where x.old_id = a.place_id), a.place_id)
      = coalesce((select x.new_id from _absorb x where x.old_id = b.place_id), b.place_id)
    and (a.created_at, a.id) < (b.created_at, b.id);

  update public.saved_places s
  set place_id = ab.new_id
  from _absorb ab
  where s.place_id = ab.old_id;

  update public.routes t
  set place_id = ab.new_id
  from _absorb ab
  where t.place_id = ab.old_id;

  delete from public.venue_imdf_archives v
  using _absorb ab
  where v.place_id = ab.old_id;

  delete from public.place_cache pc
  using _absorb ab
  where pc.place_id = ab.old_id;

  return query select ab.old_id, ab.new_id, ab.old_name from _absorb ab;

  drop table if exists _absorb;
end;
$$;

-- --------------------------------------------------------------------------
-- 3. Aliases on the directory read
--
-- The client has no copy of place_aliases, so NearbyPlacesService could only
-- match MapKit results against the seeded name itself. "Park23" and "Park23
-- Mall" are not equal, so both drew a pin — two markers on one building, one
-- carrying the reviews and one leading to an empty page. Ship the names with
-- the place so the client can apply the same rule the database does.
-- --------------------------------------------------------------------------

-- Adding `aliases` changes the return type, and Postgres will not REPLACE a
-- function across that — it fails with "cannot change return type of existing
-- function". Drop explicitly so the change actually lands rather than erroring
-- mid-migration.
drop function if exists public.places_directory_nearby(
  double precision, double precision, integer, integer
);

create function public.places_directory_nearby(
  user_lat double precision,
  user_lng double precision,
  radius_meters integer default 15000,
  max_results integer default 100
)
returns table (
  place_id      text,
  name          text,
  lat           double precision,
  lng           double precision,
  address       text,
  city          text,
  category      text,
  phone         text,
  website       text,
  opening_hours text,
  levels        smallint,
  image_url     text,
  image_attribution text,
  data_attribution  text,
  distance_meters   double precision,
  worst_value   accessibility_value,
  graded_features integer,
  aliases       text[]
)
language sql
stable
as $$
  with origin as (
    select ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography as g
  )
  select
    pc.place_id, pc.name, pc.lat, pc.lng,
    pc.address, pc.city, pc.category, pc.phone, pc.website, pc.opening_hours,
    pc.levels, pc.image_url, pc.image_attribution, pc.data_attribution,
    ST_Distance(pc.geog, o.g) as distance_meters,
    coalesce(g.worst_value, 'unknown'::accessibility_value) as worst_value,
    coalesce(g.graded_features, 0) as graded_features,
    coalesce(
      (select array_agg(a.display_name order by a.display_name)
       from public.place_aliases a where a.place_id = pc.place_id),
      '{}'
    ) as aliases
  from public.place_cache pc
  cross join origin o
  left join lateral (
    select
      (
        select ag2.best_value
        from public.accessibility_grade(pc.place_id) ag2
        where ag2.best_value <> 'unknown'
        order by case ag2.best_value
                   when 'no' then 0
                   when 'limited' then 1
                   when 'yes' then 2
                 end
        limit 1
      ) as worst_value,
      (select count(*)::integer from public.accessibility_grade(pc.place_id)) as graded_features
  ) g on true
  where pc.is_seeded
    and pc.geog is not null
    and ST_DWithin(pc.geog, o.g, radius_meters)
  order by pc.geog <-> o.g
  limit greatest(1, least(max_results, 500));
$$;

comment on function public.places_directory_nearby is
  'Curated directory places near a point, nearest first, each with the worst accessibility verdict currently held for it and every name it is known by. Backs the places-nearby Edge Function; the aliases let the client suppress the MapKit copy of a place it is already showing. Returns ungraded places too — an unreviewed mall is the one most worth sending a contributor to.';
