-- Production schema for GitHub Pages + Supabase.
-- Run in Supabase Dashboard > SQL Editor > New query > Run.
-- Idempotent: safe to run more than once.
--
-- Part 1/2 -- profiles + access control (auth)
-- Part 2/2 -- application data (campaigns, contents, team, references)

-- ===========================================================================
-- 1) profiles
-- ===========================================================================
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

drop policy if exists "profiles_read_own" on public.profiles;
create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_insert_own_pending" on public.profiles;
create policy "profiles_insert_own_pending" on public.profiles
  for insert with check (auth.uid() = id and is_admin = false and status = 'pending');

drop policy if exists "profiles_update_own_contact" on public.profiles;
create policy "profiles_update_own_contact" on public.profiles
  for update using (auth.uid() = id or public.is_admin())
  with check (auth.uid() = id or public.is_admin());

-- ===========================================================================
-- 2) application data
--    Each row keeps the complete app object in `data` (jsonb) so nothing is
--    lost, plus duplicated scalar columns used for filtering and ordering.
-- ===========================================================================

create table if not exists public.projects (
  id text primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text,
  created_at timestamptz,
  data jsonb not null default '{}'::jsonb
);

create table if not exists public.campaigns (
  id text primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id text,
  name text,
  start_date date,
  end_date date,
  created_at timestamptz,
  data jsonb not null default '{}'::jsonb
);

create table if not exists public.storyboards (
  id text primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  campaign_id text,
  project_id text,
  name text,
  content_type text,
  deadline date,
  publish_date date,
  status text,
  created_at timestamptz,
  data jsonb not null default '{}'::jsonb
);

create table if not exists public.team_members (
  id text primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text,
  phone text,
  data jsonb not null default '{}'::jsonb
);

create table if not exists public.reference_items (
  id text primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('countries','institutions')),
  name text,
  data jsonb not null default '{}'::jsonb
);

create table if not exists public.app_settings (
  owner_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now(),
  data jsonb not null default '{}'::jsonb
);

create index if not exists campaigns_owner_idx      on public.campaigns(owner_id, created_at desc);
create index if not exists campaigns_project_idx    on public.campaigns(owner_id, project_id);
create index if not exists storyboards_owner_idx    on public.storyboards(owner_id, created_at desc);
create index if not exists storyboards_campaign_idx on public.storyboards(owner_id, campaign_id);
create index if not exists team_members_owner_idx   on public.team_members(owner_id, name);
create index if not exists reference_items_owner_idx on public.reference_items(owner_id, kind, name);

alter table public.projects        enable row level security;
alter table public.campaigns       enable row level security;
alter table public.storyboards     enable row level security;
alter table public.team_members    enable row level security;
alter table public.reference_items enable row level security;
alter table public.app_settings    enable row level security;

drop policy if exists "projects_own" on public.projects;
create policy "projects_own" on public.projects for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "campaigns_own" on public.campaigns;
create policy "campaigns_own" on public.campaigns for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "storyboards_own" on public.storyboards;
create policy "storyboards_own" on public.storyboards for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "team_members_own" on public.team_members;
create policy "team_members_own" on public.team_members for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "reference_items_own" on public.reference_items;
create policy "reference_items_own" on public.reference_items for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "app_settings_own" on public.app_settings;
create policy "app_settings_own" on public.app_settings for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- First admin, after signing up as `admin` in the app:
--   update public.profiles set is_admin = true, status = 'active' where username = 'admin';
