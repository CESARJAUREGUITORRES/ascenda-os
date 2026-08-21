-- CC-Q1 / Call Center Contact-Debt Priority V1
-- Goal: every NEW lead touchpoint must be worked before legacy call-center tiers.
-- Order: TODAY -> CURRENT MONTH -> CURRENT YEAR -> HISTORICAL -> existing TIER engine.
-- Important: a phone having an OLD call does not satisfy a NEW lead touchpoint.
-- Raw leads/calls are never rewritten. Existing aos_siguiente_lead_v2 remains the fallback engine.

create or replace function public.aos_siguiente_lead(
  p_asesor text,
  p_id_asesor text,
  p_hoy date
)
returns json
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_lead_id bigint := null;
  v_num text := null;
  v_trat text := '';
  v_anuncio text := '';
  v_fecha date := null;
  v_hora_ingreso timestamptz := null;
  v_lead_ts timestamptz := null;
  v_bucket integer := null;
  v_bucket_code text := null;
  v_tier text := null;
  v_cola_tipo text := 'global';
  v_contexto json := null;
  v_intento integer := 1;
  v_wait_minutes integer := 0;
  v_lead json := null;
begin
  -- Preserve historical cleanup behavior.
  delete from public.aos_leads_en_curso where fecha < p_hoy;

  select coalesce(tipo_cola,'global')
    into v_cola_tipo
  from public.aos_cola_config
  where upper(asesor)=upper(p_asesor)
  limit 1;
  v_cola_tipo := coalesce(v_cola_tipo,'global');

  -- CONTACT DEBT:
  -- A lead touchpoint is pending when there is no call tied to that lead_id
  -- and no same-phone call recorded at/after that lead arrived.
  -- Multiple pending touchpoints for one phone collapse to the latest touchpoint.
  -- Active assignments from another advisor are leased for 20 minutes; abandoned
  -- assignments can then re-enter the pool instead of being frozen all day.
  with debt as (
    select
      ld.id,
      ld.numero_limpio,
      ld.fecha,
      coalesce(ld.tratamiento,'') as tratamiento,
      coalesce(ld.anuncio,'') as anuncio,
      ld.hora_ingreso,
      coalesce(
        ld.hora_ingreso,
        ld.created_at,
        (ld.fecha::timestamp at time zone 'America/Lima')
      ) as lead_ts,
      case
        when ld.fecha=p_hoy then 0
        when date_trunc('month',ld.fecha)=date_trunc('month',p_hoy) then 1
        when date_trunc('year',ld.fecha)=date_trunc('year',p_hoy) then 2
        else 3
      end as bucket,
      row_number() over (
        partition by ld.numero_limpio
        order by coalesce(
          ld.hora_ingreso,
          ld.created_at,
          (ld.fecha::timestamp at time zone 'America/Lima')
        ) desc, ld.id desc
      ) as rn
    from public.aos_leads ld
    where ld.numero_limpio is not null
      and ld.numero_limpio<>''
      and not exists (
        select 1
        from public.aos_llamadas ll
        where ll.numero_limpio=ld.numero_limpio
          and (
            ll.lead_id_origen=ld.id
            or coalesce(
              ll.created_at,
              ll.ult_ts,
              ll.ts_log,
              (ll.fecha::timestamp at time zone 'America/Lima')
            ) >= coalesce(
              ld.hora_ingreso,
              ld.created_at,
              (ld.fecha::timestamp at time zone 'America/Lima')
            )
          )
      )
      and not exists (
        select 1
        from public.v_numeros_con_cita_pendiente cp
        where cp.numero_limpio=ld.numero_limpio
      )
      and not exists (
        select 1
        from public.aos_leads_en_curso lc
        where lc.numero_limpio=ld.numero_limpio
          and lc.fecha=p_hoy
          and upper(lc.asesor)<>upper(p_asesor)
          and coalesce(lc.asignado_at,now()) >= now()-interval '20 minutes'
      )
  ), ranked as (
    select *
    from debt
    where rn=1
    order by bucket,lead_ts,id
    limit 32
  )
  select
    ld.id,
    ld.numero_limpio,
    r.tratamiento,
    r.anuncio,
    r.fecha,
    r.hora_ingreso,
    r.lead_ts,
    r.bucket
  into
    v_lead_id,
    v_num,
    v_trat,
    v_anuncio,
    v_fecha,
    v_hora_ingreso,
    v_lead_ts,
    v_bucket
  from ranked r
  join public.aos_leads ld on ld.id=r.id
  order by r.bucket,r.lead_ts,r.id
  for update of ld skip locked
  limit 1;

  if v_num is not null then
    v_bucket_code := case v_bucket
      when 0 then 'TODAY'
      when 1 then 'MONTH'
      when 2 then 'YEAR'
      else 'HISTORICAL'
    end;

    v_tier := case v_bucket
      when 0 then 'PRIORIDAD 0 · NUEVO SIN CONTACTO HOY'
      when 1 then 'PRIORIDAD 0 · PENDIENTE DEL MES'
      when 2 then 'PRIORIDAD 0 · PENDIENTE DEL AÑO'
      else 'PRIORIDAD 0 · PENDIENTE HISTÓRICO'
    end;

    select coalesce(count(*),0)+1
      into v_intento
    from public.aos_llamadas
    where numero_limpio=v_num;

    v_wait_minutes := greatest(
      0,
      floor(extract(epoch from (now()-v_lead_ts))/60)::integer
    );

    v_lead := json_build_object(
      'id',v_lead_id,
      'num',v_num,
      'trat',v_trat,
      'anuncio',v_anuncio,
      'fecha',v_fecha,
      'hora_ingreso',v_hora_ingreso,
      'intento',v_intento,
      'rowNum',0,
      'attributionSource','CONTACT_DEBT_EXACT',
      'contactDebtBucket',v_bucket_code,
      'waitMinutes',v_wait_minutes
    );

    insert into public.aos_leads_en_curso(
      asesor,numero_limpio,fecha,lead_id_origen,asignado_at
    )
    values(
      upper(p_asesor),v_num,p_hoy,v_lead_id,now()
    )
    on conflict(asesor,numero_limpio,fecha)
    do update set
      lead_id_origen=excluded.lead_id_origen,
      asignado_at=excluded.asignado_at;

    select json_build_object(
      'ultimaLlamada',json_build_object(
        'fecha',ll.fecha,
        'estado',ll.estado,
        'asesor',ll.asesor,
        'obs',coalesce(ll.observacion,''),
        'intento',ll.intento
      )
    )
    into v_contexto
    from public.aos_llamadas ll
    where ll.numero_limpio=v_num
    order by coalesce(ll.created_at,ll.ult_ts,ll.ts_log) desc nulls last,ll.id desc
    limit 1;

    return json_build_object(
      'ok',true,
      'lead',v_lead,
      'tier',v_tier,
      'tierNum',0,
      'fromSupabase',true,
      'colaConfig',v_cola_tipo,
      'contexto',v_contexto,
      'contactDebt',true,
      'contactDebtBucket',v_bucket_code,
      'waitMinutes',v_wait_minutes,
      'leaseMinutes',20
    );
  end if;

  -- No new/uncontacted touchpoints remain: preserve the certified existing
  -- campaign/tipification/no-show/patient/province + TIER 1-8 engine exactly.
  return public.aos_siguiente_lead_v2(p_asesor,p_id_asesor,p_hoy);
end;
$function$;

-- Keep the same browser execution surface used by the current Call Center.
grant execute on function public.aos_siguiente_lead(text,text,date) to anon,authenticated,service_role;
