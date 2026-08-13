-- Fixes from the pre-merge code review of the Google/OSM pivot branch.

-- ==========================================================================
-- #1 (HIGH) — Grade-forgery RLS gap. The client holds the anon key and can
-- POST directly to PostgREST; the old policies bounded neither
-- confidence_weight nor (on UPDATE) anything at all, so an authenticated user
-- could insert a signal with an arbitrary weight and dominate any place's
-- grade. Cap client-writable weight to each source's intended value and add a
-- with-check on UPDATE. Google (0.6) / OSM (0.5) rows are written only by the
-- service_role Edge Function, which bypasses RLS, so this doesn't affect them.
-- ==========================================================================

drop policy if exists "authenticated users can submit their own signal" on public.accessibility_signals;
create policy "authenticated users can submit their own signal"
  on public.accessibility_signals for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and (
      (source = 'review'::accessibility_source and confidence_weight <= 0.4)
      or (source = 'confirmation'::accessibility_source and confidence_weight <= 0.2)
    )
  );

drop policy if exists "users can update their own signal" on public.accessibility_signals;
create policy "users can update their own signal"
  on public.accessibility_signals for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and (
      (source = 'review'::accessibility_source and confidence_weight <= 0.4)
      or (source = 'confirmation'::accessibility_source and confidence_weight <= 0.2)
    )
  );

-- ==========================================================================
-- #2 (MEDIUM-HIGH) — Duplicate google/osm signals. The unique index is
-- NULLS DISTINCT (Postgres default), so the Edge Function's upserts with
-- user_id = NULL never conflict and insert a new duplicate row on every
-- refresh; accessibility_grade() sums them, inflating confidence without
-- bound. Collapse existing dupes, then rebuild the index as NULLS NOT
-- DISTINCT so NULL user_ids conflict and upserts update in place.
-- ==========================================================================

-- Collapse existing duplicates, keeping one row per logical key (NULLs equal).
delete from public.accessibility_signals a
using public.accessibility_signals b
where a.ctid < b.ctid
  and a.place_id = b.place_id
  and a.feature = b.feature
  and a.source = b.source
  and a.user_id is not distinct from b.user_id;

alter table public.accessibility_signals
  drop constraint if exists accessibility_signals_place_id_feature_source_user_id_key;
drop index if exists public.accessibility_signals_place_id_feature_source_user_id_key;

create unique index if not exists accessibility_signals_place_id_feature_source_user_id_key
  on public.accessibility_signals (place_id, feature, source, user_id)
  nulls not distinct;

-- ==========================================================================
-- #4 (MEDIUM) — Decay clock never refreshed. accessibility_grade() decays on
-- created_at, but re-confirmations / re-fetches only bump updated_at, so a
-- "refreshed" signal keeps aging from its original timestamp. Decay on the
-- most recent of the two instead. (The Edge Function change in this same
-- review now bumps updated_at on its google/osm upserts.)
-- ==========================================================================

create or replace function public.accessibility_grade(
  target_place_id text,
  halflife_days integer default 180
)
returns table (feature accessibility_feature, best_value accessibility_value, confidence numeric)
language sql
stable
as $$
  with weighted as (
    select
      s.feature,
      s.value,
      sum(
        s.confidence_weight *
        power(
          0.5,
          extract(epoch from (now() - greatest(s.created_at, s.updated_at))) / 86400.0 / halflife_days
        )
      ) as weight
    from public.accessibility_signals s
    where s.place_id = target_place_id
    group by s.feature, s.value
  ),
  ranked as (
    select feature, value, weight,
           row_number() over (partition by feature order by weight desc) as rnk
    from weighted
  )
  select feature, value as best_value, weight as confidence
  from ranked
  where rnk = 1;
$$;

-- ==========================================================================
-- #5 (LOW) — nearby_places() still filters on synthesized_label, a column
-- dropped in the pivot, so it errors at call time (dormant: nothing invokes
-- it yet). Recreate it filtering on actually-present accessibility data.
-- ==========================================================================

create or replace function public.nearby_places(
  user_lat double precision,
  user_lng double precision,
  radius_meters integer default 2000
)
returns setof public.place_cache
language sql
stable
as $$
  select *
  from public.place_cache
  where geog is not null
    and ST_DWithin(geog, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, radius_meters)
    and (google_accessibility is not null or osm_accessibility is not null)
  order by geog <-> ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography;
$$;
