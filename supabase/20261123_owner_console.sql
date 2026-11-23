-- Owner console: an authenticated owner plus a short-lived PIN unlock is
-- required for every write. Owner assignment and PIN hash are private setup.
create table public.spark_owners(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.spark_owners enable row level security;
revoke all on public.spark_owners from public,anon,authenticated;
grant select(user_id) on public.spark_owners to authenticated;
create policy "owner sees membership" on public.spark_owners for select to authenticated
  using(user_id=(select auth.uid()));

create schema if not exists spark_private;
revoke all on schema spark_private from public,anon,authenticated;
create table spark_private.admin_gate(id boolean primary key default true check(id),pin_hash text not null);
create table spark_private.admin_sessions(user_id uuid primary key references auth.users(id) on delete cascade,
  unlocked_until timestamptz not null,failed_count int not null default 0,locked_until timestamptz);
revoke all on all tables in schema spark_private from public,anon,authenticated;

create function public.spark_owner_unlocked() returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.spark_owners o join spark_private.admin_sessions s on s.user_id=o.user_id
  where o.user_id=auth.uid() and s.unlocked_until>now()) $$;
revoke all on function public.spark_owner_unlocked() from public,anon;
grant execute on function public.spark_owner_unlocked() to authenticated;

create function public.spark_owner_unlock(pin text) returns boolean language plpgsql security definer set search_path=''
as $$
declare current_session spark_private.admin_sessions%rowtype; stored_hash text;
begin
  if not exists(select 1 from public.spark_owners where user_id=auth.uid()) then return false; end if;
  insert into spark_private.admin_sessions(user_id,unlocked_until) values(auth.uid(),now()) on conflict do nothing;
  select * into current_session from spark_private.admin_sessions where user_id=auth.uid() for update;
  if current_session.locked_until>now() then return false; end if;
  select pin_hash into stored_hash from spark_private.admin_gate where id=true;
  if stored_hash is null or extensions.crypt(pin,stored_hash) is distinct from stored_hash then
    update spark_private.admin_sessions set failed_count=case when current_session.failed_count>=4 then 0 else current_session.failed_count+1 end,
      locked_until=case when current_session.failed_count>=4 then now()+interval '15 minutes' else null end,
      unlocked_until=now() where user_id=auth.uid();
    return false;
  end if;
  update spark_private.admin_sessions set failed_count=0,locked_until=null,unlocked_until=now()+interval '30 minutes'
    where user_id=auth.uid();
  return true;
end;
$$;
revoke all on function public.spark_owner_unlock(text) from public,anon;
grant execute on function public.spark_owner_unlock(text) to authenticated;

create table public.spark_plan_prices(
  tier text not null check(tier in ('Basic','Plus','Gold','Signature')),
  currency text not null check(currency in ('INR','USD','AUD')),
  price_minor integer not null check(price_minor between 0 and 100000000),
  period text not null default 'month' check(period in ('month','year')),
  description text not null default '' check(char_length(description)<=240),
  benefits text[] not null default '{}',active boolean not null default true,
  updated_at timestamptz not null default now(),primary key(tier,currency,period)
);
alter table public.spark_plan_prices enable row level security;
revoke all on public.spark_plan_prices from public,anon,authenticated;
grant select on public.spark_plan_prices to authenticated;
grant insert(tier,currency,price_minor,period,description,benefits,active),update(price_minor,description,benefits,active)
  on public.spark_plan_prices to authenticated;
create policy "members see active prices" on public.spark_plan_prices for select to authenticated
  using(active or (select public.spark_owner_unlocked()));
create policy "owner creates price" on public.spark_plan_prices for insert to authenticated
  with check((select public.spark_owner_unlocked()));
create policy "owner edits price" on public.spark_plan_prices for update to authenticated
  using((select public.spark_owner_unlocked())) with check((select public.spark_owner_unlocked()));

create table public.spark_campaigns(
  id uuid primary key default gen_random_uuid(),name text not null check(char_length(trim(name)) between 3 and 80),
  percent_off integer not null check(percent_off between 1 and 90),
  tiers text[] not null check(array_length(tiers,1)>0 and tiers <@ array['Plus','Gold','Signature']::text[]),
  starts_at timestamptz not null,ends_at timestamptz not null,
  redemption_limit integer check(redemption_limit between 1 and 1000000),
  published boolean not null default false,created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),check(ends_at>starts_at)
);
alter table public.spark_campaigns enable row level security;
revoke all on public.spark_campaigns from public,anon,authenticated;
grant select on public.spark_campaigns to authenticated;
grant insert(name,percent_off,tiers,starts_at,ends_at,redemption_limit,published,created_by),
  update(name,percent_off,tiers,starts_at,ends_at,redemption_limit,published) on public.spark_campaigns to authenticated;
