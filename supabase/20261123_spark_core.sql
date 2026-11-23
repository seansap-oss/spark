-- Spark / Vibely core schema. Project: qhnynlpnqsmytpodzmbx.
-- No service-role credential is used in the browser.

create table public.spark_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 40),
  age smallint not null check (age between 18 and 100),
  gender text not null check (gender in ('Woman','Man','Nonbinary','Prefer not to say')),
  city text not null check (char_length(trim(city)) between 2 and 80),
  bio text not null default '' check (char_length(bio) <= 500),
  goal text not null default 'Friends first' check (char_length(goal) <= 100),
  created_at timestamptz not null default now()
);

create table public.spark_blocks (
  blocker_id uuid not null references public.spark_profiles(id) on delete cascade,
  blocked_id uuid not null references public.spark_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.spark_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.spark_profiles(id) on delete cascade,
  recipient_id uuid not null references public.spark_profiles(id) on delete cascade,
  intro text not null check (char_length(trim(intro)) between 1 and 300),
  status text not null default 'pending' check (status in ('pending','accepted','declined','blocked')),
  created_at timestamptz not null default now(),
  check (requester_id <> recipient_id)
);
create unique index spark_one_connection_per_pair on public.spark_connections
  (least(requester_id,recipient_id), greatest(requester_id,recipient_id));
create index spark_connections_recipient on public.spark_connections(recipient_id,created_at desc);

create table public.spark_messages (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.spark_connections(id) on delete cascade,
  sender_id uuid not null references public.spark_profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index spark_messages_thread on public.spark_messages(connection_id,created_at);

create table public.spark_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.spark_profiles(id) on delete cascade,
  reported_id uuid not null references public.spark_profiles(id) on delete cascade,
  reason text not null check (char_length(trim(reason)) between 3 and 500),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id)
);

alter table public.spark_profiles enable row level security;
alter table public.spark_blocks enable row level security;
alter table public.spark_connections enable row level security;
alter table public.spark_messages enable row level security;
alter table public.spark_reports enable row level security;

revoke all on public.spark_profiles,public.spark_blocks,public.spark_connections,public.spark_messages,public.spark_reports from anon;
grant select,insert,update,delete on public.spark_profiles to authenticated;
grant select,insert,delete on public.spark_blocks to authenticated;
grant select,insert on public.spark_connections to authenticated;
grant update(status) on public.spark_connections to authenticated;
grant select,insert on public.spark_messages to authenticated;
grant select,insert on public.spark_reports to authenticated;

create policy "signed in members see unblocked profiles" on public.spark_profiles
  for select to authenticated using (
    id = (select auth.uid()) or not exists (
      select 1 from public.spark_blocks b
      where (b.blocker_id = (select auth.uid()) and b.blocked_id = id)
         or (b.blocker_id = id and b.blocked_id = (select auth.uid()))
    )
  );
create policy "members create own profile" on public.spark_profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy "members edit own profile" on public.spark_profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "members delete own profile" on public.spark_profiles
  for delete to authenticated using (id = (select auth.uid()));

create policy "block participants see their blocks" on public.spark_blocks
  for select to authenticated using (blocker_id = (select auth.uid()) or blocked_id = (select auth.uid()));
create policy "members block others" on public.spark_blocks
  for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy "members undo their blocks" on public.spark_blocks
  for delete to authenticated using (blocker_id = (select auth.uid()));

create policy "participants see their requests" on public.spark_connections
  for select to authenticated using (
    (requester_id = (select auth.uid()) or recipient_id = (select auth.uid()))
    and not exists (
      select 1 from public.spark_blocks b
      where (b.blocker_id = requester_id and b.blocked_id = recipient_id)
         or (b.blocker_id = recipient_id and b.blocked_id = requester_id)
    )
  );
create policy "members send intros" on public.spark_connections
  for insert to authenticated with check (
    requester_id = (select auth.uid()) and status = 'pending'
    and not exists (
      select 1 from public.spark_blocks b
      where (b.blocker_id = requester_id and b.blocked_id = recipient_id)
         or (b.blocker_id = recipient_id and b.blocked_id = requester_id)
    )
  );
create policy "recipients decide pending intros" on public.spark_connections
  for update to authenticated using (recipient_id = (select auth.uid()) and status = 'pending')
  with check (recipient_id = (select auth.uid()) and status in ('accepted','declined'));
create policy "either participant can close a connection" on public.spark_connections
  for update to authenticated using (requester_id = (select auth.uid()) or recipient_id = (select auth.uid()))
  with check ((requester_id = (select auth.uid()) or recipient_id = (select auth.uid())) and status = 'blocked');

create policy "matched participants read messages" on public.spark_messages
  for select to authenticated using (exists (
    select 1 from public.spark_connections c
    where c.id = connection_id and c.status = 'accepted'
      and (c.requester_id = (select auth.uid()) or c.recipient_id = (select auth.uid()))
      and not exists (
        select 1 from public.spark_blocks b
        where (b.blocker_id = c.requester_id and b.blocked_id = c.recipient_id)
           or (b.blocker_id = c.recipient_id and b.blocked_id = c.requester_id)
      )
  ));
create policy "matched participants send messages" on public.spark_messages
  for insert to authenticated with check (
    sender_id = (select auth.uid()) and exists (
      select 1 from public.spark_connections c
      where c.id = connection_id and c.status = 'accepted'
        and (c.requester_id = (select auth.uid()) or c.recipient_id = (select auth.uid()))
        and not exists (
          select 1 from public.spark_blocks b
          where (b.blocker_id = c.requester_id and b.blocked_id = c.recipient_id)
             or (b.blocker_id = c.recipient_id and b.blocked_id = c.requester_id)
        )
    )
  );

create policy "reporter reads own reports" on public.spark_reports
  for select to authenticated using (reporter_id = (select auth.uid()));
create policy "members submit reports" on public.spark_reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));
