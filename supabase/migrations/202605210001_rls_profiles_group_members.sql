-- Allow authenticated users to read profiles of people in the same group
drop policy if exists "group members can read co-member profiles" on public.profiles;
create policy "group members can read co-member profiles"
on public.profiles for select
to authenticated
using (
  -- own profile
  (select auth.uid()) = id
  or
  -- co-member in any shared group
  exists (
    select 1
    from public.group_members my_groups
    join public.group_members their_groups
      on their_groups.group_id = my_groups.group_id
    where my_groups.user_id = (select auth.uid())
      and their_groups.user_id = profiles.id
  )
);

-- Allow members to update their own RSVP status at any time
drop policy if exists "users can upsert own rsvp" on public.rsvps;
create policy "users can upsert own rsvp"
on public.rsvps for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Add unique constraint on excused_votes so upsert works
alter table public.excused_votes
  drop constraint if exists excused_votes_move_petitioner_unique;
alter table public.excused_votes
  add constraint excused_votes_move_petitioner_unique
  unique (move_id, petitioner_id);

-- Allow members to read excused votes for moves they are part of
drop policy if exists "members can read excused votes" on public.excused_votes;
create policy "members can read excused votes"
on public.excused_votes for select
to authenticated
using (
  exists (
    select 1
    from public.moves m
    join public.group_members gm on gm.group_id = m.group_id
    where m.id = excused_votes.move_id
      and gm.user_id = (select auth.uid())
  )
);

-- Allow petitioner to insert their own excused request
drop policy if exists "petitioner can insert excused vote" on public.excused_votes;
create policy "petitioner can insert excused vote"
on public.excused_votes for insert
to authenticated
with check (petitioner_id = (select auth.uid()));

-- Allow petitioner to update their own excused request
drop policy if exists "petitioner can update excused vote" on public.excused_votes;
create policy "petitioner can update excused vote"
on public.excused_votes for update
to authenticated
using (petitioner_id = (select auth.uid()))
with check (petitioner_id = (select auth.uid()));

-- Ballot RLS
drop policy if exists "members can read ballots" on public.excused_vote_ballots;
create policy "members can read ballots"
on public.excused_vote_ballots for select
to authenticated
using (
  exists (
    select 1
    from public.excused_votes ev
    join public.moves m on m.id = ev.move_id
    join public.group_members gm on gm.group_id = m.group_id
    where ev.id = excused_vote_ballots.vote_id
      and gm.user_id = (select auth.uid())
  )
);

drop policy if exists "members can cast ballots" on public.excused_vote_ballots;
create policy "members can cast ballots"
on public.excused_vote_ballots for all
to authenticated
using (voter_id = (select auth.uid()))
with check (voter_id = (select auth.uid()));

-- Attendance RLS
drop policy if exists "members can read attendance" on public.attendance;
create policy "members can read attendance"
on public.attendance for select
to authenticated
using (
  exists (
    select 1
    from public.moves m
    join public.group_members gm on gm.group_id = m.group_id
    where m.id = attendance.move_id
      and gm.user_id = (select auth.uid())
  )
);

drop policy if exists "members can record attendance" on public.attendance;
create policy "members can record attendance"
on public.attendance for all
to authenticated
using (
  exists (
    select 1
    from public.moves m
    join public.group_members gm on gm.group_id = m.group_id
    where m.id = attendance.move_id
      and gm.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.moves m
    join public.group_members gm on gm.group_id = m.group_id
    where m.id = attendance.move_id
      and gm.user_id = (select auth.uid())
  )
);

-- Allow updating moves (for settling etc)
drop policy if exists "creator can update move" on public.moves;
create policy "creator can update move"
on public.moves for update
to authenticated
using (
  creator_id = (select auth.uid())
  or exists (
    select 1 from public.group_members gm
    where gm.group_id = moves.group_id
      and gm.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.group_members gm
    where gm.group_id = moves.group_id
      and gm.user_id = (select auth.uid())
  )
);
