-- Newest community review wins for grade; enable Realtime on reviews so
-- open Place Detail clients can refresh when another device submits.

-- ==========================================================================
-- A. review_to_signals — drop prior review signals for the place so only
-- the newest review's answers remain as source='review'.
-- ==========================================================================

create or replace function public.review_to_signals()
returns trigger
language plpgsql
as $$
begin
  delete from public.accessibility_signals
  where place_id = new.place_id
    and source = 'review';

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

-- ==========================================================================
-- B. accessibility_grade — review source overrides providers for features
-- it answers; otherwise keep the decayed weighted blend.
-- ==========================================================================

create or replace function public.accessibility_grade(
  target_place_id text,
  halflife_days integer default 180
)
returns table (feature accessibility_feature, best_value accessibility_value, confidence numeric)
language sql
stable
as $$
  with review_wins as (
    select distinct on (s.feature)
      s.feature,
      s.value,
      s.confidence_weight as weight
    from public.accessibility_signals s
    where s.place_id = target_place_id
      and s.source = 'review'
    order by s.feature, greatest(s.created_at, s.updated_at) desc
  ),
  blended as (
    select
      s.feature,
      s.value,
      sum(
        s.confidence_weight *
        power(
          0.5,
          extract(epoch from (now() - greatest(s.created_at, s.updated_at))) / 86400.0 / halflife_days
        )
      ) as weight
    from public.accessibility_signals s
    where s.place_id = target_place_id
      and s.source is distinct from 'review'
    group by s.feature, s.value
  ),
  blended_ranked as (
    select feature, value, weight,
           row_number() over (partition by feature order by weight desc) as rnk
    from blended
  ),
  blended_best as (
    select feature, value, weight
    from blended_ranked
    where rnk = 1
  )
  select
    coalesce(r.feature, b.feature) as feature,
    coalesce(r.value, b.value) as best_value,
    coalesce(r.weight, b.weight) as confidence
  from review_wins r
  full outer join blended_best b on b.feature = r.feature;
$$;

-- ==========================================================================
-- C. Realtime — clients subscribe to new reviews for an open place.
-- ==========================================================================

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reviews'
  ) then
    alter publication supabase_realtime add table public.reviews;
  end if;
end $$;
