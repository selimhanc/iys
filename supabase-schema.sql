-- Production auth schema for GitHub Pages + Supabase.
-- Run this in Supabase Dashboard > SQL Editor (New query > Run).
-- Idempotent: safe to run more than once.

-- ---------------------------------------------------------------------------
-- 1) profiles table
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  phone text,
  status text not null default 'pending' check (status in ('pending','active','rejected')),
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

alter table public.profiles enable row level security;

-- ---------------------------------------------------------------------------
-- 2) admin check helper (SECURITY DEFINER avoids RLS recursion)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 3) auto-create the profile row when a user signs up
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, phone)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'username',''), split_part(new.email, '@', 1)),
    nullif(new.raw_user_meta_data->>'phone','')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 4) RLS policies
-- ---------------------------------------------------------------------------
drop policy if exists "profiles_read_own" on public.profiles;
create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_insert_own_pending" on public.profiles;
create policy "profiles_insert_own_pending" on public.profiles
  for insert with check (auth.uid() = id and is_admin = false and status = 'pending');

-- users may edit their own phone only; status/is_admin are admin-only
drop policy if exists "profiles_update_own_contact" on public.profiles;
create policy "profiles_update_own_contact" on public.profiles
  for update using (auth.uid() = id or public.is_admin())
  with check (auth.uid() = id or public.is_admin());

-- ---------------------------------------------------------------------------
-- 5) first admin
--    Sign up as `admin` in the app first, then run this once:
-- update public.profiles set is_admin = true, status = 'active' where username = 'admin';
-- ---------------------------------------------------------------------------

-- Admin approval/reset (approve, reject, set password) runs through the
-- `admin-users` Edge Function using the service role key.
-- Never expose that key in GitHub.
