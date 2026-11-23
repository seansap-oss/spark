-- Private chat attachments: one image or voice note per message, at most 5 MiB.
alter table public.spark_messages
  add column attachment_path text,
  add column attachment_kind text,
  add column attachment_mime text,
  add constraint spark_message_attachment_shape check (
    (attachment_path is null and attachment_kind is null and attachment_mime is null)
    or (attachment_path is not null and attachment_kind in ('image','audio') and attachment_mime is not null)
  );
create unique index spark_message_attachment_unique on public.spark_messages(attachment_path)
  where attachment_path is not null;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('spark-chat-media','spark-chat-media',false,5242880,
  array['image/webp','image/jpeg','image/png','audio/webm','audio/ogg','audio/mp4','audio/mpeg'])
on conflict (id) do update set public=false,file_size_limit=5242880,
  allowed_mime_types=excluded.allowed_mime_types;

create policy "matched members upload chat media" on storage.objects
  for insert to authenticated with check (
    bucket_id='spark-chat-media'
    and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}/[0-9a-f-]{36}[.](webp|jpg|png|webm|ogg|m4a|mp3)$')
    and exists (select 1 from public.spark_connections c
      where c.id::text=(storage.foldername(name))[2]
        and c.status='accepted'
        and (select auth.uid()) in (c.requester_id,c.recipient_id)
        and not exists (select 1 from public.spark_suspended_profiles s
          where s.user_id in (c.requester_id,c.recipient_id))
        and not exists (select 1 from public.spark_blocks b
          where (b.blocker_id=c.requester_id and b.blocked_id=c.recipient_id)
             or (b.blocker_id=c.recipient_id and b.blocked_id=c.requester_id)))
  );
create policy "matched members read sent chat media" on storage.objects
  for select to authenticated using (
    bucket_id='spark-chat-media' and exists (
      select 1 from public.spark_messages m
      join public.spark_connections c on c.id=m.connection_id
      where m.attachment_path=name
        and c.status='accepted'
        and (select auth.uid()) in (c.requester_id,c.recipient_id)
        and not exists (select 1 from public.spark_suspended_profiles s
          where s.user_id in (c.requester_id,c.recipient_id))
        and not exists (select 1 from public.spark_blocks b
          where (b.blocker_id=c.requester_id and b.blocked_id=c.recipient_id)
             or (b.blocker_id=c.recipient_id and b.blocked_id=c.requester_id))
    )
  );
create policy "sender removes unposted chat media" on storage.objects
  for delete to authenticated using (
    bucket_id='spark-chat-media'
    and (storage.foldername(name))[1]=(select auth.uid())::text
    and not exists (select 1 from public.spark_messages m where m.attachment_path=name)
  );

create function public.spark_validate_chat_attachment() returns trigger
language plpgsql security definer set search_path=''
as $$
declare media_type text;
begin
  if new.attachment_path is null then return new; end if;
  if new.attachment_path !~ ('^' || new.sender_id::text || '/' || new.connection_id::text || '/[0-9a-f-]{36}[.](webp|jpg|png|webm|ogg|m4a|mp3)$') then
    raise exception 'Invalid attachment path';
  end if;
  if (new.attachment_kind='image' and new.attachment_mime not in ('image/webp','image/jpeg','image/png'))
     or (new.attachment_kind='audio' and new.attachment_mime not in ('audio/webm','audio/ogg','audio/mp4','audio/mpeg')) then
    raise exception 'Invalid attachment format';
  end if;
  select o.metadata->>'mimetype' into media_type from storage.objects o
    where o.bucket_id='spark-chat-media' and o.name=new.attachment_path;
  if media_type is distinct from new.attachment_mime then
    raise exception 'Attachment has not been uploaded in the selected format';
  end if;
  return new;
end;
$$;
revoke all on function public.spark_validate_chat_attachment() from public, anon, authenticated;
create trigger spark_validate_chat_attachment before insert on public.spark_messages
for each row execute function public.spark_validate_chat_attachment();
