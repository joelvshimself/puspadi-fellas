-- ==========================================================================
-- API cost / rate-limit fixes (2026-08-21)
--
-- #1  place_cache.refresh_claimed_at — an atomic claim so that when N requests
--     for the same cold place arrive together, exactly ONE of them pays for
--     the Google Places lookup, the Overpass query and the Mapillary download.
--     Previously all N read the same empty row, all N decided "needs refresh",
--     and all N ran the whole (paid) pipeline.
--
-- #2  place_id precision 5 decimals -> 4 decimals (~1m -> ~11m).
--     MapKit hands back a slightly different coordinate for the same physical
--     place depending on how the client reached it — a nearby sweep, a text
--     search, or a tapped map POI. At 1m each variant minted its own place_id:
--     its own place_cache row (its own paid Google call), its own signals, and
--     reviews/saved places scattered across ids that all mean one venue.
--     Rewriting to 4 decimals MERGES those, which is the point.
--
--     Keep in step with canonicalPlaceId() in
--     supabase/functions/place-accessibility/index.ts and PlaceCacheStore.key
--     on the client. All three must produce the same string — the two clients
--     use printf "%.4f" / Number.toFixed(4), which ROUND, so this rounds too.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- #1 Refresh claim
-- --------------------------------------------------------------------------

alter table public.place_cache
  add column if not exists refresh_claimed_at timestamptz;

comment on column public.place_cache.refresh_claimed_at is
  'Set by place-accessibility while it is enriching this place; cleared when done. A claim older than a couple of minutes is treated as abandoned, so a worker killed mid-flight cannot wedge a place until the 90-day TTL.';

-- Partial: only claimed rows are ever looked at.
create index if not exists place_cache_refresh_claimed_idx
  on public.place_cache (refresh_claimed_at)
  where refresh_claimed_at is not null;

-- --------------------------------------------------------------------------
-- #2 place_id precision
-- --------------------------------------------------------------------------

-- Rewrites `loc_<lat>_<lng>` to 4-decimal precision. Anything not in that
-- shape is returned untouched rather than mangled — place_id is plain text and
-- older rows may predate the convention.
--
-- round(numeric, 4) fixes the scale at 4, so ::text keeps the trailing zeros
-- ("115.2" -> "115.2000") and matches what the two clients format.
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
  return 'loc_'
      || round(parts[1]::numeric, 4)::text
      || '_'
      || round(parts[2]::numeric, 4)::text;
end;
$fn$;

-- ---- place_cache (place_id is unique) ------------------------------------
-- Several old rows can collapse onto one new id. The most recently fetched row
-- keeps the identity, but any accessibility/image data the others hold is
-- folded into it first — a merge must never LOSE a Google or OSM answer, or we
-- would pay for that lookup again.
create temp table place_cache_merge as
with remapped as (
  select
    pc.id,
    pc.place_id,
    public.__place_id_to_4dp(pc.place_id) as new_id,
    pc.google_accessibility,
    pc.osm_accessibility,
    pc.google_place_id,
    pc.image_url,
    pc.image_attribution,
    pc.fetched_at
  from public.place_cache pc
  where pc.place_id is not null
)
select
  (array_agg(r.id order by r.fetched_at desc nulls last, r.id))[1] as winner_id,
  r.new_id,
  (array_agg(r.google_accessibility order by r.fetched_at desc nulls last)
     filter (where r.google_accessibility is not null))[1] as google_accessibility,
  (array_agg(r.osm_accessibility order by r.fetched_at desc nulls last)
     filter (where r.osm_accessibility is not null))[1] as osm_accessibility,
  (array_agg(r.google_place_id order by r.fetched_at desc nulls last)
     filter (where r.google_place_id is not null))[1] as google_place_id,
  (array_agg(r.image_url order by r.fetched_at desc nulls last)
     filter (where r.image_url is not null))[1] as image_url,
  (array_agg(r.image_attribution order by r.fetched_at desc nulls last)
     filter (where r.image_attribution is not null))[1] as image_attribution
from remapped r
group by r.new_id;

-- Losers go FIRST. A winner's new id can be byte-identical to a loser's
-- current id (the loser was already at 4dp), so updating before deleting would
-- trip the unique constraint.
delete from public.place_cache pc
where pc.place_id is not null
  and not exists (select 1 from place_cache_merge m where m.winner_id = pc.id);

update public.place_cache pc
set place_id             = m.new_id,
    google_accessibility = coalesce(pc.google_accessibility, m.google_accessibility),
    osm_accessibility    = coalesce(pc.osm_accessibility, m.osm_accessibility),
    google_place_id      = coalesce(pc.google_place_id, m.google_place_id),
    image_url            = coalesce(pc.image_url, m.image_url),
    image_attribution    = coalesce(pc.image_attribution, m.image_attribution)
from place_cache_merge m
where pc.id = m.winner_id
  and pc.place_id is distinct from m.new_id;

-- ---- accessibility_signals (unique place_id, feature, source, user_id) ----
-- Two merged ids mean two signals for one logical key. Keep the freshest:
-- accessibility_grade() decays on greatest(created_at, updated_at), so the
-- newest row is the one that would have dominated anyway.
delete from public.accessibility_signals a
using public.accessibility_signals b
where a.id <> b.id
  and public.__place_id_to_4dp(a.place_id) = public.__place_id_to_4dp(b.place_id)
  and a.feature = b.feature
  and a.source = b.source
  and a.user_id is not distinct from b.user_id
  and (greatest(a.updated_at, a.created_at), a.id)
      < (greatest(b.updated_at, b.created_at), b.id);

update public.accessibility_signals
set place_id = public.__place_id_to_4dp(place_id)
where public.__place_id_to_4dp(place_id) is distinct from place_id;

-- ---- saved_places (unique user_id, place_id) -----------------------------
delete from public.saved_places a
using public.saved_places b
where a.id <> b.id
  and a.user_id = b.user_id
  and public.__place_id_to_4dp(a.place_id) = public.__place_id_to_4dp(b.place_id)
  and (a.created_at, a.id) < (b.created_at, b.id);

update public.saved_places
set place_id = public.__place_id_to_4dp(place_id)
where public.__place_id_to_4dp(place_id) is distinct from place_id;

-- ---- reviews (nothing unique on place_id — every review survives) --------
-- The merge that actually matters to users: reviews written against two ids
-- 1m apart for one mall now group under a single place.
update public.reviews
set place_id = public.__place_id_to_4dp(place_id)
where public.__place_id_to_4dp(place_id) is distinct from place_id;

-- ---- routes --------------------------------------------------------------
update public.routes
set place_id = public.__place_id_to_4dp(place_id)
where public.__place_id_to_4dp(place_id) is distinct from place_id;

-- ---- venue_imdf_archives (place_id is the primary key) -------------------
-- storage_path embeds the id, so it is rebuilt alongside and the row is marked
-- stale — whatever sits under the old Storage prefix is regenerated on the
-- next refresh rather than migrated.
delete from public.venue_imdf_archives a
using public.venue_imdf_archives b
where a.place_id <> b.place_id
  and public.__place_id_to_4dp(a.place_id) = public.__place_id_to_4dp(b.place_id)
  and a.place_id > b.place_id;

update public.venue_imdf_archives
set place_id     = public.__place_id_to_4dp(place_id),
    storage_path = 'venue_imdf/' || public.__place_id_to_4dp(place_id) || '/',
    is_stale     = true
where public.__place_id_to_4dp(place_id) is distinct from place_id;

drop table if exists place_cache_merge;
drop function if exists public.__place_id_to_4dp(text);
