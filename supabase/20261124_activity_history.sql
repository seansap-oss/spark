-- Keep dates for future match decisions; historical rows remain unknown.
alter table public.spark_connections add column accepted_at timestamptz,
  add column declined_at timestamptz;
create function public.spark_stamp_connection_decision() returns trigger
language plpgsql security definer set search_path=''
as $$ begin
  if old.status='pending' and new.status='accepted' then new.accepted_at:=now(); end if;
  if old.status='pending' and new.status='declined' then new.declined_at:=now(); end if;
  return new;
end $$;
revoke all on function public.spark_stamp_connection_decision() from public,anon,authenticated;
create trigger spark_stamp_connection_decision before update of status on public.spark_connections
for each row execute function public.spark_stamp_connection_decision();

create table public.spark_profile_passes (
  owner_id uuid not null references public.spark_profiles(id) on delete cascade,
  target_id uuid not null references public.spark_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),primary key(owner_id,target_id),
  check(owner_id<>target_id)
);
create index spark_passes_member_date on public.spark_profile_passes(owner_id,created_at desc);
alter table public.spark_profile_passes enable row level security;
revoke all on public.spark_profile_passes from public,anon,authenticated;
grant select(owner_id,target_id,created_at),insert(owner_id,target_id) on public.spark_profile_passes to authenticated;
create policy "member sees own passed profiles" on public.spark_profile_passes for select to authenticated
  using(owner_id=(select auth.uid()));
create policy "member passes visible profile" on public.spark_profile_passes for insert to authenticated
  with check(owner_id=(select auth.uid()) and exists(select 1 from public.spark_profiles p where p.id=target_id));
create function public.spark_stamp_profile_pass() returns trigger
language plpgsql security definer set search_path=''
as $$ begin new.created_at:=now();return new;end $$;
revoke all on function public.spark_stamp_profile_pass() from public,anon,authenticated;
create trigger spark_stamp_profile_pass before insert on public.spark_profile_passes
for each row execute function public.spark_stamp_profile_pass();

-- RLS on spark_messages limits this aggregate to the caller's active matches.
create function public.spark_my_chat_history() returns table(connection_id uuid,first_message_at timestamptz,message_count bigint)
language sql stable security invoker set search_path=''
as $$ select m.connection_id,min(m.created_at),count(*) from public.spark_messages m
  join public.spark_connections c on c.id=m.connection_id
  where c.status='accepted' and auth.uid() in(c.requester_id,c.recipient_id)
  group by m.connection_id $$;
revoke all on function public.spark_my_chat_history() from public,anon;
grant execute on function public.spark_my_chat_history() to authenticated;
