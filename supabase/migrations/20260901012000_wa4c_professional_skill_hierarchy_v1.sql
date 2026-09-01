-- WA-4C · Professional Skill Hierarchy V1
-- service -> procedure -> skill -> professional -> schedule -> slot
-- Keeps current parent skills backward-compatible; procedure scopes are opt-in.
begin;

create table if not exists public.aos_booking_procedure_map_v1 (
  service_name_norm text primary key,
  capability text not null,
  procedure_key text not null,
  procedure_name text not null,
  evidence_ref text not null default 'SKILL_HIERARCHY_V1',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_aos_booking_procedure_map_v1_capability
  on public.aos_booking_procedure_map_v1(capability, procedure_key)
  where active=true;

create table if not exists public.aos_professional_procedure_scope_v1 (
  codigo_asesor text not null,
  capability text not null,
  procedure_key text not null,
  procedure_name text not null,
  enabled boolean not null,
  source text not null default 'ADMIN_TEAM',
  updated_at timestamptz not null default now(),
  primary key(codigo_asesor, capability, procedure_key)
);

create index if not exists idx_aos_professional_procedure_scope_v1_lookup
  on public.aos_professional_procedure_scope_v1(codigo_asesor, capability, enabled);

create table if not exists public.aos_team_skill_audit_v1 (
  id bigserial primary key,
  codigo_asesor text not null,
  user_id uuid,
  parent_skills text[] not null default array[]::text[],
  procedure_scope jsonb not null default '[]'::jsonb,
  actor text not null default 'ADMIN_TEAM',
  created_at timestamptz not null default now()
);

create or replace function public.aos_booking_procedure_name_v1(p_capability text, p_service_name text)
returns text
language plpgsql
immutable
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  c text:=upper(public.aos_booking_norm_v1(coalesce(p_capability,'')));
  n text:=upper(public.aos_booking_norm_v1(coalesce(p_service_name,'')));
begin
  if c='BIOREVITALIZACION FACIAL' then
    if n like 'CELLBOOSTER GLOW%' then return 'CELLBOOSTER GLOW'; end if;
    if n like 'CELLBOOSTER LIFT%' then return 'CELLBOOSTER LIFT'; end if;
    if n like 'NANOPLASMA FACIAL%' then return 'NANOPLASMA FACIAL'; end if;
    if n like 'MESOGLOW%' then return 'MESOGLOW'; end if;
    if n like '%SUCCINICO%AMBER%' then return 'ACIDO SUCCINICO AMBER'; end if;
    if n like '%TRANEXAMICO%' then return 'ACIDO TRANEXAMICO'; end if;
    if n like 'PINK GLOW ROSTRO%' then return 'PINK GLOW ROSTRO'; end if;
  elsif c='ACIDO HIALURONICO' then
    if n like 'BACCIO LABIOS%' then return 'BACCIO LABIOS'; end if;
    if n like 'MONALISA%' then return 'MONALISA'; end if;
    if n like 'PROFHILO%' then return 'PROFHILO ROSTRO'; end if;
    if n like 'SKINFILL BLUE%' then return 'SKINFILL BLUE'; end if;
    if n like 'SKINFILL ITALIA%' then return 'SKINFILL ITALIA'; end if;
    if n like 'SUNEKO PERFORMANCE%' then return 'SUNEKO PERFORMANCE'; end if;
  elsif c='BIOESTIMULADOR' then
    if n like 'BIOESTIMULADOR GLUTEOS POWERFILL%' then return 'POWERFILL GLUTEOS'; end if;
    if n like 'ELLANSE M%' then return 'ELLANSE M'; end if;
    if n like 'HIDROXIAPATITA DE CALCIO%' then return 'HIDROXIAPATITA DE CALCIO'; end if;
    if n like 'NUCLEOFILL MEDIUM%' then return 'NUCLEOFILL MEDIUM'; end if;
    if n like 'NUCLEOFILL SOFT%' then return 'NUCLEOFILL SOFT'; end if;
    if n like 'NUCLEOFILL STRONG%' then return 'NUCLEOFILL STRONG'; end if;
    if n like 'RADIESSE%' then return 'RADIESSE'; end if;
    if n like 'RICH PL ADVANCE%' then return 'RICH PL ADVANCE'; end if;
    if n like 'RICH PL 10ML%' then return 'RICH PL 10ML'; end if;
    if n like 'RICH PL 5ML%' then return 'RICH PL 5ML'; end if;
  elsif c='CAPILAR' then
    if n like 'CASCO REGENERADOR%' then return 'CASCO REGENERADOR COLAGENO'; end if;
    if n like 'DUTASTERIDE CAPILAR%' then return 'DUTASTERIDE CAPILAR'; end if;
    if n like 'RF FRACCIONADA CAPILAR%' then return 'RF FRACCIONADA CAPILAR'; end if;
  elsif c='CARBOXITERAPIA' then
    if n like 'CARBOXI PACK 1%' then return 'CARBOXI PACK 1'; end if;
    if n like 'CARBOXI PACK 2%' then return 'CARBOXI PACK 2'; end if;
    if n like 'CARBOXI PLUS%' then return 'CARBOXI PLUS'; end if;
  elsif c='CONSULTA MEDICA' then
    if n like 'CONSULTA CIRUJANO%' then return 'CONSULTA CIRUJANO PLASTICO'; end if;
    if n like 'CONSULTA MEDICA VIRTUAL%' then return 'CONSULTA MEDICA VIRTUAL'; end if;
  elsif c='DETOX' then
    if n like 'DETOX IONICO%' then return 'DETOX IONICO'; end if;
    if n like 'FULL B VITAL DETOX%' then return 'FULL B VITAL DETOX'; end if;
    if n like 'VITA DETOX PASCOE%' then return 'VITA DETOX PASCOE'; end if;
  elsif c='ENZIMAS CORPORALES' then
    if n like 'CELLBOOSTER SHAPE%' then return 'CELLBOOSTER SHAPE'; end if;
    if n like 'ENZIMAS CORP BRAZOS%' then return 'ENZIMAS CORP BRAZOS'; end if;
  elsif c='ENZIMAS FACIALES' then
    if n like 'ENZIMAS FACIAL MCCM%' then return 'ENZIMAS FACIAL MCCM'; end if;
    if n like 'ENZIMAS FACIAL PBSERUM%' then return 'ENZIMAS FACIAL PBSERUM'; end if;
    if n like 'EXO SLIM PAPADA%' then return 'EXO SLIM PAPADA'; end if;
  elsif c='EXOSOMAS' then
    if n like 'MCCM EXO TRX%' then return 'MCCM EXO TRX'; end if;
    if n like 'V TECH%' then return 'V TECH'; end if;
    if n like 'YOUTH HEALTH%' then return 'YOUTH HEALTH'; end if;
  elsif c='EXOSOMAS CAPILARES' then
    return 'EXOSOMAS EXOSIGNAL HAIR';
  elsif c='FACIALES' then
    if n like 'DESCONGESTIVO PARPADOS%' then return 'DESCONGESTIVO PARPADOS'; end if;
    if n like 'FACIAL CELULAS MADRE%' then return 'FACIAL CELULAS MADRE'; end if;
    if n like 'FACIAL COREANO%' then return 'FACIAL COREANO'; end if;
    if n like 'FACIAL DIAMANTE%' then return 'FACIAL DIAMANTE'; end if;
    if n like 'HIDROVITAL PASCOE%' then return 'HIDROVITAL PASCOE'; end if;
    if n like 'MASCARILLA ESTHEMAX%' then return 'MASCARILLA ESTHEMAX'; end if;
    if n like 'MASCARILLA Q10%' then return 'MASCARILLA Q10'; end if;
    if n like 'SKIN PREP%' then return 'SKIN PREP'; end if;
  elsif c='GLUTEOS' then
    if n like 'AH SKINFILL GLUTEOS%' then return 'AH SKINFILL GLUTEOS'; end if;
    if n like 'ENZIMAS CORP ABDOMEN%GLUTEOS%MUSLOS%' then return 'ENZIMAS ABDOMEN GLUTEOS MUSLOS'; end if;
  elsif c='HIDROFACIAL' then
    if n like 'HIDROFACIAL ANTIACNE%' then return 'HIDROFACIAL ANTIACNE'; end if;
    if n like 'HIDROFACIAL%' then return 'HIDROFACIAL ROSTRO'; end if;
  elsif c='HIFU' then
    if n like 'HIFU 7D BRAZOS%' then return 'HIFU 7D BRAZOS'; end if;
    if n like 'HIFU CORP ABDOMEN%' then return 'HIFU ABDOMEN'; end if;
    if n like 'HIFU CORP ENTREPIERNAS%' then return 'HIFU ENTREPIERNAS'; end if;
    if n like 'HIFU CORP ESPALDA BAJA%' then return 'HIFU ESPALDA BAJA'; end if;
    if n like 'HIFUTOX%' then return 'HIFUTOX'; end if;
    if n like 'ZI FROZEN BEAUTY%' then return 'ZI FROZEN BEAUTY'; end if;
    if n like 'ZI FROZEN CISNE%' then return 'ZI FROZEN CISNE'; end if;
    if n like 'ZI FROZEN FULL FACE%' then return 'ZI FROZEN FULL FACE'; end if;
  elsif c='MESOTERAPIA CAPILAR' then
    if n like 'HAIR COCTEL MESO%' then return 'HAIR COCTEL MESO'; end if;
    if n like 'MESO CAPILAR VIT%' then return 'MESO CAPILAR VIT'; end if;
  elsif c='MESOTERAPIA CORPORAL' then
    if n like 'MESOTERAPIA CORPORAL 2 AMP%' then return 'MESOTERAPIA CORPORAL 2 AMP'; end if;
    if n like 'MESOTERAPIA CORPORAL 4+2 AMP%' then return 'MESOTERAPIA CORPORAL 4+2 AMP'; end if;
  elsif c='MESOTERAPIA FACIAL' then
    return 'MESOTERAPIA CON PLASMA FACIAL';
  elsif c='MICRONEEDLING FACIAL' then
    return 'MICRONEEDLING CON PLASMA';
  elsif c='NANO GLOW' then
    return 'NANO GLOW';
  elsif c='PEELINGS' then
    return 'ZK';
  elsif c='PEPTONAS' then
    return 'PEPTOPLUS';
  elsif c='PINK INTIMATE' then
    return 'PINK INTIMATE';
  elsif c='PQ AGE' then
    return 'PQ AGE';
  elsif c='PRP CAPILAR' then
    return 'PRP CAPILAR';
  elsif c='RADIOFRECUENCIA FRACCIONADA' then
    if n like 'RF FRACCIONADA BRAZO%' then return 'RF FRACCIONADA BRAZO'; end if;
    if n like 'RF FRACCIONADA ROSTRO%CUELLO%' then return 'RF FRACCIONADA ROSTRO CUELLO'; end if;
  elsif c='TOXINA' then
    if n like 'HUTOX%' then return 'HUTOX'; end if;
    if n like 'NABOTA%' then return 'NABOTA'; end if;
    if n like 'HIPERHIDROSIS%' then return 'HIPERHIDROSIS'; end if;
    if n like 'MACETERO%' then return 'MACETERO'; end if;
    if n like 'PLATISMA%' then return 'PLATISMA'; end if;
  elsif c='VITAMINAS' then
    if n like 'HIERRO SACAROSA%' then return 'HIERRO SACAROSA'; end if;
    if n like '%HEPATOPROTECTOR%' or n like 'PACK HEPATOREGEN%' then return 'HEPATOPROTECTOR'; end if;
    if n like '%B12%' and n not like '%VITC%' and n not like '%VIT C%' then return 'B12'; end if;
    if n like 'FULL B%' then return 'FULL B'; end if;
    if n like '%VITAMINA C%' or n like '%VITC%' or n like '%VIT C%' then return 'VITAMINA C Y COMBINACIONES'; end if;
    if n like '%PASCOE%' then return 'PROTOCOLOS PASCOE'; end if;
    if n like '%SUPLEMENTO%' or n like '%SUP%' then return 'SUPLEMENTOS'; end if;
    if n like 'COMBO RESET%' then return 'COMBO RESET'; end if;
    return 'OTROS PROTOCOLOS IV';
  end if;

  return coalesce(nullif(trim(p_capability),''),'GENERAL');
end
$$;

insert into public.aos_booking_procedure_map_v1(
  service_name_norm,capability,procedure_key,procedure_name,evidence_ref,active,updated_at
)
select
  public.aos_booking_norm_v1(s.nombre),
  cap.capability,
  public.aos_booking_norm_v1(public.aos_booking_procedure_name_v1(cap.capability,s.nombre)),
  public.aos_booking_procedure_name_v1(cap.capability,s.nombre),
  'SKILL_HIERARCHY_V1:CATALOG',
  true,
  now()
from public.aos_catalogo_servicios s
cross join lateral (select public.aos_booking_capability_for_service_v1(s.id) capability) cap
where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
  and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
  and cap.capability is not null
on conflict(service_name_norm) do update
set capability=excluded.capability,
    procedure_key=excluded.procedure_key,
    procedure_name=excluded.procedure_name,
    evidence_ref=excluded.evidence_ref,
    active=true,
    updated_at=now();

create or replace function public.aos_booking_procedure_for_service_v1(p_treatment_id uuid)
returns jsonb
language sql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
select case when m.service_name_norm is null then null else jsonb_build_object(
  'capability',m.capability,
  'procedure_key',m.procedure_key,
  'procedure_name',m.procedure_name
) end
from public.aos_catalogo_servicios s
left join public.aos_booking_procedure_map_v1 m
  on m.service_name_norm=public.aos_booking_norm_v1(s.nombre) and m.active=true
where s.id=p_treatment_id
limit 1
$$;

create or replace function public.aos_professional_can_service_v1(p_profile_id text, p_treatment_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_profile public.aos_perfiles_profesional%rowtype;
  v_proc jsonb;
  v_cap text;
  v_key text;
  v_has_scope boolean;
  v_enabled boolean;
begin
  select * into v_profile from public.aos_perfiles_profesional where id::text=p_profile_id limit 1;
  if not found or coalesce(v_profile.visible,true) is not true then return false; end if;

  v_proc:=public.aos_booking_procedure_for_service_v1(p_treatment_id);
  if v_proc is null then return false; end if;
  v_cap:=v_proc->>'capability'; v_key:=v_proc->>'procedure_key';

  if not exists (
    select 1 from unnest(coalesce(v_profile.servicios,array[]::text[])) s
    where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(v_cap)
  ) then return false; end if;

  select exists(
    select 1 from public.aos_professional_procedure_scope_v1 x
    where x.codigo_asesor=v_profile.codigo_asesor
      and public.aos_booking_norm_v1(x.capability)=public.aos_booking_norm_v1(v_cap)
  ) into v_has_scope;

  if not v_has_scope then return true; end if;

  select coalesce(max(x.enabled::int),0)=1 into v_enabled
  from public.aos_professional_procedure_scope_v1 x
  where x.codigo_asesor=v_profile.codigo_asesor
    and public.aos_booking_norm_v1(x.capability)=public.aos_booking_norm_v1(v_cap)
    and x.procedure_key=v_key;

  return coalesce(v_enabled,false);
end
$$;

create or replace function public.aos_team_skill_hierarchy_v1(p_codigo_asesor text)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_user public.aos_usuarios%rowtype;
  v_profile public.aos_perfiles_profesional%rowtype;
  v_role text;
  v_result jsonb;
begin
  select * into v_user
  from public.aos_usuarios
  where codigo_asesor=p_codigo_asesor and activo is distinct from false
  order by updated_at desc nulls last
  limit 1;
  if not found then return jsonb_build_object('ok',false,'error','TEAM_USER_NOT_FOUND'); end if;

  select * into v_profile
  from public.aos_perfiles_profesional
  where codigo_asesor=p_codigo_asesor and coalesce(visible,true)=true
  order by orden nulls last
  limit 1;
  if not found then return jsonb_build_object('ok',false,'error','TEAM_PROFILE_NOT_FOUND'); end if;

  v_role:=upper(coalesce(v_profile.tipo,''));

  with skills as (
    select t.tratamiento,t.categoria,t.orden,t.requiere_doctora,t.requiere_enfermeria,
           exists(select 1 from unnest(coalesce(v_user.servicios,array[]::text[])) s
                  where public.aos_booking_norm_v1(s)=public.aos_booking_norm_v1(t.tratamiento)) parent_enabled
    from public.aos_cat_tratamientos t
    where upper(coalesce(t.estado,'ACTIVO'))='ACTIVO'
      and (
        (v_role='DOCTORA' and coalesce(t.requiere_doctora,false))
        or (v_role='ENFERMERIA' and coalesce(t.requiere_enfermeria,false))
      )
  ), proc as (
    select distinct m.capability,m.procedure_key,m.procedure_name,
           count(*) over(partition by m.capability,m.procedure_key) variant_count
    from public.aos_booking_procedure_map_v1 m
    join public.aos_catalogo_servicios s
      on public.aos_booking_norm_v1(s.nombre)=m.service_name_norm
     and upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
     and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
    where m.active=true
      and ((v_role='DOCTORA' and coalesce(s.requiere_doctora,false))
        or (v_role='ENFERMERIA' and coalesce(s.requiere_enfermeria,false)))
  ), skill_json as (
    select sk.categoria,sk.orden,
      jsonb_build_object(
        'skill',sk.tratamiento,
        'parent_enabled',sk.parent_enabled,
        'requires_doctor',sk.requiere_doctora,
        'requires_nursing',sk.requiere_enfermeria,
        'scope_mode',case when exists(
          select 1 from public.aos_professional_procedure_scope_v1 sc
          where sc.codigo_asesor=p_codigo_asesor
            and public.aos_booking_norm_v1(sc.capability)=public.aos_booking_norm_v1(sk.tratamiento)
        ) then 'EXPLICIT' else 'INHERIT' end,
        'procedures',coalesce((
          select jsonb_agg(jsonb_build_object(
            'key',p.procedure_key,
            'name',p.procedure_name,
            'variant_count',p.variant_count,
            'enabled',case
              when not sk.parent_enabled then false
              when exists(
                select 1 from public.aos_professional_procedure_scope_v1 sc0
                where sc0.codigo_asesor=p_codigo_asesor
                  and public.aos_booking_norm_v1(sc0.capability)=public.aos_booking_norm_v1(sk.tratamiento)
              ) then coalesce((
                select sc.enabled
                from public.aos_professional_procedure_scope_v1 sc
                where sc.codigo_asesor=p_codigo_asesor
                  and public.aos_booking_norm_v1(sc.capability)=public.aos_booking_norm_v1(sk.tratamiento)
                  and sc.procedure_key=p.procedure_key
                limit 1
              ),false)
              else true end
          ) order by p.procedure_name)
          from proc p
          where public.aos_booking_norm_v1(p.capability)=public.aos_booking_norm_v1(sk.tratamiento)
        ),'[]'::jsonb)
      ) item
    from skills sk
  ), cats as (
    select categoria,min(orden) ord,jsonb_agg(item order by orden,item->>'skill') skills
    from skill_json
    group by categoria
  )
  select jsonb_build_object(
    'ok',true,
    'codigo_asesor',p_codigo_asesor,
    'profile_id',v_profile.id,
    'profile_name',v_profile.nombre_publico,
    'profile_type',v_role,
    'categories',coalesce(jsonb_agg(jsonb_build_object(
      'category',categoria,'skills',skills
    ) order by case categoria
      when 'FACIAL' then 10 when 'INYECTABLES' then 20 when 'APARATOLOGÍA' then 30
      when 'CORPORAL' then 40 when 'CAPILAR' then 50 when 'CONSULTA' then 60
      when 'COMBO' then 70 when 'OTROS' then 80 else 90 end, ord),'[]'::jsonb)
  ) into v_result
  from cats;

  return coalesce(v_result,jsonb_build_object('ok',true,'categories','[]'::jsonb));
end
$$;

create or replace function public.aos_team_save_skill_hierarchy_v1(
  p_user_id uuid,
  p_parent_skills text[],
  p_scopes jsonb,
  p_cmp text default null
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_user public.aos_usuarios%rowtype;
  v_profile public.aos_perfiles_profesional%rowtype;
  v_role text;
  v_scope jsonb;
  v_cap text;
  v_mode text;
  v_enabled jsonb;
  v_proc record;
  v_count int:=0;
begin
  select * into v_user from public.aos_usuarios where id=p_user_id for update;
  if not found or v_user.activo is false then return jsonb_build_object('ok',false,'error','TEAM_USER_NOT_FOUND'); end if;
  if coalesce(btrim(v_user.codigo_asesor),'')='' then return jsonb_build_object('ok',false,'error','TEAM_CODE_REQUIRED'); end if;

  select * into v_profile from public.aos_perfiles_profesional
  where codigo_asesor=v_user.codigo_asesor and coalesce(visible,true)=true limit 1;
  if not found then return jsonb_build_object('ok',false,'error','TEAM_PROFILE_NOT_FOUND'); end if;
  v_role:=upper(coalesce(v_profile.tipo,''));

  if exists (
    select 1 from unnest(coalesce(p_parent_skills,array[]::text[])) x
    left join public.aos_cat_tratamientos t
      on public.aos_booking_norm_v1(t.tratamiento)=public.aos_booking_norm_v1(x)
     and upper(coalesce(t.estado,'ACTIVO'))='ACTIVO'
    where t.tratamiento is null
       or (v_role='DOCTORA' and coalesce(t.requiere_doctora,false) is not true)
       or (v_role='ENFERMERIA' and coalesce(t.requiere_enfermeria,false) is not true)
  ) then
    return jsonb_build_object('ok',false,'error','TEAM_SKILL_ROLE_MISMATCH');
  end if;

  update public.aos_usuarios
     set servicios=coalesce(p_parent_skills,array[]::text[]),
         cmp=case when p_cmp is null then cmp else nullif(btrim(p_cmp),'') end,
         updated_at=now()
   where id=p_user_id;

  delete from public.aos_professional_procedure_scope_v1
  where codigo_asesor=v_user.codigo_asesor
    and not exists (
      select 1 from unnest(coalesce(p_parent_skills,array[]::text[])) x
      where public.aos_booking_norm_v1(x)=public.aos_booking_norm_v1(capability)
    );

  if p_scopes is not null and jsonb_typeof(p_scopes)='array' then
    for v_scope in select value from jsonb_array_elements(p_scopes)
    loop
      v_cap:=nullif(btrim(v_scope->>'capability'),'');
      v_mode:=upper(coalesce(v_scope->>'mode','INHERIT'));
      if v_cap is null then continue; end if;
      if not exists (
        select 1 from unnest(coalesce(p_parent_skills,array[]::text[])) x
        where public.aos_booking_norm_v1(x)=public.aos_booking_norm_v1(v_cap)
      ) then
        delete from public.aos_professional_procedure_scope_v1
        where codigo_asesor=v_user.codigo_asesor
          and public.aos_booking_norm_v1(capability)=public.aos_booking_norm_v1(v_cap);
        continue;
      end if;

      delete from public.aos_professional_procedure_scope_v1
      where codigo_asesor=v_user.codigo_asesor
        and public.aos_booking_norm_v1(capability)=public.aos_booking_norm_v1(v_cap);

      if v_mode='EXPLICIT' then
        v_enabled:=coalesce(v_scope->'enabled_keys','[]'::jsonb);
        for v_proc in
          select distinct procedure_key,procedure_name
          from public.aos_booking_procedure_map_v1
          where active=true
            and public.aos_booking_norm_v1(capability)=public.aos_booking_norm_v1(v_cap)
          order by procedure_name
        loop
          insert into public.aos_professional_procedure_scope_v1(
            codigo_asesor,capability,procedure_key,procedure_name,enabled,source,updated_at
          ) values (
            v_user.codigo_asesor,v_cap,v_proc.procedure_key,v_proc.procedure_name,
            exists(select 1 from jsonb_array_elements_text(v_enabled) e where e=v_proc.procedure_key),
            'ADMIN_TEAM',now()
          )
          on conflict(codigo_asesor,capability,procedure_key) do update
          set procedure_name=excluded.procedure_name,enabled=excluded.enabled,source='ADMIN_TEAM',updated_at=now();
          v_count:=v_count+1;
        end loop;
      end if;
    end loop;
  end if;

  insert into public.aos_team_skill_audit_v1(codigo_asesor,user_id,parent_skills,procedure_scope,actor)
  values(v_user.codigo_asesor,p_user_id,coalesce(p_parent_skills,array[]::text[]),coalesce(p_scopes,'[]'::jsonb),'ADMIN_TEAM');

  return jsonb_build_object(
    'ok',true,
    'codigo_asesor',v_user.codigo_asesor,
    'parent_skill_count',coalesce(array_length(p_parent_skills,1),0),
    'procedure_scope_rows_written',v_count,
    'profile_sync_expected',true
  );
end
$$;

create or replace function public.aos_booking_availability_v2(
  p_treatment_id uuid,
  p_fecha date,
  p_sede text,
  p_profesional_id text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_t public.aos_catalogo_servicios%rowtype;
  v_capability text;
  v_procedure jsonb;
  v_site text;
  v_doc_allowed boolean;
  v_nurse_allowed boolean;
  v_do_doc boolean;
  v_do_nurse boolean;
  v_doc_latest date;
  v_nurse_latest date;
  v_slots jsonb := '[]'::jsonb;
  v_providers jsonb := '[]'::jsonb;
  v_np jsonb := '[]'::jsonb;
  v_p record;
  v_h record;
  v_time time;
  v_min_start time;
  v_max_end time;
  v_members int;
  v_capacity int;
  v_occupied int;
  v_names jsonb;
  v_step interval;
  v_role_out text;
  v_mode_out text;
begin
  v_site:=upper(replace(trim(coalesce(p_sede,'')),'_',' '));
  if p_fecha is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','INVALID_DATE_OR_SITE');
  end if;

  select * into v_t
  from public.aos_catalogo_servicios
  where id=p_treatment_id
    and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'status','TREATMENT_NOT_ACTIVE'); end if;

  v_doc_allowed:=coalesce(v_t.requiere_doctora,false);
  v_nurse_allowed:=coalesce(v_t.requiere_enfermeria,false);
  if not v_doc_allowed and not v_nurse_allowed then
    return jsonb_build_object('ok',false,'status','ROLE_UNSPECIFIED','treatment_id',v_t.id,'treatment',v_t.nombre);
  end if;

  v_capability:=public.aos_booking_capability_for_service_v1(v_t.id);
  if v_capability is null then
    return jsonb_build_object('ok',false,'status','CAPABILITY_UNMAPPED','treatment_id',v_t.id,'treatment',v_t.nombre);
  end if;
  v_procedure:=public.aos_booking_procedure_for_service_v1(v_t.id);
  if v_procedure is null then
    return jsonb_build_object('ok',false,'status','PROCEDURE_UNMAPPED','treatment_id',v_t.id,'treatment',v_t.nombre,'capability',v_capability);
  end if;

  v_do_doc:=v_doc_allowed;
  v_do_nurse:=v_nurse_allowed and p_profesional_id is null;

  if v_do_doc then
    select max(fecha) into v_doc_latest
    from public.aos_horarios_personal
    where activo=true and upper(coalesce(rol,''))='DOCTORA';
    if v_doc_latest is null or v_doc_latest<p_fecha then v_do_doc:=false; end if;
  end if;
  if v_do_nurse then
    select max(fecha) into v_nurse_latest
    from public.aos_horarios_personal
    where activo=true and upper(coalesce(rol,''))='ENFERMERIA';
    if v_nurse_latest is null or v_nurse_latest<p_fecha then v_do_nurse:=false; end if;
  end if;
  if not v_do_doc and not v_do_nurse then
    return jsonb_build_object(
      'ok',false,'status','SCHEDULE_SOURCE_STALE','capability',v_capability,'procedure',v_procedure,
      'schedule_sources',jsonb_build_object('DOCTORA',v_doc_latest,'ENFERMERIA',v_nurse_latest)
    );
  end if;

  if v_do_doc then
    v_step:=interval '30 minutes';
    for v_p in
      select p.*
      from public.aos_perfiles_profesional p
      where coalesce(p.visible,true)=true
        and upper(coalesce(p.tipo,''))='DOCTORA'
        and (p_profesional_id is null or p.id::text=p_profesional_id)
        and public.aos_professional_can_service_v1(p.id::text,v_t.id)
        and exists (
          select 1 from public.aos_horarios_personal h
          where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
            and upper(coalesce(h.rol,''))='DOCTORA'
            and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        )
      order by p.orden nulls last,p.nombre_publico
    loop
      v_providers:=v_providers||jsonb_build_array(jsonb_build_object(
        'id',v_p.id,'name',v_p.nombre_publico,'role','DOCTORA','capability',v_capability,
        'procedure_key',v_procedure->>'procedure_key','procedure_name',v_procedure->>'procedure_name'
      ));
      for v_h in
        select h.* from public.aos_horarios_personal h
        where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
          and upper(coalesce(h.rol,''))='DOCTORA'
          and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
      loop
        v_time:=v_h.hora_inicio::time;
        while v_time+v_step<=v_h.hora_fin::time loop
          select count(*) into v_occupied
          from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha
            and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.doctora,'')) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          if v_occupied<1 then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'libres',1-v_occupied,'capacidad',1,'professional_id',v_p.id,
              'professional_name',v_p.nombre_publico,'role','DOCTORA','mode','EXACT_PROVIDER',
              'procedure_key',v_procedure->>'procedure_key','procedure_name',v_procedure->>'procedure_name'
            ));
          end if;
          v_time:=v_time+v_step;
        end loop;
      end loop;
    end loop;
  end if;

  if v_do_nurse then
    v_step:=interval '45 minutes';
    select min(h.hora_inicio::time),max(h.hora_fin::time)
      into v_min_start,v_max_end
    from public.aos_perfiles_profesional p
    join public.aos_horarios_personal h
      on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
     and upper(coalesce(h.rol,''))='ENFERMERIA'
     and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
    where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
      and public.aos_professional_can_service_v1(p.id::text,v_t.id);

    select coalesce(jsonb_agg(distinct jsonb_build_object(
      'id',p.id,'name',p.nombre_publico,'role','ENFERMERIA','capability',v_capability,
      'procedure_key',v_procedure->>'procedure_key','procedure_name',v_procedure->>'procedure_name'
    )),'[]'::jsonb)
      into v_np
    from public.aos_perfiles_profesional p
    join public.aos_horarios_personal h
      on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
     and upper(coalesce(h.rol,''))='ENFERMERIA'
     and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
    where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
      and public.aos_professional_can_service_v1(p.id::text,v_t.id);
    v_providers:=v_providers||v_np;

    if v_min_start is not null and v_max_end is not null then
      v_time:=v_min_start;
      while v_time+v_step<=v_max_end loop
        select count(distinct p.id),coalesce(jsonb_agg(distinct p.nombre_publico),'[]'::jsonb)
          into v_members,v_names
        from public.aos_perfiles_profesional p
        join public.aos_horarios_personal h
          on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
         and upper(coalesce(h.rol,''))='ENFERMERIA'
         and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        where coalesce(p.visible,true)=true and upper(coalesce(p.tipo,''))='ENFERMERIA'
          and public.aos_professional_can_service_v1(p.id::text,v_t.id)
          and v_time>=h.hora_inicio::time
          and v_time+v_step<=h.hora_fin::time;
        if coalesce(v_members,0)>0 then
          v_capacity:=v_members*2;
          select count(*) into v_occupied
          from public.aos_agenda_citas a
          where a.fecha_cita=p_fecha
            and upper(coalesce(a.sede,''))=v_site
            and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(v_time,'HH24:MI')
            and upper(coalesce(a.tipo_atencion,''))='ENFERMERIA'
            and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO');
          if v_occupied<v_capacity then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'libres',v_capacity-v_occupied,'capacidad',v_capacity,
              'member_count',v_members,'member_names',v_names,
              'professional_id',null,'professional_name','Enfermería',
              'role','ENFERMERIA','mode','SITE_POOL',
              'procedure_key',v_procedure->>'procedure_key','procedure_name',v_procedure->>'procedure_name'
            ));
          end if;
        end if;
        v_time:=v_time+v_step;
      end loop;
    end if;
  end if;

  if v_doc_allowed and v_nurse_allowed and p_profesional_id is null then
    v_role_out:='MULTI_ROLE';v_mode_out:='MULTI_ROLE';
  elsif v_do_doc then
    v_role_out:='DOCTORA';v_mode_out:='EXACT_PROVIDER';
  else
    v_role_out:='ENFERMERIA';v_mode_out:='SITE_POOL';
  end if;

  return jsonb_build_object(
    'ok',true,
    'status',case when jsonb_array_length(v_slots)>0 then 'REAL_SLOTS_READY' else 'NO_REAL_SLOTS' end,
    'treatment_id',v_t.id,'treatment',v_t.nombre,'capability',v_capability,'procedure',v_procedure,
    'role',v_role_out,'mode',v_mode_out,
    'eligible_roles',case when v_doc_allowed and v_nurse_allowed then '["DOCTORA","ENFERMERIA"]'::jsonb when v_doc_allowed then '["DOCTORA"]'::jsonb else '["ENFERMERIA"]'::jsonb end,
    'fecha',p_fecha,'sede',v_site,
    'schedule_source_max_date',greatest(v_doc_latest,v_nurse_latest),
    'schedule_sources',jsonb_build_object('DOCTORA',v_doc_latest,'ENFERMERIA',v_nurse_latest),
    'eligible_professionals',v_providers,'slots',v_slots
  );
