-- ============================================================
-- DELETE policies for groups, moves, and group_members
-- All FK references already have ON DELETE CASCADE so deleting
-- the parent row is sufficient — no manual child cleanup needed.
-- ============================================================

-- groups: creator can delete their group
drop policy if exists "creator can delete group" on public.groups;
create policy "creator can delete group"
  on public.groups for delete
  using (auth.uid() = created_by);

-- moves: creator can delete their move
drop policy if exists "creator can delete move" on public.moves;
create policy "creator can delete move"
  on public.moves for delete
  using (auth.uid() = creator_id);

-- group_members: members can remove themselves (leave group)
drop policy if exists "members can leave group" on public.group_members;
create policy "members can leave group"
  on public.group_members for delete
  using (auth.uid() = user_id);

-- rsvps: users can delete their own rsvp
drop policy if exists "users can delete own rsvp" on public.rsvps;
create policy "users can delete own rsvp"
  on public.rsvps for delete
  using (auth.uid() = user_id);
