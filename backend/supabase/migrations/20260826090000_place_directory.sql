-- ==========================================================================
-- Place directory (2026-08-26)
--
-- Turns place_cache from a pure cache-of-whatever-MapKit-found into something
-- that can also hold a curated directory of places we seeded ourselves — the
-- south-Bali malls in the migration that follows this one.
--
-- Three pieces, in dependency order:
--
--   1. Detail columns. place_cache held name/lat/lng/image and nothing a
--      person would recognise as a listing. A directory row needs the address,
--      phone, hours and floor count that OSM actually gives us, plus the
--      provenance fields that keep seeded rows honest about where they came
--      from.
--
--   2. place_aliases + resolve_place_id v2. THE piece that makes seeding work
--      at all. resolve_place_id matches names exactly, and the names differ
--      between every source: OSM says "Beachwalk Bali", MapKit says "Beachwalk
--      Shopping Center", the seed says one of them. Without an alias table a
--      client lookup does not find the seeded row, mints a coordinate-keyed
--      duplicate beside it, and the seed is dead on arrival. This is not
--      hypothetical — it is the same failure already visible in the live
--      table, which holds five "Beachwalk Shopping Center" rows, five "Icon
--      Bali Mall" rows and five Park23 rows under two spellings.
--
--   3. places_directory_nearby(). The read side. nearby_places() has existed
--      since the initial schema and nothing has ever called it; the client
--      gets its pins from MKLocalSearch alone, which is why seeding data
--      changes nothing on the map by itself. This RPC is what the
--      places-nearby Edge Function serves to the app.
--
-- NOTE FOR WHOEVER PUSHES THIS: 20260821160000_place_identity.sql is still
-- local-only — `supabase migration list --linked` shows no remote entry, and
-- resolve_place_id genuinely does not exist on the project (PGRST202 when
-- called). place-accessibility already handles that by logging and falling
-- back to a coordinate key, which is exactly why the duplicates above kept
-- accumulating. `db push` applies it ahead of this file, which is what should
-- happen — just expect that migration's backfill to do real work on its first
-- run.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Directory detail columns
-- --------------------------------------------------------------------------

alter table public.place_cache
  add column if not exists address text,
  add column if not exists city text,
  add column if not exists postcode text,
  add column if not exists phone text,
  add column if not exists website text,
  add column if not exists opening_hours text,
  add column if not exists levels smallint,
  add column if not exists category text,
  -- True for rows we imported deliberately rather than minted from a client
  -- lookup. Drives the directory RPC below, and marks which rows a re-import
  -- is allowed to overwrite.
  add column if not exists is_seeded boolean not null default false,
  -- ODbL requires attribution to travel with the data. Storing it per row
  -- rather than assuming it in the client means a future second source does
  -- not silently inherit OSM's credit.
  add column if not exists data_attribution text,
  add column if not exists data_source text;

comment on column public.place_cache.is_seeded is
  'True for curated directory rows imported from a seed file. False for rows minted on demand by place-accessibility from a client lookup. The directory RPC returns only seeded rows — the on-demand ones are a cache of wherever users happened to look, which is not a browsable list.';

create index if not exists place_cache_seeded_idx
  on public.place_cache (is_seeded)
  where is_seeded;

-- --------------------------------------------------------------------------
-- 2. place_aliases
-- --------------------------------------------------------------------------

create table if not exists public.place_aliases (
  place_id        text not null references public.place_cache (place_id) on delete cascade,
  -- Pre-normalised on write: lower(), punctuation stripped. Same shape
  -- resolve_place_id derives from the incoming name, so the lookup is a plain
  -- index probe rather than a function call per row.
  normalized_name text not null,
  -- What the alias actually looked like, kept for debugging and for anyone
  -- reading the table trying to work out where an entry came from.
  display_name    text not null,
  source          text not null default 'seed',
  created_at      timestamptz not null default now(),
  primary key (place_id, normalized_name)
);

-- Deliberately NOT unique on normalized_name alone: "Level 21" or "Discovery
-- Mall" can name a different venue in another city, and resolve_place_id
-- disambiguates by distance. Uniqueness per (place, alias) is all that's
-- wanted — the same alias twice for one place is the actual mistake.
create index if not exists place_aliases_normalized_name_idx
  on public.place_aliases (normalized_name);

alter table public.place_aliases enable row level security;

