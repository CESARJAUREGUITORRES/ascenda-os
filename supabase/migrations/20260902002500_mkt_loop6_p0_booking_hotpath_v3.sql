-- ASCENDA OS · P0 LOOP6 BOOKING HOTPATH V3
-- Incident: governed Call Center booking commits hit anon statement_timeout=3s.
-- Root cause: the synchronous credit context materialized global REV-F6 identity/lifecycle views.
-- Boundary: preserve identity/patient-state/active appointment/NO SHOW/ownership/lead policy;
--           do NOT raise statement_timeout and do NOT modify REV-F6 analytical functions.

-- ---------------------------------------------------------------------------
-- A. Exact normalized-phone indexes used by the operational resolver.
-- These mirror REV-F6 PHONE normalization semantics but permit predicate pushdown.
-- ---------------------------------------------------------------------------
create index if not exists idx_aos_pacientes_phone_resolve_loop6_v3
  on public.aos_pacientes (
    public.aos_rev_normalize_patient_identifier_v2(
      'PHONE',coalesce(nullif(numero_limpio,''),"Teléfono")
    )
  )
  where coalesce("ESTADO_PACIENTE",'')<>'FUSIONADO';

create index if not exists idx_aos_f5_source_rows_phone_resolve_loop6_v3
  on public.aos_f5_patient_source_rows_v1 (
    public.aos_rev_normalize_patient_identifier_v2('PHONE',phone_key)
  )
  where phone_key is not null;

-- ---------------------------------------------------------------------------
-- B. Operational identity resolver.
-- Semantics intentionally mirror the PHONE branch of aos_rev_patient_identity_alias_v2:
-- canonical CURRENT evidence + reviewed F5 MATCH evidence, candidate conflict preserved.
-- The difference is execution shape: filter the requested phone before aggregation.
-- ---------------------------------------------------------------------------
create or replace function public.aos_callcenter_resolve_identity_fast_v3(p_numero text)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_key text;
  v_row record;
begin
  v_key:=public.aos_rev_normalize_patient_identifier_v2('PHONE',p_numero);
  if v_key is null then
    return pg_catalog.jsonb_build_object(
      'status','INVALID_IDENTIFIER','lookup_type','PHONE',
      'canonical_patient_id',null,'candidate_count',0
    );
  end if;

  with raw_alias as (
    select p."ID_PACIENTE"::text as canonical_patient_id,
           'CANONICAL_CURRENT'::text as source_scope
    from public.aos_pacientes p
    where coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
      and public.aos_rev_normalize_patient_identifier_v2(
            'PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")
          )=v_key

    union all

    select c.target_patient_id::text,
           'F5_REVIEWED_MATCH'::text
    from public.aos_f5_patient_source_rows_v1 s
    join public.aos_f5_identity_cluster_members_v1 m
      on m.source_row_id=s.id
    join public.aos_f5_canonical_classification_v1 c
      on c.cluster_id=m.cluster_id
    where c.classification='MATCH'
      and c.target_patient_id is not null
      and public.aos_rev_normalize_patient_identifier_v2('PHONE',s.phone_key)=v_key
  ), per_candidate as (
    select r.canonical_patient_id,
           count(*)::integer as evidence_rows,
           pg_catalog.bool_or(r.source_scope='F5_REVIEWED_MATCH') as has_reviewed_match,
           pg_catalog.jsonb_agg(distinct r.source_scope order by r.source_scope) as evidence_scopes
    from raw_alias r
    where r.canonical_patient_id is not null
    group by r.canonical_patient_id
  )
  select pc.*,
         count(*) over()::integer as candidate_count
    into v_row
  from per_candidate pc
  order by pc.canonical_patient_id
  limit 1;

  if not found then
    return pg_catalog.jsonb_build_object(
      'status','UNRESOLVED','lookup_type','PHONE',
      'canonical_patient_id',null,'candidate_count',0
    );
  end if;

  if v_row.candidate_count>1 then
    return pg_catalog.jsonb_build_object(
      'status','IDENTITY_CONFLICT','lookup_type','PHONE',
      'canonical_patient_id',null,'candidate_count',v_row.candidate_count
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'status','MATCH',
    'lookup_type','PHONE',
    'canonical_patient_id',v_row.canonical_patient_id,
    'candidate_count',1,
    'confidence_band',case when v_row.has_reviewed_match then 'HIGH' else 'MEDIUM' end,
    'evidence_scopes',coalesce(v_row.evidence_scopes,'[]'::jsonb)
  );
