-- Private profile photos for the Spark app only.
alter table public.spark_profiles
  add column photo_path text
  check (photo_path is null or photo_path ~ ('^' || id::text || '/[0-9a-f-]{36}[.]webp$'));

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('spark-profile-photos','spark-profile-photos',false,5242880,array['image/webp'])
on conflict (id) do nothing;

create policy "spark members upload own profile photo" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'spark-profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}[.]webp$')
    and exists (select 1 from public.spark_profiles p where p.id = (select auth.uid()))
  );

create policy "spark members read visible profile photos" on storage.objects
  for select to authenticated using (
    bucket_id = 'spark-profile-photos'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.spark_profiles p
        where p.photo_path = name
          and p.age >= 18
          and not exists (
            select 1 from public.spark_blocks b
            where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.id)
               or (b.blocker_id = p.id and b.blocked_id = (select auth.uid()))
          )
      )
    )
  );

create policy "spark members delete own profile photo" on storage.objects
  for delete to authenticated using (
    bucket_id = 'spark-profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
