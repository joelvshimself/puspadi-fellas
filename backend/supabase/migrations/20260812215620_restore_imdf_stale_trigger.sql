-- Fix a regression in 20260812215139_maps_data_pivot.sql: dropping
-- mark_place_stale() correctly decoupled place_cache from reviews/routes,
-- but that function also marked venue_imdf_archives stale (for Record
-- Route's IMDF rendering, unrelated to this pivot) — restore just that half.

create or replace function public.mark_imdf_archive_stale()
returns trigger
language plpgsql
as $$
begin
  insert into public.venue_imdf_archives (place_id, storage_path, is_stale)
    values (new.place_id, 'venue_imdf/' || new.place_id || '/', true)
  on conflict (place_id) do update set is_stale = true;

  return new;
end;
$$;

drop trigger if exists reviews_mark_imdf_stale on public.reviews;
create trigger reviews_mark_imdf_stale
  after insert on public.reviews
  for each row execute function public.mark_imdf_archive_stale();

drop trigger if exists routes_mark_imdf_stale on public.routes;
create trigger routes_mark_imdf_stale
  after insert on public.routes
  for each row execute function public.mark_imdf_archive_stale();
