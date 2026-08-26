-- ==========================================================================
-- Imported reviews are evidence, not testimony (2026-08-26)
--
-- reviews.provenance has existed since the pseudonyms migration but only ever
-- held 'community'. Rows sourced from the web are about to arrive, and as the
-- trigger stands they would be indistinguishable from a first-hand report the
-- moment they touch accessibility_signals:
--
--   * review_to_signals() writes source='review' at weight 0.4, and
--   * accessibility_grade()'s review_wins CTE lets source='review' OVERRIDE
--     Google and OSM outright for any feature it answers.
--
-- That override exists because somebody stood at the door and looked. A
-- traveller's aside on a review site, transcribed by a researcher, has not
-- earned it — it would let one sentence outrank a provider's structured
-- answer for a building nobody from the community has visited.
--
-- So imported rows get their own source. 'imported' falls through to the
-- blended branch of accessibility_grade, where it competes on weight instead
-- of overriding: 0.25, below a community review's 0.4 and below OSM's 0.5 and
-- Google's 0.6. In practice that means an imported claim CANNOT flip a feature
-- a provider already answers, and DOES answer a feature nobody else has —
-- which is the useful case. Discovery Mall is the example: Google and OSM
-- describe its entrance and parking and say nothing about the lift, while the
-- imported observation says the lift does not reach the upper floors. That
-- fact should reach a wheelchair user; it should not silently rewrite the
-- entrance grade around it.
--
-- Split across two migrations on purpose: Postgres will not let a new enum
-- value be USED in the same transaction that adds it, and db push wraps each
-- migration in one. This file adds the value and the plumbing;
-- 20260826150000 inserts rows that depend on it.
-- ==========================================================================

alter type public.accessibility_source add value if not exists 'imported';

-- Where the claim was read. Required in practice for anything not written by a
-- community member: it is the attribution shown on the card, and the answer to
-- "where did this come from" without archaeology.
alter table public.reviews
  add column if not exists source_url text;

comment on column public.reviews.source_url is
  'For imported rows, the page the claim was read on. Rendered on the review card as the attribution, and the record of provenance if the claim is ever disputed. Null for community contributions, which are their own source.';

create or replace function public.review_to_signals()
returns trigger
language plpgsql
as $$
declare
  -- Community contributions keep the behaviour they have always had. Anything
  -- else is evidence from elsewhere and is weighted, and sourced, accordingly.
  sig_source public.accessibility_source :=
    case when new.provenance = 'community' then 'review' else 'imported' end;
  sig_weight numeric :=
    case when new.provenance = 'community' then 0.4 else 0.25 end;
begin
  -- Newest wins, within its own kind. A new community review supersedes the
  -- previous community review; a re-import supersedes the previous import.
  -- Crucially they no longer clear each other: an import must not delete a
  -- signal a person contributed.
  delete from public.accessibility_signals
  where place_id = new.place_id
    and source = sig_source;

  if new.entrance_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'entrance', new.entrance_accessible, sig_source, new.user_id, sig_weight)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  if new.parking_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'parking', new.parking_accessible, sig_source, new.user_id, sig_weight)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  if new.restroom_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'restroom', new.restroom_accessible, sig_source, new.user_id, sig_weight)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  if new.seating_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'seating', new.seating_accessible, sig_source, new.user_id, sig_weight)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  if new.elevator_accessible is not null then
    insert into public.accessibility_signals (place_id, feature, value, source, user_id, confidence_weight)
    values (new.place_id, 'elevator', new.elevator_accessible, sig_source, new.user_id, sig_weight)
    on conflict (place_id, feature, source, user_id)
    do update set value = excluded.value, updated_at = now();
  end if;
  return new;
end;
$$;
