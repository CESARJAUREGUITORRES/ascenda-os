-- ASCENDA CIA Phase 8 — binding/read contracts and Phase 9 handoff.

create or replace function public.aos_cia_context_policy_list_internal_v1(p_channel text default null)
returns jsonb
language sql
stable
set search_path=public
as $$
select jsonb_build_object('ok',true,'items',coalesce(jsonb_agg(jsonb_build_object(
  'policy_key',policy_key,'version',version,'channel',channel,'name',name,'is_default',is_default,
  'rules',rules,'effective_from',effective_from,'effective_to',effective_to
) order by channel,is_default desc,policy_key,version desc),'[]'::jsonb))
from public.aos_cia_context_policies
where status='ACTIVE' and effective_from<=now() and (effective_to is null or effective_to>now())
  and (p_channel is null or channel=upper(p_channel));
$$;

create or replace function public.aos_cia_activation_context_bind_admin_v1(
  p_token text,p_activation_id uuid,p_policy_key text default null,p_policy_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare auth jsonb; uid uuid; ch text; pk text; pv integer; existing record;
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  uid:=(auth->>'user_id')::uuid;
  select c.channel into ch from public.aos_audiencia_activacion_config c where c.activacion_id=p_activation_id;
  if ch is null then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND'); end if;
  select * into existing from public.aos_audiencia_activacion_context where activation_id=p_activation_id;
  if existing.activation_id is not null then
    return jsonb_build_object('ok',true,'already_bound',true,'activation_id',p_activation_id,'policy_key',existing.policy_key,'policy_version',existing.policy_version,'bound_at',existing.bound_at);
  end if;
  if nullif(upper(btrim(coalesce(p_policy_key,''))),'') is null then
    select policy_key,version into pk,pv from public.aos_cia_context_policies
    where channel=upper(ch) and status='ACTIVE' and is_default and effective_from<=now() and (effective_to is null or effective_to>now())
    order by version desc limit 1;
  else
    pk:=upper(btrim(p_policy_key));
    if p_policy_version is null then
      select version into pv from public.aos_cia_context_policies where policy_key=pk and channel=upper(ch) and status='ACTIVE' and effective_from<=now() and (effective_to is null or effective_to>now()) order by version desc limit 1;
    else pv:=p_policy_version; end if;
  end if;
  if pk is null or pv is null then return jsonb_build_object('ok',false,'error','NO_COMPATIBLE_POLICY','channel',ch); end if;
  insert into public.aos_audiencia_activacion_context(activation_id,policy_key,policy_version,bound_by_user_id)
  values(p_activation_id,pk,pv,uid);
  return jsonb_build_object('ok',true,'already_bound',false,'activation_id',p_activation_id,'policy_key',pk,'policy_version',pv,'channel',upper(ch),'bound_by_user_id',uid,'bound_at',now());
exception when others then
  if sqlerrm like '%CONTEXT_POLICY_CHANNEL_MISMATCH%' then return jsonb_build_object('ok',false,'error','CONTEXT_POLICY_CHANNEL_MISMATCH'); end if;
  raise;
end;
$$;

create or replace function public.aos_cia_activation_context_summary_v1(p_activation_id uuid)
returns jsonb
language sql
stable
set search_path=public
as $$
with meta as (
  select a.id,c.mode,c.channel,s.estado,b.policy_key,b.policy_version,p.name policy_name
  from public.aos_audiencia_activaciones a
  join public.aos_audiencia_activacion_config c on c.activacion_id=a.id
  join public.aos_audiencia_activacion_estado s on s.activacion_id=a.id
  left join public.aos_audiencia_activacion_context b on b.activation_id=a.id
  left join public.aos_cia_context_policies p on p.policy_key=b.policy_key and p.version=b.policy_version
  where a.id=p_activation_id
), rows as materialized (
  select * from public.aos_cia_activation_context_rows_v1(p_activation_id)
), counts as (
  select count(*) total,
    count(*) filter(where eligibility_status='ELIGIBLE') eligible,
    count(*) filter(where eligibility_status='INELIGIBLE') ineligible,
    count(*) filter(where eligibility_status='UNKNOWN') eligibility_unknown,
    count(*) filter(where eligibility_status='ELIGIBLE' and availability_status='AVAILABLE') available_now,
    count(*) filter(where eligibility_status='ELIGIBLE' and availability_status='UNAVAILABLE') unavailable_now,
    count(*) filter(where eligibility_status='ELIGIBLE' and availability_status='UNKNOWN') availability_unknown,
    count(*) filter(where is_assignable) assignable_now
  from rows
), rc as (
  select coalesce(jsonb_object_agg(reason,n order by reason),'{}'::jsonb) reason_counts
  from (select reason,count(*) n from rows cross join lateral unnest(reasons) reason group by reason) x
), wc as (
  select coalesce(jsonb_object_agg(warning,n order by warning),'{}'::jsonb) warning_counts
  from (select warning,count(*) n from rows cross join lateral unnest(warnings) warning group by warning) x
)
select case when not exists(select 1 from meta) then jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND')
            when (select policy_key from meta) is null then jsonb_build_object('ok',false,'error','CONTEXT_NOT_BOUND','channel',(select channel from meta))
            else jsonb_build_object('ok',true,'activation_id',p_activation_id,
              'activation_state',(select estado from meta),'membership_mode',(select mode from meta),
              'channel',(select channel from meta),'policy_key',(select policy_key from meta),'policy_version',(select policy_version from meta),'policy_name',(select policy_name from meta),
              'audience_total',counts.total,'eligible',counts.eligible,'ineligible',counts.ineligible,'eligibility_unknown',counts.eligibility_unknown,
              'available_now',counts.available_now,'unavailable_now',counts.unavailable_now,'availability_unknown',counts.availability_unknown,
              'assignable_now',counts.assignable_now,'reason_counts',rc.reason_counts,'warning_counts',wc.warning_counts,
              'evaluated_at',statement_timestamp()) end
from counts,rc,wc;
$$;

create or replace function public.aos_cia_activation_context_preview_v1(p_activation_id uuid,p_limit integer default 50,p_offset integer default 0)
returns jsonb
language sql
stable
set search_path=public
as $$
with lim as (select least(greatest(coalesce(p_limit,50),1),100) n,greatest(coalesce(p_offset,0),0) o),
rows as materialized (select * from public.aos_cia_activation_context_rows_v1(p_activation_id)),
page as (
 select r.* from rows r order by r.is_assignable desc,r.eligibility_status,r.availability_status,r.contact_key
 limit (select n from lim) offset (select o from lim)
)
select jsonb_build_object('ok',true,'limit',(select n from lim),'offset',(select o from lim),'total',(select count(*) from rows),
 'items',coalesce(jsonb_agg(jsonb_build_object('contact_key',contact_key,'eligibility_status',eligibility_status,'availability_status',availability_status,'is_assignable',is_assignable,'reasons',to_jsonb(reasons),'warnings',to_jsonb(warnings),'policy_key',policy_key,'policy_version',policy_version,'channel',channel)),'[]'::jsonb))
from page;
$$;

create or replace function public.aos_cia_activation_context_explain_v1(p_activation_id uuid,p_contact_key text)
returns jsonb
language sql
stable
set search_path=public
as $$
select coalesce((select jsonb_build_object('ok',true,'activation_id',p_activation_id,'contact_key',r.contact_key,
 'eligibility_status',r.eligibility_status,'availability_status',r.availability_status,'is_assignable',r.is_assignable,
 'reasons',to_jsonb(r.reasons),'warnings',to_jsonb(r.warnings),'policy_key',r.policy_key,'policy_version',r.policy_version,'channel',r.channel,'evaluated_at',statement_timestamp())
 from public.aos_cia_activation_context_rows_v1(p_activation_id) r where r.contact_key=p_contact_key limit 1),
 jsonb_build_object('ok',false,'error','CONTACT_NOT_IN_ACTIVATION'));
$$;

create or replace function public.aos_cia_activation_available_keys_v1(p_activation_id uuid)
returns table(contact_key text)
language sql
stable
set search_path=public
as $$
select r.contact_key from public.aos_cia_activation_context_rows_v1(p_activation_id) r where r.is_assignable order by r.contact_key;
$$;
