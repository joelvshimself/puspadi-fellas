-- ==========================================================================
-- absorb_alias_duplicates() (2026-08-26)
--
-- The Bali seed migration folded the duplicate rows that existed AT THE MOMENT
-- IT RAN into their seeded venue. That was written as one-shot cleanup, which
-- turned out to be the wrong shape: duplicates are not a historical mess, they
-- are a thing that keeps happening.
--
-- Two ways they keep arriving:
--
--   * Deploy skew. resolve_place_id only started existing when the identity
--     migration was pushed, and place-accessibility only starts USING it when
--     that function is redeployed. Every lookup in between mints a fresh
--     coordinate-keyed row — verified against the live project immediately
--     after the push: four lookups under names the alias table knows produced
--     four new rows.
--   * New aliases. Adding a spelling to place_aliases makes rows that were
--     previously unrecognisable suddenly recognisable, and they are already
--     sitting in the table.
--
-- So the merge is lifted into a function anyone can re-run. The seed
-- migration's inline copy is left exactly as it was pushed — an applied
-- migration is history and does not get edited — so the two are duplicated for
-- one release. Anything that needs the merge from here calls this.
--
-- Safe to run at any time: it only ever touches non-seeded rows whose name is
-- a curated alias of a seeded place within 1km, and it moves the dependent
-- rows before deleting anything.
-- ==========================================================================

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

  -- Enrichment first: a merge must never lose a Google answer that was paid
  -- for or an image already downloaded into Storage.
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
      (array_agg(pc.image_url order by pc.fetched_at desc nulls last)
         filter (where pc.image_url is not null))[1]                as image_url,
      (array_agg(pc.image_attribution order by pc.fetched_at desc nulls last)
         filter (where pc.image_attribution is not null))[1]        as image_attribution,
      max(pc.fetched_at)                                            as fetched_at
    from _absorb ab
    join public.place_cache pc on pc.place_id = ab.old_id
    group by ab.new_id
  )
  update public.place_cache seed
  set google_accessibility = coalesce(seed.google_accessibility, f.google_accessibility),
      osm_accessibility    = coalesce(seed.osm_accessibility, f.osm_accessibility),
      google_place_id      = coalesce(seed.google_place_id, f.google_place_id),
      image_url            = coalesce(seed.image_url, f.image_url),
      image_attribution    = coalesce(seed.image_attribution, f.image_attribution),
      fetched_at           = coalesce(seed.fetched_at, f.fetched_at)
  from folded f
  where seed.place_id = f.new_id;

  -- Signals that would collide once remapped: keep the freshest, matching how
  -- accessibility_grade() decays on greatest(created_at, updated_at).
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

comment on function public.absorb_alias_duplicates is
  'Folds every non-seeded place_cache row whose name is a curated alias of a seeded place within radius_meters into that place, moving its reviews, saved places, routes and signals first. Idempotent — returns an empty set when there is nothing to merge. Re-run after redeploying place-accessibility, or after adding aliases.';

-- Clean up whatever has accumulated since the seed ran. On the first push that
-- is the rows minted by lookups made in the window between the identity
-- migration landing and place-accessibility being redeployed.
do $$
declare
  merged integer;
begin
  select count(*) into merged from public.absorb_alias_duplicates();
  raise notice 'absorb_alias_duplicates: % row(s) folded into their seeded venue', merged;
end $$;
