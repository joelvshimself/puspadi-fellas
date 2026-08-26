-- ==========================================================================
-- Web-sourced accessibility observations (2026-08-26)
--
-- Two rows. That is not a shortfall in the search — it is the finding. Six
-- Bali malls were researched against their own sites, accessibility blogs,
-- accommodation guides and traveller forums; Park23, Lippo Mall Kuta and
-- Beachwalk returned nothing usable, and the other three yielded one quotable
-- observation each, of which two carry a concrete structural fact. Padding
-- that to a round number per mall would mean inventing facility answers for
-- buildings nobody has written about, and those answers drive the badge a
-- wheelchair user reads before deciding whether to make the trip.
--
-- PLACES ARE RESOLVED BY NAME, NOT BY THE SUPPLIED COORDINATE. The research
-- pass returned a place_id for each observation and both were wrong: Mal Bali
-- Galeria's was 1322m from the real anchor — outside the alias radius, so a
-- coordinate lookup would have failed outright rather than obviously — and
-- Discovery's was 732m off. The names, however, are both exact aliases we
-- already hold. place_aliases is the authority here; a coordinate that arrives
-- with a text claim is a guess about the claim, not a measurement.
--
-- Every field the source did not state is left null and therefore never
-- reaches accessibility_signals. `blockers` is deliberately empty: the schema's
-- vocabulary is 'no_ramp' and 'too_small', and "the lift does not serve L2/L3"
-- is neither — it belongs in the prose, where it is quoted verbatim, rather
-- than mangled into a tag that means something else.
-- ==========================================================================

with observation (alias, source_url, quote, entrance_accessible, elevator_exists,
                  elevator_accessible, entrance_location, has_dropoff_ramp) as (
  values
    (
      'Mal Bali Galeria',
      'https://www.tripadvisor.com/ShowUserReviews-g297697-d2027967-r256093269-Mal_Bali_Galeria-Kuta_Kuta_District_Bali.html',
      'This entire complex is ''wheelchair friendly'' with ramps and lifts.',
      'yes'::public.accessibility_value,
      true,
      null::public.accessibility_value,   -- "lifts" exist; nothing said about using one in a wheelchair
      'other',
      true
    ),
    (
      'Discovery Shopping Mall',
      'https://www.tripadvisor.com/ShowUserReviews-g297697-d1602617-r991950201-Discovery_Shopping_Mall-Kuta_Kuta_District_Bali.html',
      'Has lift but not very wheelchair accessible. Basement to L1 is fine. From L1 to L2/3 is not able to do so (as per some staff we enquired working there).',
      null::public.accessibility_value,   -- says nothing about the entrance
      true,
      'no'::public.accessibility_value,
      null,
      null::boolean
    )
),
resolved as (
  select o.*, a.place_id, pc.lat, pc.lng
  from observation o
  join public.place_aliases a
    on a.normalized_name = lower(regexp_replace(o.alias, '[^a-zA-Z0-9]+', '', 'g'))
  join public.place_cache pc on pc.place_id = a.place_id
),
inserted as (
  insert into public.reviews (
    user_id, place_id, apple_maps_id, lat, lng,
    provenance, source_url,
    entrance_accessible, elevator_exists, elevator_accessible,
    elevator_review_text, notes
  )
  select
    null,                                  -- nobody in the app wrote this
    r.place_id,
    'imported:' || r.place_id,             -- stable key, so a re-run updates rather than stacks
    r.lat, r.lng,
    'imported'::public.review_provenance,
    r.source_url,
    r.entrance_accessible,
    r.elevator_exists,
    r.elevator_accessible,
    r.quote,                               -- verbatim; the card renders it as the body
    r.quote
  from resolved r
  -- Idempotent: the apple_maps_id above is unique per place, so a second run
  -- of this migration adds nothing.
  where not exists (
    select 1 from public.reviews x
    where x.place_id = r.place_id and x.apple_maps_id = 'imported:' || r.place_id
  )
  returning id, place_id
)
insert into public.review_entrances (review_id, location, has_dropoff_ramp, review_text, sort_order)
select i.id, r.entrance_location, r.has_dropoff_ramp, r.quote, 0
from inserted i
join resolved r on r.place_id = i.place_id
where r.entrance_location is not null;

do $$
declare
  n integer;
  sig record;
begin
  select count(*) into n from public.reviews where provenance = 'imported';
  raise notice 'imported observations now in reviews: %', n;

  for sig in
    select s.place_id, pc.name, s.feature, s.value, s.confidence_weight
    from public.accessibility_signals s
    join public.place_cache pc on pc.place_id = s.place_id
    where s.source = 'imported'
    order by pc.name, s.feature
  loop
    raise notice '  signal: % / % = % (weight %)', sig.name, sig.feature, sig.value, sig.confidence_weight;
  end loop;
end $$;
