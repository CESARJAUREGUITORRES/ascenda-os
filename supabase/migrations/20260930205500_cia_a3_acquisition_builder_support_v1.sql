begin;

-- CIA A3 · Acquisition builder support + acquisition-aware previews.
-- Additive: no distribution execution is enabled.

create or replace function public.aos_cia_audience_field_type_v1(p_field text)
returns text
language sql
immutable parallel safe
as $function$
select case
 when p_field in ('contact.identity_status','crm.age_band','lead.latest_interest_type','sales.latest_item_type','segment.value_tier','segment.lifecycle','segment.engagement') then 'enum'
 when p_field in ('contact.email_valid','lead.called_since_latest_entry','lead.unworked_since_latest_entry','email.never_sent') then 'boolean3'
 when p_field in ('contact.identity_conflict','contact.exists_as_patient','contact.exists_as_lead','calls.never_called','calls.called_today','appointments.never_had','appointments.has_future','appointments.ever_no_show','sales.never_bought') then 'boolean'
 when p_field in ('appointments.last_at','appointments.next_at','followups.next_at','acquisition.first_web_booking_at','acquisition.last_web_booking_at') then 'date'
 when p_field in ('lead.interests','lead.ads','calls.ever_statuses','appointments.statuses','sales.products','sales.services','sales.payment_states','sales.payment_methods','followups.treatments','segment.traits') then 'set'
 when p_field='sales.revenue_lifetime' then 'numeric'
 when p_field in ('crm.age_years','lead.count','lead.days_since_last','calls.total','calls.days_since_last','calls.effective_contact_count','appointments.total','appointments.no_show_count','appointments.attended_count','sales.total','sales.days_since_last','sales.product_count','sales.service_count','followups.pending_count','followups.overdue_count','email.sent_count','email.days_since_last','email.opened_count','email.clicked_count','email.bounced_count','segment.value_score','acquisition.web_booking_count') then 'integer'
 when p_field in ('crm.patient_state','crm.base_label','crm.base_campaign','crm.branch','crm.department','crm.city','crm.district','crm.sex','lead.latest_interest','calls.latest_status','calls.latest_substatus',
                  'acquisition.channel','acquisition.platform','acquisition.landing_code','acquisition.landing_name',
                  'acquisition.campaign_code','acquisition.campaign_name','acquisition.ad_code','acquisition.ad_name',
                  'acquisition.treatment','acquisition.utm_source','acquisition.utm_medium','acquisition.utm_campaign','acquisition.utm_content') then 'text'
 else null end;
$function$;

create or replace function public.aos_cia_audience_preview_v2(
  p_filter jsonb,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
as $function$
declare
  v jsonb;
  keys text[];
  page_keys text[];
  lim integer:=greatest(1,least(coalesce(p_limit,50),100));
  offv integer:=greatest(0,coalesce(p_offset,0));
  items jsonb;
  seg_fresh timestamptz;
  email_fresh timestamptz;
begin
  v:=public.aos_cia_audience_validate_v1(p_filter);
  if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v); end if;
  keys:=public.aos_cia_audience_resolve_node_v2(p_filter->'root',1);
  select coalesce(array_agg(k order by k),array[]::text[]) into page_keys
  from (select k from unnest(keys) k order by k limit lim offset offv) q;

  select coalesce(jsonb_agg(jsonb_build_object(
    'contact_key',c.contact_key,'identity_status',c.identity_status,'identity_conflict',c.identity_conflict,
    'name',c.contact_name,'patient_state',c.patient_state,
    'branch',coalesce(c.raw_branch,a.latest_sale_branch,a.next_appointment_branch),'age_band',c.age_band,
    'value_tier',c.value_tier,'lifecycle',c.lifecycle,'engagement',c.engagement,'traits',c.traits,
    'latest_interest',a.latest_interest,'last_call_at',a.last_call_at,'latest_call_status',a.latest_call_status,
    'has_future_appointment',(a.next_appointment_at is not null),'next_appointment_at',a.next_appointment_at,
    'sale_count',a.sale_count,'revenue_lifetime',a.revenue_lifetime,
    'pending_followups',a.pending_followups,'overdue_followups',a.overdue_followups,
    'email_never_sent',c.email_never_sent,
    'canonical_email',r.canonical_email,
    'web_booking_count',r.web_booking_count,
    'latest_acquisition_channel',r.latest_acquisition_channel,
    'latest_platform',r.latest_platform,
    'latest_landing_code',r.latest_landing_code,
    'latest_landing_name',r.latest_landing_name,
    'latest_campaign_code',r.latest_campaign_code,
    'latest_campaign_name',r.latest_campaign_name,
    'latest_ad_code',r.latest_ad_code,
    'latest_ad_name',r.latest_ad_name,
    'latest_treatment',r.latest_treatment,
    'latest_utm_source',r.latest_utm_source,
    'latest_utm_medium',r.latest_utm_medium,
    'latest_utm_campaign',r.latest_utm_campaign,
    'latest_utm_content',r.latest_utm_content,
    'first_web_booking_at',r.first_web_booking_at,
    'last_web_booking_at',r.last_web_booking_at
  ) order by c.contact_key),'[]'::jsonb) into items
  from public.aos_cia_preview_core_v2(page_keys) c
  join public.aos_cia_preview_activity_v2(page_keys) a using(contact_key)
  left join public.aos_cia_contact_runtime_cache_v1 r using(contact_key);

  select max(cache_refreshed_at) into seg_fresh from public.aos_cia_segment_runtime_cache_v2;
  select max(cache_refreshed_at) into email_fresh from public.aos_cia_email_runtime_cache_v2;
  return jsonb_build_object(
    'ok',true,'count',cardinality(keys),'limit',lim,'offset',offv,'items',items,
    'resolver_version',2,'segment_cache_refreshed_at',seg_fresh,'email_cache_refreshed_at',email_fresh,
    'observed_at',statement_timestamp()
  );
