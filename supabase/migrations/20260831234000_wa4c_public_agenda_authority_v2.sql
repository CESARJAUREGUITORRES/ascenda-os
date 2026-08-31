-- Public agenda V2 consumes the same booking authority as WA-4C.
-- Exact-provider for doctors; site pool for nursing.

begin;

create or replace function public.aos_booking_public_catalog_v2()
returns jsonb
language sql
stable
security definer
set search_path='public'
as $$
  select coalesce(jsonb_agg(x order by x->>'categoria',x->>'nombre'),'[]'::jsonb)
  from (
    select jsonb_build_object(
      'id',s.id,
      'nombre',s.nombre,
      'categoria',coalesce(s.categoria,'GENERAL'),
      'capability',public.aos_booking_capability_for_service_v1(s.id),
      'role',case
        when coalesce(s.requiere_doctora,false) and not coalesce(s.requiere_enfermeria,false) then 'DOCTORA'
        when coalesce(s.requiere_enfermeria,false) and not coalesce(s.requiere_doctora,false) then 'ENFERMERIA'
        else null end,
      'mode',case
        when coalesce(s.requiere_doctora,false) and not coalesce(s.requiere_enfermeria,false) then 'EXACT_PROVIDER'
        when coalesce(s.requiere_enfermeria,false) and not coalesce(s.requiere_doctora,false) then 'SITE_POOL'
        else null end
    ) x
    from public.aos_catalogo_servicios s
    where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
      and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
      and public.aos_booking_capability_for_service_v1(s.id) is not null
      and (coalesce(s.requiere_doctora,false) <> coalesce(s.requiere_enfermeria,false))
  ) q;
$$;

revoke all on function public.aos_booking_public_catalog_v2() from public;
grant execute on function public.aos_booking_public_catalog_v2() to anon,authenticated,service_role;

