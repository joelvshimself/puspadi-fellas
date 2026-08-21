-- ==========================================================================
-- Place identity (2026-08-21)
--
-- The coordinate IS the place id, which assumed MapKit returns a stable point
-- per venue. It does not. Measured against this table's own rows:
--
--   beachwalk shopping center   5 place_ids, spread 189m
--   lippo mall kuta             4 place_ids, spread 636m
--   trans studio mall bali      3 place_ids, spread 809m
--
-- MapKit hands back a different representative point for the same mall
-- depending on the region it was searched in. So the previous migration's move
-- from ~1m to ~11m precision -- which merged all of 3 rows -- never had a
-- chance: the drift is two orders of magnitude larger than any sane grid.
--
-- Consequences: every pan re-enriched malls we already had data for (a fresh
-- paid Google lookup and an Overpass query each time, which is what was
-- generating 429s), the device cache almost never hit, and map pins showed
-- "Unknown" for places whose grade was sitting in the table under a
-- neighbouring id.
--
-- Fix: stop deriving identity from the coordinate alone. resolve_place_id()
-- below matches an incoming (lat, lng, name) against places we already know,
-- and the Edge Function adopts that id instead of minting a new one. The
-- coordinate key remains the fallback for a genuinely new place.
--
-- Part 1 backfills existing duplicates so the id a lookup resolves to is
-- stable; part 2 installs the function that keeps it that way.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 0. Stragglers from the 4dp migration
--
-- Rows written between that migration landing and the Edge Functions
-- deploying were still minted at 5dp by the old code. Normalise them so they
-- take part in the clustering below rather than lingering as unreachable
-- cache entries.
-- --------------------------------------------------------------------------

create or replace function public.__place_id_to_4dp(pid text)
returns text
language plpgsql
immutable
as $fn$
declare
  parts text[];
begin
  parts := regexp_match(pid, '^loc_(-?[0-9]+\.[0-9]+)_(-?[0-9]+\.[0-9]+)$');
  if parts is null then
    return pid;
  end if;
  return 'loc_' || round(parts[1]::numeric, 4)::text
              || '_' || round(parts[2]::numeric, 4)::text;
end;
$fn$;

-- Drop any straggler that would collide with a row already at 4dp. The 4dp row
-- is the one every other table now points at, so it keeps the identity.
delete from public.place_cache a
where public.__place_id_to_4dp(a.place_id) <> a.place_id
  and exists (
    select 1 from public.place_cache b
    where b.place_id = public.__place_id_to_4dp(a.place_id)
  );

delete from public.accessibility_signals a
using public.accessibility_signals b
where a.id <> b.id
  and public.__place_id_to_4dp(a.place_id) = public.__place_id_to_4dp(b.place_id)
  and a.feature = b.feature and a.source = b.source
  and a.user_id is not distinct from b.user_id
  and (greatest(a.updated_at, a.created_at), a.id)
      < (greatest(b.updated_at, b.created_at), b.id);

update public.accessibility_signals
set place_id = public.__place_id_to_4dp(place_id)
where public.__place_id_to_4dp(place_id) is distinct from place_id;

update public.place_cache
set place_id = public.__place_id_to_4dp(place_id)
where public.__place_id_to_4dp(place_id) is distinct from place_id;

-- --------------------------------------------------------------------------
-- 1. Backfill: collapse duplicate rows for one venue
--
-- Greedy clustering, richest row first: the row carrying the most enrichment
-- becomes the leader and absorbs every same-named row within 500m. Greedy
-- rather than transitive on purpose -- transitive closure would chain across a
-- whole street of same-named outlets, which is the false merge this must
-- avoid.
-- --------------------------------------------------------------------------

create temp table place_cluster as
select
  pc.place_id,
  pc.geog,
  lower(regexp_replace(pc.name, '[^a-zA-Z0-9]+', '', 'g')) as nname,
  -- Real Google data outranks an empty {} marker, which outranks nothing.
  (case when pc.google_accessibility is not null
         and pc.google_accessibility <> '{}'::jsonb then 4 else 0 end)
  + (case when pc.osm_accessibility is not null then 2 else 0 end)
  + (case when pc.image_url is not null then 1 else 0 end) as richness,
  pc.fetched_at,
  null::text as leader_id
from public.place_cache pc
where pc.name is not null
  and pc.geog is not null
  and lower(regexp_replace(pc.name, '[^a-zA-Z0-9]+', '', 'g')) <> '';

do $$
declare
  leader record;
begin
  loop
    select * into leader
    from place_cluster
    where leader_id is null
    order by richness desc, fetched_at desc nulls last, place_id
    limit 1;
    exit when not found;

    update place_cluster c
    set leader_id = leader.place_id
    where c.leader_id is null
      and c.nname = leader.nname
      and ST_DWithin(c.geog, leader.geog, 500);
  end loop;
end $$;

-- Fold every absorbed row's enrichment into its leader before deleting it, so
-- a merge can never lose a Google or OSM answer we already paid for.
create temp table leader_merge as
select
  c.leader_id,
  (array_agg(pc.google_accessibility order by pc.fetched_at desc nulls last)
     filter (where pc.google_accessibility is not null
                and pc.google_accessibility <> '{}'::jsonb))[1] as google_accessibility,
  (array_agg(pc.osm_accessibility order by pc.fetched_at desc nulls last)
     filter (where pc.osm_accessibility is not null))[1] as osm_accessibility,
  (array_agg(pc.google_place_id order by pc.fetched_at desc nulls last)
     filter (where pc.google_place_id is not null))[1] as google_place_id,
  (array_agg(pc.image_url order by pc.fetched_at desc nulls last)
     filter (where pc.image_url is not null))[1] as image_url,
  (array_agg(pc.image_attribution order by pc.fetched_at desc nulls last)
     filter (where pc.image_attribution is not null))[1] as image_attribution
