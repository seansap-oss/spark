-- A recipient may mark a message read; the sender can see that timestamp.
alter table public.spark_messages add column read_at timestamptz;
grant update(read_at) on public.spark_messages to authenticated;

-- Use database time even when a phone clock is wrong.
create function public.spark_stamp_message_read() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  new.read_at := now();
  return new;
end;
$$;
create trigger spark_stamp_message_read before update of read_at on public.spark_messages
  for each row execute function public.spark_stamp_message_read();

create policy "active recipients mark messages read" on public.spark_messages
  for update to authenticated
  using (
    read_at is null
    and sender_id <> (select auth.uid())
    and exists (
      select 1 from public.spark_connections c
      where c.id = connection_id and c.status = 'accepted'
        and (c.requester_id = (select auth.uid()) or c.recipient_id = (select auth.uid()))
        and not exists (select 1 from public.spark_suspended_profiles s
                        where s.user_id in (c.requester_id,c.recipient_id))
        and not exists (
          select 1 from public.spark_blocks b
          where (b.blocker_id = c.requester_id and b.blocked_id = c.recipient_id)
             or (b.blocker_id = c.recipient_id and b.blocked_id = c.requester_id)
        )
    )
  )
  with check (
    read_at is not null and read_at >= created_at and read_at <= now() + interval '1 minute'
    and sender_id <> (select auth.uid())
    and exists (
      select 1 from public.spark_connections c
      where c.id = connection_id and c.status = 'accepted'
        and (c.requester_id = (select auth.uid()) or c.recipient_id = (select auth.uid()))
        and not exists (select 1 from public.spark_suspended_profiles s
                        where s.user_id in (c.requester_id,c.recipient_id))
        and not exists (
          select 1 from public.spark_blocks b
          where (b.blocker_id = c.requester_id and b.blocked_id = c.recipient_id)
             or (b.blocker_id = c.recipient_id and b.blocked_id = c.requester_id)
        )
    )
  );

create index spark_unread_messages on public.spark_messages(connection_id,created_at)
  where read_at is null;
