-- Payment/webhook service provisions these entitlements. Browser roles cannot.
create table public.spark_member_plans(user_id uuid primary key references public.spark_profiles(id) on delete cascade,
  tier text not null check(tier in ('Plus','Gold','Signature')),expires_at timestamptz not null);
alter table public.spark_member_plans enable row level security;
revoke all on public.spark_member_plans from public,anon,authenticated;
grant select(user_id,tier,expires_at) on public.spark_member_plans to authenticated;
create policy "member sees own plan" on public.spark_member_plans for select to authenticated
  using(user_id=(select auth.uid()));

-- Exposes only visible candidate IDs and their tier weights. No contact data,
-- payment details or hidden profiles are returned by this function.
create function public.spark_discovery_weights() returns table(profile_id uuid,boost smallint)
language sql stable security definer set search_path=''
as $$ select p.id,
  (case when mp.expires_at>now() then case mp.tier when 'Signature' then 3 when 'Gold' then 2 when 'Plus' then 1 else 0 end else 0 end)::smallint
  from public.spark_profiles p left join public.spark_member_plans mp on mp.user_id=p.id
  where auth.uid() is not null and p.id<>auth.uid()
    and not exists(select 1 from public.spark_suspended_profiles s where s.user_id=p.id)
    and not exists(select 1 from public.spark_discovery_pauses d where d.user_id=p.id)
    and not exists(select 1 from public.spark_blocks b where
      (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
$$;
revoke all on function public.spark_discovery_weights() from public,anon;
grant execute on function public.spark_discovery_weights() to authenticated;