from place_cluster c
join public.place_cache pc on pc.place_id = c.place_id
group by c.leader_id;

update public.place_cache l
set google_accessibility = coalesce(nullif(l.google_accessibility, '{}'::jsonb),
                                    m.google_accessibility,
                                    l.google_accessibility),
    osm_accessibility    = coalesce(l.osm_accessibility, m.osm_accessibility),
    google_place_id      = coalesce(l.google_place_id, m.google_place_id),
    image_url            = coalesce(l.image_url, m.image_url),
    image_attribution    = coalesce(l.image_attribution, m.image_attribution)
from leader_merge m
where l.place_id = m.leader_id;

-- Absorbed -> leader, everywhere place_id is referenced.
create temp table place_alias as
select place_id as old_id, leader_id as new_id
from place_cluster
where leader_id is not null
  and leader_id <> place_id;

-- The signal dedupe below probes this per row pair; without an index that is a
-- sequential scan inside a self-join.
create index on place_alias (old_id);

-- Signals that would collide once remapped: keep the freshest, matching how
-- accessibility_grade() decays on greatest(created_at, updated_at).
delete from public.accessibility_signals a
using public.accessibility_signals b
where a.id <> b.id
  and coalesce((select x.new_id from place_alias x where x.old_id = a.place_id), a.place_id)
    = coalesce((select x.new_id from place_alias x where x.old_id = b.place_id), b.place_id)
  and a.feature = b.feature and a.source = b.source
  and a.user_id is not distinct from b.user_id
  and (greatest(a.updated_at, a.created_at), a.id)
      < (greatest(b.updated_at, b.created_at), b.id);

update public.accessibility_signals s
set place_id = a.new_id
from place_alias a
where s.place_id = a.old_id;

update public.reviews r set place_id = a.new_id
from place_alias a where r.place_id = a.old_id;

-- saved_places is unique (user_id, place_id): drop the older of a pair that
-- would collide before remapping.
delete from public.saved_places a
using public.saved_places b
where a.id <> b.id
  and a.user_id = b.user_id
  and coalesce((select x.new_id from place_alias x where x.old_id = a.place_id), a.place_id)
    = coalesce((select x.new_id from place_alias x where x.old_id = b.place_id), b.place_id)
  and (a.created_at, a.id) < (b.created_at, b.id);

update public.saved_places s set place_id = a.new_id
from place_alias a where s.place_id = a.old_id;

update public.routes t set place_id = a.new_id
from place_alias a where t.place_id = a.old_id;

-- The archive tracks a Storage prefix derived from the id; the leader's own
-- row already covers the venue, so an absorbed one is just dropped and will be
-- regenerated stale on next use.
delete from public.venue_imdf_archives v
using place_alias a where v.place_id = a.old_id;

delete from public.place_cache pc
using place_alias a where pc.place_id = a.old_id;

drop table if exists place_alias;
drop table if exists leader_merge;
drop table if exists place_cluster;
drop function if exists public.__place_id_to_4dp(text);

-- --------------------------------------------------------------------------
-- 2. resolve_place_id -- what keeps identity stable from here
--
-- Called by place-accessibility before it mints a row. Returns the id of a
-- place we already know at this location under this name, or null.
--
-- Name equality is exact after stripping case and punctuation, NOT fuzzy. A
-- radius alone would merge a food court into the mall around it; a fuzzy name
-- would merge "Level 21 Mall" into "Level 21". The pair is what makes it safe.
--
-- The radius is the tuning knob and a genuine trade-off: too small and
-- MapKit's drift keeps minting duplicates, too large and two same-named
-- outlets of a chain on one street collapse into one. 250m covers every drift
-- observed within a real single venue in this table (max 189m) while staying
-- under the distance between separate branches.
-- --------------------------------------------------------------------------

create or replace function public.resolve_place_id(
  in_lat double precision,
  in_lng double precision,
  in_name text,
  radius_meters integer default 250
)
returns text
language sql
stable
as $$
  select pc.place_id
  from public.place_cache pc
  where pc.geog is not null
    and pc.name is not null
    and lower(regexp_replace(coalesce(in_name, ''), '[^a-zA-Z0-9]+', '', 'g')) <> ''
    and lower(regexp_replace(pc.name, '[^a-zA-Z0-9]+', '', 'g'))
      = lower(regexp_replace(in_name, '[^a-zA-Z0-9]+', '', 'g'))
    and ST_DWithin(
          pc.geog,
          ST_SetSRID(ST_MakePoint(in_lng, in_lat), 4326)::geography,
          radius_meters
        )
  order by pc.geog <-> ST_SetSRID(ST_MakePoint(in_lng, in_lat), 4326)::geography
  limit 1;
$$;

comment on function public.resolve_place_id is
  'Maps an incoming (lat, lng, name) onto the id of a place already in place_cache within radius_meters carrying the same punctuation-insensitive name. Null when this is a place we have not seen. Exists because MapKit returns a different coordinate for the same venue depending on the search region, so the coordinate alone is not an identity.';

-- Backs the name half of the lookup; the GIST index on geog already covers the
-- spatial half.
create index if not exists place_cache_normalized_name_idx
  on public.place_cache (lower(regexp_replace(name, '[^a-zA-Z0-9]+', '', 'g')))
  where name is not null;
