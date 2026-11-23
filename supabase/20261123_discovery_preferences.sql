-- Saved discovery filters and a database-enforced pause switch.
create table public.spark_discovery_preferences (
  owner_id uuid primary key references public.spark_profiles(id) on delete cascade,
  min_age smallint not null default 18 check (min_age between 18 and 100),
  max_age smallint not null default 100 check (max_age between 18 and 100),
  gender_filter text not null default 'All' check (gender_filter in ('All','Woman','Man','Nonbinary','Prefer not to say')),
  city_only boolean not null default false,
  goal_filter text not null default 'All' check (goal_filter in ('All','Friends first','Open to a serious relationship','Getting to know people')),
  check (min_age <= max_age)
);
alter table public.spark_discovery_preferences enable row level security;
revoke all on public.spark_discovery_preferences from anon, authenticated;
grant select,insert,update,delete on public.spark_discovery_preferences to authenticated;
create policy "members read own filters" on public.spark_discovery_preferences
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "members save own filters" on public.spark_discovery_preferences
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "members update own filters" on public.spark_discovery_preferences
  for update to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "members reset own filters" on public.spark_discovery_preferences
  for delete to authenticated using (owner_id = (select auth.uid()));

create table public.spark_discovery_pauses (
  user_id uuid primary key references public.spark_profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.spark_discovery_pauses enable row level security;
revoke all on public.spark_discovery_pauses from anon, authenticated;
grant select(user_id),insert(user_id),delete on public.spark_discovery_pauses to authenticated;
-- Member IDs that are paused are visible to signed-in members so profile RLS
-- can evaluate the switch without a privileged function.
create policy "members see paused profile ids" on public.spark_discovery_pauses
  for select to authenticated using (true);
create policy "members pause own discovery" on public.spark_discovery_pauses
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "members resume own discovery" on public.spark_discovery_pauses
  for delete to authenticated using (user_id = (select auth.uid()));

drop policy "signed in members see active profiles" on public.spark_profiles;
create policy "members see available profiles or matches" on public.spark_profiles
  for select to authenticated using (
    id = (select auth.uid())
    or exists (select 1 from public.spark_moderators m where m.user_id = (select auth.uid()))
    or (
      not exists (select 1 from public.spark_suspended_profiles s where s.user_id = id)
      and not exists (
        select 1 from public.spark_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = id)
           or (b.blocker_id = id and b.blocked_id = (select auth.uid()))
      )
      and (
        not exists (select 1 from public.spark_discovery_pauses d where d.user_id = id)
        or exists (
          select 1 from public.spark_connections c
          where c.status = 'accepted'
            and ((c.requester_id = (select auth.uid()) and c.recipient_id = id)
              or (c.recipient_id = (select auth.uid()) and c.requester_id = id))
        )
      )
    )
  );

drop policy "active members send intros" on public.spark_connections;
create policy "visible members send intros" on public.spark_connections
  for insert to authenticated with check (
    requester_id = (select auth.uid()) and status = 'pending'
    and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (requester_id,recipient_id))
    and not exists (select 1 from public.spark_discovery_pauses d where d.user_id in (requester_id,recipient_id))
    and not exists (
      select 1 from public.spark_blocks b
      where (b.blocker_id = requester_id and b.blocked_id = recipient_id)
         or (b.blocker_id = recipient_id and b.blocked_id = requester_id)
    )
  );

drop policy "owner or active members see links" on public.spark_social_links;
create policy "owner or available members see links" on public.spark_social_links
  for select to authenticated using (
    owner_id = (select auth.uid()) or (
      visibility <> 'hidden'
      and exists (select 1 from public.spark_profiles owner where owner.id = owner_id)
      and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (owner_id,(select auth.uid())))
      and exists (select 1 from public.spark_profiles viewer where viewer.id = (select auth.uid()))
      and not exists (
        select 1 from public.spark_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = owner_id)
           or (b.blocker_id = owner_id and b.blocked_id = (select auth.uid()))
      )
      and (visibility = 'members' or (visibility = 'matches' and exists (
        select 1 from public.spark_connections c
        where c.status = 'accepted'
          and ((c.requester_id = (select auth.uid()) and c.recipient_id = owner_id)
            or (c.recipient_id = (select auth.uid()) and c.requester_id = owner_id))
      )))
    )
  );
