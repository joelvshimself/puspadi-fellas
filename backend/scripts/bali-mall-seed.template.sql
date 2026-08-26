-- ==========================================================================
-- Bali mall directory seed — GENERATED FILE, DO NOT EDIT BY HAND
--
-- Generated  @@GENERATED_AT@@
-- By         backend/scripts/generate-bali-mall-seed.mjs
-- From       backend/seed/bali-malls.json (@@MALL_COUNT@@ malls, @@ALIAS_COUNT@@ aliases)
-- Source     OpenStreetMap via the Overpass API, ODbL 1.0
--
-- To change what this file contains, change the inputs and regenerate:
--
--   node backend/scripts/fetch-bali-malls.mjs        # re-download from OSM
--   node backend/scripts/generate-bali-mall-seed.mjs # rewrite this migration
--
-- The data is carried as one JSON literal rather than @@MALL_COUNT@@ INSERT
-- statements so that a regeneration shows up in review as a diff of the data
-- itself, not as a rewritten wall of SQL.
--
-- WHAT THIS DOES
--   1. Upserts the malls into place_cache as is_seeded rows.
--   2. Registers every known spelling of each one in place_aliases.
--   3. Absorbs the duplicate rows the live table has already accumulated for
--      these same venues, moving their reviews, saved places and signals onto
--      the seeded id first.
--   4. Turns the handful of OSM accessibility tags into accessibility_signals.
--
-- WHAT IT DELIBERATELY DOES NOT DO
--   Set fetched_at. A seeded row has a name, an address and a coordinate but
--   no photo and no Google data, and place-accessibility treats a row with no
--   google_accessibility as needing a refresh — so the first person to open
--   one of these malls triggers the normal enrichment and the row fills in.
--   Stamping fetched_at here would suppress that for the full 90-day TTL and
--   the seeded malls would sit there photoless until November.
-- ==========================================================================

create temp table _bali_seed (doc jsonb);
insert into _bali_seed (doc) values (
$seed$@@SEED_JSON@@$seed$::jsonb
);

-- --------------------------------------------------------------------------
-- 1. The places
--
-- On conflict the row may already exist as an on-demand cache entry that a
-- user's lookup minted. Adopt it: take the directory fields from the seed,
-- but never clobber enrichment that was already paid for (google_accessibility,
-- the Mapillary image) or the freshness stamp that governs it.
-- --------------------------------------------------------------------------

insert into public.place_cache (
  place_id, name, lat, lng, osm_id, osm_accessibility,
  address, city, postcode, phone, website, opening_hours, levels, category,
  is_seeded, data_source, data_attribution
)
select
  m->>'place_id',
  m->>'name',
  (m->>'lat')::double precision,
  (m->>'lng')::double precision,
  m->>'osm_id',
  nullif(m->'osm_accessibility', '{}'::jsonb),
  m->>'address',
  m->>'city',
  m->>'postcode',
  m->>'phone',
  m->>'website',
  m->>'opening_hours',
  nullif(m->>'levels', '')::smallint,
  m->>'category',
  true,
  'openstreetmap',
  d.doc->>'attribution'
from _bali_seed d
cross join lateral jsonb_array_elements(d.doc->'malls') m
on conflict (place_id) do update set
  name              = excluded.name,
  lat               = excluded.lat,
  lng               = excluded.lng,
  osm_id            = coalesce(excluded.osm_id, public.place_cache.osm_id),
  osm_accessibility = coalesce(excluded.osm_accessibility, public.place_cache.osm_accessibility),
  address           = coalesce(excluded.address, public.place_cache.address),
  city              = coalesce(excluded.city, public.place_cache.city),
  postcode          = coalesce(excluded.postcode, public.place_cache.postcode),
  phone             = coalesce(excluded.phone, public.place_cache.phone),
  website           = coalesce(excluded.website, public.place_cache.website),
  opening_hours     = coalesce(excluded.opening_hours, public.place_cache.opening_hours),
  levels            = coalesce(excluded.levels, public.place_cache.levels),
  category          = coalesce(excluded.category, public.place_cache.category),
  is_seeded         = true,
  data_source       = excluded.data_source,
  data_attribution  = excluded.data_attribution,
  updated_at        = now();