end
$function$;

revoke all on function public.aos_callcenter_resolve_identity_fast_v3(text)
  from public,anon,authenticated;
grant execute on function public.aos_callcenter_resolve_identity_fast_v3(text)
  to service_role;

comment on function public.aos_callcenter_resolve_identity_fast_v3(text) is
  'LOOP6 P0 operational PHONE identity resolver. Mirrors REV-F6 candidate/conflict semantics with indexed phone predicate pushdown; service-only.';

-- ---------------------------------------------------------------------------
-- C. Operational patient state.
-- Lifecycle is analytical evidence only and is deliberately deferred here.
-- All fields used by Loop6 eligibility/ownership remain synchronous.
-- ---------------------------------------------------------------------------
create or replace function public.aos_callcenter_patient_state_fast_v3(
  p_numero text,
  p_event_ts timestamptz default pg_catalog.now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_num text:=pg_catalog.regexp_replace(coalesce(p_numero,''),'[^0-9]','','g');
  v_event_ts timestamptz:=coalesce(p_event_ts,pg_catalog.now());
  v_day date:=(v_event_ts at time zone 'America/Lima')::date;
  v_identity jsonb;
  v_identity_status text;
  v_canonical text;
  v_sale boolean:=false;
  v_attention boolean:=false;
  v_attended boolean:=false;
  v_historical boolean:=false;
  v_last_sale jsonb;
  v_last_attention jsonb;
  v_last_attended jsonb;
  v_state text;
begin
  if pg_catalog.length(v_num)<7 then
    return pg_catalog.jsonb_build_object(
      'ok',false,'error','INVALID_PHONE','patientState','REVIEW'
    );
  end if;

  v_identity:=public.aos_callcenter_resolve_identity_fast_v3(v_num);
  v_identity_status:=coalesce(v_identity->>'status','UNRESOLVED');
  v_canonical:=v_identity->>'canonical_patient_id';

  if v_identity_status='IDENTITY_CONFLICT' then
    return pg_catalog.jsonb_build_object(
      'ok',false,'error','IDENTITY_CONFLICT','identity',v_identity,
      'identityStatus',v_identity_status,'patientState','REVIEW','converted',false
    );
  end if;

  select pg_catalog.jsonb_build_object(
           'fecha',v.fecha,'monto',v.monto,'tratamiento',v.tratamiento,
           'asesor',v.asesor,'created_at',v.created_at
         )
    into v_last_sale
  from public.aos_ventas v
  where v.numero_limpio=v_num
    and (v.fecha<v_day or (v.fecha=v_day and v.created_at is not null and v.created_at<v_event_ts))
  order by v.fecha desc,v.created_at desc nulls last,v.id desc
  limit 1;
  v_sale:=v_last_sale is not null;

  select pg_catalog.jsonb_build_object(
           'fecha',a.fecha,'estado',a.estado,'tratamiento',a.tratamiento_principal,
           'created_at',a.created_at
         )
    into v_last_attention
  from public.aos_atenciones a
  where a.numero_limpio=v_num
    and (a.fecha<v_day or (a.fecha=v_day and a.created_at is not null and a.created_at<v_event_ts))
  order by a.fecha desc,a.created_at desc nulls last,a.id desc
  limit 1;
  v_attention:=v_last_attention is not null;

  select pg_catalog.jsonb_build_object(
           'fecha',a.fecha_cita,'estado',a.estado_cita,'tratamiento',a.tratamiento,
           'asesor',a.asesor,'ts_actualizado',a.ts_actualizado,'ts_creado',a.ts_creado
         )
    into v_last_attended
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA')
    and (a.fecha_cita<v_day or (
      a.fecha_cita=v_day
      and coalesce(a.ts_actualizado,a.ts_creado) is not null
      and coalesce(a.ts_actualizado,a.ts_creado)<v_event_ts
    ))
  order by a.fecha_cita desc,coalesce(a.ts_actualizado,a.ts_creado) desc nulls last,a.id desc
  limit 1;
  v_attended:=v_last_attended is not null;

  select
    exists(
      select 1 from public.aos_leads l
      where l.numero_limpio=v_num
        and coalesce(l.hora_ingreso,l.created_at,(l.fecha::timestamp at time zone 'America/Lima'))<v_event_ts
    )
    or exists(
      select 1 from public.aos_llamadas l
      where l.numero_limpio=v_num
        and coalesce(l.created_at,l.ult_ts,l.ts_log,(l.fecha::timestamp at time zone 'America/Lima'))<v_event_ts
    )
    or exists(
      select 1 from public.aos_agenda_citas a
      where a.numero_limpio=v_num
        and coalesce(a.ts_creado,(a.fecha_cita::timestamp at time zone 'America/Lima'))<v_event_ts
    )
  into v_historical;

  if v_sale or v_attention or v_attended then
    v_state:='CONVERTED_PATIENT';
  elsif v_identity_status='MATCH' or v_historical then
    v_state:='HISTORICAL_PROSPECT';
  else
    v_state:='PROSPECT';
  end if;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'numero',v_num,
    'eventTs',v_event_ts,
    'businessDate',v_day,
    'identityStatus',v_identity_status,
    'canonicalPatientId',v_canonical,
    'patientState',v_state,
    'converted',(v_state='CONVERTED_PATIENT'),
    'identity',v_identity,
    'lifecycle',null,
    'lifecycleDeferred',true,
    'evidence',pg_catalog.jsonb_build_object(
      'priorSale',v_sale,
      'priorAttention',v_attention,
      'priorAttendedAppointment',v_attended,
      'lastSale',v_last_sale,
      'lastAttention',v_last_attention,
      'lastAttendedAppointment',v_last_attended
    )
  );
