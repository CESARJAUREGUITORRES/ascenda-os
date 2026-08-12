-- Parallel wrapper around the current queue engine.
-- It does not change which phone is selected; it only resolves an exact
-- marketing touchpoint when evidence exists and explicitly returns NULL when it does not.

create or replace function public.aos_siguiente_lead_v2(
  p_asesor text,
  p_id_asesor text,
  p_hoy date
)
returns json
language plpgsql
security invoker
as $function$
declare
  v_res jsonb;
  v_num text;
  v_tier text;
  v_cola_tipo text;
  v_cola_filtro text := '';
  v_lead_id bigint := null;
  v_source text := 'UNRESOLVED';
  v_intento integer := 1;
  v_lead jsonb;
begin
  -- Preserve V1 phone-selection behavior and side effects exactly.
  v_res := public.aos_siguiente_lead(p_asesor,p_id_asesor,p_hoy)::jsonb;

  if not coalesce((v_res->>'ok')::boolean,false) or v_res->'lead' is null then
    return v_res::json;
  end if;

  v_num := nullif(v_res->'lead'->>'num','');
  v_tier := coalesce(v_res->>'tier','');
  v_cola_tipo := coalesce(v_res->>'colaConfig','global');
  v_intento := coalesce(nullif(v_res->'lead'->>'intento','')::integer,1);

  select coalesce(filtro_valor,'')
    into v_cola_filtro
  from public.aos_cola_config
  where upper(asesor)=upper(p_asesor)
  limit 1;
  v_cola_filtro := coalesce(v_cola_filtro,'');

  -- Direct lead queues: preserve the selected phone and make the touchpoint deterministic.
  if v_num is not null and v_cola_tipo='campana' and v_cola_filtro<>'' then
    select ld.id into v_lead_id
    from public.aos_leads ld
    where ld.numero_limpio=v_num and upper(ld.tratamiento)=upper(v_cola_filtro)
    order by ld.fecha desc,ld.hora_ingreso desc nulls last,ld.id desc limit 1;
    if v_lead_id is not null then v_source:='DIRECT_CAMPAIGN_QUEUE'; end if;

  elsif v_num is not null and v_tier like 'TIER 1%' then
    select ld.id into v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num and ld.fecha=p_hoy
    order by ld.hora_ingreso desc nulls last,ld.id desc limit 1;
    if v_lead_id is not null then v_source:='DIRECT_TIER_1'; end if;

  elsif v_num is not null and v_tier like 'TIER 2%' then
    select ld.id into v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num
      and ld.fecha >= (p_hoy-extract(dow from p_hoy)::int)::date
      and ld.fecha < p_hoy
    order by ld.fecha desc,ld.hora_ingreso desc nulls last,ld.id desc limit 1;
    if v_lead_id is not null then v_source:='DIRECT_TIER_2'; end if;

  elsif v_num is not null and v_tier like 'TIER 3%' then
    select ld.id into v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num
      and date_trunc('month',ld.fecha)=date_trunc('month',p_hoy)
      and ld.fecha < (p_hoy-extract(dow from p_hoy)::int)::date
    order by ld.fecha desc,ld.hora_ingreso desc nulls last,ld.id desc limit 1;
    if v_lead_id is not null then v_source:='DIRECT_TIER_3'; end if;

  elsif v_num is not null and v_tier like 'TIER 4%' then
    select ld.id into v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num
      and date_trunc('month',ld.fecha)<date_trunc('month',p_hoy)
    order by ld.fecha desc,ld.hora_ingreso desc nulls last,ld.id desc limit 1;
    if v_lead_id is not null then v_source:='DIRECT_TIER_4'; end if;
  end if;

  -- Follow-up/no-show/re-sweep: only propagate an origin already recorded.
  -- Never invent the latest lead as attribution.
  if v_lead_id is null and v_num is not null and v_tier<>'PACIENTE ACTIVO' then
    select ll.lead_id_origen into v_lead_id
    from public.aos_llamadas ll
    where ll.numero_limpio=v_num and ll.lead_id_origen is not null
    order by coalesce(ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc limit 1;
    if v_lead_id is not null then v_source:='PROPAGATED_FROM_CALL'; end if;
  end if;

  if v_lead_id is null and v_num is not null and v_tier<>'PACIENTE ACTIVO' then
    select a.lead_id_origen into v_lead_id
    from public.aos_agenda_citas a
    where a.numero_limpio=v_num and a.lead_id_origen is not null
    order by a.ts_creado desc nulls last limit 1;
    if v_lead_id is not null then v_source:='PROPAGATED_FROM_APPOINTMENT'; end if;
  end if;

  if v_lead_id is null and v_num is not null and v_tier like '%SEGUIMIENTO%' then
    select s.lead_id_origen into v_lead_id
    from public.aos_seguimientos s
    where regexp_replace(coalesce(s."NUMERO",''),'\D','','g')=v_num
      and s.lead_id_origen is not null
    order by s."TS_ACTUALIZADO" desc nulls last,s."TS_CREADO" desc nulls last limit 1;
    if v_lead_id is not null then v_source:='PROPAGATED_FROM_FOLLOWUP'; end if;
  end if;

  if v_lead_id is not null then
    select jsonb_build_object(
      'id',ld.id,
      'num',ld.numero_limpio,
      'trat',coalesce(ld.tratamiento,''),
      'anuncio',coalesce(ld.anuncio,''),
      'fecha',ld.fecha,
      'hora_ingreso',ld.hora_ingreso,
      'intento',v_intento,
      'rowNum',0,
      'attributionSource',v_source
    ) into v_lead
    from public.aos_leads ld where ld.id=v_lead_id;

    if v_lead is not null then
      v_res:=jsonb_set(v_res,'{lead}',v_lead,true);
      update public.aos_leads_en_curso
      set lead_id_origen=v_lead_id
      where upper(asesor)=upper(p_asesor)
        and numero_limpio=v_num and fecha=p_hoy;
    end if;
  else
    v_res:=jsonb_set(
      v_res,'{lead}',
      coalesce(v_res->'lead','{}'::jsonb)||jsonb_build_object(
        'id',null,
        'hora_ingreso',null,
        'attributionSource','UNRESOLVED'
      ),true
    );
  end if;

  return v_res::json;
end;
$function$;
