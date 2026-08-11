-- Puspadi Fellas — initial schema
-- Mirrors docs/specs.md §5 (Auth Strategy) and §6 (Caching Strategy).
-- Owner 1 (Search & Discover): place_cache, nearby_places()
-- Owner 2 (Save & Share): profiles, folders, saved_places
-- Owner 3 (Review & Record Route): reviews, routes, venue_imdf_archives

create extension if not exists postgis;
create extension if not exists pgcrypto;

-- =========================================================================
-- Owner 1 — Search & Discover: global shared cache
-- =========================================================================

create table if not exists public.place_cache (
  id                 uuid primary key default gen_random_uuid(),
  place_id           text unique,        -- exact-location search key
  query_hash         text unique,        -- descriptive/fuzzy search key
  lat                double precision,
  lng                double precision,
  geog               geography(point, 4326)
                       generated always as (
                         case when lat is not null and lng is not null
                           then ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
                         end
                       ) stored,
  raw_scrape         jsonb,              -- Apify output, pre-synthesis
  synthesized_label  jsonb,              -- on-device Foundation Models output
  is_stale           boolean not null default false,
  expires_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint place_cache_has_key check (place_id is not null or query_hash is not null)
);

create index if not exists place_cache_geog_idx on public.place_cache using gist (geog);
create index if not exists place_cache_stale_idx on public.place_cache (is_stale);

alter table public.place_cache enable row level security;

-- Readable by anyone (anon or authenticated) — Discover Nearby and Search both
-- read this directly. Writes only happen via the Edge Function's service_role
-- key, which bypasses RLS entirely — no insert/update policy is defined for
-- anon/authenticated on purpose, so a client can never poison the shared cache.
create policy "place_cache is publicly readable"
  on public.place_cache for select
  to anon, authenticated
  using (true);

-- RPC used by Flow A's Discover Nearby path — a pure Postgres/PostGIS read,
-- no Apify call, no Edge Function involved.
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
    and synthesized_label is not null
  order by geog <-> ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography;
$$;

-- =========================================================================
-- Owner 2 — Save & Share: account-gated personal data
-- =========================================================================

-- Profile row per auth.users — this is what docs/specs.md §7 calls "users".
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "users can read own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

create policy "users can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Auto-create a profile row whenever someone signs in for the first time
-- (Auth Gate flow: Sign in with Apple / email OTP -> profile created here).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table if not exists public.folders (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now()
);

alter table public.folders enable row level security;

create policy "owner can manage own folders"
  on public.folders for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.saved_places (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  place_id   text not null,
  folder_id  uuid references public.folders (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, place_id)
);

alter table public.saved_places enable row level security;

create policy "owner can manage own saved places"
  on public.saved_places for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- =========================================================================
-- Owner 3 — Review & Record Route: community-contributed accessibility data
-- =========================================================================

create table if not exists public.reviews (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  place_id     text not null,
  entrance_exit jsonb,   -- facilities at entrance/exit
  indoor       jsonb,    -- indoor space accessibility
  outdoor      jsonb,    -- outdoor space accessibility
  created_at   timestamptz not null default now()
);

alter table public.reviews enable row level security;

create policy "reviews are publicly readable"
  on public.reviews for select
  to anon, authenticated
  using (true);

create policy "authenticated users can submit reviews"
  on public.reviews for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "owner can update or delete own review"
  on public.reviews for update
  to authenticated
  using (auth.uid() = user_id);

create policy "owner can delete own review"
  on public.reviews for delete
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.routes (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  place_id           text not null,
  waypoints          jsonb not null,  -- [{lat,lng,timestamp,flag}, ...] raw trace
  positioning_method text not null check (positioning_method in ('imdf', 'fallback')),
  created_at         timestamptz not null default now()
);

alter table public.routes enable row level security;

create policy "routes are publicly readable"
  on public.routes for select
  to anon, authenticated
  using (true);

create policy "authenticated users can submit routes"
  on public.routes for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Self-hosted per-venue IMDF archive metadata (docs/specs.md §4.6). The actual
-- manifest.json + GeoJSON feature files live in Supabase Storage under
-- venue_imdf/{place_id}/ — this table just tracks freshness. Never submitted
-- to Apple's Indoor Maps Program; rendered client-side via MKGeoJSONDecoder.
create table if not exists public.venue_imdf_archives (
  place_id      text primary key,
  storage_path  text not null,
  generated_at  timestamptz,
  is_stale      boolean not null default true,
  created_at    timestamptz not null default now()
);

alter table public.venue_imdf_archives enable row level security;

create policy "imdf archive metadata is publicly readable"
  on public.venue_imdf_archives for select
  to anon, authenticated
  using (true);

-- =========================================================================
-- Cache invalidation triggers (docs/specs.md §6)
-- New review or route for a place marks place_cache AND the venue's IMDF
-- archive stale, so the next request forces a refresh instead of silently
-- serving outdated accessibility info.
-- =========================================================================

create or replace function public.mark_place_stale()
returns trigger
language plpgsql
as $$
begin
  update public.place_cache
    set is_stale = true, updated_at = now()
    where place_id = new.place_id;

  insert into public.venue_imdf_archives (place_id, storage_path, is_stale)
    values (new.place_id, 'venue_imdf/' || new.place_id || '/', true)
  on conflict (place_id) do update set is_stale = true;

  return new;
end;
$$;

drop trigger if exists reviews_mark_stale on public.reviews;
create trigger reviews_mark_stale
  after insert on public.reviews
  for each row execute function public.mark_place_stale();

drop trigger if exists routes_mark_stale on public.routes;
create trigger routes_mark_stale
  after insert on public.routes
  for each row execute function public.mark_place_stale();
