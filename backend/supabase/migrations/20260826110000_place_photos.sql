-- ==========================================================================
-- place_photos — venue photography, separate from review photos (2026-08-26)
--
-- place_cache.image_url holds ONE image and is owned by the enrichment
-- pipeline: Mapillary downloads it, the merge moves it, the TTL refreshes it.
-- A venue photo taken from the mall's own website is none of those things —
-- it is curated, it is several per place, and it carries a credit and a source
-- page that have to survive. Putting it in image_url would mean the next
-- Mapillary refresh overwrites a photo a human chose.
--
-- LICENCE, RECORDED HERE BECAUSE IT MATTERS LATER
-- ----------------------------------------------
-- These are the malls' own copyrighted marketing photographs, taken from their
-- own sites, used to identify the business they depict and credited to it.
-- That is a deliberate product decision, not a licence we hold. The columns
-- exist to make it reversible and auditable: source_page says where each image
-- came from, so "take our photo down" is one DELETE, and credit is rendered
-- next to the image rather than buried here.
--
-- Openly-licensed sources are still preferred where they have coverage and are
-- untouched by this: Mapillary (CC BY-SA), then Look Around, then a map
-- snapshot. This is a fallback for the places those cannot see.
-- ==========================================================================

do $$ begin
  create type place_photo_source as enum ('official_website', 'community', 'mapillary');
exception when duplicate_object then null;
end $$;

create table if not exists public.place_photos (
  id           uuid primary key default gen_random_uuid(),
  place_id     text not null references public.place_cache (place_id) on delete cascade,
  url          text not null,
  source       place_photo_source not null,
  -- The page the image was taken from. Not decoration: this is what makes a
  -- takedown request answerable without guesswork.
  source_page  text,
  -- Shown with the image. "Photo © Seminyak Village".
  credit       text,
  width        integer,
  height       integer,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  -- Re-running the upload must update the existing row rather than stack a
  -- second copy of the same photo.
  unique (place_id, url)
);

create index if not exists place_photos_place_idx
  on public.place_photos (place_id, sort_order);

alter table public.place_photos enable row level security;

drop policy if exists "place photos are publicly readable" on public.place_photos;
create policy "place photos are publicly readable"
  on public.place_photos for select
  to anon, authenticated
  using (true);
-- Writes only via service_role (the upload script / Edge Functions), same
-- stance as place_cache: no insert or update policy for anon or authenticated.

comment on table public.place_photos is
  'Curated photographs OF a venue, as opposed to review_photos which document a specific facility. Each row records where the image came from and who to credit, so an image can be attributed on screen and removed on request.';

-- Public bucket, same as place-images: these are meant to be shown to anyone,
-- and writes go through service_role which bypasses RLS.
insert into storage.buckets (id, name, public)
values ('place-photos', 'place-photos', true)
on conflict (id) do nothing;

drop policy if exists "place photos bucket is publicly readable" on storage.objects;
create policy "place photos bucket is publicly readable"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'place-photos');
