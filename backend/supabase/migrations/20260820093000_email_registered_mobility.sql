-- Lookup whether an email already has an Auth user (anon-callable; used by the
-- unified Welcome screen to branch login vs signup).
-- Also stores onboarding mobility choices on profiles.

alter table public.profiles
  add column if not exists mobility_aids text[] not null default '{}';

create or replace function public.email_registered(check_email text)
returns boolean
language sql
stable
security definer
set search_path = auth, public
as $$
  select exists (
    select 1 from auth.users
    where lower(email) = lower(trim(check_email))
  );
$$;

revoke all on function public.email_registered(text) from public;
grant execute on function public.email_registered(text) to anon, authenticated;
