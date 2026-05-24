-- Ensure group_members write policies are explicitly present and compatible
-- with app-side insert flows.

alter table public.group_members enable row level security;

drop policy if exists "users can join groups as themselves" on public.group_members;
create policy "users can join groups as themselves"
on public.group_members for insert
to authenticated
with check (
  auth.uid() is not null
  and user_id = auth.uid()
);

drop policy if exists "users can update own membership row" on public.group_members;
create policy "users can update own membership row"
on public.group_members for update
to authenticated
using (
  auth.uid() is not null
  and user_id = auth.uid()
)
with check (
  auth.uid() is not null
  and user_id = auth.uid()
);
