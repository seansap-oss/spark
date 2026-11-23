-- Keep a verified snapshot of a reported chat message for moderator review.
alter table public.spark_reports
  add column category text not null default 'Other',
  add column message_id uuid references public.spark_messages(id) on delete set null,
  add column message_excerpt text,
  add constraint spark_report_category_valid check (
    category in ('Harassment','Scam or spam','Fake profile','Underage concern','Other')
  );

create function public.spark_capture_report_message() returns trigger
  language plpgsql set search_path = ''
as $$
declare
  source_message record;
begin
  new.message_excerpt := null;
  if new.message_id is null then
    return new;
  end if;

  select m.body, m.sender_id, c.requester_id, c.recipient_id
    into source_message
    from public.spark_messages m
    join public.spark_connections c on c.id = m.connection_id
    where m.id = new.message_id and c.status = 'accepted';
  if not found
    or source_message.sender_id <> new.reported_id
    or not (
      (source_message.requester_id = new.reporter_id and source_message.recipient_id = new.reported_id)
      or (source_message.recipient_id = new.reporter_id and source_message.requester_id = new.reported_id)
    )
  then
    raise exception 'Invalid reported message';
  end if;

  new.message_excerpt := left(source_message.body,300);
  return new;
end;
$$;

create trigger spark_capture_report_message before insert on public.spark_reports
  for each row execute function public.spark_capture_report_message();
