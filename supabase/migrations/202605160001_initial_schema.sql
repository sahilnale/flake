create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  initials text not null,
  avatar_color text not null default 'ff6b9d',
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  thread_key text unique,
  name text not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.moves (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups(id) on delete cascade,
  title text not null,
  subtitle text not null default '',
  location_name text not null,
  location_lat double precision,
  location_lng double precision,
  starts_at timestamptz not null,
  creator_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.rsvps (
  move_id uuid references public.moves(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  status text not null check (status in ('locked_in', 'sending_it', 'flaked', 'silent')),
  updated_at timestamptz not null default now(),
  primary key (move_id, user_id)
);

create table if not exists public.attendance (
  move_id uuid references public.moves(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  status text not null check (status in ('showed', 'missed')),
  settled_by uuid references public.profiles(id),
  settled_at timestamptz not null default now(),
  primary key (move_id, user_id)
);

create table if not exists public.excused_votes (
  id uuid primary key default gen_random_uuid(),
  move_id uuid references public.moves(id) on delete cascade,
  petitioner_id uuid references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'denied')),
  points_at_risk int not null,
  closes_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.excused_vote_ballots (
  vote_id uuid references public.excused_votes(id) on delete cascade,
  voter_id uuid references public.profiles(id) on delete cascade,
  choice text not null check (choice in ('approve', 'deny')),
  created_at timestamptz not null default now(),
  primary key (vote_id, voter_id)
);

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.moves enable row level security;
alter table public.rsvps enable row level security;
alter table public.attendance enable row level security;
alter table public.excused_votes enable row level security;
alter table public.excused_vote_ballots enable row level security;

drop policy if exists "users can read own profile" on public.profiles;
create policy "users can read own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = id);

drop policy if exists "users can insert own profile" on public.profiles;
create policy "users can insert own profile"
on public.profiles for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "authenticated users can create groups" on public.groups;
create policy "authenticated users can create groups"
on public.groups for insert
to authenticated
with check (created_by = (select auth.uid()));

drop policy if exists "members can read their groups" on public.groups;
create policy "members can read their groups"
on public.groups for select
to authenticated
using (
  exists (
    select 1 from public.group_members gm
    where gm.group_id = groups.id
    and gm.user_id = (select auth.uid())
  )
);

drop policy if exists "users can join groups as themselves" on public.group_members;
create policy "users can join groups as themselves"
on public.group_members for insert
to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "members can read memberships" on public.group_members;
create policy "members can read memberships"
on public.group_members for select
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.group_members gm
    where gm.group_id = group_members.group_id
    and gm.user_id = (select auth.uid())
  )
);

drop policy if exists "members can create moves" on public.moves;
create policy "members can create moves"
on public.moves for insert
to authenticated
with check (
  creator_id = (select auth.uid())
  and exists (
    select 1 from public.group_members gm
    where gm.group_id = moves.group_id
    and gm.user_id = (select auth.uid())
  )
);

drop policy if exists "members can read moves" on public.moves;
create policy "members can read moves"
on public.moves for select
to authenticated
using (
  exists (
    select 1 from public.group_members gm
    where gm.group_id = moves.group_id
    and gm.user_id = (select auth.uid())
  )
);

drop policy if exists "members can read rsvps" on public.rsvps;
create policy "members can read rsvps"
on public.rsvps for select
to authenticated
using (
  exists (
    select 1
    from public.moves m
    join public.group_members gm on gm.group_id = m.group_id
    where m.id = rsvps.move_id
    and gm.user_id = (select auth.uid())
  )
);

drop policy if exists "users can insert own rsvp" on public.rsvps;
create policy "users can insert own rsvp"
on public.rsvps for insert
to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "users can update own rsvp" on public.rsvps;
create policy "users can update own rsvp"
on public.rsvps for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
