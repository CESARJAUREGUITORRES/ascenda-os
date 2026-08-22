-- Deterministic repair for first real Loop 6 V2 canary: Ruben Carlos Dominguez Munoz / 997883711.
-- Preconditions are intentionally strict. Run only once in production.

do $repair$
declare
  v_call_id bigint;
  v_key text:='repair-ruben-997883711-20260821-193506';
  v_actor uuid:='ddfefe34-a598-4262-8d99-3f55a43a1afb';
  v_agenda text:='2c581c52-89e9-465f-89be-0e3818eda309';
  v_follow text:='SEG-1787354621097-4zle';
  v_event timestamptz:='2026-08-22T00:35:06.586+00:00';
  v_result jsonb;
begin
  if exists(select 1 from public.aos_callcenter_actions_v1 where idempotency_key=v_key) then
    raise exception 'RUBEN_REPAIR_ALREADY_APPLIED';
  end if;
  if (select count(*) from public.aos_leads where id=5884 and numero_limpio='997883711' and tratamiento='CAPILAR')<>1 then
    raise exception 'RUBEN_LEAD_PRECONDITION_FAILED';
  end if;
  if (select count(*) from public.aos_llamadas where numero_limpio='997883711' and fecha='2026-08-21' and upper(coalesce(estado,''))='CITA CONFIRMADA')<>0 then
    raise exception 'RUBEN_ALREADY_HAS_COMMERCIAL_CITA_CALL';
  end if;
  if not exists(select 1 from public.aos_agenda_citas where id=v_agenda and numero_limpio='997883711' and upper(coalesce(asesor,''))='MIREYA' and lead_id_origen is null and llamada_id_origen is null) then
    raise exception 'RUBEN_AGENDA_PRECONDITION_FAILED';
  end if;
  if not exists(select 1 from public.aos_seguimientos where "ID"=v_follow and upper(coalesce("ASESOR",''))='MIREYA' and upper(coalesce("ESTADO",''))='PENDIENTE') then
    raise exception 'RUBEN_FOLLOWUP_PRECONDITION_FAILED';
  end if;

  perform pg_catalog.set_config('aos.loop6_governed_write','1',true);

  insert into public.aos_llamadas(
    fecha,numero,numero_limpio,tratamiento,estado,sub_estado,observacion,hora_llamada,
    asesor,id_asesor,anuncio,origen,intento,created_at,duracion_seg,tipo_gestion,desde_dispositivo,lead_id_origen
  ) values(
    '2026-08-21','997883711','997883711','CAPILAR','CITA CONFIRMADA','FOLLOWUP_CONVERSION',
    'RUBEN | Reparacion Loop6 V2: lead 5884 + seguimiento Mireya + cita real 25/08 18:00',
    '19:35:06','MIREYA','ZIV-003','CAPILAR- INJERTO REEL4','MARKETING',2,v_event,0,'FOLLOWUP_CONVERSION','web',5884
  ) returning id into v_call_id;

  update public.aos_agenda_citas
  set lead_id_origen=5884,
      llamada_id_origen=v_call_id,
      origen_cita='CALL_CENTER',
      ts_actualizado=pg_catalog.now()
  where id=v_agenda;

  update public.aos_seguimientos
  set "ESTADO"='COMPLETADO',
      "TS_ACTUALIZADO"='2026-08-22T00:35:06.586Z',
      lead_id_origen=5884
  where "ID"=v_follow;

  v_result:=pg_catalog.jsonb_build_object(
    'ok',true,'idempotent',false,'requestedAction','CALLBACK_INBOUND_APPOINTMENT',
    'effectiveAction','CALLBACK_INBOUND_APPOINTMENT','patientState','HISTORICAL_PROSPECT',
    'identityStatus','MATCH','canonicalPatientId','5a0bc038-7dd4-4fab-9aac-b9d5d2a23e05','converted',false,
    'callId',v_call_id,'agendaId',v_agenda,'leadId',5884,'origin','MARKETING',
    'callState','CITA CONFIRMADA','tipoGestion','FOLLOWUP_CONVERSION','businessDate','2026-08-21',
    'executedBy','MIREYA','executedById','ZIV-003','creditedAdvisor','MIREYA','creditedAdvisorId','ZIV-003',
    'commercialOwner','MIREYA','commercialOwnerId','ZIV-003','beneficiaryScope','ADVISOR',
    'eligibilityStatus','ALLOW','eligibilityReason','LEGACY_FOLLOWUP_CONVERSION_REPAIR',
    'ownershipTransfer',false,'priorAgendaId',null,'priorAdvisor',''
  );

  insert into public.aos_callcenter_actions_v1(
    idempotency_key,request_hash,actor_user_id,asesor,id_asesor,numero_limpio,action_type,source_mode,
    patient_state,identity_status,canonical_patient_id,lead_id_origen,origen,llamada_id,agenda_id,status,result,
    created_at,updated_at,credited_advisor,credited_advisor_id,commercial_owner,commercial_owner_id,beneficiary_scope,
    eligibility_status,eligibility_reason,prior_agenda_id,prior_advisor,prior_advisor_id,ownership_transfer,rule_context
  ) values(
    v_key,pg_catalog.md5('RUBEN|5884|FOLLOWUP_CONVERSION|2026-08-21T19:35:06'),v_actor,'MIREYA','ZIV-003','997883711',
    'CALLBACK_INBOUND_APPOINTMENT','FOLLOWUP','HISTORICAL_PROSPECT','MATCH','5a0bc038-7dd4-4fab-9aac-b9d5d2a23e05',
    5884,'MARKETING',v_call_id,v_agenda,'COMPLETE',v_result,v_event,pg_catalog.now(),
    'MIREYA','ZIV-003','MIREYA','ZIV-003','ADVISOR','ALLOW','LEGACY_FOLLOWUP_CONVERSION_REPAIR',null,null,null,false,
    pg_catalog.jsonb_build_object('repair',true,'reason','FIRST_REAL_CANARY_LEGACY_BYPASS','leadId',5884,'followupId',v_follow)
  );
end
$repair$;
