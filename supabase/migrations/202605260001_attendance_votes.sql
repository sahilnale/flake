-- attendance_votes: each member attests who they saw at a move.
-- Majority vote (≥50%) determines showed/missed for scoring.

create table if not exists public.attendance_votes (
    id          uuid        primary key default gen_random_uuid(),
    move_id     uuid        not null references public.moves(id) on delete cascade,
    voter_id    uuid        not null,
    subject_id  uuid        not null,  -- the member being attested about
    vote        text        not null check (vote in ('showed', 'missed')),
    created_at  timestamptz default now(),
    unique (move_id, voter_id, subject_id)
);

alter table public.attendance_votes enable row level security;

-- Group members can read attestation votes for moves they belong to
create policy "group members can read attendance votes"
on public.attendance_votes for select
using (
    exists (
        select 1 from public.moves m
        join public.group_members gm on gm.group_id = m.group_id
        where m.id = attendance_votes.move_id
          and gm.user_id = auth.uid()
    )
);

-- Users can insert/update/delete their own votes
create policy "users can manage own attendance votes"
on public.attendance_votes for all
using  (voter_id = auth.uid())
with check (voter_id = auth.uid());
