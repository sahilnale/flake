-- The move creator needs to be able to flip status → 'approved' or 'denied'.
-- The existing "petitioner can update excused vote" policy only covers the
-- petitioner updating their own reason — it doesn't cover the move leader
-- writing the outcome. This adds that missing permission.

drop policy if exists "move creator can resolve excused votes" on public.excused_votes;
create policy "move creator can resolve excused votes"
on public.excused_votes for update
to authenticated
using (
  exists (
    select 1 from public.moves m
    where m.id = excused_votes.move_id
      and m.creator_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.moves m
    where m.id = excused_votes.move_id
      and m.creator_id = (select auth.uid())
  )
);