create policy "published campaigns visible" on public.spark_campaigns for select to authenticated
  using(published or (select public.spark_owner_unlocked()));
create policy "owner creates campaign" on public.spark_campaigns for insert to authenticated
  with check((select public.spark_owner_unlocked()) and created_by=auth.uid());
create policy "owner edits campaign" on public.spark_campaigns for update to authenticated
  using((select public.spark_owner_unlocked())) with check((select public.spark_owner_unlocked()));

create table public.spark_notice_preferences(owner_id uuid primary key references public.spark_profiles(id) on delete cascade,
  product_tips boolean not null default false);
alter table public.spark_notice_preferences enable row level security;
revoke all on public.spark_notice_preferences from public,anon,authenticated;
grant select,insert(owner_id,product_tips),update(product_tips) on public.spark_notice_preferences to authenticated;
create policy "member reads notice preference" on public.spark_notice_preferences for select to authenticated
  using(owner_id=(select auth.uid()));
create policy "member creates notice preference" on public.spark_notice_preferences for insert to authenticated
  with check(owner_id=(select auth.uid()));
create policy "member updates notice preference" on public.spark_notice_preferences for update to authenticated
  using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));

create table public.spark_admin_notices(id uuid primary key default gen_random_uuid(),recipient_id uuid not null references public.spark_profiles(id) on delete cascade,
  author_id uuid not null references auth.users(id),title text not null check(char_length(trim(title)) between 3 and 80),
  body text not null check(char_length(trim(body)) between 10 and 500),created_at timestamptz not null default now());
create index spark_notices_recipient on public.spark_admin_notices(recipient_id,created_at desc);
alter table public.spark_admin_notices enable row level security;
revoke all on public.spark_admin_notices from public,anon,authenticated;
grant select,insert(recipient_id,author_id,title,body) on public.spark_admin_notices to authenticated;
create policy "member reads own official notices" on public.spark_admin_notices for select to authenticated
  using(recipient_id=(select auth.uid()) or (select public.spark_owner_unlocked()));
create policy "owner sends opted-in notice" on public.spark_admin_notices for insert to authenticated
  with check((select public.spark_owner_unlocked()) and author_id=(select auth.uid())
    and exists(select 1 from public.spark_notice_preferences p where p.owner_id=recipient_id and p.product_tips));
create function public.spark_limit_owner_notice() returns trigger language plpgsql security definer set search_path=''
as $$ begin
  if (select count(*) from public.spark_admin_notices where recipient_id=new.recipient_id
      and created_at>now()-interval '7 days')>=2 then raise exception 'This member has reached the weekly notice limit'; end if;
  new.created_at:=now();return new;
end $$;
revoke all on function public.spark_limit_owner_notice() from public,anon,authenticated;
create trigger spark_limit_owner_notice before insert on public.spark_admin_notices
  for each row execute function public.spark_limit_owner_notice();

create function public.spark_owner_member_stats() returns table(user_id uuid,member_name text,intros bigint,matches bigint,messages bigint,last_activity timestamptz,opted_in boolean)
language sql stable security definer set search_path=''
as $$ select p.id,p.name,
 (select count(*) from public.spark_connections c where c.requester_id=p.id),
 (select count(*) from public.spark_connections c where c.status='accepted' and p.id in(c.requester_id,c.recipient_id)),
 (select count(*) from public.spark_messages m where m.sender_id=p.id),
 greatest(p.created_at,coalesce((select max(c.created_at) from public.spark_connections c where p.id in(c.requester_id,c.recipient_id)),p.created_at),coalesce((select max(m.created_at) from public.spark_messages m where m.sender_id=p.id),p.created_at)),
 coalesce((select n.product_tips from public.spark_notice_preferences n where n.owner_id=p.id),false)
 from public.spark_profiles p where public.spark_owner_unlocked() order by 6 desc limit 500 $$;
revoke all on function public.spark_owner_member_stats() from public,anon;
grant execute on function public.spark_owner_member_stats() to authenticated;