end;
$function$;

create or replace function public.aos_cia_workspace_preview_app_v2(
  p_app_token text,
  p_preset_key text default null,
  p_all_contacts boolean default false,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;v_uid uuid;v_role text;v_assurance text;v_panels text[];
  v_key text:=upper(coalesce(p_preset_key,''));v_limit integer;v_offset integer;v_count integer;v_items jsonb;
begin
  v_auth:=public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  v_uid:=(v_auth->>'user_id')::uuid;
  v_role:=upper(coalesce(v_auth->>'rol',''));
  v_assurance:=upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels from public.aos_usuarios u where u.id=v_uid and u.activo=true;
  if v_role<>'ADMIN' or v_assurance<>'PASSWORD_2FA' or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;

  v_limit:=greatest(1,least(coalesce(p_limit,25),100));
  v_offset:=greatest(0,coalesce(p_offset,0));
  if not coalesce(p_all_contacts,false)
     and not exists(select 1 from public.aos_audience_presets p where p.active=true and p.preset_key=v_key) then
    return jsonb_build_object('ok',false,'error','UNKNOWN_CATALOG_AUDIENCE');
  end if;

  if coalesce(p_all_contacts,false) then
    select coalesce((select count_cache::integer from public.aos_audience_preset_runtime_cache_v1 where preset_key='__ALL__'),
                    (select count(*)::integer from public.aos_cia_contact_runtime_cache_v1)) into v_count;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.contact_key),'[]'::jsonb) into v_items
    from (
      select c.contact_key,
             nullif(trim(concat_ws(' ',c.canonical_names,c.canonical_surnames)),'') name,
             c.canonical_email email,c.crm_branch branch,c.district,c.sex,c.age_band,c.patient_state,
             c.value_tier,c.lifecycle,c.engagement,c.latest_interest,c.latest_call_status,c.last_call_at,
             c.next_appointment_at,c.sale_count,c.revenue_lifetime,c.overdue_followup_count overdue_followups,
             c.web_booking_count,c.latest_acquisition_channel,c.latest_platform,c.latest_landing_code,c.latest_landing_name,
             c.latest_campaign_code,c.latest_campaign_name,c.latest_ad_code,c.latest_ad_name,c.latest_treatment,
             c.latest_utm_source,c.latest_utm_medium,c.latest_utm_campaign,c.latest_utm_content,
             c.first_web_booking_at,c.last_web_booking_at
      from public.aos_cia_contact_runtime_cache_v1 c
      order by c.contact_key limit v_limit offset v_offset
    ) q;
  else
    select coalesce((select count_cache::integer from public.aos_audience_preset_runtime_cache_v1 where preset_key=v_key),
                    (select count(*)::integer from public.aos_cia_workspace_catalog_members_v1(v_key))) into v_count;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.contact_key),'[]'::jsonb) into v_items
    from (
      select c.contact_key,
             nullif(trim(concat_ws(' ',c.canonical_names,c.canonical_surnames)),'') name,
             c.canonical_email email,c.crm_branch branch,c.district,c.sex,c.age_band,c.patient_state,
             c.value_tier,c.lifecycle,c.engagement,c.latest_interest,c.latest_call_status,c.last_call_at,
             c.next_appointment_at,c.sale_count,c.revenue_lifetime,c.overdue_followup_count overdue_followups,
             c.web_booking_count,c.latest_acquisition_channel,c.latest_platform,c.latest_landing_code,c.latest_landing_name,
             c.latest_campaign_code,c.latest_campaign_name,c.latest_ad_code,c.latest_ad_name,c.latest_treatment,
             c.latest_utm_source,c.latest_utm_medium,c.latest_utm_campaign,c.latest_utm_content,
             c.first_web_booking_at,c.last_web_booking_at
      from public.aos_cia_workspace_catalog_members_v1(v_key) c
      order by c.contact_key limit v_limit offset v_offset
    ) q;
  end if;

  return jsonb_build_object('ok',true,'count',v_count,'limit',v_limit,'offset',v_offset,'items',v_items,
                            'source','CATALOG_RUNTIME_FAST_V2','observed_at',statement_timestamp());
exception when others then
  return jsonb_build_object('ok',false,'error','WORKSPACE_PREVIEW_V2_ERROR','code',sqlstate);
end;
$function$;

revoke all on function public.aos_cia_workspace_preview_app_v2(text,text,boolean,integer,integer) from public;
grant execute on function public.aos_cia_workspace_preview_app_v2(text,text,boolean,integer,integer) to anon,authenticated;

select public.aos_cia_catalog_refresh_counts_v1();
select pg_notify('pgrst','reload schema');

commit;
