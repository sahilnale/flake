-- Add season configuration columns to groups so the group leader can control seasons.
-- season_number: which season the group is currently on (default 1)
-- season_weeks:  how many weeks a season runs (default 12)
-- season_started_at: when the current season started

alter table public.groups
  add column if not exists season_number     int          not null default 1,
  add column if not exists season_weeks      int          not null default 12,
  add column if not exists season_started_at timestamptz;

-- Allow the group creator to update group settings (name, season config).
drop policy if exists "group creator can update group" on public.groups;
create policy "group creator can update group"
on public.groups for update
to authenticated
using  (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));
