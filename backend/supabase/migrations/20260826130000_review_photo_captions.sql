-- Per-photo captions, parallel to existing photo_urls arrays (same index order).
--
-- Renumbered from 20260826100000 on 2026-08-26. That version was already taken
-- by 20260826100000_fix_merged_place_images.sql, which had been pushed — two
-- files claiming one version made `db push` refuse the whole batch with
-- "local migration files to be inserted before the last migration on remote".
-- Nothing had applied this yet and it is add-column-if-not-exists throughout,
-- so renumbering costs nothing; leaving it would have blocked every future
-- push. Timestamps are the ordering key, so two branches adding a migration on
-- the same day at the same round hour will collide again — worth picking the
-- minute from the clock rather than rounding.

alter table public.reviews
  add column if not exists elevator_photo_captions text[] not null default '{}',
  add column if not exists toilet_photo_captions text[] not null default '{}';

alter table public.review_entrances
  add column if not exists photo_captions text[] not null default '{}';
