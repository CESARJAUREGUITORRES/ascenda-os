begin;

-- Google delivery V1.3
-- Fresh appointments and stale claimed jobs must not sit behind historical OAuth backlog.
-- A small partial index keeps stale-claim recovery bounded.

create index if not exists idx_aos_google_sync_outbox_v1_claimed_lock
  on public.aos_google_sync_outbox_v1 (locked_at, created_at desc)
  where state='CLAIMED';

create or replace function public.aos_google_claim_sync_v1(
  p_worker text,
  p_limit integer default 10
)
returns setof public.aos_google_sync_outbox_v1
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return query
  with picked as (
    select q.id
    from public.aos_google_sync_outbox_v1 q
    join public.aos_google_connections_v1 c on c.id=q.connection_id
    where (
        q.state in ('READY','FAILED')
        or (
          q.state='CLAIMED'
          and q.locked_at is not null
          and q.locked_at < now() - interval '5 minutes'
        )
      )
      and q.available_at <= now()
      and q.attempt_count < 8
      and c.status='CONNECTED'
      and c.is_primary=true
    order by
      case
        when q.state='CLAIMED' and q.locked_at < now() - interval '5 minutes' then 0
        when q.created_at >= now() - interval '24 hours' then 1
        else 2
      end,
      case
        when q.state='CLAIMED' and q.locked_at < now() - interval '5 minutes' then q.created_at
        when q.created_at >= now() - interval '24 hours' then q.created_at
      end desc nulls last,
      q.created_at asc
    for update of q skip locked
    limit greatest(1, least(coalesce(p_limit,10),50))
  )
  update public.aos_google_sync_outbox_v1 q
     set state='CLAIMED',
         attempt_count=q.attempt_count+1,
         locked_at=now(),
         locked_by=left(coalesce(p_worker,'google-worker'),120),
         updated_at=now()
   where q.id in (select id from picked)
  returning q.*;
end
$$;

revoke all on function public.aos_google_claim_sync_v1(text,integer) from public, anon, authenticated;
grant execute on function public.aos_google_claim_sync_v1(text,integer) to service_role;

comment on function public.aos_google_claim_sync_v1(text,integer) is
'Google sync claim V1.3: prioritize stale claims and fresh appointment delivery ahead of historical backlog.';

commit;
