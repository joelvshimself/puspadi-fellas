-- Place images from Mapillary (open, CC BY-SA street-level imagery).
--
-- Unlike Google/Apple imagery, Mapillary's license PERMITS storing the actual
-- image with attribution — so we cache the downloaded bytes in Supabase
-- Storage and keep a permanent public URL here. (Mapillary's own thumbnail
-- URLs expire on a TTL, so caching the URL wouldn't work; caching the bytes
-- does.) The Edge Function is the only writer.

alter table public.place_cache
  add column if not exists image_url text,
  add column if not exists image_attribution text;

-- Public bucket: images are openly licensed and meant to be shown to anyone.
-- Writes happen only via the Edge Function's service_role key (bypasses RLS),
-- so no extra write policy is needed; public = true allows anonymous reads
-- of the stored images by URL.
insert into storage.buckets (id, name, public)
values ('place-images', 'place-images', true)
on conflict (id) do nothing;