end
$function$;

revoke all on function public.aos_callcenter_patient_state_fast_v3(text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.aos_callcenter_patient_state_fast_v3(text,timestamptz)
  to service_role;

comment on function public.aos_callcenter_patient_state_fast_v3(text,timestamptz) is
  'LOOP6 P0 operational patient state. Preserves conversion/identity evidence but defers REV-F6 analytical lifecycle from synchronous booking.';

-- ---------------------------------------------------------------------------
-- D. Rebind the existing credit-policy contract to the operational patient state.
-- Everything after patient-state resolution is the previously certified V2 logic.
-- ---------------------------------------------------------------------------
create or replace function public.aos_callcenter_credit_context_v2(
  p_numero text,
  p_event_ts timestamptz default pg_catalog.now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_num text:=pg_catalog.regexp_replace(coalesce(p_numero,''),'[^0-9]','','g');
  v_event timestamptz:=coalesce(p_event_ts,pg_catalog.now());
  v_day date:=(v_event at time zone 'America/Lima')::date;
  v_state jsonb;
  v_last_qual_ts timestamptz;
  v_last_qual_type text;
  v_reactivation_from timestamptz;
  v_active record;
  v_no_show record;
  v_no_show_slot timestamptz;
  v_protected_until timestamptz;
  v_owner_followup boolean:=false;
begin
  v_state:=public.aos_callcenter_patient_state_fast_v3(v_num,v_event);
  if coalesce((v_state->>'ok')::boolean,false)=false then
    return v_state;
  end if;

  select q.ts,q.kind
    into v_last_qual_ts,v_last_qual_type
  from (
    select (v.fecha::timestamp at time zone 'America/Lima') ts,'SALE'::text kind
    from public.aos_ventas v
    where v.numero_limpio=v_num and v.fecha<=v_day

    union all

    select (a.fecha::timestamp at time zone 'America/Lima'),'ATTENTION'
    from public.aos_atenciones a
    where a.numero_limpio=v_num and a.fecha<=v_day

    union all

    select public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita),'ATTENDED_APPOINTMENT'
    from public.aos_agenda_citas a
    where a.numero_limpio=v_num
      and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA')
      and public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita)<=v_event
  ) q
  where q.ts<=v_event
  order by q.ts desc nulls last
  limit 1;

  if v_last_qual_ts is not null then
    v_reactivation_from:=v_last_qual_ts+interval '15 days';
  end if;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
    into v_active
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA')
    and a.fecha_cita>=v_day
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) asc,
           a.ts_creado asc nulls last
  limit 1;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
    into v_no_show
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('NO ASISTIO','NO ASISTIÓ')
    and public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita)<v_event
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) desc,
           a.ts_creado desc nulls last
  limit 1;

  if v_no_show.id is not null then
    v_no_show_slot:=v_no_show.slot;
    v_protected_until:=v_no_show_slot+interval '72 hours';

    select exists(
      select 1
      from public.aos_llamadas l
      where l.numero_limpio=v_num
        and upper(coalesce(l.asesor,''))=upper(coalesce(v_no_show.asesor,''))
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)>v_no_show_slot
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)<v_event
    )
    or exists(
      select 1
      from public.aos_seguimientos s
      where pg_catalog.regexp_replace(coalesce(s."NUMERO",''),'[^0-9]','','g')=v_num
        and upper(coalesce(s."ASESOR",''))=upper(coalesce(v_no_show.asesor,''))
        and (
          public.aos_callcenter_try_timestamptz_v1(s."TS_CREADO")>v_no_show_slot
          or (
            upper(coalesce(s."ESTADO",''))='COMPLETADO'
            and public.aos_callcenter_try_timestamptz_v1(s."TS_ACTUALIZADO")>v_no_show_slot
          )
        )
        and coalesce(
          public.aos_callcenter_try_timestamptz_v1(s."TS_CREADO"),
          public.aos_callcenter_try_timestamptz_v1(s."TS_ACTUALIZADO")
        )<v_event
    )
    into v_owner_followup;
  end if;

  return v_state||pg_catalog.jsonb_build_object(
    'creditPolicy',pg_catalog.jsonb_build_object(
      'lastQualifyingTs',v_last_qual_ts,
      'lastQualifyingType',v_last_qual_type,
      'reactivationEligibleFrom',v_reactivation_from,
      'reactivationEligible',case
        when coalesce((v_state->>'converted')::boolean,false)
             and v_reactivation_from is not null
        then v_event>=v_reactivation_from
        else false
      end,
      'activeAppointment',case when v_active.id is null then null else
        pg_catalog.jsonb_build_object(
          'id',v_active.id,'advisor',v_active.asesor,'advisorId',v_active.id_asesor,
          'date',v_active.fecha_cita,'time',v_active.hora_cita,'status',v_active.estado_cita,
          'slot',v_active.slot,'leadId',v_active.lead_id_origen
        ) end,
      'lastNoShow',case when v_no_show.id is null then null else
        pg_catalog.jsonb_build_object(
          'id',v_no_show.id,'advisor',v_no_show.asesor,'advisorId',v_no_show.id_asesor,
          'date',v_no_show.fecha_cita,'time',v_no_show.hora_cita,'slot',v_no_show_slot,
          'leadId',v_no_show.lead_id_origen,'protectedUntil',v_protected_until,
          'ownerFollowupAfterNoShow',v_owner_followup
        ) end
    )
  );
end
$function$;

comment on function public.aos_callcenter_credit_context_v2(text,timestamptz) is
  'LOOP6 credit/ownership V2 policy with P0 V3 operational patient-state hotpath. REV-F6 lifecycle remains analytical and deferred; business rules unchanged.';
