-- Fix infinite recursion in group_members RLS policies.
-- The old policy queried group_members from within a group_members policy → loop.
-- Solution: a SECURITY DEFINER function that bypasses RLS to fetch the caller's group IDs.

create or replace function public.my_group_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select group_id from public.group_members where user_id = auth.uid()
$$;

-- Fix group_members: use the helper instead of a self-referencing subquery
drop policy if exists "members can read memberships" on public.group_members;
create policy "members can read memberships"
on public.group_members for select
to authenticated
using (
  group_id in (select public.my_group_ids())
);

-- Fix groups: same helper (avoids triggering group_members RLS from inside groups RLS)
drop policy if exists "members can read their groups" on public.groups;
create policy "members can read their groups"
on public.groups for select
to authenticated
using (
  id in (select public.my_group_ids())
);

-- Fix profiles: use helper so co-member lookup doesn't chain through group_members RLS
drop policy if exists "group members can read co-member profiles" on public.profiles;
create policy "group members can read co-member profiles"
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or id in (
    select gm.user_id
    from public.group_members gm
    where gm.group_id in (select public.my_group_ids())
  )
);

-- Fix moves: use helper
drop policy if exists "members can create moves" on public.moves;
create policy "members can create moves"
on public.moves for insert
to authenticated
with check (
  creator_id = auth.uid()
  and group_id in (select public.my_group_ids())
);

drop policy if exists "members can read moves" on public.moves;
create policy "members can read moves"
on public.moves for select
to authenticated
using (
  group_id in (select public.my_group_ids())
);

drop policy if exists "creator can update move" on public.moves;
create policy "creator can update move"
on public.moves for update
to authenticated
using (group_id in (select public.my_group_ids()))
with check (group_id in (select public.my_group_ids()));

-- Fix rsvps
drop policy if exists "members can read rsvps" on public.rsvps;
create policy "members can read rsvps"
on public.rsvps for select
to authenticated
using (
  exists (
    select 1 from public.moves m
    where m.id = rsvps.move_id
      and m.group_id in (select public.my_group_ids())
  )
);

-- Fix attendance
drop policy if exists "members can read attendance" on public.attendance;
create policy "members can read attendance"
on public.attendance for select
to authenticated
using (
  exists (
    select 1 from public.moves m
    where m.id = attendance.move_id
      and m.group_id in (select public.my_group_ids())
  )
);

drop policy if exists "members can record attendance" on public.attendance;
create policy "members can record attendance"
on public.attendance for all
to authenticated
using (
  exists (
    select 1 from public.moves m
    where m.id = attendance.move_id
      and m.group_id in (select public.my_group_ids())
  )
)
with check (
  exists (
    select 1 from public.moves m
    where m.id = attendance.move_id
      and m.group_id in (select public.my_group_ids())
  )
);

-- Fix excused_votes
drop policy if exists "members can read excused votes" on public.excused_votes;
create policy "members can read excused votes"
on public.excused_votes for select
to authenticated
using (
  exists (
    select 1 from public.moves m
    where m.id = excused_votes.move_id
      and m.group_id in (select public.my_group_ids())
  )
);

-- Fix excused_vote_ballots
drop policy if exists "members can read ballots" on public.excused_vote_ballots;
create policy "members can read ballots"
on public.excused_vote_ballots for select
to authenticated
using (
  exists (
    select 1
    from public.excused_votes ev
    join public.moves m on m.id = ev.move_id
    where ev.id = excused_vote_ballots.vote_id
      and m.group_id in (select public.my_group_ids())
  )
);
