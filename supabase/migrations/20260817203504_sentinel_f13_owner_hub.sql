-- Sentinel F13 — owner/admin Hub read boundary
-- Read-only projection over F8 incidents. Reuses F9 Auth V3 + PASSWORD_2FA owner actor.
begin;

create or replace function public.aos_sentinel_owner_hub_v1(p_token text,p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_actor uuid;
  v_limit integer;
  v_items jsonb;
  v_active bigint;
begin
  v_actor:=public.aos_sentinel_owner_actor_v1(p_token);
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','SENTINEL_OWNER_2FA_REQUIRED');
  end if;

  v_limit:=least(greatest(coalesce(p_limit,50),1),50);

  select coalesce(pg_catalog.jsonb_agg(x.obj order by x.updated_at desc),'[]'::jsonb)
  into v_items
  from (
    select i.updated_at,
      pg_catalog.jsonb_build_object(
        'incident_id',i.incident_id,
        'severity',i.severity,
        'status',i.status,
        'environment',i.environment,
        'domain',i.domain,
        'component',i.component,
        'capability',i.capability,
        'failure_family',i.failure_family,
        'opened_at',i.opened_at,
        'updated_at',i.updated_at,
        'last_signal_at',i.last_signal_at,
        'resolved_at',i.resolved_at,
        'signal_count',i.signal_count,
        'reopened_count',i.reopened_count,
        'evidence_refs',i.evidence_refs,
        'correlation',coalesce(i.correlation,'{}'::jsonb),
        'timeline',(
          select coalesce(pg_catalog.jsonb_agg(t.obj order by t.occurred_at asc),'[]'::jsonb)
          from (
            select tl.occurred_at,
              pg_catalog.jsonb_build_object('event_type',tl.event_type,'occurred_at',tl.occurred_at) obj
            from public.aos_sentinel_incident_timeline_v1 tl
            where tl.incident_id=i.incident_id
            order by tl.occurred_at desc,tl.timeline_id desc
            limit 20
          ) t
        )
      ) obj
    from public.aos_sentinel_incidents_v1 i
    order by i.updated_at desc
    limit v_limit
  ) x;

  select count(*) into v_active
  from public.aos_sentinel_incidents_v1 i
  where i.status<>'RESOLVED';

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'schema_version','sentinel-owner-hub/v1',
    'generated_at',pg_catalog.clock_timestamp(),
    'active_incidents',v_active,
    'health_mode','INCIDENT_PLUS_EXPLICIT_UNKNOWN',
    'items',v_items
  );
end;
$$;

revoke all on function public.aos_sentinel_owner_hub_v1(text,integer) from public;
grant execute on function public.aos_sentinel_owner_hub_v1(text,integer) to anon,authenticated,service_role;

commit;