drop policy if exists "place aliases are publicly readable" on public.place_aliases;
create policy "place aliases are publicly readable"
  on public.place_aliases for select
  to anon, authenticated
  using (true);
-- Writes only via migrations / the service_role Edge Functions, same stance as
-- place_cache: no insert or update policy for anon/authenticated, on purpose.

comment on table public.place_aliases is
  'Alternate names one venue is known by across sources. OSM, MapKit and Google each spell the same mall differently ("Beachwalk Bali" / "Beachwalk Shopping Center"), and resolve_place_id matches names exactly — this table is what stops each spelling minting its own place_cache row.';

-- --------------------------------------------------------------------------
-- 2b. resolve_place_id v2 — alias-aware
--
-- Same contract as before (in_lat, in_lng, in_name, radius_meters) so
-- place-accessibility and submit-accessibility-review need no change: they
-- call it exactly as they do today and simply start resolving names they
-- previously missed.
--
-- Two tiers, alias first:
--
--   tier 0  a curated alias, within ALIAS_RADIUS (1km)
--   tier 1  an exact name match, within radius_meters (250m, unchanged)
--
-- The alias tier gets the wider radius because it is curated — a human wrote
-- down that these two names are one venue, so the only remaining question is
-- whether this is that venue or a namesake, and two same-named malls within a
-- kilometre of each other do not happen. It needs the width: the live table's
-- own Icon Bali rows span roughly 600m and its Lippo Mall Kuta rows likewise,
-- both well past the 250m the name tier allows. The exact-name tier keeps the
-- tighter radius precisely because nobody vouched for it, and 250m is what
-- separates two branches of a chain on one street.
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
  with target as (
    select
      ST_SetSRID(ST_MakePoint(in_lng, in_lat), 4326)::geography as g,
      lower(regexp_replace(coalesce(in_name, ''), '[^a-zA-Z0-9]+', '', 'g')) as n
  ),
  candidates as (
    -- tier 0: curated alias
    select pc.place_id, pc.geog, 0 as tier
    from public.place_aliases a
    join public.place_cache pc on pc.place_id = a.place_id
    cross join target t
    where t.n <> ''
      and a.normalized_name = t.n
      and pc.geog is not null
      and ST_DWithin(pc.geog, t.g, greatest(radius_meters, 1000))

    union all

    -- tier 1: exact name, the original rule
    select pc.place_id, pc.geog, 1 as tier
    from public.place_cache pc
    cross join target t
    where t.n <> ''
      and pc.name is not null
      and pc.geog is not null
      and lower(regexp_replace(pc.name, '[^a-zA-Z0-9]+', '', 'g')) = t.n
      and ST_DWithin(pc.geog, t.g, radius_meters)
  )
  select c.place_id
  from candidates c
  cross join target t
  order by c.tier, c.geog <-> t.g
  limit 1;
$$;

comment on function public.resolve_place_id is
  'Maps an incoming (lat, lng, name) onto the id of a place we already know: first via a curated place_aliases entry within 1km, then via an exact punctuation-insensitive name match within radius_meters. Null when this is a place we have not seen. Exists because the same venue arrives under a different name and a different coordinate depending on whether MapKit, OSM or a seed file supplied it.';

-- --------------------------------------------------------------------------
-- 3. places_directory_nearby — the read side
--
-- Returns seeded directory rows near a point, each with the single worst
-- accessibility verdict we hold for it, so the caller can colour a map pin
-- without a second round trip per place.
--
-- Seeded rows only. The rest of place_cache is a cache of wherever users
-- happened to look — 7-Elevens in Cupertino, a salon in San Francisco — and
-- listing that as a directory would be nonsense.
--
-- 'unknown' is returned as the grade when we hold nothing, which is honest and
-- is what the client renders as an unrated pin. Note this deliberately does
-- NOT filter out ungraded places the way nearby_places() does: a mall nobody
-- has reviewed is exactly the one we want a contributor to walk into.
-- --------------------------------------------------------------------------

-- accessibility_value is declared yes < no < limited < unknown, which is
-- declaration order, NOT severity order — min() over it would call 'yes' the
-- worst value in the set. The rank is spelled out below for that reason.
create or replace function public.places_directory_nearby(
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
  graded_features integer
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
    coalesce(g.graded_features, 0) as graded_features
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
  'Curated directory places near a point, nearest first, each with the worst accessibility verdict currently held for it. Backs the places-nearby Edge Function. Returns ungraded places too — an unreviewed mall is the one most worth sending a contributor to.';
