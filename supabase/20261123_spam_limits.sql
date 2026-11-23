-- Per-member limits use database time and serialize concurrent sends.
create index spark_connections_requester_time
  on public.spark_connections(requester_id,created_at desc);
create index spark_messages_sender_time
  on public.spark_messages(sender_id,created_at desc);

create function public.spark_limit_intro_insert() returns trigger
  language plpgsql security definer set search_path = ''
as $$
declare
  recent_count integer;
begin
  if new.requester_id is distinct from auth.uid() then
    raise exception 'You can only send your own intros';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('spark-intro:' || new.requester_id::text,0)
  );
  new.created_at := now();
  select count(*) into recent_count from public.spark_connections
    where requester_id = new.requester_id
      and created_at >= now() - interval '24 hours';
  if recent_count >= 25 then
    raise exception 'Daily intro limit reached. Try again tomorrow.';
  end if;
  return new;
end;
$$;
revoke all on function public.spark_limit_intro_insert() from public, anon, authenticated;
create trigger spark_limit_intro_insert before insert on public.spark_connections
  for each row execute function public.spark_limit_intro_insert();

create function public.spark_limit_message_insert() returns trigger
  language plpgsql security definer set search_path = ''
as $$
declare
  recent_count integer;
begin
  if new.sender_id is distinct from auth.uid() then
    raise exception 'You can only send your own messages';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('spark-message:' || new.sender_id::text,0)
  );
  new.created_at := now();
  new.read_at := null;
  select count(*) into recent_count from public.spark_messages
    where sender_id = new.sender_id
      and created_at >= now() - interval '1 minute';
  if recent_count >= 30 then
    raise exception 'Message limit reached. Wait a minute and try again.';
  end if;
  return new;
end;
$$;
revoke all on function public.spark_limit_message_insert() from public, anon, authenticated;
create trigger spark_limit_message_insert before insert on public.spark_messages
  for each row execute function public.spark_limit_message_insert();