end
$$;

create or replace function public.aos_team_skill_hierarchy_audit_v1()
returns jsonb
language sql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
with active_services as (
  select s.id,s.nombre,
         public.aos_booking_capability_for_service_v1(s.id) capability,
         public.aos_booking_procedure_for_service_v1(s.id) procedure
  from public.aos_catalogo_servicios s
  where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
), scope_bad as (
  select sc.*
  from public.aos_professional_procedure_scope_v1 sc
  where not exists (
    select 1 from public.aos_booking_procedure_map_v1 m
    where m.active=true
      and public.aos_booking_norm_v1(m.capability)=public.aos_booking_norm_v1(sc.capability)
      and m.procedure_key=sc.procedure_key
  )
)
select jsonb_build_object(
  'active_services',(select count(*) from active_services),
  'capability_mapped',(select count(*) from active_services where capability is not null),
  'procedure_mapped',(select count(*) from active_services where procedure is not null),
  'procedure_unmapped_names',coalesce((select jsonb_agg(nombre order by nombre) from active_services where procedure is null),'[]'::jsonb),
  'distinct_procedures',(select count(distinct procedure->>'procedure_key') from active_services where procedure is not null),
  'explicit_scope_rows',(select count(*) from public.aos_professional_procedure_scope_v1),
  'invalid_scope_rows',(select count(*) from scope_bad),
  'profile_user_service_drift',(
    select count(*)
    from public.aos_perfiles_profesional p
    join public.aos_usuarios u on u.codigo_asesor=p.codigo_asesor and u.activo is distinct from false
    where p.servicios is distinct from u.servicios
  )
)
$$;

