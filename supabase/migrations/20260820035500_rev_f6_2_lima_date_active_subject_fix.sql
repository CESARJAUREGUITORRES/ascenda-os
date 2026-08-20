-- REV-F6.2 hotfix — business date is America/Lima and lifecycle excludes fused canonical subjects.
begin;

create or replace function public.aos_rev_business_date_lima_v1()
returns date
language sql
stable
set search_path=''
as $$ select (now() at time zone 'America/Lima')::date $$;
revoke all on function public.aos_rev_business_date_lima_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_business_date_lima_v1() to service_role;

create or replace view public.aos_rev_customer_agenda_identity_v1 as
with candidate as (
  select c.id appointment_id,c.fecha_cita,c.estado_cita,a.canonical_patient_id,'PHONE'::text match_method
  from public.aos_agenda_citas c
  join public.aos_rev_patient_identity_alias_v2 a
    on a.identifier_type='PHONE'
   and a.identifier_key=public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(c.numero_limpio,''),c.numero))
   and a.status='RESOLVED'
  join public.aos_pacientes p on p."ID_PACIENTE"=a.canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  union all
  select c.id,c.fecha_cita,c.estado_cita,a.canonical_patient_id,'DOCUMENT'
  from public.aos_agenda_citas c
  join public.aos_rev_patient_identity_alias_v2 a
    on a.identifier_type='DOCUMENT'
   and a.identifier_key=public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',c.dni)
   and a.status='RESOLVED'
  join public.aos_pacientes p on p."ID_PACIENTE"=a.canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  union all
  select c.id,c.fecha_cita,c.estado_cita,a.canonical_patient_id,'EMAIL'
  from public.aos_agenda_citas c
  join public.aos_rev_patient_identity_alias_v2 a
    on a.identifier_type='EMAIL'
   and a.identifier_key=public.aos_rev_normalize_patient_identifier_v2('EMAIL',c.correo)
   and a.status='RESOLVED'
  join public.aos_pacientes p on p."ID_PACIENTE"=a.canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
), scored as (
  select c.id appointment_id,c.fecha_cita,c.estado_cita,
         count(distinct x.canonical_patient_id)::integer candidate_count,
         min(x.canonical_patient_id) canonical_patient_id,
         coalesce(jsonb_agg(distinct x.match_method order by x.match_method) filter(where x.match_method is not null),'[]'::jsonb) match_methods
  from public.aos_agenda_citas c
  left join candidate x on x.appointment_id=c.id
  group by c.id,c.fecha_cita,c.estado_cita
)
select appointment_id,fecha_cita,estado_cita,
       case when candidate_count=1 then canonical_patient_id else null end canonical_patient_id,
       candidate_count,
       case when candidate_count=1 then 'RESOLVED' when candidate_count>1 then 'IDENTITY_CONFLICT' else 'UNRESOLVED' end::text identity_status,
       match_methods
from scored;

revoke all on public.aos_rev_customer_agenda_identity_v1 from public,anon,authenticated;
grant select on public.aos_rev_customer_agenda_identity_v1 to service_role;

create or replace view public.aos_rev_customer_lifecycle_events_v1 as
select distinct
  c.target_patient_id::text canonical_patient_id,
  s.last_appointment::date event_date,
  'HISTORICAL_APPOINTMENT'::text event_type,
  'F5_REVIEWED_MATCH'::text provenance,
  'PATIENT_HISTORY'::text evidence_domain
from public.aos_f5_canonical_classification_v1 c
join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
join public.aos_pacientes p on p."ID_PACIENTE"=c.target_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
where c.classification='MATCH' and c.target_patient_id is not null and s.last_appointment is not null
union
select distinct
  a.canonical_patient_id::text,a.fecha_cita::date,'ATTENDED_APPOINTMENT'::text,
  'AGENDA_IDENTITY_BRIDGE_V2'::text,'PATIENT_ACTIVITY'::text
from public.aos_rev_customer_agenda_identity_v1 a
where a.identity_status='RESOLVED' and a.estado_cita in ('ASISTIO','EFECTIVA') and a.canonical_patient_id is not null
union
select distinct
  j.canonical_patient_id::text,v.fecha::date,'CANONICAL_SALE'::text,
  'F5_SALE_MATCH'::text,'TRANSACTION_2026'::text
from public.aos_f5_historical_join_v1 j
join public.aos_ventas v on v.id=j.sale_id
join public.aos_pacientes p on p."ID_PACIENTE"=j.canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
where j.patient_link_status='MATCH' and j.canonical_patient_id is not null;