create or replace function public.aos_agendar_publica_v2(
  p_token text,
  p_nombre text,
  p_apellido text,
  p_telefono text,
  p_treatment_id uuid,
  p_fecha date,
  p_hora text,
  p_sede text,
  p_profesional_id text default null,
  p_dni text default '',
  p_email text default '',
  p_nota text default '',
  p_tipo_cita text default 'CONSULTA NUEVA'
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_link record;
  v_t public.aos_catalogo_servicios%rowtype;
  v_num text;
  v_paciente record;
  v_asesor text;
  v_site text;
  v_role text;
  v_mode text;
  v_avail jsonb;
  v_slot jsonb;
  v_prof_id text;
  v_prof_name text;
  v_id text;
begin
  if coalesce(trim(p_token),'') in ('','__permanent__') then
    v_asesor:='ORGANICO';
  else
    select * into v_link from public.aos_links_agenda where token=p_token and expira_at>now();
    if not found then return jsonb_build_object('ok',false,'error','LINK_INVALID_OR_EXPIRED'); end if;
    v_asesor:=coalesce(v_link.asesor_codigo,'ORGANICO');
  end if;

  select * into v_t from public.aos_catalogo_servicios
  where id=p_treatment_id and upper(coalesce(estado,'ACTIVO'))='ACTIVO' and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'error','TREATMENT_NOT_ACTIVE'); end if;

  if coalesce(v_t.requiere_doctora,false) and not coalesce(v_t.requiere_enfermeria,false) then
    v_role:='DOCTORA';v_mode:='EXACT_PROVIDER';v_prof_id:=nullif(trim(p_profesional_id),'');
    if v_prof_id is null then return jsonb_build_object('ok',false,'error','EXACT_PROVIDER_REQUIRED'); end if;
  elsif coalesce(v_t.requiere_enfermeria,false) and not coalesce(v_t.requiere_doctora,false) then
    v_role:='ENFERMERIA';v_mode:='SITE_POOL';v_prof_id:=null;
  else
    return jsonb_build_object('ok',false,'error','COMPLEX_ROLE_REQUIRES_HUMAN');
  end if;

  v_site:=upper(replace(trim(coalesce(p_sede,'')),'_',' '));
  if v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','SITE_INVALID'); end if;
  if p_fecha<current_date or extract(isodow from p_fecha)=7 then return jsonb_build_object('ok',false,'error','DATE_INVALID'); end if;
  if coalesce(trim(p_hora),'')!~'^[0-2][0-9]:[0-5][0-9]$' then return jsonb_build_object('ok',false,'error','TIME_INVALID'); end if;

  perform pg_advisory_xact_lock(hashtextextended('public-booking-v2:'||v_role||':'||v_site||':'||p_fecha::text||':'||p_hora,0));
  v_avail:=coalesce(public.aos_booking_availability_v2(v_t.id,p_fecha,v_site,v_prof_id),'{}'::jsonb);
  if coalesce((v_avail->>'ok')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'error','BOOKING_AUTHORITY_BLOCKED','authority_status',coalesce(v_avail->>'status','UNKNOWN'));
  end if;

  select s into v_slot
  from jsonb_array_elements(coalesce(v_avail->'slots','[]'::jsonb)) s
  where s->>'hora'=substring(p_hora from 1 for 5)
    and coalesce((s->>'disponible')::boolean,false)=true
    and (v_role='ENFERMERIA' or s->>'professional_id'=v_prof_id)
  limit 1;
  if v_slot is null then return jsonb_build_object('ok',false,'error','SLOT_NO_LONGER_AVAILABLE'); end if;

  if v_role='DOCTORA' then
    v_prof_name:=nullif(v_slot->>'professional_name','');
    if v_prof_name is null then return jsonb_build_object('ok',false,'error','PROFESSIONAL_NOT_AVAILABLE'); end if;
  else
    v_prof_name:='ENFERMERIA';
  end if;

  v_num:=regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g');
  if length(v_num)<7 then return jsonb_build_object('ok',false,'error','PHONE_REQUIRED'); end if;
  if coalesce(trim(p_nombre),'')='' then return jsonb_build_object('ok',false,'error','NAME_REQUIRED'); end if;

  select * into v_paciente from public.aos_pacientes where numero_limpio=v_num limit 1;
  if not found then
    insert into public.aos_pacientes(numero_limpio,"Nombres","Apellidos","Email","N° documento","ESTADO_PACIENTE","FECHA_REGISTRO","FUENTE")
    values(v_num,upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),nullif(trim(p_email),''),nullif(trim(p_dni),''),'PROSPECTO',current_date,case when v_asesor='ORGANICO' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end);
  elsif (v_paciente."Email" is null or v_paciente."Email"='') and coalesce(trim(p_email),'')<>'' then
    update public.aos_pacientes set "Email"=trim(p_email) where numero_limpio=v_num;
  end if;

  v_id:=gen_random_uuid()::text;
  insert into public.aos_agenda_citas(
    id,fecha_cita,hora_cita,nombre,apellido,numero,numero_limpio,tratamiento,sede,doctora,asesor,
    estado_cita,tipo_cita,tipo_atencion,origen_cita,obs,ts_creado
  ) values (
    v_id,p_fecha,substring(p_hora from 1 for 5),upper(trim(p_nombre)),upper(trim(coalesce(p_apellido,''))),v_num,v_num,
    v_t.nombre,v_site,case when v_role='DOCTORA' then v_prof_name else null end,v_asesor,
    'PENDIENTE',upper(trim(coalesce(p_tipo_cita,'CONSULTA NUEVA'))),v_role,
    case when v_asesor='ORGANICO' then 'WEB-PUBLICA' else 'AUTO-AGENDA' end,
    trim(coalesce(p_nota,''))||case when v_role='ENFERMERIA' then case when coalesce(trim(p_nota),'')='' then '' else ' | ' end||'BOOKING_MODE=SITE_POOL' else '' end,
    now()
  );

  if coalesce(trim(p_token),'') not in ('','__permanent__') then
    update public.aos_links_agenda set usado=true where token=p_token and tipo='paciente_especifico';
  end if;

  return jsonb_build_object('ok',true,'status','BOOKED','agenda_id',v_id,'fecha',p_fecha,'hora',substring(p_hora from 1 for 5),'sede',v_site,'role',v_role,'mode',v_mode,'professional_name',case when v_role='DOCTORA' then v_prof_name else 'Enfermería' end);
end
$$;

revoke all on function public.aos_agendar_publica_v2(text,text,text,text,uuid,date,text,text,text,text,text,text,text) from public;
grant execute on function public.aos_agendar_publica_v2(text,text,text,text,uuid,date,text,text,text,text,text,text,text) to anon,authenticated,service_role;

commit;
