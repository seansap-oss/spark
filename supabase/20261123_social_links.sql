-- Spark social links. Privacy is enforced in the Data API by RLS.
create table public.spark_social_links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.spark_profiles(id) on delete cascade,
  platform text not null check (platform in ('Instagram','Facebook','YouTube','Snapchat','TikTok','Threads','X','Other')),
  url text not null check (
    char_length(url) between 12 and 500
    and url ~ '^https://[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}(/|[?#]|$)'
    and case platform
      when 'Instagram' then lower(substring(url from '^https://([^/?#]+)')) in ('instagram.com','www.instagram.com')
      when 'Facebook' then lower(substring(url from '^https://([^/?#]+)')) in ('facebook.com','www.facebook.com','m.facebook.com','fb.com','www.fb.com')
      when 'YouTube' then lower(substring(url from '^https://([^/?#]+)')) in ('youtube.com','www.youtube.com','m.youtube.com','youtu.be')
      when 'Snapchat' then lower(substring(url from '^https://([^/?#]+)')) in ('snapchat.com','www.snapchat.com')
      when 'TikTok' then lower(substring(url from '^https://([^/?#]+)')) in ('tiktok.com','www.tiktok.com','m.tiktok.com')
      when 'Threads' then lower(substring(url from '^https://([^/?#]+)')) in ('threads.net','www.threads.net')
      when 'X' then lower(substring(url from '^https://([^/?#]+)')) in ('x.com','www.x.com','twitter.com','www.twitter.com')
      else true
    end
  ),
  visibility text not null default 'hidden' check (visibility in ('hidden','matches','members')),
  created_at timestamptz not null default now(),
  unique (owner_id,platform)
);

create index spark_social_links_owner_visibility on public.spark_social_links(owner_id,visibility);
alter table public.spark_social_links enable row level security;
revoke all on public.spark_social_links from anon;
grant select,insert,update,delete on public.spark_social_links to authenticated;

create policy "owner or permitted members see links" on public.spark_social_links
  for select to authenticated using (
    owner_id = (select auth.uid())
    or (
      visibility <> 'hidden'
      and exists (select 1 from public.spark_profiles viewer where viewer.id = (select auth.uid()))
      and not exists (
        select 1 from public.spark_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = owner_id)
           or (b.blocker_id = owner_id and b.blocked_id = (select auth.uid()))
      )
      and (
        visibility = 'members'
        or (visibility = 'matches' and exists (
          select 1 from public.spark_connections c
          where c.status = 'accepted'
            and ((c.requester_id = (select auth.uid()) and c.recipient_id = owner_id)
              or (c.recipient_id = (select auth.uid()) and c.requester_id = owner_id))
        ))
      )
    )
  );
create policy "owner creates link" on public.spark_social_links
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "owner edits link" on public.spark_social_links
  for update to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "owner removes link" on public.spark_social_links
  for delete to authenticated using (owner_id = (select auth.uid()));
