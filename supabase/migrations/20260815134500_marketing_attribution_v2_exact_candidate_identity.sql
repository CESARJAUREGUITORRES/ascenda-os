-- Marketing Attribution V2: preserve the exact aos_leads.id in the same SELECT
-- that chooses direct campaign / Tier 1-4 candidates. Secondary queues only
-- propagate an origin when the recorded evidence is unanimous; otherwise NULL.
create or replace function public.aos_siguiente_lead_v2(p_asesor text,p_id_asesor text,p_hoy date)
returns json language plpgsql security invoker as $function$
declare
  v_lead json:=null; v_num text:=null; v_lead_id bigint:=null;
  v_tier text:=''; v_tier_num int:=0; v_cola_tipo text:='global'; v_cola_filtro text:='';
  v_hace14 date; v_contexto json:=null; v_intento int:=1; v_source text:='UNRESOLVED';
  v_count int:=0; v_nonnull int:=0; v_distinct int:=0;
begin
  v_hace14:=(p_hoy-14)::date;
  delete from public.aos_leads_en_curso where fecha<p_hoy;
  select tipo_cola,coalesce(filtro_valor,'') into v_cola_tipo,v_cola_filtro
  from public.aos_cola_config where upper(asesor)=upper(p_asesor);
  v_cola_tipo:=coalesce(v_cola_tipo,'global'); v_cola_filtro:=coalesce(v_cola_filtro,'');

  if v_cola_tipo='campana' and v_cola_filtro<>'' then
    select ld.id,ld.numero_limpio into v_lead_id,v_num
    from public.aos_leads ld
    left join (select numero_limpio,count(*) cnt from public.aos_llamadas group by numero_limpio) ul on ul.numero_limpio=ld.numero_limpio
    where upper(ld.tratamiento)=upper(v_cola_filtro)
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=ld.numero_limpio and ll.estado in('NO LE INTERESA','SACAR DE LA BASE','PROVINCIA'))
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=ld.numero_limpio and ll.fecha=p_hoy)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ld.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ld.numero_limpio)
    order by case when ul.cnt is null then 0 else 1 end,ld.fecha desc limit 1;
    if v_num is not null then v_tier:='CAMPAÑA · '||v_cola_filtro;v_source:='DIRECT_CAMPAIGN_EXACT'; end if;
  end if;

  if v_num is null and v_cola_tipo='tipificacion' and v_cola_filtro<>'' then
    select ll.numero_limpio into v_num from public.aos_llamadas ll
    where upper(ll.estado)=upper(v_cola_filtro)
      and not exists(select 1 from public.aos_llamadas l2 where l2.numero_limpio=ll.numero_limpio and l2.fecha=p_hoy)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ll.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ll.numero_limpio)
    order by ll.fecha desc limit 1;
    if v_num is not null then
      v_tier:='TIPIF · '||v_cola_filtro;
      select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen) into v_count,v_nonnull,v_distinct,v_lead_id
      from public.aos_llamadas where numero_limpio=v_num and upper(estado)=upper(v_cola_filtro);
      if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='TIPIFICACION_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
    end if;
  end if;

  if v_num is null and v_cola_tipo='no_asistio' then
    select a.numero_limpio into v_num from public.aos_agenda_citas a
    where a.estado_cita='NO ASISTIO' and a.numero_limpio is not null and a.numero_limpio<>''
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=a.numero_limpio and ll.fecha=p_hoy)
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=a.numero_limpio and ll.estado in('NO LE INTERESA','SACAR DE LA BASE'))
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=a.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=a.numero_limpio)
    order by a.fecha_cita desc limit 1;
    if v_num is not null then
      v_tier:='NO ASISTIÓ CITA';
      select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen) into v_count,v_nonnull,v_distinct,v_lead_id
      from public.aos_agenda_citas where numero_limpio=v_num and estado_cita='NO ASISTIO';
      if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='NO_SHOW_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
    end if;
  end if;

  if v_num is null and v_cola_tipo='pacientes_activos' then
    select v.numero_limpio into v_num from public.aos_ventas v
    where v.fecha>=(p_hoy-90)::date and v.numero_limpio is not null
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=v.numero_limpio and ll.fecha=p_hoy)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=v.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
    order by v.fecha asc limit 1;
    if v_num is not null then v_tier:='PACIENTE ACTIVO';v_lead_id:=null;v_source:='UNRESOLVED'; end if;
  end if;

  if v_num is null and v_cola_tipo='provincia' then
    select ll.numero_limpio into v_num from public.aos_llamadas ll
    where ll.estado in('PROVINCIA','PROVINCIAS')
      and not exists(select 1 from public.aos_llamadas l2 where l2.numero_limpio=ll.numero_limpio and l2.fecha=p_hoy)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ll.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ll.numero_limpio)
    order by ll.fecha desc limit 1;
    if v_num is not null then
      v_tier:='PROVINCIA';
      select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen) into v_count,v_nonnull,v_distinct,v_lead_id
      from public.aos_llamadas where numero_limpio=v_num and estado in('PROVINCIA','PROVINCIAS');
      if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='PROVINCE_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
    end if;
  end if;

  if v_num is null then
    select ld.id,ld.numero_limpio into v_lead_id,v_num from public.aos_leads ld
    where ld.fecha=p_hoy
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=ld.numero_limpio)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ld.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ld.numero_limpio)
    order by ld.numero_limpio limit 1;
    if v_num is not null then v_tier:='TIER 1 · VÍRGENES HOY';v_tier_num:=1;v_source:='DIRECT_TIER_1_EXACT'; end if;
  end if;
  if v_num is null then
    select ld.id,ld.numero_limpio into v_lead_id,v_num from public.aos_leads ld
    where ld.fecha>=(p_hoy-extract(dow from p_hoy)::int)::date and ld.fecha<p_hoy
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=ld.numero_limpio)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ld.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ld.numero_limpio)
    order by ld.fecha desc limit 1;
    if v_num is not null then v_tier:='TIER 2 · VÍRGENES SEMANA';v_tier_num:=2;v_source:='DIRECT_TIER_2_EXACT'; end if;
  end if;
  if v_num is null then
    select ld.id,ld.numero_limpio into v_lead_id,v_num from public.aos_leads ld
    where date_trunc('month',ld.fecha)=date_trunc('month',p_hoy) and ld.fecha<(p_hoy-extract(dow from p_hoy)::int)::date
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=ld.numero_limpio)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ld.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ld.numero_limpio)
    order by ld.fecha desc limit 1;
    if v_num is not null then v_tier:='TIER 3 · VÍRGENES MES';v_tier_num:=3;v_source:='DIRECT_TIER_3_EXACT'; end if;
  end if;
  if v_num is null then
    select ld.id,ld.numero_limpio into v_lead_id,v_num from public.aos_leads ld
    where date_trunc('month',ld.fecha)<date_trunc('month',p_hoy)
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=ld.numero_limpio)
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ld.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ld.numero_limpio)
    order by ld.fecha desc limit 1;
    if v_num is not null then v_tier:='TIER 4 · VÍRGENES HISTÓRICOS';v_tier_num:=4;v_source:='DIRECT_TIER_4_EXACT'; end if;
  end if;

  if v_num is null then
    select a.numero_limpio into v_num from public.aos_agenda_citas a
    where a.estado_cita='NO ASISTIO' and a.fecha_cita between v_hace14 and p_hoy and a.numero_limpio is not null and a.numero_limpio<>''
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=a.numero_limpio and ll.fecha=p_hoy)
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=a.numero_limpio and ll.estado in('NO LE INTERESA','SACAR DE LA BASE','PROVINCIA'))
      and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=a.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
      and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=a.numero_limpio)
    order by a.fecha_cita asc limit 1;
    if v_num is not null then
      v_tier:='TIER 5 · NO ASISTIÓ CITA';v_tier_num:=5;
      select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen) into v_count,v_nonnull,v_distinct,v_lead_id
      from public.aos_agenda_citas where numero_limpio=v_num and estado_cita='NO ASISTIO' and fecha_cita between v_hace14 and p_hoy;
      if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='TIER_5_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
    end if;
  end if;

  if v_num is null then
    select s."NUMERO" into v_num from public.aos_seguimientos s
    where s."ESTADO"='PENDIENTE' and s."FECHA_PROGRAMADA"::date<=p_hoy
      and (p_asesor='' or upper(coalesce(s."ASESOR",''))=upper(p_asesor) or (p_id_asesor<>'' and coalesce(s."ID_ASESOR",'')=p_id_asesor))
      and not exists(select 1 from public.aos_llamadas ll where ll.numero_limpio=s."NUMERO" and ll.fecha=p_hoy)
    order by s."FECHA_PROGRAMADA" asc limit 1;
    if v_num is not null then
      v_tier:='TIER 6 · SEGUIMIENTO';v_tier_num:=6;
      select count(*),count(lead_id_origen),count(distinct lead_id_origen),min(lead_id_origen) into v_count,v_nonnull,v_distinct,v_lead_id
      from public.aos_seguimientos
      where regexp_replace(coalesce("NUMERO",''),'\D','','g')=regexp_replace(coalesce(v_num,''),'\D','','g') and "ESTADO"='PENDIENTE' and "FECHA_PROGRAMADA"::date<=p_hoy
        and (p_asesor='' or upper(coalesce("ASESOR",''))=upper(p_asesor) or (p_id_asesor<>'' and coalesce("ID_ASESOR",'')=p_id_asesor));
      if v_count>0 and v_count=v_nonnull and v_distinct=1 then v_source:='FOLLOWUP_ORIGIN_UNANIMOUS'; else v_lead_id:=null; end if;
    end if;
  end if;

  if v_num is null then
    select x.numero_limpio into v_num from(
      select ld.numero_limpio from public.aos_leads ld join public.aos_llamadas ll on ll.numero_limpio=ld.numero_limpio
      where not exists(select 1 from public.aos_llamadas d where d.numero_limpio=ld.numero_limpio and d.estado in('NO LE INTERESA','SACAR DE LA BASE','PROVINCIA'))
        and not exists(select 1 from public.aos_llamadas h where h.numero_limpio=ld.numero_limpio and h.fecha=p_hoy)
        and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ld.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
        and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ld.numero_limpio)
      group by ld.numero_limpio having max(ll.fecha)<(p_hoy-3)::date order by max(ll.fecha) asc limit 1) x;
    if v_num is not null then v_tier:='TIER 7 · REBARRIDO';v_tier_num:=7;v_lead_id:=null;v_source:='UNRESOLVED'; end if;
  end if;
  if v_num is null then
    select x.numero_limpio into v_num from(
      select ld.numero_limpio from public.aos_leads ld join public.aos_llamadas ll on ll.numero_limpio=ld.numero_limpio
      where not exists(select 1 from public.aos_llamadas d where d.numero_limpio=ld.numero_limpio and d.estado in('NO LE INTERESA','SACAR DE LA BASE','PROVINCIA'))
        and not exists(select 1 from public.aos_llamadas h where h.numero_limpio=ld.numero_limpio and h.fecha=p_hoy)
        and not exists(select 1 from public.aos_leads_en_curso lc where lc.numero_limpio=ld.numero_limpio and lc.fecha=p_hoy and upper(lc.asesor)<>upper(p_asesor))
        and not exists(select 1 from public.v_numeros_con_cita_pendiente cp where cp.numero_limpio=ld.numero_limpio)
      group by ld.numero_limpio order by max(ll.fecha) asc limit 1) x;
    if v_num is not null then v_tier:='TIER 8 · REBARRIDO URGENTE';v_tier_num:=8;v_lead_id:=null;v_source:='UNRESOLVED'; end if;
  end if;

  if v_num is null then return json_build_object('ok',false,'sin_leads',true,'msg','¡Todos los leads fueron llamados hoy! Base 100% trabajada.'); end if;
  select coalesce(count(*),0)+1 into v_intento from public.aos_llamadas where numero_limpio=v_num;

  if v_lead_id is not null then
    select json_build_object('id',ld.id,'num',ld.numero_limpio,'trat',coalesce(ld.tratamiento,''),'anuncio',coalesce(ld.anuncio,''),'fecha',ld.fecha,'hora_ingreso',ld.hora_ingreso,'intento',v_intento,'rowNum',0,'attributionSource',v_source)
      into v_lead from public.aos_leads ld where ld.id=v_lead_id;
  else
    select json_build_object('id',null,'num',ld.numero_limpio,'trat',coalesce(ld.tratamiento,''),'anuncio','','fecha',ld.fecha,'hora_ingreso',null,'intento',v_intento,'rowNum',0,'attributionSource','UNRESOLVED')
      into v_lead from public.aos_leads ld where ld.numero_limpio=v_num limit 1;
    if v_lead is null then v_lead:=json_build_object('id',null,'num',v_num,'trat','','anuncio','','fecha',p_hoy::text,'hora_ingreso',null,'intento',v_intento,'rowNum',0,'attributionSource','UNRESOLVED'); end if;
  end if;

  insert into public.aos_leads_en_curso(asesor,numero_limpio,fecha,lead_id_origen)
  values(upper(p_asesor),v_num,p_hoy,v_lead_id)
  on conflict(asesor,numero_limpio,fecha) do update set lead_id_origen=excluded.lead_id_origen;

  select json_build_object('ultimaLlamada',json_build_object('fecha',ll.fecha,'estado',ll.estado,'asesor',ll.asesor,'obs',coalesce(ll.observacion,''),'intento',ll.intento))
    into v_contexto from public.aos_llamadas ll where ll.numero_limpio=v_num order by ll.created_at desc nulls last,ll.id desc limit 1;

  return json_build_object('ok',true,'lead',v_lead,'tier',v_tier,'tierNum',v_tier_num,'fromSupabase',true,'colaConfig',v_cola_tipo,'contexto',v_contexto);
end;
$function$;
