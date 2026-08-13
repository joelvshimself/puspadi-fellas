-- Flatten contribution contract out of reviews.details into real columns +
-- review_entrances child rows. Backfill existing details, then drop the blob.

alter table public.reviews
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists elevator_exists boolean,
  add column if not exists elevator_wheelchair_accessible boolean,
  add column if not exists elevator_blockers text[] not null default '{}',
  add column if not exists elevator_review_text text,
  add column if not exists elevator_photo_urls text[] not null default '{}',
  add column if not exists has_disabled_toilet boolean,
  add column if not exists toilet_review_text text,
  add column if not exists toilet_photo_urls text[] not null default '{}';

create table if not exists public.review_entrances (
  id                uuid primary key default gen_random_uuid(),
  review_id         uuid not null references public.reviews (id) on delete cascade,
  location          text not null check (location in ('lobby', 'basement', 'exit_side', 'other')),
  has_dropoff_ramp  boolean,
  has_rails         boolean,
  door_type         text check (door_type is null or door_type in ('manual', 'automatic')),
  is_wide_enough    boolean,
  review_text       text,
  photo_urls        text[] not null default '{}',
  sort_order        integer not null default 0,
  created_at        timestamptz not null default now()
);

create index if not exists review_entrances_review_idx
  on public.review_entrances (review_id);

alter table public.review_entrances enable row level security;

drop policy if exists "review entrances are publicly readable" on public.review_entrances;
create policy "review entrances are publicly readable"
  on public.review_entrances for select
  to anon, authenticated
  using (true);

-- Writes go through the Edge Function (service_role). No insert/update policies
-- for anon/authenticated — same pattern as place_cache.

-- Backfill scalars from details jsonb (only where still present).
update public.reviews
set
  lat = coalesce(lat, (details->>'lat')::double precision),
  lng = coalesce(lng, (details->>'lng')::double precision),
  elevator_exists = coalesce(
    elevator_exists,
    (details->'elevator'->>'exists')::boolean
  ),
  elevator_wheelchair_accessible = coalesce(
    elevator_wheelchair_accessible,
    (details->'elevator'->>'wheelchairAccessible')::boolean
  ),
  elevator_blockers = case
    when details->'elevator'->'blockers' is not null
      and jsonb_typeof(details->'elevator'->'blockers') = 'array'
    then coalesce(
      (
        select array_agg(b)
        from jsonb_array_elements_text(details->'elevator'->'blockers') as b
      ),
      '{}'
    )
    else elevator_blockers
  end,
  elevator_review_text = coalesce(
    elevator_review_text,
    nullif(details->'elevator'->'review'->>'text', '')
  ),
  elevator_photo_urls = case
    when details->'elevator'->'review'->'photoUrls' is not null
      and jsonb_typeof(details->'elevator'->'review'->'photoUrls') = 'array'
    then coalesce(
      (
        select array_agg(u)
        from jsonb_array_elements_text(details->'elevator'->'review'->'photoUrls') as u
      ),
      '{}'
    )
    else elevator_photo_urls
  end,
  has_disabled_toilet = coalesce(
    has_disabled_toilet,
    (details->'toilet'->>'hasDisabledToilet')::boolean
  ),
  toilet_review_text = coalesce(
    toilet_review_text,
    nullif(details->'toilet'->'review'->>'text', '')
  ),
  toilet_photo_urls = case
    when details->'toilet'->'review'->'photoUrls' is not null
      and jsonb_typeof(details->'toilet'->'review'->'photoUrls') = 'array'
    then coalesce(
      (
        select array_agg(u)
        from jsonb_array_elements_text(details->'toilet'->'review'->'photoUrls') as u
      ),
      '{}'
    )
    else toilet_photo_urls
  end
where details is not null;

-- Backfill entrance rows (skip if this review already has any).
insert into public.review_entrances (
  review_id,
  location,
  has_dropoff_ramp,
  has_rails,
  door_type,
  is_wide_enough,
  review_text,
  photo_urls,
  sort_order
)
select
  r.id,
  e.elem->>'location',
  (e.elem->>'hasDropoffRamp')::boolean,
  (e.elem->>'hasRails')::boolean,
  case
    when e.elem->>'doorType' in ('manual', 'automatic') then e.elem->>'doorType'
    else null
  end,
  (e.elem->>'isWideEnough')::boolean,
  nullif(e.elem->'review'->>'text', ''),
  coalesce(
    (
      select array_agg(u)
      from jsonb_array_elements_text(coalesce(e.elem->'review'->'photoUrls', '[]'::jsonb)) as u
    ),
    '{}'
  ),
  (e.ord - 1)::integer
from public.reviews r
cross join lateral jsonb_array_elements(coalesce(r.details->'entrances', '[]'::jsonb))
  with ordinality as e(elem, ord)
where r.details is not null
  and e.elem->>'location' in ('lobby', 'basement', 'exit_side', 'other')
  and not exists (
    select 1 from public.review_entrances re where re.review_id = r.id
  );

alter table public.reviews drop column if exists details;
