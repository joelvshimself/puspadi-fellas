-- Per-photo captions, parallel to existing photo_urls arrays (same index order).

alter table public.reviews
  add column if not exists elevator_photo_captions text[] not null default '{}',
  add column if not exists toilet_photo_captions text[] not null default '{}';

alter table public.review_entrances
  add column if not exists photo_captions text[] not null default '{}';
