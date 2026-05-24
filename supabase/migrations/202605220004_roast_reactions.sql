-- roast_reactions: one row per (group, target, season, emoji, reactor) combination.
-- Counts are derived by grouping; toggling is insert-or-delete.

create table if not exists public.roast_reactions (
    id             uuid        primary key default gen_random_uuid(),
    group_id       uuid        not null references public.groups(id) on delete cascade,
    target_user_id uuid        not null,
    season         int         not null default 1,
    emoji          text        not null,
    reactor_id     uuid        not null,
    created_at     timestamptz default now(),
    unique (group_id, target_user_id, season, emoji, reactor_id)
);

alter table public.roast_reactions enable row level security;

-- Group members can read all reactions for their group
create policy "group members can read roast reactions"
    on public.roast_reactions for select
    to authenticated
    using (
        exists (
            select 1 from public.group_members gm
            where gm.group_id = roast_reactions.group_id
              and gm.user_id  = auth.uid()
        )
    );

-- Users can add their own reactions
create policy "users can add own roast reactions"
    on public.roast_reactions for insert
    to authenticated
    with check (reactor_id = auth.uid());

-- Users can remove their own reactions
create policy "users can remove own roast reactions"
    on public.roast_reactions for delete
    to authenticated
    using (reactor_id = auth.uid());
