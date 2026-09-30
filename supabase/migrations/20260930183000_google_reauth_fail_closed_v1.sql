begin;

-- ASCENDA Google sync P0 · fail closed when OAuth refresh is no longer valid.
-- 1) Never claim Calendar/Contacts work for a disconnected/error/non-primary connection.
-- 2) A refresh-token failure immediately marks the connection ERROR so the existing
--    Configuración > Integraciones UI asks for OAuth reconnection instead of churning.

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
    where q.state in ('READY','FAILED')
      and q.available_at <= now()
      and q.attempt_count < 8
      and c.status='CONNECTED'
      and c.is_primary=true
    order by q.created_at
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

create or replace function public.aos_google_reauth_fail_closed_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.state='FAILED'
     and coalesce(new.last_error,'') like 'GOOGLE_TOKEN_REFRESH_FAILED%'
     and (
       old.state is distinct from new.state
       or old.last_error is distinct from new.last_error
     ) then
    update public.aos_google_connections_v1 c
       set status='ERROR',
           last_error='GOOGLE_TOKEN_REFRESH_FAILED · REAUTH_REQUIRED',
           updated_at=now()
     where c.id=new.connection_id
       and c.status='CONNECTED';
  end if;
  return new;
end
$$;

revoke all on function public.aos_google_reauth_fail_closed_v1() from public, anon, authenticated;
grant execute on function public.aos_google_reauth_fail_closed_v1() to service_role;

drop trigger if exists trg_aos_google_reauth_fail_closed_v1 on public.aos_google_sync_outbox_v1;
create trigger trg_aos_google_reauth_fail_closed_v1
after update of state,last_error on public.aos_google_sync_outbox_v1
for each row
execute function public.aos_google_reauth_fail_closed_v1();

comment on function public.aos_google_claim_sync_v1(text,integer) is
'Google sync claim V1.1: claims only work owned by the active primary CONNECTED OAuth connection.';
comment on function public.aos_google_reauth_fail_closed_v1() is
'Marks Google OAuth connection ERROR on refresh-token failure so retries fail closed until human reauthorization.';

commit;
