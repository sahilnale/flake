-- Allow authenticated users to discover groups by invite code (thread_key)
-- This is needed so users can join a group before they're members
drop policy if exists "anyone can find group by thread_key" on public.groups;
create policy "anyone can find group by thread_key"
on public.groups for select
to authenticated
using (
  thread_key is not null
  or id in (select public.my_group_ids())
);