revoke all on function public.aos_booking_procedure_for_service_v1(uuid) from public;
grant execute on function public.aos_booking_procedure_for_service_v1(uuid) to anon,authenticated,service_role;
revoke all on function public.aos_professional_can_service_v1(text,uuid) from public;
grant execute on function public.aos_professional_can_service_v1(text,uuid) to anon,authenticated,service_role;
revoke all on function public.aos_team_skill_hierarchy_v1(text) from public;
grant execute on function public.aos_team_skill_hierarchy_v1(text) to anon,authenticated,service_role;
revoke all on function public.aos_team_save_skill_hierarchy_v1(uuid,text[],jsonb,text) from public;
grant execute on function public.aos_team_save_skill_hierarchy_v1(uuid,text[],jsonb,text) to anon,authenticated,service_role;
revoke all on function public.aos_team_skill_hierarchy_audit_v1() from public;
grant execute on function public.aos_team_skill_hierarchy_audit_v1() to authenticated,service_role;

do $$
declare v_bad int;
begin
  select count(*) into v_bad
  from public.aos_catalogo_servicios s
  where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
    and (
      public.aos_booking_capability_for_service_v1(s.id) is null
      or public.aos_booking_procedure_for_service_v1(s.id) is null
    );
  if v_bad<>0 then raise exception 'WA4C_SKILL_HIERARCHY_UNMAPPED_ACTIVE_SERVICES:%',v_bad; end if;
end
$$;

comment on table public.aos_professional_procedure_scope_v1 is
'Optional child-procedure overrides. No rows for a professional+skill means parent skill inherits all current child procedures. Any rows mean explicit allow/deny scope.';
comment on function public.aos_professional_can_service_v1(text,uuid) is
'WA-4C hierarchy authority: service -> procedure -> parent skill -> professional explicit/inherited scope.';
comment on function public.aos_team_skill_hierarchy_v1(text) is
'Admin Equipo hierarchy surface: category -> parent skill -> procedures, role-filtered and backward compatible.';
comment on function public.aos_booking_availability_v2(uuid,date,text,text) is
'WA-4C availability using category/catalog role + procedure + skill + professional + schedule + capacity. HUMAN_ONLY booking boundary unchanged.';

commit;
