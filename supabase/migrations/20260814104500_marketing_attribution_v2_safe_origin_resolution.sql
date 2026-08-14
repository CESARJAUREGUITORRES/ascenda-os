-- P0 hotfix: Marketing Attribution V2 must never infer a touchpoint from phone alone.
-- Preserve V1 phone/tier selection exactly, but only attach lead_id when evidence is unique.
-- Ambiguous cases remain operational with lead_id NULL and no ad attribution.

create or replace function public.aos_siguiente_lead_v2(p_asesor text,p_id_asesor text,p_hoy date)
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
  v_count integer := 0;
  v_nonnull integer := 0;
  v_distinct integer := 0;
begin
  v_res := public.aos_siguiente_lead(p_asesor,p_id_asesor,p_hoy)::jsonb;
  if not coalesce((v_res->>'ok')::boolean,false) or v_res->'lead' is null then return v_res::json; end if;

  v_num := nullif(v_res->'lead'->>'num','');
  v_tier := coalesce(v_res->>'tier','');
  v_cola_tipo := coalesce(v_res->>'colaConfig','global');
  v_intento := coalesce(nullif(v_res->'lead'->>'intento','')::integer,1);
  select coalesce(filtro_valor,'') into v_cola_filtro from public.aos_cola_config where upper(asesor)=upper(p_asesor) limit 1;
  v_cola_filtro := coalesce(v_cola_filtro,'');

  if v_num is not null and v_cola_tipo='campana' and v_cola_filtro<>'' then
    select count(*), min(ld.id) into v_count,v_lead_id
    from public.aos_leads ld
    where ld.numero_limpio=v_num and upper(ld.tratamiento)=upper(v_cola_filtro);
    if v_count=1 then v_source:='DIRECT_CAMPAIGN_UNIQUE'; else v_lead_id:=null; end if;
  elsif v_num is not null and v_tier like 'TIER 1%' then
    select count(*), min(ld.id) into v_count,v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num and ld.fecha=p_hoy;
    if v_count=1 then v_source:='DIRECT_TIER_1_UNIQUE'; else v_lead_id:=null; end if;
  elsif v_num is not null and v_tier like 'TIER 2%' then
    select count(*), min(ld.id) into v_count,v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num and ld.fecha >= (p_hoy-extract(dow from p_hoy)::int)::date and ld.fecha<p_hoy;
    if v_count=1 then v_source:='DIRECT_TIER_2_UNIQUE'; else v_lead_id:=null; end if;
  elsif v_num is not null and v_tier like 'TIER 3%' then
    select count(*), min(ld.id) into v_count,v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num and date_trunc('month',ld.fecha)=date_trunc('month',p_hoy)
      and ld.fecha < (p_hoy-extract(dow from p_hoy)::int)::date;
    if v_count=1 then v_source:='DIRECT_TIER_3_UNIQUE'; else v_lead_id:=null; end if;
  elsif v_num is not null and v_tier like 'TIER 4%' then
    select count(*), min(ld.id) into v_count,v_lead_id from public.aos_leads ld
    where ld.numero_limpio=v_num and date_trunc('month',ld.fecha)<date_trunc('month',p_hoy);
    if v_count=1 then v_source:='DIRECT_TIER_4_UNIQUE'; else v_lead_id:=null; end if;
  end if;

  if v_lead_id is null and v_num is not null and v_cola_tipo='tipificacion' and v_cola_filtro<>'' then
    select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen)
      into v_count,v_nonnull,v_distinct,v_lead_id
    from public.aos_llamadas where numero_limpio=v_num and upper(estado)=upper(v_cola_filtro);
    if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='TIPIFICACION_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
  elsif v_lead_id is null and v_num is not null and (v_cola_tipo='no_asistio' or v_tier like 'TIER 5%') then
    select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen)
      into v_count,v_nonnull,v_distinct,v_lead_id
    from public.aos_agenda_citas
    where numero_limpio=v_num and estado_cita='NO ASISTIO'
      and (v_cola_tipo='no_asistio' or fecha_cita between (p_hoy-14)::date and p_hoy);
    if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='NO_SHOW_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
  elsif v_lead_id is null and v_num is not null and v_tier like 'TIER 6%' then
    select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen)
      into v_count,v_nonnull,v_distinct,v_lead_id
    from public.aos_seguimientos
    where regexp_replace(coalesce("NUMERO",''),'\D','','g')=v_num
      and "ESTADO"='PENDIENTE' and "FECHA_PROGRAMADA"::date<=p_hoy
      and (p_asesor='' or upper(coalesce("ASESOR",''))=upper(p_asesor) or (p_id_asesor<>'' and coalesce("ID_ASESOR",'')=p_id_asesor));
    if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='FOLLOWUP_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
  elsif v_lead_id is null and v_num is not null and v_cola_tipo='provincia' then
    select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen)
      into v_count,v_nonnull,v_distinct,v_lead_id
    from public.aos_llamadas where numero_limpio=v_num and estado in ('PROVINCIA','PROVINCIAS');
    if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='PROVINCE_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
  end if;

  if v_lead_id is not null then
    select jsonb_build_object('id',ld.id,'num',ld.numero_limpio,'trat',coalesce(ld.tratamiento,''),'anuncio',coalesce(ld.anuncio,''),'fecha',ld.fecha,'hora_ingreso',ld.hora_ingreso,'intento',v_intento,'rowNum',0,'attributionSource',v_source)
      into v_lead from public.aos_leads ld where ld.id=v_lead_id;
    if v_lead is not null then
      v_res:=jsonb_set(v_res,'{lead}',v_lead,true);
      update public.aos_leads_en_curso set lead_id_origen=v_lead_id
      where upper(asesor)=upper(p_asesor) and numero_limpio=v_num and fecha=p_hoy;
    end if;
  else
    v_res:=jsonb_set(v_res,'{lead}',coalesce(v_res->'lead','{}'::jsonb)||jsonb_build_object('id',null,'anuncio','','hora_ingreso',null,'attributionSource','UNRESOLVED'),true);
    update public.aos_leads_en_curso set lead_id_origen=null
      where upper(asesor)=upper(p_asesor) and numero_limpio=v_num and fecha=p_hoy;
  end if;
  return v_res::json;
end;
$function$;
