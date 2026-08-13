-- Puspadi Fellas — pivot from Apify/TikTok scraping to Google Places +
-- OpenStreetMap as base accessibility data sources, plus a confidence-weighted,
-- time-decayed Accessibility Grade fed by both that base data and crowdsourced
-- signals. See docs/specs.md for the full writeup and the decisions behind this.
--
-- This is a NEW migration on top of 20260812073342_init_schema.sql, which is
-- already applied to the live project — we evolve the schema, we don't edit
-- that file.

-- =========================================================================
-- place_cache: repurposed from "Apify raw scrape + on-device synthesis" to
-- "Google Places + OSM base data for this place". The grade is no longer
-- stored here — it's computed live from accessibility_signals (see below),
-- because time-decay depends on the current time, not a snapshot.
-- =========================================================================

alter table public.place_cache
  drop column if exists raw_scrape,
  drop column if exists synthesized_label,
  add column if not exists name text,
  add column if not exists osm_id text,
  add column if not exists google_accessibility jsonb,
  add column if not exists osm_accessibility jsonb,
  add column if not exists fetched_at timestamptz;

-- Base-data staleness is now purely about "is our Google/OSM fetch too old",
-- independent of user signals — a new review/confirmation should NOT force
-- a re-fetch of the (unrelated, slow-changing) base API data.
drop trigger if exists reviews_mark_stale on public.reviews;
drop trigger if exists routes_mark_stale on public.routes;
drop function if exists public.mark_place_stale();

-- Descriptive/text search now caches Google's Text Search result LIST
-- (candidate place_ids), which is a different shape from place_cache's
-- per-place record — kept as its own small table rather than overloading
-- place_cache with a second meaning.
create table if not exists public.search_query_cache (
  query_hash  text primary key,
  place_ids   text[] not null,
  fetched_at  timestamptz not null default now(),
  expires_at  timestamptz
);

alter table public.search_query_cache enable row level security;

create policy "search cache is publicly readable"
  on public.search_query_cache for select
  to anon, authenticated
  using (true);
-- writes only via the Edge Function's service_role key, same pattern as
-- place_cache — no insert/update policy defined for anon/authenticated.

-- =========================================================================
-- accessibility_signals: one unified ledger for every piece of evidence
-- about a place's accessibility, whichever source it came from — Google,
-- OSM, a detailed review, or a one-tap proximity-nudge confirmation. The
-- Accessibility Grade is computed live from this table (confidence-weighted,
-- time-decayed), not stored, since decay depends on "now".
-- =========================================================================

do $$ begin
  create type accessibility_feature as enum ('entrance', 'parking', 'restroom', 'seating');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type accessibility_value as enum ('yes', 'no', 'limited', 'unknown');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type accessibility_source as enum ('google', 'osm', 'review', 'confirmation');
exception when duplicate_object then null;
end $$;

create table if not exists public.accessibility_signals (
  id                uuid primary key default gen_random_uuid(),
  place_id          text not null,
  feature           accessibility_feature not null,
  value             accessibility_value not null,
  source            accessibility_source not null,
  user_id           uuid references auth.users (id) on delete set null,  -- null for google/osm
  confidence_weight numeric not null default 1.0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- One signal per (place, feature, source, user): a repeat confirmation from
  -- the same user updates the existing row (refreshes recency) instead of
  -- stacking weight, so a single person can't inflate confidence by spamming.
  unique (place_id, feature, source, user_id)
);

create index if not exists accessibility_signals_place_idx on public.accessibility_signals (place_id);

alter table public.accessibility_signals enable row level security;

create policy "accessibility signals are publicly readable"
  on public.accessibility_signals for select
  to anon, authenticated
  using (true);

create policy "authenticated users can submit their own signal"
  on public.accessibility_signals for insert
  to authenticated
  with check (source in ('review', 'confirmation') and auth.uid() = user_id);

create policy "users can update their own signal"
  on public.accessibility_signals for update
  to authenticated
  using (auth.uid() = user_id);
-- google/osm-sourced rows are written only by the Edge Function via
-- service_role, which bypasses RLS — same pattern as place_cache.

-- Confidence-weighted, time-decayed grade per place/feature, computed live.
-- Half-life default 180 days — tune once we have real usage data; see
-- docs/specs.md open questions. Default confidence_weight per source
-- (google=0.6, osm=0.5, review=0.4, confirmation=0.2) is applied by the
-- inserting code (Edge Function / app), not hardcoded here, so it stays
-- easy to tune without a migration.
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
        power(0.5, extract(epoch from (now() - s.created_at)) / 86400.0 / halflife_days)
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

-- Feeds a detailed review's structured answers into the same signal ledger,
-- so a review and a one-tap confirmation are just two sources of the same
-- kind of evidence rather than two disconnected systems.
alter table public.reviews
  add column if not exists entrance_accessible accessibility_value,
  add column if not exists parking_accessible accessibility_value,
  add column if not exists restroom_accessible accessibility_value,
  add column if not exists seating_accessible accessibility_value,
  add column if not exists notes text;

create or replace function public.review_to_signals()
returns trigger
language plpgsql
as $$
begin
  if new.entrance_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'entrance', new.entrance_accessible, 'review', new.user_id, 0.4)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  if new.parking_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'parking', new.parking_accessible, 'review', new.user_id, 0.4)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  if new.restroom_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'restroom', new.restroom_accessible, 'review', new.user_id, 0.4)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  if new.seating_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'seating', new.seating_accessible, 'review', new.user_id, 0.4)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists reviews_to_signals on public.reviews;
create trigger reviews_to_signals
  after insert on public.reviews
  for each row execute function public.review_to_signals();

-- =========================================================================
-- Proximity-triggered nudges (StreetComplete-style): the client periodically
-- calls this to find nearby places with low-confidence/missing features and
-- registers a CLCircularRegion geofence for each one; on region entry, the
-- app surfaces a single-tap "is this accessible?" quest for the specific
-- missing feature. Correlated subquery over accessibility_grade() is fine
-- at v1 traffic; revisit (e.g. a scheduled materialized view) if this RPC
-- becomes a hot path bottleneck.
-- =========================================================================

create or replace function public.places_needing_confirmation(
  user_lat double precision,
  user_lng double precision,
  radius_meters integer default 500,
  confidence_threshold numeric default 0.5
)
returns table (place_id text, name text, lat double precision, lng double precision, missing_feature accessibility_feature)
language sql
stable
as $$
  select pc.place_id, pc.name, pc.lat, pc.lng, f.feature
  from public.place_cache pc
  cross join unnest(enum_range(null::accessibility_feature)) as f(feature)
  where pc.geog is not null
    and ST_DWithin(pc.geog, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, radius_meters)
    and coalesce(
      (select ag.confidence from public.accessibility_grade(pc.place_id) ag where ag.feature = f.feature),
      0
    ) < confidence_threshold;
$$;
