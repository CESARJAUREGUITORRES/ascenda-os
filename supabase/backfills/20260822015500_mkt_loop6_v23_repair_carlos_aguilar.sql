-- Loop 6 V2.3 deterministic repair: CARLOS ALONSO AGUILAR UCEDA / 941764266
-- Preserve existing Call 38396 SIN CONTACTO. Add exactly one governed queue conversion.
-- Idempotency key is excluded from the future genuine-operation gate.

do $repair$
declare
  v_actor uuid;
  v_res jsonb;
  v_key text := 'repair-carlos-941764266-20260821-v23';
begin
  select u.id into v_actor
  from public.aos_usuarios u
  where u.activo=true and upper(u.nombre)='MIREYA' and u.codigo_asesor='ZIV-003'
  limit 1;
  if v_actor is null then raise exception 'CARLOS_REPAIR_MIREYA_NOT_FOUND'; end if;

  if not exists (
    select 1 from public.aos_leads l
    where l.id=5894 and l.numero_limpio='941764266' and upper(coalesce(l.tratamiento,'')) like '%CAPILAR%'
  ) then raise exception 'CARLOS_REPAIR_LEAD_PRECONDITION'; end if;

  if not exists (
    select 1 from public.aos_llamadas l
    where l.id=38396 and l.numero_limpio='941764266' and upper(l.asesor)='MIREYA' and l.estado='SIN CONTACTO'
  ) then raise exception 'CARLOS_REPAIR_PRIOR_CALL_PRECONDITION'; end if;

  if exists (
    select 1 from public.aos_llamadas l
    where l.numero_limpio='941764266' and l.estado='CITA CONFIRMADA' and l.id<>38396
      and not exists(select 1 from public.aos_callcenter_actions_v1 a where a.idempotency_key=v_key and a.llamada_id=l.id)
  ) then raise exception 'CARLOS_REPAIR_UNEXPECTED_COMMERCIAL_CALL'; end if;

  if exists (
    select 1 from public.aos_agenda_citas a
    where a.numero_limpio='941764266'
      and not exists(select 1 from public.aos_callcenter_actions_v1 j where j.idempotency_key=v_key and j.agenda_id=a.id)
  ) then raise exception 'CARLOS_REPAIR_UNEXPECTED_AGENDA'; end if;

  -- Idempotent second run returns the stored result.
  v_res := public.aos_callcenter_confirm_queue_core_v1(
    v_actor,
    v_key,
    pg_catalog.jsonb_build_object(
      'numero','941764266',
      'lead_id',5894,
      'tratamiento','CAPILAR',
      'anuncio','CAPILAR- INJERTO REEL4',
      'nombre','CARLOS ALONSO',
      'apellido','AGUILAR UCEDA',
      'dni','44925360',
      'correo','aguilarucedacarlosalonso@gmail.com',
      'tipo_atencion','CONSULTA',
      'sede','SAN ISIDRO',
      'fecha_cita','2026-08-22',
      'hora_cita','14:30',
      'tipo_cita','CONSULTA NUEVA',
      'doctora','',
      'obs','REPAIR LOOP 6 V2.3 — CITA CONFIRMADA NUEVO. Paciente 38 años; caída capilar asociada a antecedente de estrés. Viene de Surco. Asesor: MIREYA.',
      'desde_dispositivo','repair',
      'duracion_seg',0
    ),
    null
  );
  if coalesce((v_res->>'ok')::boolean,false)=false then
    raise exception 'CARLOS_REPAIR_COMMIT_FAILED: %',v_res::text;
  end if;
  if (v_res->>'leadId')::bigint<>5894 or v_res->>'origin'<>'MARKETING' or v_res->>'callState'<>'CITA CONFIRMADA' then
    raise exception 'CARLOS_REPAIR_RESULT_MISMATCH: %',v_res::text;
  end if;
end
$repair$;
