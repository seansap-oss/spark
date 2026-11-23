-- Per-member conversation controls. The other participant cannot see pin/mute.
create table public.spark_chat_preferences (
  owner_id uuid not null references public.spark_profiles(id) on delete cascade,
  connection_id uuid not null references public.spark_connections(id) on delete cascade,
  pinned boolean not null default false,
  muted boolean not null default false,
  primary key(owner_id,connection_id)
);
alter table public.spark_chat_preferences enable row level security;
revoke all on public.spark_chat_preferences from anon,authenticated;
grant select(owner_id,connection_id,pinned,muted),insert(owner_id,connection_id,pinned,muted),update(pinned,muted)
  on public.spark_chat_preferences to authenticated;
create policy "member reads own conversation controls" on public.spark_chat_preferences
  for select to authenticated using (owner_id=(select auth.uid()));
create policy "member adds own conversation controls" on public.spark_chat_preferences
  for insert to authenticated with check (
    owner_id=(select auth.uid()) and exists (
      select 1 from public.spark_connections c where c.id=connection_id and c.status='accepted'
        and (select auth.uid()) in (c.requester_id,c.recipient_id)
    )
  );
create policy "member updates own conversation controls" on public.spark_chat_preferences
  for update to authenticated using (owner_id=(select auth.uid()))
  with check (owner_id=(select auth.uid()));

-- One emoji per member per message; reaction is visible only to the active match.
create table public.spark_message_reactions (
  message_id uuid not null references public.spark_messages(id) on delete cascade,
  connection_id uuid not null references public.spark_connections(id) on delete cascade,
  user_id uuid not null references public.spark_profiles(id) on delete cascade,
  emoji text not null check (emoji in ('❤️','😂','👍','🥰','🔥','👏')),
  created_at timestamptz not null default now(),
  primary key(message_id,user_id)
);
create index spark_reactions_thread on public.spark_message_reactions(connection_id);
alter table public.spark_message_reactions enable row level security;
revoke all on public.spark_message_reactions from anon,authenticated;
grant select(message_id,connection_id,user_id,emoji),insert(message_id,connection_id,user_id,emoji),update(emoji),delete
  on public.spark_message_reactions to authenticated;
create policy "active match reads reactions" on public.spark_message_reactions
  for select to authenticated using (exists (
    select 1 from public.spark_connections c where c.id=connection_id and c.status='accepted'
      and (select auth.uid()) in (c.requester_id,c.recipient_id)
      and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (c.requester_id,c.recipient_id))
      and not exists (select 1 from public.spark_blocks b
        where (b.blocker_id=c.requester_id and b.blocked_id=c.recipient_id)
           or (b.blocker_id=c.recipient_id and b.blocked_id=c.requester_id))
  ));
create policy "active member adds reaction" on public.spark_message_reactions
  for insert to authenticated with check (user_id=(select auth.uid()) and exists (
    select 1 from public.spark_messages m join public.spark_connections c on c.id=m.connection_id
    where m.id=message_id and m.connection_id=spark_message_reactions.connection_id
      and c.status='accepted' and (select auth.uid()) in (c.requester_id,c.recipient_id)
      and not exists (select 1 from public.spark_suspended_profiles s where s.user_id in (c.requester_id,c.recipient_id))
      and not exists (select 1 from public.spark_blocks b
        where (b.blocker_id=c.requester_id and b.blocked_id=c.recipient_id)
           or (b.blocker_id=c.recipient_id and b.blocked_id=c.requester_id))
  ));
create policy "member changes own reaction" on public.spark_message_reactions
  for update to authenticated using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));
create policy "member removes own reaction" on public.spark_message_reactions
  for delete to authenticated using (user_id=(select auth.uid()));
