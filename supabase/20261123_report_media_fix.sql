-- Report inputs were unintentionally missing column grants after hardening.
grant insert(category,message_id) on public.spark_reports to authenticated;
alter table public.spark_reports add column media_path text, add column media_kind text;

create or replace function public.spark_capture_report_message() returns trigger
language plpgsql set search_path=''
as $$
declare source_message record;
begin
  new.message_excerpt:=null;
  new.media_path:=null;
  new.media_kind:=null;
  if new.message_id is null then return new; end if;
  select m.body,m.sender_id,m.attachment_path,m.attachment_kind,c.requester_id,c.recipient_id
    into source_message from public.spark_messages m
    join public.spark_connections c on c.id=m.connection_id
    where m.id=new.message_id and c.status='accepted';
  if not found or source_message.sender_id<>new.reported_id or not (
    (source_message.requester_id=new.reporter_id and source_message.recipient_id=new.reported_id)
    or (source_message.recipient_id=new.reporter_id and source_message.requester_id=new.reported_id)
  ) then raise exception 'Invalid reported message'; end if;
  new.message_excerpt:=left(source_message.body,300);
  new.media_path:=source_message.attachment_path;
  new.media_kind:=source_message.attachment_kind;
  return new;
end;
$$;
revoke all on function public.spark_capture_report_message() from public,anon,authenticated;

-- Only a member of the moderator table may fetch a file captured by a
-- verified report. This remains possible after the match is blocked.
create policy "moderators read reported chat media" on storage.objects
for select to authenticated using (
  bucket_id='spark-chat-media'
  and exists (select 1 from public.spark_moderators mod
    join public.spark_reports r on r.media_path=name
    where mod.user_id=(select auth.uid()))
);