-- --------------------------------------------------------------------------
-- 2. The names
--
-- The canonical name is registered alongside the aliases so tier 0 of
-- resolve_place_id answers for it too — a lookup under the mall's own name
-- then gets the curated 1km radius rather than the 250m name-match radius,
-- which is what MapKit's coordinate drift needs.
-- --------------------------------------------------------------------------

-- distinct on: several spellings collapse to ONE normalized form — Park23's
-- "Park23 Mall" and "Park 23 Mall" are the same string once punctuation and
-- case are stripped. Feeding both to ON CONFLICT DO UPDATE is an error
-- ("cannot affect row a second time"), not a silent no-op, so the duplicates
-- have to go before the insert rather than be absorbed by it.
insert into public.place_aliases (place_id, normalized_name, display_name, source)
select distinct on (place_id, normalized_name) *
from (
  select
    m->>'place_id' as place_id,
    lower(regexp_replace(alias, '[^a-zA-Z0-9]+', '', 'g')) as normalized_name,
    alias as display_name,
    'seed' as source
  from _bali_seed d
  cross join lateral jsonb_array_elements(d.doc->'malls') m
  cross join lateral jsonb_array_elements_text(
    coalesce(m->'aliases', '[]'::jsonb) || jsonb_build_array(m->>'name')
  ) alias
) candidates
where normalized_name <> ''
on conflict (place_id, normalized_name) do update set
  display_name = excluded.display_name,
  source       = excluded.source;

-- --------------------------------------------------------------------------
-- 3. Absorb the duplicates that already exist
--
-- The live table holds several rows per mall — five for Beachwalk, five for
-- Icon Bali, five for Park23 across two spellings — each minted by a client
-- lookup that resolve_place_id could not match, and each with its own reviews
-- and saved places hanging off it. Seeding a 23rd row next to them would make
-- the problem worse, not better. So every non-seeded row whose name is a known
-- alias of a seeded mall within 1km is folded into it.
--
-- 1km, not the 250m of a bare name match, for the same reason tier 0 uses it:
-- these are curated names, and the observed drift within one venue in this
-- very table reaches ~600m.
-- --------------------------------------------------------------------------

create temp table _bali_absorb as
select dup.place_id as old_id, s.place_id as new_id
from public.place_cache dup
cross join lateral (
  select seed.place_id
  from public.place_cache seed
  join public.place_aliases a on a.place_id = seed.place_id
  where seed.is_seeded
    and seed.geog is not null
    and a.normalized_name = lower(regexp_replace(dup.name, '[^a-zA-Z0-9]+', '', 'g'))
    and ST_DWithin(dup.geog, seed.geog, 1000)
  order by dup.geog <-> seed.geog
  limit 1
) s
where not dup.is_seeded
  and dup.name is not null
  and dup.geog is not null
  and dup.place_id <> s.place_id;

create index on _bali_absorb (old_id);

-- Fold each absorbed row's enrichment into its seed row FIRST. A merge must
-- never lose a Google answer we paid for or an image we already downloaded and
-- stored — those are the expensive parts.
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
  from _bali_absorb ab
  join public.place_cache pc on pc.place_id = ab.old_id
  group by ab.new_id
)
update public.place_cache seed
set google_accessibility = coalesce(seed.google_accessibility, f.google_accessibility),
    osm_accessibility    = coalesce(seed.osm_accessibility, f.osm_accessibility),
    google_place_id      = coalesce(seed.google_place_id, f.google_place_id),
    image_url            = coalesce(seed.image_url, f.image_url),
    image_attribution    = coalesce(seed.image_attribution, f.image_attribution),
    -- Inheriting fetched_at matters: the absorbed row may already have been
    -- enriched, and re-running the paid pipeline for a place we have data for
    -- is exactly what this whole identity mechanism exists to stop.
    fetched_at           = coalesce(seed.fetched_at, f.fetched_at)
from folded f
where seed.place_id = f.new_id;

-- Signals that would collide once remapped: keep the freshest, matching how
-- accessibility_grade() decays on greatest(created_at, updated_at).
delete from public.accessibility_signals a
using public.accessibility_signals b
where a.id <> b.id
  and coalesce((select x.new_id from _bali_absorb x where x.old_id = a.place_id), a.place_id)
    = coalesce((select x.new_id from _bali_absorb x where x.old_id = b.place_id), b.place_id)
  and a.feature = b.feature
  and a.source = b.source
  and a.user_id is not distinct from b.user_id
  and (greatest(a.updated_at, a.created_at), a.id)
      < (greatest(b.updated_at, b.created_at), b.id);

