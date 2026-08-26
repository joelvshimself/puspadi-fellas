-- ==========================================================================
-- Pseudonymous reviewers + review provenance (2026-08-26)
--
-- TWO SEPARATE THINGS, both about who a review card says wrote it.
--
-- 1. PSEUDONYMS. Until now place-reviews returned profiles.display_name — a
--    real name, typed during onboarding — on a public, unauthenticated
--    endpoint, next to a statement about that person's disability and a photo
--    of where they were. Every review card is now signed with a stable
--    per-account handle instead. Stable is the point: the same handle across
--    places is what lets a reader recognise a contributor whose judgement
--    they've come to trust, which a per-review random string would destroy.
--    Someone who WANTS their real name can have it, via show_real_name.
--
--    "Pseudonymous", not "anonymous": the row still carries user_id, the
--    account is still accountable, and the owner can still find their own
--    reviews. It is the public surface that is pseudonymous.
--
-- 2. PROVENANCE. reviews is about to hold rows that no community member
--    wrote — anything imported from a data source. On an accessibility app a
--    wrong "the entrance has a ramp" sends a wheelchair user to a building
--    they cannot enter, so a machine-imported claim must never be able to
--    present itself as a person's first-hand report. Every row now says which
--    it is, defaulting to 'community' for the 29 rows already there, all of
--    which are genuine.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. Provenance
-- --------------------------------------------------------------------------

do $$ begin
  create type review_provenance as enum ('community', 'imported', 'osm');
exception when duplicate_object then null;
end $$;

alter table public.reviews
  add column if not exists provenance review_provenance not null default 'community';

comment on column public.reviews.provenance is
  'Who authored this. community = a person using the app, the default and the only value submit-accessibility-review ever writes. imported/osm = brought in from a data source; the client labels these so a reader is never shown machine-derived data as somebody''s first-hand account.';

create index if not exists reviews_provenance_idx
  on public.reviews (provenance)
  where provenance <> 'community';

-- --------------------------------------------------------------------------
-- 2. Pseudonyms
--
-- Derived from the account id, so it is stable for the life of the account and
-- needs no extra state to stay that way. Two words plus, only when that pair
-- is already taken, a disambiguating number — a handle a person can actually
-- say out loud, which "user_8f3a1c" is not.
--
-- Deliberately NOT a hash the client can invert: the wordlists are small
-- (24 x 24), so a handle identifies a person only within this app, and knowing
-- one tells you nothing about the account behind it.
-- --------------------------------------------------------------------------

alter table public.profiles
  add column if not exists pseudonym text,
  -- Opt-in, default false. The safe state has to be the default one: a person
  -- who never opens settings must not be publishing their real name next to a
  -- disclosure about their disability.
  add column if not exists show_real_name boolean not null default false;

create unique index if not exists profiles_pseudonym_key
  on public.profiles (pseudonym)
  where pseudonym is not null;

create or replace function public.generate_pseudonym(seed uuid)
returns text
language plpgsql
volatile
as $$
declare
  adjectives constant text[] := array[
    'Amber','Bright','Calm','Coral','Curious','Dawn','Eager','Fern',
    'Gentle','Golden','Harbour','Indigo','Jade','Keen','Lively','Mellow',
    'Nimble','Opal','Patient','Quiet','River','Steady','Tidal','Wander'
  ];
  nouns constant text[] := array[
    'Albatross','Bamboo','Compass','Dolphin','Ember','Frangipani',
    'Gecko','Harbour','Ibis','Jasmine','Kite','Lantern',
    'Monsoon','Nutmeg','Orchid','Pelican','Quartz','Reef',
    'Sailfish','Tamarind','Umbrella','Volcano','Willow','Zephyr'
  ];
  n_adj constant integer := array_length(adjectives, 1);
  n_noun constant integer := array_length(nouns, 1);
  h bigint;
  candidate text;
  suffix integer := 0;
begin
  -- (x % n + n) % n rather than abs(x) % n: hashtextextended can return
  -- -9223372036854775808, and abs() of that overflows bigint.
  h := hashtextextended(seed::text, 0);

  loop
    candidate :=
      adjectives[1 + ((h % n_adj + n_adj) % n_adj)] || ' ' ||
      nouns[1 + (((h / n_adj) % n_noun + n_noun) % n_noun)] ||
      case when suffix = 0 then '' else ' ' || suffix::text end;

    exit when not exists (
      select 1 from public.profiles p where p.pseudonym = candidate
    );

    -- 576 pairs, so a collision is unlikely and a second one vanishingly so;
    -- the counter is the guarantee rather than the expected path.
    suffix := suffix + 1;
    if suffix > 999 then
      raise exception 'could not allocate a pseudonym for %', seed;
    end if;
  end loop;

  return candidate;
end;
$$;

-- Existing accounts first, oldest first so the handles are allocated in a
-- stable order rather than whatever sequence the planner picks.
do $$
declare
  r record;
begin
  for r in
    select id from public.profiles where pseudonym is null order by created_at, id
  loop
    update public.profiles
    set pseudonym = public.generate_pseudonym(r.id)
    where id = r.id;
  end loop;
end $$;

-- New accounts get one at profile-creation time. handle_new_user() inserts the
-- profile row from an auth.users trigger, so hanging this off profiles rather
-- than editing that function keeps the two concerns apart.
create or replace function public.assign_pseudonym()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.pseudonym is null then
    new.pseudonym := public.generate_pseudonym(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_assign_pseudonym on public.profiles;
create trigger profiles_assign_pseudonym
  before insert on public.profiles
  for each row execute function public.assign_pseudonym();

comment on column public.profiles.pseudonym is
  'Public handle shown on this account''s review cards. Stable for the life of the account so a reader can recognise a contributor across places. profiles is RLS-locked to its owner, so this only ever reaches the public through the place-reviews Edge Function.';

comment on column public.profiles.show_real_name is
  'Opt-in. When true, place-reviews signs this account''s reviews with display_name instead of the pseudonym. Default false — a person who never opens settings must not be publishing their real name beside a disclosure about their disability.';
