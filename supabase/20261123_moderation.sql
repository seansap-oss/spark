-- Spark moderation. Membership is assigned by a project administrator in SQL,
-- never by a browser user. No moderator is assigned by this migration.
create table public.spark_moderators (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.spark_moderators enable row level security;
revoke all on public.spark_moderators from anon;
grant select on public.spark_moderators to authenticated;
create policy "moderators see own membership" on public.spark_moderators
  for select to authenticated using (user_id = (select auth.uid()));

create table public.spark_suspended_profiles (
  user_id uuid primary key references public.spark_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  moderator_id uuid references auth.users(id)
);
alter table public.spark_suspended_profiles enable row level security;
revoke all on public.spark_suspended_profiles from anon;
grant select(user_id),insert,delete on public.spark_suspended_profiles to authenticated;
-- A member can see whether an account is paused; reasons stay in reports.
create policy "members see paused account ids" on public.spark_suspended_profiles
  for select to authenticated using (true);
create policy "moderators pause accounts" on public.spark_suspended_profiles
  for insert to authenticated with check (
    moderator_id = (select auth.uid()) and user_id <> (select auth.uid())
    and exists (select 1 from public.spark_moderators m where m.user_id = (select auth.uid()))
  );
create policy "moderators restore accounts" on public.spark_suspended_profiles
  for delete to authenticated using (
    exists (select 1 from public.spark_moderators m where m.user_id = (select auth.uid()))
  );

alter table public.spark_reports
  add column status text not null default 'pending' check (status in ('pending','reviewed','dismissed')),
  add column reviewed_at timestamptz,
  add column reviewed_by uuid references auth.users(id);
grant update(status,reviewed_at,reviewed_by) on public.spark_reports to authenticated;
create policy "moderators read reports" on public.spark_reports
  for select to authenticated using (
    exists (select 1 from public.spark_moderators m where m.user_id = (select auth.uid()))
  );
create policy "moderators triage reports" on public.spark_reports
  for update to authenticated using (
    exists (select 1 from public.spark_moderators m where m.user_id = (select auth.uid()))
  ) with check (
    reviewed_by = (select auth.uid()) and reviewed_at is not null
    and status in ('reviewed','dismissed')
  );

drop policy "signed in members see unblocked profiles" on public.spark_profiles;
create policy "signed in members see active profiles" on public.spark_profiles
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
    )
  );

drop policy "members send intros" on public.spark_connections;
drop policy "participants see their requests" on public.spark_connections;
create policy "active participants see requests" on public.spark_connections
  for select to authenticated using (
    (requester_id = (select auth.uid()) or recipient_id = (select auth.uid()))
    and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (requester_id,recipient_id))
    and not exists (
      select 1 from public.spark_blocks b
      where (b.blocker_id = requester_id and b.blocked_id = recipient_id)
         or (b.blocker_id = recipient_id and b.blocked_id = requester_id)
    )
  );
create policy "active members send intros" on public.spark_connections
  for insert to authenticated with check (
    requester_id = (select auth.uid()) and status = 'pending'
    and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (requester_id,recipient_id))
    and not exists (
      select 1 from public.spark_blocks b
      where (b.blocker_id = requester_id and b.blocked_id = recipient_id)
         or (b.blocker_id = recipient_id and b.blocked_id = requester_id)
    )
  );

drop policy "matched participants read messages" on public.spark_messages;
create policy "active matched participants read messages" on public.spark_messages
  for select to authenticated using (exists (
    select 1 from public.spark_connections c
    where c.id = connection_id and c.status = 'accepted'
      and (c.requester_id = (select auth.uid()) or c.recipient_id = (select auth.uid()))
      and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (c.requester_id,c.recipient_id))
      and not exists (
        select 1 from public.spark_blocks b
        where (b.blocker_id = c.requester_id and b.blocked_id = c.recipient_id)
           or (b.blocker_id = c.recipient_id and b.blocked_id = c.requester_id)
      )
  ));
drop policy "matched participants send messages" on public.spark_messages;
create policy "active matched participants send messages" on public.spark_messages
  for insert to authenticated with check (
    sender_id = (select auth.uid()) and exists (
      select 1 from public.spark_connections c
      where c.id = connection_id and c.status = 'accepted'
        and (c.requester_id = (select auth.uid()) or c.recipient_id = (select auth.uid()))
        and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (c.requester_id,c.recipient_id))
        and not exists (
          select 1 from public.spark_blocks b
          where (b.blocker_id = c.requester_id and b.blocked_id = c.recipient_id)
             or (b.blocker_id = c.recipient_id and b.blocked_id = c.requester_id)
        )
    )
  );

drop policy "owner or permitted members see links" on public.spark_social_links;
create policy "owner or active members see links" on public.spark_social_links
  for select to authenticated using (
    owner_id = (select auth.uid()) or (
      visibility <> 'hidden'
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