update public.accessibility_signals s
set place_id = ab.new_id
from _bali_absorb ab
where s.place_id = ab.old_id;

-- The merge that actually matters to a user: reviews written against four
-- different ids for one mall now group under a single place.
update public.reviews r
set place_id = ab.new_id
from _bali_absorb ab
where r.place_id = ab.old_id;

-- saved_places is unique (user_id, place_id) — drop the older of any pair that
-- would collide before remapping.
delete from public.saved_places a
using public.saved_places b
where a.id <> b.id
  and a.user_id = b.user_id
  and coalesce((select x.new_id from _bali_absorb x where x.old_id = a.place_id), a.place_id)
    = coalesce((select x.new_id from _bali_absorb x where x.old_id = b.place_id), b.place_id)
  and (a.created_at, a.id) < (b.created_at, b.id);

update public.saved_places s
set place_id = ab.new_id
from _bali_absorb ab
where s.place_id = ab.old_id;

update public.routes t
set place_id = ab.new_id
from _bali_absorb ab
where t.place_id = ab.old_id;

-- The archive's storage_path embeds the id and the seed row will regenerate
-- its own; an absorbed one is dropped rather than migrated.
delete from public.venue_imdf_archives v
using _bali_absorb ab
where v.place_id = ab.old_id;

delete from public.place_cache pc
using _bali_absorb ab
where pc.place_id = ab.old_id;

-- --------------------------------------------------------------------------
-- 4. OSM accessibility tags -> signals
--
-- Only a handful of these malls carry any. That is the honest state of OSM in
-- Bali, and it is the gap the app's own contributors are there to close — a
-- seeded mall with no signals renders as "not reviewed yet", which is true.
--
-- Weight 0.5 and source 'osm', identical to what tryEnrichFromOSM writes, so a
-- seeded signal and a live-fetched one are the same kind of evidence.
-- --------------------------------------------------------------------------

insert into public.accessibility_signals (
  place_id, feature, value, source, user_id, confidence_weight, updated_at
)
select
  m->>'place_id',
  'entrance'::accessibility_feature,
  case m->'osm_accessibility'->>'wheelchair'
    when 'yes'        then 'yes'
    when 'designated' then 'yes'
    when 'limited'    then 'limited'
    when 'no'         then 'no'
  end::accessibility_value,
  'osm'::accessibility_source,
  null,
  0.5,
  now()
from _bali_seed d
cross join lateral jsonb_array_elements(d.doc->'malls') m
where m->'osm_accessibility'->>'wheelchair' in ('yes', 'designated', 'limited', 'no')
on conflict (place_id, feature, source, user_id) do update set
  value = excluded.value,
  updated_at = now();

insert into public.accessibility_signals (
  place_id, feature, value, source, user_id, confidence_weight, updated_at
)
select
  m->>'place_id',
  'restroom'::accessibility_feature,
  case m->'osm_accessibility'->>'toilets:wheelchair'
    when 'yes'     then 'yes'
    when 'limited' then 'limited'
    when 'no'      then 'no'
  end::accessibility_value,
  'osm'::accessibility_source,
  null,
  0.5,
  now()
from _bali_seed d
cross join lateral jsonb_array_elements(d.doc->'malls') m
where m->'osm_accessibility'->>'toilets:wheelchair' in ('yes', 'limited', 'no')
on conflict (place_id, feature, source, user_id) do update set
  value = excluded.value,
  updated_at = now();

-- --------------------------------------------------------------------------
-- 5. Report, so a push that quietly does nothing is visible
-- --------------------------------------------------------------------------

do $$
declare
  seeded  integer;
  aliases integer;
  merged  integer;
  signals integer;
begin
  select count(*) into seeded from public.place_cache where is_seeded;
  select count(*) into aliases from public.place_aliases;
  select count(*) into merged from _bali_absorb;
  select count(*) into signals
  from public.accessibility_signals s
  join public.place_cache pc on pc.place_id = s.place_id
  where pc.is_seeded and s.source = 'osm';

  raise notice 'Bali mall seed: % seeded place(s), % alias(es), % duplicate row(s) absorbed, % OSM signal(s)',
    seeded, aliases, merged, signals;
end $$;

drop table if exists _bali_absorb;
drop table if exists _bali_seed;
