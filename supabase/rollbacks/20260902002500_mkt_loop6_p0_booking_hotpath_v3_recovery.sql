-- ASCENDA OS · P0 LOOP6 BOOKING HOTPATH V3 RECOVERY
-- Restore the previously certified credit-context dependency on patient_state_v1.

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
  v_state:=public.aos_callcenter_patient_state_v1(v_num,v_event);
  if coalesce((v_state->>'ok')::boolean,false)=false then return v_state; end if;

  select q.ts,q.kind into v_last_qual_ts,v_last_qual_type from (
    select (v.fecha::timestamp at time zone 'America/Lima') ts,'SALE'::text kind
      from public.aos_ventas v where v.numero_limpio=v_num and v.fecha<=v_day
    union all
    select (a.fecha::timestamp at time zone 'America/Lima'),'ATTENTION'
      from public.aos_atenciones a where a.numero_limpio=v_num and a.fecha<=v_day
    union all
    select public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita),'ATTENDED_APPOINTMENT'
      from public.aos_agenda_citas a
      where a.numero_limpio=v_num
        and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA')
        and public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita)<=v_event
  ) q where q.ts<=v_event order by q.ts desc nulls last limit 1;

  if v_last_qual_ts is not null then v_reactivation_from:=v_last_qual_ts+interval '15 days'; end if;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
    into v_active
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA')
    and a.fecha_cita>=v_day
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) asc,a.ts_creado asc nulls last
  limit 1;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
    into v_no_show
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('NO ASISTIO','NO ASISTIÓ')
    and public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita)<v_event
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) desc,a.ts_creado desc nulls last
  limit 1;

  if v_no_show.id is not null then
    v_no_show_slot:=v_no_show.slot;
    v_protected_until:=v_no_show_slot+interval '72 hours';
    select exists(
      select 1 from public.aos_llamadas l
      where l.numero_limpio=v_num
        and upper(coalesce(l.asesor,''))=upper(coalesce(v_no_show.asesor,''))
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)>v_no_show_slot
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)<v_event
    ) or exists(
      select 1 from public.aos_seguimientos s
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
    ) into v_owner_followup;
  end if;

  return v_state||pg_catalog.jsonb_build_object('creditPolicy',pg_catalog.jsonb_build_object(
    'lastQualifyingTs',v_last_qual_ts,
    'lastQualifyingType',v_last_qual_type,
    'reactivationEligibleFrom',v_reactivation_from,
    'reactivationEligible',case when coalesce((v_state->>'converted')::boolean,false) and v_reactivation_from is not null then v_event>=v_reactivation_from else false end,
    'activeAppointment',case when v_active.id is null then null else pg_catalog.jsonb_build_object(
      'id',v_active.id,'advisor',v_active.asesor,'advisorId',v_active.id_asesor,'date',v_active.fecha_cita,
      'time',v_active.hora_cita,'status',v_active.estado_cita,'slot',v_active.slot,'leadId',v_active.lead_id_origen
    ) end,
    'lastNoShow',case when v_no_show.id is null then null else pg_catalog.jsonb_build_object(
      'id',v_no_show.id,'advisor',v_no_show.asesor,'advisorId',v_no_show.id_asesor,'date',v_no_show.fecha_cita,
      'time',v_no_show.hora_cita,'slot',v_no_show_slot,'leadId',v_no_show.lead_id_origen,
      'protectedUntil',v_protected_until,'ownerFollowupAfterNoShow',v_owner_followup
    ) end
  ));
end
$function$;

drop function if exists public.aos_callcenter_patient_state_fast_v3(text,timestamptz);
drop function if exists public.aos_callcenter_resolve_identity_fast_v3(text);
drop index if exists public.idx_aos_f5_source_rows_phone_resolve_loop6_v3;
drop index if exists public.idx_aos_pacientes_phone_resolve_loop6_v3;
