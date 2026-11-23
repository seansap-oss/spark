-- Private Activity is a paid entitlement provisioned only by trusted billing code.
-- The browser can read its own entitlement but can never create or extend one.
create table public.spark_private_activity_entitlements (
  user_id uuid primary key references public.spark_profiles(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table public.spark_private_activity_entitlements enable row level security;
revoke all on public.spark_private_activity_entitlements from anon,authenticated;
grant select(user_id,expires_at) on public.spark_private_activity_entitlements to authenticated;
create policy "member reads own private activity entitlement" on public.spark_private_activity_entitlements
  for select to authenticated using (user_id=(select auth.uid()));

create table public.spark_activity_preferences (
  owner_id uuid primary key references public.spark_profiles(id) on delete cascade,
  hide_activity boolean not null default false,
  changed_at timestamptz not null default now()
);
alter table public.spark_activity_preferences enable row level security;
revoke all on public.spark_activity_preferences from anon,authenticated;
grant select(owner_id,hide_activity,changed_at),insert(owner_id,hide_activity),update(hide_activity)
  on public.spark_activity_preferences to authenticated;
create policy "member reads own activity setting" on public.spark_activity_preferences
  for select to authenticated using (owner_id=(select auth.uid()));
create policy "member creates own activity setting" on public.spark_activity_preferences
  for insert to authenticated with check (owner_id=(select auth.uid()));
create policy "member changes own activity setting" on public.spark_activity_preferences
  for update to authenticated using (owner_id=(select auth.uid()))
  with check (owner_id=(select auth.uid()));

create function public.spark_validate_activity_setting() returns trigger
language plpgsql security definer set search_path=''
as $$
begin
  if new.owner_id is distinct from auth.uid() then
    raise exception 'You can only edit your own activity setting';
  end if;
  if new.hide_activity and not exists (
    select 1 from public.spark_private_activity_entitlements e
    where e.user_id=new.owner_id and e.expires_at>now()
  ) then
    raise exception 'Private Activity requires an active add-on';
  end if;
  if tg_op='INSERT' or new.hide_activity is distinct from old.hide_activity then
    new.changed_at:=now();
  end if;
  return new;
end;
$$;
revoke all on function public.spark_validate_activity_setting() from public,anon,authenticated;
create trigger spark_validate_activity_setting before insert or update on public.spark_activity_preferences
for each row execute function public.spark_validate_activity_setting();

-- This receipt belongs to the recipient: a client cannot bypass the setting
-- by sending a direct PATCH instead of using the app.
create or replace function public.spark_stamp_message_read() returns trigger
language plpgsql security definer set search_path=''
as $$
begin
  if exists (
    select 1 from public.spark_activity_preferences p
    join public.spark_private_activity_entitlements e on e.user_id=p.owner_id
    where p.owner_id=auth.uid() and p.hide_activity and e.expires_at>now()
  ) then
    raise exception 'Read receipts are hidden while Private Activity is on';
  end if;
  new.read_at:=now();
  return new;
end;
$$;
revoke all on function public.spark_stamp_message_read() from public,anon,authenticated;

-- This private view marker clears a member's unread count without sharing a
-- timestamp with the sender. Rows cannot be read by the other participant.
create table public.spark_message_views (
  message_id uuid not null references public.spark_messages(id) on delete cascade,
  connection_id uuid not null references public.spark_connections(id) on delete cascade,
  viewer_id uuid not null references public.spark_profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key(message_id,viewer_id)
);
create index spark_message_views_member_thread on public.spark_message_views(viewer_id,connection_id);
alter table public.spark_message_views enable row level security;
revoke all on public.spark_message_views from anon,authenticated;
grant select(message_id,connection_id,viewer_id),insert(message_id,connection_id,viewer_id)
  on public.spark_message_views to authenticated;
create policy "member reads own message views" on public.spark_message_views
  for select to authenticated using (viewer_id=(select auth.uid()));
create policy "recipient tracks own views" on public.spark_message_views
  for insert to authenticated with check (
    viewer_id=(select auth.uid()) and exists (
      select 1 from public.spark_messages m join public.spark_connections c on c.id=m.connection_id
      where m.id=message_id and m.connection_id=spark_message_views.connection_id
        and m.sender_id<>(select auth.uid()) and c.status='accepted'
        and (select auth.uid()) in (c.requester_id,c.recipient_id)
        and not exists (select 1 from public.spark_suspended_profiles s
          where s.user_id in (c.requester_id,c.recipient_id))
        and not exists (select 1 from public.spark_blocks b
          where (b.blocker_id=c.requester_id and b.blocked_id=c.recipient_id)
             or (b.blocker_id=c.recipient_id and b.blocked_id=c.requester_id))
    )
  );
create function public.spark_stamp_message_view() returns trigger
language plpgsql security definer set search_path=''
as $$
begin
  new.viewed_at:=now();
  return new;
end;
$$;
revoke all on function public.spark_stamp_message_view() from public,anon,authenticated;
create trigger spark_stamp_message_view before insert on public.spark_message_views
for each row execute function public.spark_stamp_message_view();