revoke all on public.aos_rev_customer_lifecycle_events_v1 from public,anon,authenticated;
grant select on public.aos_rev_customer_lifecycle_events_v1 to service_role;

create or replace function public.aos_rev_customer_lifecycle_by_patient_v1(p_canonical_patient_id text,p_as_of date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_as_of date := coalesce(p_as_of,public.aos_rev_business_date_lima_v1());
  v_exists boolean := false;
  v_event_rows integer := 0;
  v_active_days integer := 0;
  v_first_event date;
  v_last_event date;
  v_previous_event date;
  v_hist_events integer := 0;
  v_agenda_events integer := 0;
  v_sale_events integer := 0;
  v_observed_months integer := 0;
  v_future boolean := false;
  v_future_date date;
  v_recency integer;
  v_gap integer;
  v_state text;
  v_classification_status text;
  v_claim_strength text;
begin
  select exists(select 1 from public.aos_pacientes p where p."ID_PACIENTE"=p_canonical_patient_id and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO') into v_exists;
  if not v_exists then
    return jsonb_build_object('contract','REV-F6.2_CUSTOMER_LIFECYCLE_V1','as_of',v_as_of,'canonical_patient_id',p_canonical_patient_id,'lifecycle_state',null,'classification_status','CANONICAL_TARGET_MISSING','claim_strength','UNRESOLVED');
  end if;

  select count(*)::integer,count(distinct e.event_date)::integer,min(e.event_date),max(e.event_date),
         count(*) filter(where e.event_type='HISTORICAL_APPOINTMENT')::integer,
         count(*) filter(where e.event_type='ATTENDED_APPOINTMENT')::integer,
         count(*) filter(where e.event_type='CANONICAL_SALE')::integer,
         count(distinct date_trunc('month',e.event_date::timestamp))::integer
  into v_event_rows,v_active_days,v_first_event,v_last_event,v_hist_events,v_agenda_events,v_sale_events,v_observed_months
  from public.aos_rev_customer_lifecycle_events_v1 e
  where e.canonical_patient_id=p_canonical_patient_id and e.event_date<=v_as_of;

  if v_last_event is not null then
    select max(e.event_date) into v_previous_event from public.aos_rev_customer_lifecycle_events_v1 e where e.canonical_patient_id=p_canonical_patient_id and e.event_date<v_last_event and e.event_date<=v_as_of;
    v_recency := v_as_of-v_last_event;
    if v_previous_event is not null then v_gap := v_last_event-v_previous_event; end if;
  end if;

  select exists(select 1 from public.aos_rev_customer_agenda_identity_v1 a where a.identity_status='RESOLVED' and a.canonical_patient_id=p_canonical_patient_id and a.estado_cita='CITA CONFIRMADA' and a.fecha_cita>v_as_of),
         min(a.fecha_cita) filter(where a.identity_status='RESOLVED' and a.canonical_patient_id=p_canonical_patient_id and a.estado_cita='CITA CONFIRMADA' and a.fecha_cita>v_as_of)
  into v_future,v_future_date from public.aos_rev_customer_agenda_identity_v1 a;

  if v_event_rows=0 then
    v_state:=null; v_classification_status:='INSUFFICIENT_ACTIVITY_EVIDENCE'; v_claim_strength:='UNRESOLVED';
  elsif v_previous_event is not null and v_gap>=180 and v_recency between 0 and 30 then
    v_state:='HISTORICAL_REACTIVATED'; v_classification_status:='CLASSIFIED'; v_claim_strength:=case when v_hist_events>0 then 'HIGH' else 'MEDIUM' end;
  elsif v_active_days=1 and v_recency between 0 and 90 then
    v_state:='NEW_PATIENT'; v_classification_status:='CLASSIFIED'; v_claim_strength:=case when v_hist_events>0 then 'MEDIUM' else 'LOW' end;
  elsif v_active_days>=2 and v_recency between 0 and 90 then
    v_state:='ACTIVE_REPEAT'; v_classification_status:='CLASSIFIED'; v_claim_strength:=case when v_hist_events>0 then 'HIGH' else 'MEDIUM' end;
  elsif v_recency>180 and not v_future then
    v_state:='DORMANT'; v_classification_status:='CLASSIFIED'; v_claim_strength:=case when v_hist_events>0 then 'HIGH' else 'MEDIUM' end;
  else
    v_state:='RETURNING_PATIENT'; v_classification_status:='CLASSIFIED'; v_claim_strength:=case when v_hist_events>0 or v_active_days>=2 then 'MEDIUM' else 'LOW' end;
  end if;

  return jsonb_build_object(
    'contract','REV-F6.2_CUSTOMER_LIFECYCLE_V1','as_of',v_as_of,'canonical_patient_id',p_canonical_patient_id,
    'lifecycle_state',v_state,'classification_status',v_classification_status,'claim_strength',v_claim_strength,
    'precedence',jsonb_build_array('UNRESOLVED_IDENTITY','HISTORICAL_REACTIVATED','NEW_PATIENT','ACTIVE_REPEAT','RETURNING_PATIENT','DORMANT'),
    'thresholds',jsonb_build_object('active_days',90,'dormant_gap_days',180,'reactivation_gap_days',180,'reactivation_window_days',30),
    'event_definition',jsonb_build_object('qualifying',jsonb_build_array('F5_REVIEWED_MATCH:HISTORICAL_APPOINTMENT','AGENDA:ASISTIO','AGENDA:EFECTIVA','F5_MATCH:CANONICAL_SALE'),'future_confirmed_appointment_status','CITA CONFIRMADA','registration_is_not_qualifying',true),
    'evidence',jsonb_build_object('event_rows',v_event_rows,'active_days',v_active_days,'first_observed_event',v_first_event,'last_observed_event',v_last_event,'previous_observed_event',v_previous_event,'historical_patient_events',v_hist_events,'agenda_attended_events',v_agenda_events,'observed_sales',v_sale_events,'observed_active_months',v_observed_months),
    'flags',jsonb_build_object('is_first_observed_sale',(v_sale_events=1),'is_repeat_sale',(v_sale_events>=2),'reactivation_gap_days',v_gap,'has_future_appointment',v_future,'next_confirmed_appointment',v_future_date,'observed_purchase_count',v_sale_events,'observed_active_months',v_observed_months,'recency_days',v_recency),
    'coverage',jsonb_build_object('patient_activity_scope','F5 reviewed patient-history appointment evidence + safely resolved Agenda + canonical matched sales','patient_history_linkage','PARTIAL_SAFE_MATCH_ONLY','transaction_scope','2026_ONLY','transaction_min_date',(select min(v.fecha) from public.aos_ventas v),'transaction_max_date',(select max(v.fecha) from public.aos_ventas v),'history_complete',false),
    'historical_warning','2024/2025 transactional sales = NO_CERTIFIED_SOURCE; lifecycle patient-history evidence must not be interpreted as historical revenue'
  );
end;
$$;
revoke all on function public.aos_rev_customer_lifecycle_by_patient_v1(text,date) from public,anon,authenticated;
grant execute on function public.aos_rev_customer_lifecycle_by_patient_v1(text,date) to service_role;

create or replace function public.aos_rev_customer_lifecycle_v1(p_lookup_type text,p_lookup_value text,p_as_of date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_resolution jsonb; v_result jsonb; v_as_of date := coalesce(p_as_of,public.aos_rev_business_date_lima_v1());
begin
  v_resolution:=public.aos_rev_resolve_patient_identity_v2(p_lookup_type,p_lookup_value);
  if coalesce(v_resolution->>'status','')<>'MATCH' then
    return jsonb_build_object('contract','REV-F6.2_CUSTOMER_LIFECYCLE_V1','as_of',v_as_of,'canonical_patient_id',null,'lifecycle_state','UNRESOLVED_IDENTITY','classification_status','IDENTITY_NOT_RESOLVED','claim_strength','UNRESOLVED','identity_resolution_status',v_resolution->>'status','candidate_count',coalesce((v_resolution->>'candidate_count')::integer,0),'historical_warning','No patient-level repeat/lifetime claim is allowed without one safe canonical identity');
  end if;
  v_result:=public.aos_rev_customer_lifecycle_by_patient_v1(v_resolution->>'canonical_patient_id',v_as_of);
  return v_result||jsonb_build_object('identity_resolution_status','MATCH');
end;
$$;
revoke all on function public.aos_rev_customer_lifecycle_v1(text,text,date) from public,anon,authenticated;
grant execute on function public.aos_rev_customer_lifecycle_v1(text,text,date) to service_role;

create or replace function public.aos_rev_customer_lifecycle_summary_v1(p_as_of date default null)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
with params as (select coalesce(p_as_of,public.aos_rev_business_date_lima_v1()) as as_of),
patients as (select p."ID_PACIENTE"::text patient_id from public.aos_pacientes p where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'),
ev as (select e.* from public.aos_rev_customer_lifecycle_events_v1 e,params x where e.event_date<=x.as_of),
dates as (
  select canonical_patient_id,array_agg(distinct event_date order by event_date desc) event_dates,count(*)::integer event_rows,
         count(*) filter(where event_type='HISTORICAL_APPOINTMENT')::integer hist_events,count(*) filter(where event_type='CANONICAL_SALE')::integer sale_events
  from ev group by canonical_patient_id
),
future as (
  select a.canonical_patient_id,min(a.fecha_cita) next_confirmed from public.aos_rev_customer_agenda_identity_v1 a,params x
  where a.identity_status='RESOLVED' and a.estado_cita='CITA CONFIRMADA' and a.fecha_cita>x.as_of group by a.canonical_patient_id
),
features as (
  select p.patient_id,d.event_dates,d.event_rows,d.hist_events,d.sale_events,f.next_confirmed,x.as_of,
         case when d.event_dates is null then 0 else cardinality(d.event_dates) end active_days,
         case when d.event_dates is null then null else d.event_dates[1] end last_event,
         case when d.event_dates is null or cardinality(d.event_dates)<2 then null else d.event_dates[2] end previous_event
  from patients p cross join params x left join dates d on d.canonical_patient_id=p.patient_id left join future f on f.canonical_patient_id=p.patient_id
),
classified as (
  select *,case
    when active_days=0 then null
    when previous_event is not null and (last_event-previous_event)>=180 and (as_of-last_event) between 0 and 30 then 'HISTORICAL_REACTIVATED'
    when active_days=1 and (as_of-last_event) between 0 and 90 then 'NEW_PATIENT'
    when active_days>=2 and (as_of-last_event) between 0 and 90 then 'ACTIVE_REPEAT'
    when (as_of-last_event)>180 and next_confirmed is null then 'DORMANT'
    else 'RETURNING_PATIENT' end::text lifecycle_state
  from features
),
state_counts as (select lifecycle_state,count(*)::integer c from classified where lifecycle_state is not null group by lifecycle_state)
select jsonb_build_object('contract','REV-F6.2_CUSTOMER_LIFECYCLE_V1','as_of',(select as_of from params),'canonical_population',(select count(*) from patients),'classified_population',(select count(*) from classified where lifecycle_state is not null),'insufficient_activity_evidence',(select count(*) from classified where lifecycle_state is null),'states',coalesce((select jsonb_object_agg(lifecycle_state,c order by lifecycle_state) from state_counts),'{}'::jsonb),'thresholds',jsonb_build_object('active_days',90,'dormant_gap_days',180,'reactivation_gap_days',180,'reactivation_window_days',30),'qualifying_event_rows',(select count(*) from ev),'historical_warning','2024/2025 transactional sales = NO_CERTIFIED_SOURCE; state counts are observed lifecycle, not complete historical revenue cohorts');
$$;
revoke all on function public.aos_rev_customer_lifecycle_summary_v1(date) from public,anon,authenticated;
grant execute on function public.aos_rev_customer_lifecycle_summary_v1(date) to service_role;

create or replace function public.aos_patient_commercial_360_v2(p_token text,p_lookup_type text,p_lookup_value text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_base jsonb; v_lifecycle jsonb; v_pid text; v_as_of date := public.aos_rev_business_date_lima_v1();
begin
  v_base:=public.aos_patient_commercial_360_v2_f6_1_base(p_token,p_lookup_type,p_lookup_value);
  if coalesce((v_base->>'found')::boolean,false) then
    v_pid:=v_base#>>'{paciente,canonical_patient_id}';
    v_lifecycle:=public.aos_rev_customer_lifecycle_by_patient_v1(v_pid,v_as_of);
    v_base:=jsonb_set(v_base,'{commercial_summary,lifecycle_state}',coalesce(v_lifecycle->'lifecycle_state','null'::jsonb),true);
    v_base:=jsonb_set(v_base,'{commercial_summary,reactivation_count_status}',to_jsonb(coalesce(v_lifecycle->>'classification_status','UNKNOWN')),true);
    v_base:=jsonb_set(v_base,'{intelligence,lifecycle}',v_lifecycle,true);
  else
    v_lifecycle:=public.aos_rev_customer_lifecycle_v1(p_lookup_type,p_lookup_value,v_as_of);
  end if;
  v_base:=jsonb_set(v_base,'{contract}',to_jsonb('REV-F6.2_PATIENT_COMMERCIAL_360_V2'::text),true);
  return v_base||jsonb_build_object('lifecycle',v_lifecycle);
end;
$$;
revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public;
grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon,authenticated,service_role;

select pg_notify('pgrst','reload schema');
commit;
