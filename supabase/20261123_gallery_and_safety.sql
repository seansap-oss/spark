-- Four-photo galleries and a readable block list for Spark members.
create table public.spark_profile_photos (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.spark_profiles(id) on delete cascade,
  path text not null unique check (path ~ ('^' || owner_id::text || '/[0-9a-f-]{36}[.]webp$')),
  slot smallint not null check (slot between 0 and 3),
  created_at timestamptz not null default now(),
  unique(owner_id,slot)
);
create index spark_profile_photos_owner on public.spark_profile_photos(owner_id,slot);

insert into public.spark_profile_photos(owner_id,path,slot)
select id,photo_path,0 from public.spark_profiles where photo_path is not null;

alter table public.spark_profile_photos enable row level security;
revoke all on public.spark_profile_photos from anon;
grant select,insert,delete on public.spark_profile_photos to authenticated;

create policy "spark members see unblocked galleries" on public.spark_profile_photos
  for select to authenticated using (
    owner_id = (select auth.uid()) or (
      exists (select 1 from public.spark_profiles p where p.id = owner_id and p.age >= 18)
      and not exists (
        select 1 from public.spark_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = owner_id)
           or (b.blocker_id = owner_id and b.blocked_id = (select auth.uid()))
      )
    )
  );
create policy "spark members add own gallery photos" on public.spark_profile_photos
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "spark members remove own gallery photos" on public.spark_profile_photos
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "spark members read visible gallery objects" on storage.objects
  for select to authenticated using (
    bucket_id = 'spark-profile-photos'
    and exists (
      select 1 from public.spark_profile_photos g
      where g.path = name
        and (g.owner_id = (select auth.uid()) or not exists (
          select 1 from public.spark_blocks b
          where (b.blocker_id = (select auth.uid()) and b.blocked_id = g.owner_id)
             or (b.blocker_id = g.owner_id and b.blocked_id = (select auth.uid()))
        ))
    )
  );

alter table public.spark_blocks add column blocked_name text not null default 'Member'
  check (char_length(blocked_name) between 1 and 40);
update public.spark_blocks b set blocked_name = p.name
from public.spark_profiles p where b.blocked_id = p.id;
