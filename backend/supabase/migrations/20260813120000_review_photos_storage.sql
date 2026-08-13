-- Community review photos for facility notes (lobby / basement / elevator / toilet).
-- Bytes live in Storage; Postgres keeps public URL arrays
-- (review_entrances.photo_urls, reviews.elevator_photo_urls, toilet_photo_urls).
--
-- Path convention (written by the iOS client):
--   reviews/{appleMapsId}/{facility}/{uuid}.jpg
--
-- TODO: re-enable auth before production — anon insert is intentional for
-- device testing (same stance as submit-accessibility-review user_id = null).

insert into storage.buckets (id, name, public)
values ('review-photos', 'review-photos', true)
on conflict (id) do nothing;

-- Public read (also covered by public = true; policy keeps explicit access clear).
drop policy if exists "review photos are publicly readable" on storage.objects;
create policy "review photos are publicly readable"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'review-photos');

-- Anon/authenticated insert under reviews/** only.
drop policy if exists "anon can upload review photos" on storage.objects;
create policy "anon can upload review photos"
  on storage.objects for insert
  to anon, authenticated
  with check (
    bucket_id = 'review-photos'
    and (storage.foldername(name))[1] = 'reviews'
  );
