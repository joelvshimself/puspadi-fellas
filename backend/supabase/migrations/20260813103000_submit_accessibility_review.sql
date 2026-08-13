-- submit-accessibility-review (Owner 3): store the iPhone contribution payload
-- on reviews, fan elevator into accessibility_signals, and allow null user_id
-- while JWT auth is temporarily disabled for device testing.
-- TODO: re-enable NOT NULL on reviews.user_id when auth returns.

-- Elevator joins entrance/parking/restroom/seating in the grade vocabulary.
alter type public.accessibility_feature add value if not exists 'elevator';

alter table public.reviews
  add column if not exists apple_maps_id text,
  add column if not exists details jsonb,
  add column if not exists elevator_accessible accessibility_value;

-- Testing only: anon Edge Function inserts with user_id = null via service_role.
alter table public.reviews
  alter column user_id drop not null;

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
  if new.elevator_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'elevator', new.elevator_accessible, 'review', new.user_id, 0.4)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  return new;
end;
$$;
