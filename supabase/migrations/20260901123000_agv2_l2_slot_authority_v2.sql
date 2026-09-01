-- ASCENDA OS · WA-AUTO L2 — Agenda Slot Authority V2
-- Additive/dormant. Does not replace live aos_booking_availability_v2.
-- Business authority revalidated by owner on 2026-09-01:
-- - commercial booking grid = 30 minutes
-- - normal capacity = 5 reservations per site/slot
-- - governed overflow = 6 reservations per site/slot
-- - clinical execution duration is independent from later commercial slots
-- - consultation is separate from application/execution duration
-- - anesthesia/prep reference ~= 30 min but must be explicitly mapped before it becomes required
-- - hard resource constraints are opt-in only; unknown resource rules fail closed

begin;

create table if not exists public.aos_booking_operating_defaults_v2 (
  id smallint primary key check (id=1),
  commercial_step_min integer not null check (commercial_step_min=30),
  anesthesia_reference_min integer not null check (anesthesia_reference_min between 0 and 180),
  consultation_is_separate boolean not null default true,
  duration_blocks_future_booking_default boolean not null default false,
  source text not null,
  updated_at timestamptz not null default now()
);

insert into public.aos_booking_operating_defaults_v2(
  id,commercial_step_min,anesthesia_reference_min,consultation_is_separate,
  duration_blocks_future_booking_default,source,updated_at
) values (1,30,30,true,false,'OWNER_REVALIDATED_2026-09-01',now())
on conflict(id) do update set
  commercial_step_min=excluded.commercial_step_min,
  anesthesia_reference_min=excluded.anesthesia_reference_min,
  consultation_is_separate=excluded.consultation_is_separate,
  duration_blocks_future_booking_default=excluded.duration_blocks_future_booking_default,
  source=excluded.source,
  updated_at=now();

create table if not exists public.aos_booking_commercial_capacity_policy_v2 (
  site text primary key check (site in ('SAN ISIDRO','PUEBLO LIBRE')),
  commercial_step_min integer not null default 30 check (commercial_step_min=30),
  soft_capacity integer not null check (soft_capacity>=1),
  overflow_capacity integer not null check (overflow_capacity>=soft_capacity),
  autonomous_overflow_enabled boolean not null default false,
  active boolean not null default true,
  source text not null,
  updated_at timestamptz not null default now()
);

insert into public.aos_booking_commercial_capacity_policy_v2(
  site,commercial_step_min,soft_capacity,overflow_capacity,autonomous_overflow_enabled,active,source,updated_at
) values
  ('SAN ISIDRO',30,5,6,false,true,'OWNER_REVALIDATED_2026-09-01',now()),
  ('PUEBLO LIBRE',30,5,6,false,true,'OWNER_REVALIDATED_2026-09-01',now())
on conflict(site) do update set
  commercial_step_min=excluded.commercial_step_min,
  soft_capacity=excluded.soft_capacity,
  overflow_capacity=excluded.overflow_capacity,
  autonomous_overflow_enabled=excluded.autonomous_overflow_enabled,
  active=excluded.active,
  source=excluded.source,
  updated_at=now();

create table if not exists public.aos_booking_family_duration_policy_v2 (
  capability text primary key,
  execution_min integer,
  execution_max integer,
  execution_default integer,
  prep_default_min integer not null default 0,
  prep_rule text not null default 'EXPLICIT_ONLY' check (prep_rule in ('NONE','EXPLICIT_ONLY','REQUIRED')),
  duration_blocks_future_booking boolean not null default false,
  hard_resource_constraint boolean not null default false,
  policy_status text not null check (policy_status in ('ACTIVE','NEEDS_REVIEW')),
  evidence_ref text not null,
  note text,
  updated_at timestamptz not null default now(),
  check (execution_min is null or execution_min>0),
  check (execution_max is null or execution_max>=execution_min),
  check (execution_default is null or (execution_default>=execution_min and execution_default<=execution_max))
);

create table if not exists public.aos_booking_procedure_duration_override_v2 (
  procedure_key text primary key,
  capability text not null,
  procedure_name text not null,
  execution_min integer,
  execution_max integer,
  execution_default integer,
  prep_default_min integer not null default 0,
  prep_rule text not null default 'EXPLICIT_ONLY' check (prep_rule in ('NONE','EXPLICIT_ONLY','REQUIRED')),
  duration_blocks_future_booking boolean not null default false,
  hard_resource_constraint boolean not null default false,
  policy_status text not null check (policy_status in ('ACTIVE','NEEDS_REVIEW')),
  evidence_ref text not null,
  note text,
  updated_at timestamptz not null default now(),
  check (execution_min is null or execution_min>0),
  check (execution_max is null or execution_max>=execution_min),
  check (execution_default is null or (execution_default>=execution_min and execution_default<=execution_max))
);

-- Family defaults. Heterogeneous or not-yet-confirmed families intentionally remain NEEDS_REVIEW.
insert into public.aos_booking_family_duration_policy_v2(
  capability,execution_min,execution_max,execution_default,prep_default_min,prep_rule,
  duration_blocks_future_booking,hard_resource_constraint,policy_status,evidence_ref,note,updated_at
) values
  ('CONSULTA MEDICA',20,30,30,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Consultation duration; consultation remains separate from application execution.',now()),
  ('TOXINA',15,30,30,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Application only.',now()),
  ('ACIDO HIALURONICO',60,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Application only.',now()),
  ('BIOESTIMULADOR',60,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Application only.',now()),
  ('HIFU',45,60,60,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Frozen/HIFU family.',now()),
  ('HIDROFACIAL',60,60,60,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('CRIOLIPOLISIS',90,90,90,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('ENZIMAS CORPORALES',45,45,45,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('ENZIMAS FACIALES',45,45,45,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('GLUTEOS',90,90,90,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','AH / bioestimulador gluteal.',now()),
  ('PRP CAPILAR',45,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('CAPILAR',30,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Other capillary procedures.',now()),
  ('MESOTERAPIA CAPILAR',30,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('RADIOFRECUENCIA FRACCIONADA',45,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('CARBOXITERAPIA',45,60,60,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('DETOX',25,40,40,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('EXOSOMAS',60,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('EXOSOMAS CAPILARES',60,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('BIOREVITALIZACION FACIAL',45,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','30-minute products are explicit procedure overrides.',now()),
  ('FACIALES',null,null,null,0,'NONE',false,false,'NEEDS_REVIEW','OWNER_REVALIDATED_2026-09-01','Heterogeneous family; known procedures use explicit overrides. Unknown facial procedures fail closed.',now()),
  ('HIDROENZIMAS',45,45,45,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('MESOTERAPIA CORPORAL',45,45,45,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('MESOTERAPIA FACIAL',60,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('MICRONEEDLING FACIAL',60,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Microneedling con plasma.',now()),
  ('NANO GLOW',45,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('PEELINGS',30,30,30,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','ZK.',now()),
  ('PEPTONAS',30,45,45,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Peptoplus.',now()),
  ('PINK INTIMATE',45,60,60,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('PQ AGE',30,45,45,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('VITAMINAS',45,60,60,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','B12, Combo Reset, hepatoprotector, IV protocols and supplements.',now()),
  ('APARATOLOGIA CORPORAL',null,null,null,0,'NONE',false,false,'NEEDS_REVIEW','OWNER_REVALIDATED_2026-09-01','Exact execution duration not explicitly confirmed; autonomous availability must fail closed.',now())
on conflict(capability) do update set
  execution_min=excluded.execution_min,
  execution_max=excluded.execution_max,
  execution_default=excluded.execution_default,
  prep_default_min=excluded.prep_default_min,
  prep_rule=excluded.prep_rule,
  duration_blocks_future_booking=excluded.duration_blocks_future_booking,
  hard_resource_constraint=excluded.hard_resource_constraint,
  policy_status=excluded.policy_status,
  evidence_ref=excluded.evidence_ref,
  note=excluded.note,
  updated_at=now();

-- Procedure overrides for heterogeneous families and owner-specific values.
insert into public.aos_booking_procedure_duration_override_v2(
  procedure_key,capability,procedure_name,execution_min,execution_max,execution_default,
  prep_default_min,prep_rule,duration_blocks_future_booking,hard_resource_constraint,
  policy_status,evidence_ref,note,updated_at
) values
  ('ACIDO SUCCINICO AMBER','BIOREVITALIZACION FACIAL','ACIDO SUCCINICO AMBER',30,30,30,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('ACIDO TRANEXAMICO','BIOREVITALIZACION FACIAL','ACIDO TRANEXAMICO',30,30,30,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('CELLBOOSTER GLOW','BIOREVITALIZACION FACIAL','CELLBOOSTER GLOW',30,30,30,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('CELLBOOSTER LIFT','BIOREVITALIZACION FACIAL','CELLBOOSTER LIFT',30,30,30,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('CELLBOOSTER SHAPE','ENZIMAS CORPORALES','CELLBOOSTER SHAPE',30,30,30,0,'EXPLICIT_ONLY',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01','Specific Cellbooster timing overrides generic enzymes.',now()),
  ('FACIAL COREANO','FACIALES','FACIAL COREANO',90,120,120,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('FACIAL CELULAS MADRE','FACIALES','FACIAL CELULAS MADRE',20,30,30,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('FACIAL DIAMANTE','FACIALES','FACIAL DIAMANTE',60,60,60,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('HIDROVITAL PASCOE','FACIALES','HIDROVITAL PASCOE',60,60,60,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('MASCARILLA ESTHEMAX','FACIALES','MASCARILLA ESTHEMAX',15,20,20,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('MASCARILLA Q10','FACIALES','MASCARILLA Q10',15,20,20,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now()),
  ('SKIN PREP','FACIALES','SKIN PREP',15,20,20,0,'NONE',false,false,'ACTIVE','OWNER_REVALIDATED_2026-09-01',null,now())
on conflict(procedure_key) do update set
  capability=excluded.capability,
  procedure_name=excluded.procedure_name,
  execution_min=excluded.execution_min,
  execution_max=excluded.execution_max,
  execution_default=excluded.execution_default,
  prep_default_min=excluded.prep_default_min,
  prep_rule=excluded.prep_rule,
  duration_blocks_future_booking=excluded.duration_blocks_future_booking,
  hard_resource_constraint=excluded.hard_resource_constraint,
  policy_status=excluded.policy_status,
  evidence_ref=excluded.evidence_ref,
  note=excluded.note,
  updated_at=now();

alter table public.aos_booking_operating_defaults_v2 enable row level security;
alter table public.aos_booking_commercial_capacity_policy_v2 enable row level security;
alter table public.aos_booking_family_duration_policy_v2 enable row level security;
alter table public.aos_booking_procedure_duration_override_v2 enable row level security;

revoke all on table public.aos_booking_operating_defaults_v2 from public,anon,authenticated;
revoke all on table public.aos_booking_commercial_capacity_policy_v2 from public,anon,authenticated;
revoke all on table public.aos_booking_family_duration_policy_v2 from public,anon,authenticated;
revoke all on table public.aos_booking_procedure_duration_override_v2 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_booking_operating_defaults_v2 to service_role;
grant select,insert,update,delete on table public.aos_booking_commercial_capacity_policy_v2 to service_role;
grant select,insert,update,delete on table public.aos_booking_family_duration_policy_v2 to service_role;
grant select,insert,update,delete on table public.aos_booking_procedure_duration_override_v2 to service_role;

create or replace function public.aos_booking_slot_policy_for_service_v2(
  p_treatment_id uuid,
  p_site text
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_service public.aos_catalogo_servicios%rowtype;
  v_proc jsonb;
  v_cap text;
  v_key text;
  v_name text;
  v_site text;
  v_override public.aos_booking_procedure_duration_override_v2%rowtype;
  v_family public.aos_booking_family_duration_policy_v2%rowtype;
  v_capacity public.aos_booking_commercial_capacity_policy_v2%rowtype;
  v_defaults public.aos_booking_operating_defaults_v2%rowtype;
  v_source text;
  v_min int;
  v_max int;
  v_default int;
  v_prep int;
  v_prep_rule text;
  v_blocks boolean;
  v_hard boolean;
  v_status text;
  v_evidence text;
  v_note text;
begin
  v_site:=upper(replace(btrim(coalesce(p_site,'')),'_',' '));
  if v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','L2_SITE_INVALID');
  end if;

  select * into v_service
  from public.aos_catalogo_servicios
  where id=p_treatment_id
    and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'status','L2_TREATMENT_NOT_ACTIVE'); end if;

  v_proc:=public.aos_booking_procedure_for_service_v1(p_treatment_id);
  if v_proc is null then return jsonb_build_object('ok',false,'status','L2_PROCEDURE_UNMAPPED','treatment',v_service.nombre); end if;
  v_cap:=v_proc->>'capability';
  v_key:=v_proc->>'procedure_key';
  v_name:=v_proc->>'procedure_name';

  select * into v_override
  from public.aos_booking_procedure_duration_override_v2
  where procedure_key=v_key
  limit 1;

  if found then
    v_source:='PROCEDURE_OVERRIDE';
    v_min:=v_override.execution_min; v_max:=v_override.execution_max; v_default:=v_override.execution_default;
    v_prep:=v_override.prep_default_min; v_prep_rule:=v_override.prep_rule;
    v_blocks:=v_override.duration_blocks_future_booking; v_hard:=v_override.hard_resource_constraint;
    v_status:=v_override.policy_status; v_evidence:=v_override.evidence_ref; v_note:=v_override.note;
  else
    select * into v_family
    from public.aos_booking_family_duration_policy_v2
    where public.aos_booking_norm_v1(capability)=public.aos_booking_norm_v1(v_cap)
    limit 1;
    if not found then
      return jsonb_build_object('ok',false,'status','L2_DURATION_POLICY_UNMAPPED','capability',v_cap,'procedure_key',v_key,'procedure_name',v_name);
    end if;
    v_source:='FAMILY_DEFAULT';
    v_min:=v_family.execution_min; v_max:=v_family.execution_max; v_default:=v_family.execution_default;
    v_prep:=v_family.prep_default_min; v_prep_rule:=v_family.prep_rule;
    v_blocks:=v_family.duration_blocks_future_booking; v_hard:=v_family.hard_resource_constraint;
    v_status:=v_family.policy_status; v_evidence:=v_family.evidence_ref; v_note:=v_family.note;
  end if;

  if v_status<>'ACTIVE' or v_min is null or v_max is null or v_default is null then
    return jsonb_build_object(
      'ok',false,'status','L2_DURATION_POLICY_NEEDS_REVIEW','treatment_id',v_service.id,'treatment',v_service.nombre,
      'capability',v_cap,'procedure_key',v_key,'procedure_name',v_name,'policy_source',v_source,
      'evidence_ref',v_evidence,'note',v_note
    );
  end if;

  select * into v_capacity
  from public.aos_booking_commercial_capacity_policy_v2
  where site=v_site and active=true;
  if not found then return jsonb_build_object('ok',false,'status','L2_CAPACITY_POLICY_UNMAPPED','site',v_site); end if;

  select * into v_defaults from public.aos_booking_operating_defaults_v2 where id=1;
  if not found then return jsonb_build_object('ok',false,'status','L2_OPERATING_DEFAULTS_MISSING'); end if;

  if v_hard then
    return jsonb_build_object(
      'ok',false,'status','L2_HARD_RESOURCE_MAP_REQUIRED','treatment_id',v_service.id,'treatment',v_service.nombre,
      'capability',v_cap,'procedure_key',v_key,'procedure_name',v_name,'requires_human',true
    );
  end if;

  return jsonb_build_object(
    'ok',true,'status','L2_POLICY_READY',
    'treatment_id',v_service.id,'treatment',v_service.nombre,
    'capability',v_cap,'procedure_key',v_key,'procedure_name',v_name,
    'policy_source',v_source,'evidence_ref',v_evidence,'note',v_note,
    'execution_min',v_min,'execution_max',v_max,'execution_default',v_default,
    'prep_default_min',v_prep,'prep_rule',v_prep_rule,
    'anesthesia_reference_min',v_defaults.anesthesia_reference_min,
    'consultation_is_separate',v_defaults.consultation_is_separate,
    'duration_blocks_future_booking',v_blocks,
    'hard_resource_constraint',v_hard,
    'commercial_step_min',v_capacity.commercial_step_min,
    'soft_capacity',v_capacity.soft_capacity,
    'overflow_capacity',v_capacity.overflow_capacity,
    'autonomous_overflow_enabled',v_capacity.autonomous_overflow_enabled,
    'site',v_site
  );
end
$$;

create or replace function public.aos_booking_capacity_status_v2(
  p_date date,
  p_site text,
  p_time time,
  p_allow_overflow boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_site text;
  v_policy public.aos_booking_commercial_capacity_policy_v2%rowtype;
  v_occupied int;
  v_limit int;
  v_available boolean;
begin
  v_site:=upper(replace(btrim(coalesce(p_site,'')),'_',' '));
  if p_date is null or p_time is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','L2_CAPACITY_INPUT_INVALID');
  end if;
  if extract(minute from p_time)::int not in (0,30) or extract(second from p_time)<>0 then
    return jsonb_build_object('ok',false,'status','L2_NOT_ON_30_MIN_GRID','time',to_char(p_time,'HH24:MI:SS'));
  end if;

  select * into v_policy
  from public.aos_booking_commercial_capacity_policy_v2
  where site=v_site and active=true;
  if not found then return jsonb_build_object('ok',false,'status','L2_CAPACITY_POLICY_UNMAPPED','site',v_site); end if;

  select count(*) into v_occupied
  from public.aos_agenda_citas a
  where a.fecha_cita=p_date
    and upper(replace(btrim(coalesce(a.sede,'')),'_',' '))=v_site
    and substring(coalesce(a.hora_cita,'') from 1 for 5)=to_char(p_time,'HH24:MI')
    and upper(coalesce(a.estado_cita,'')) not in ('CANCELADA','CANCELADO','ANULADA','ANULADO');

  v_limit:=case when p_allow_overflow then v_policy.overflow_capacity else v_policy.soft_capacity end;
  v_available:=v_occupied<v_limit;

  return jsonb_build_object(
    'ok',true,'status',case when v_available then 'L2_CAPACITY_AVAILABLE' else 'L2_CAPACITY_FULL' end,
    'site',v_site,'date',p_date,'time',to_char(p_time,'HH24:MI'),
    'occupied',v_occupied,
    'soft_capacity',v_policy.soft_capacity,
    'overflow_capacity',v_policy.overflow_capacity,
    'soft_remaining',greatest(v_policy.soft_capacity-v_occupied,0),
    'overflow_remaining',greatest(v_policy.overflow_capacity-v_occupied,0),
    'allow_overflow',p_allow_overflow,
    'autonomous_overflow_enabled',v_policy.autonomous_overflow_enabled,
    'capacity_limit',v_limit,
    'available',v_available
  );
end
$$;

-- New dormant availability authority. The existing v2 live/public authority remains untouched.
create or replace function public.aos_booking_availability_v3(
  p_treatment_id uuid,
  p_fecha date,
  p_sede text,
  p_profesional_id text default null,
  p_allow_overflow boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_t public.aos_catalogo_servicios%rowtype;
  v_policy jsonb;
  v_site text;
  v_doc_allowed boolean;
  v_nurse_allowed boolean;
  v_do_doc boolean;
  v_do_nurse boolean;
  v_doc_latest date;
  v_nurse_latest date;
  v_slots jsonb:='[]'::jsonb;
  v_providers jsonb:='[]'::jsonb;
  v_p record;
  v_h record;
  v_time time;
  v_cap jsonb;
  v_members int;
  v_names jsonb;
  v_role_out text;
  v_mode_out text;
begin
  v_site:=upper(replace(btrim(coalesce(p_sede,'')),'_',' '));
  if p_fecha is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'status','L2_INVALID_DATE_OR_SITE');
  end if;
  if extract(isodow from p_fecha)=7 then return jsonb_build_object('ok',false,'status','L2_SUNDAY_CLOSED'); end if;

  select * into v_t
  from public.aos_catalogo_servicios
  where id=p_treatment_id
    and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'status','L2_TREATMENT_NOT_ACTIVE'); end if;

  v_policy:=public.aos_booking_slot_policy_for_service_v2(v_t.id,v_site);
  if coalesce((v_policy->>'ok')::boolean,false) is not true then return v_policy; end if;
  if coalesce((v_policy->>'hard_resource_constraint')::boolean,false) then
    return jsonb_build_object('ok',false,'status','L2_HARD_RESOURCE_MAP_REQUIRED','requires_human',true,'policy',v_policy);
  end if;

  v_doc_allowed:=coalesce(v_t.requiere_doctora,false);
  v_nurse_allowed:=coalesce(v_t.requiere_enfermeria,false);
  if not v_doc_allowed and not v_nurse_allowed then
    return jsonb_build_object('ok',false,'status','L2_ROLE_UNSPECIFIED','treatment_id',v_t.id,'treatment',v_t.nombre);
  end if;

  v_do_doc:=v_doc_allowed;
  v_do_nurse:=v_nurse_allowed and p_profesional_id is null;

  if v_do_doc then
    select max(fecha) into v_doc_latest from public.aos_horarios_personal where activo=true and upper(coalesce(rol,''))='DOCTORA';
    if v_doc_latest is null or v_doc_latest<p_fecha then v_do_doc:=false; end if;
  end if;
  if v_do_nurse then
    select max(fecha) into v_nurse_latest from public.aos_horarios_personal where activo=true and upper(coalesce(rol,''))='ENFERMERIA';
    if v_nurse_latest is null or v_nurse_latest<p_fecha then v_do_nurse:=false; end if;
  end if;
  if not v_do_doc and not v_do_nurse then
    return jsonb_build_object('ok',false,'status','L2_SCHEDULE_SOURCE_STALE','schedule_sources',jsonb_build_object('DOCTORA',v_doc_latest,'ENFERMERIA',v_nurse_latest),'policy',v_policy);
  end if;

  if v_do_doc then
    for v_p in
      select p.*
      from public.aos_perfiles_profesional p
      where coalesce(p.visible,true)=true
        and upper(coalesce(p.tipo,''))='DOCTORA'
        and (p_profesional_id is null or p.id::text=p_profesional_id)
        and public.aos_professional_can_service_v1(p.id::text,v_t.id)
        and exists(
          select 1 from public.aos_horarios_personal h
          where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
            and upper(coalesce(h.rol,''))='DOCTORA'
            and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
        )
      order by p.orden nulls last,p.nombre_publico
    loop
      v_providers:=v_providers||jsonb_build_array(jsonb_build_object('id',v_p.id,'name',v_p.nombre_publico,'role','DOCTORA'));
      for v_h in
        select h.* from public.aos_horarios_personal h
        where h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
          and upper(coalesce(h.rol,''))='DOCTORA'
          and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(v_p.nombre_publico)||'%'
      loop
        v_time:=date_trunc('hour',v_h.hora_inicio::time)::time;
        if v_time<v_h.hora_inicio::time then v_time:=v_time+interval '30 minutes'; end if;
        if extract(minute from v_h.hora_inicio::time)>=1 and extract(minute from v_h.hora_inicio::time)<=30 then
          v_time:=date_trunc('hour',v_h.hora_inicio::time)::time+interval '30 minutes';
        elsif extract(minute from v_h.hora_inicio::time)>30 then
          v_time:=date_trunc('hour',v_h.hora_inicio::time)::time+interval '1 hour';
        end if;
        while v_time+interval '30 minutes'<=v_h.hora_fin::time loop
          v_cap:=public.aos_booking_capacity_status_v2(p_fecha,v_site,v_time,p_allow_overflow);
          if coalesce((v_cap->>'available')::boolean,false) then
            v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
              'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
              'role','DOCTORA','mode','EXACT_PROVIDER','professional_id',v_p.id,'professional_name',v_p.nombre_publico,
              'occupied',(v_cap->>'occupied')::int,'soft_capacity',(v_cap->>'soft_capacity')::int,
              'overflow_capacity',(v_cap->>'overflow_capacity')::int,'soft_remaining',(v_cap->>'soft_remaining')::int,
              'overflow_remaining',(v_cap->>'overflow_remaining')::int,'allow_overflow',p_allow_overflow,
              'execution_min',(v_policy->>'execution_min')::int,'execution_max',(v_policy->>'execution_max')::int,
              'execution_default',(v_policy->>'execution_default')::int,'duration_blocks_future_booking',false,
              'procedure_key',v_policy->>'procedure_key','procedure_name',v_policy->>'procedure_name'
            ));
          end if;
          v_time:=v_time+interval '30 minutes';
        end loop;
      end loop;
    end loop;
  end if;

  if v_do_nurse then
    v_time:=time '00:00';
    while v_time<time '23:59' loop
      select count(distinct p.id),coalesce(jsonb_agg(distinct p.nombre_publico),'[]'::jsonb)
        into v_members,v_names
      from public.aos_perfiles_profesional p
      join public.aos_horarios_personal h
        on h.activo=true and h.fecha=p_fecha and upper(h.sede)=v_site
       and upper(coalesce(h.rol,''))='ENFERMERIA'
       and public.aos_booking_norm_v1(h.personal) like '%'||public.aos_booking_profile_key_v1(p.nombre_publico)||'%'
      where coalesce(p.visible,true)=true
        and upper(coalesce(p.tipo,''))='ENFERMERIA'
        and public.aos_professional_can_service_v1(p.id::text,v_t.id)
        and v_time>=h.hora_inicio::time
        and v_time+interval '30 minutes'<=h.hora_fin::time;
      if coalesce(v_members,0)>0 then
        v_cap:=public.aos_booking_capacity_status_v2(p_fecha,v_site,v_time,p_allow_overflow);
        if coalesce((v_cap->>'available')::boolean,false) then
          v_slots:=v_slots||jsonb_build_array(jsonb_build_object(
            'hora',to_char(v_time,'HH24:MI'),'sede',v_site,'disponible',true,
            'role','ENFERMERIA','mode','SITE_POOL','professional_id',null,'professional_name','Enfermería',
            'member_count',v_members,'member_names',v_names,
            'occupied',(v_cap->>'occupied')::int,'soft_capacity',(v_cap->>'soft_capacity')::int,
            'overflow_capacity',(v_cap->>'overflow_capacity')::int,'soft_remaining',(v_cap->>'soft_remaining')::int,
            'overflow_remaining',(v_cap->>'overflow_remaining')::int,'allow_overflow',p_allow_overflow,
            'execution_min',(v_policy->>'execution_min')::int,'execution_max',(v_policy->>'execution_max')::int,
            'execution_default',(v_policy->>'execution_default')::int,'duration_blocks_future_booking',false,
            'procedure_key',v_policy->>'procedure_key','procedure_name',v_policy->>'procedure_name'
          ));
        end if;
      end if;
      v_time:=v_time+interval '30 minutes';
    end loop;
  end if;

  if v_doc_allowed and v_nurse_allowed and p_profesional_id is null then v_role_out:='MULTI_ROLE';v_mode_out:='MULTI_ROLE';
  elsif v_do_doc then v_role_out:='DOCTORA';v_mode_out:='EXACT_PROVIDER';
  else v_role_out:='ENFERMERIA';v_mode_out:='SITE_POOL'; end if;

  return jsonb_build_object(
    'ok',true,
    'status',case when jsonb_array_length(v_slots)>0 then 'L2_REAL_SLOTS_READY' else 'L2_NO_REAL_SLOTS' end,
    'treatment_id',v_t.id,'treatment',v_t.nombre,'fecha',p_fecha,'sede',v_site,
    'role',v_role_out,'mode',v_mode_out,'policy',v_policy,
    'schedule_sources',jsonb_build_object('DOCTORA',v_doc_latest,'ENFERMERIA',v_nurse_latest),
    'eligible_professionals',v_providers,'slots',v_slots
  );
end
$$;

revoke all on function public.aos_booking_slot_policy_for_service_v2(uuid,text) from public,anon,authenticated;
revoke all on function public.aos_booking_capacity_status_v2(date,text,time,boolean) from public,anon,authenticated;
revoke all on function public.aos_booking_availability_v3(uuid,date,text,text,boolean) from public,anon,authenticated;
grant execute on function public.aos_booking_slot_policy_for_service_v2(uuid,text) to service_role;
grant execute on function public.aos_booking_capacity_status_v2(date,text,time,boolean) to service_role;
grant execute on function public.aos_booking_availability_v3(uuid,date,text,text,boolean) to service_role;

comment on table public.aos_booking_family_duration_policy_v2 is 'WA-AUTO L2 family-level clinical execution duration authority. Execution duration does not automatically consume future commercial booking slots.';
comment on table public.aos_booking_procedure_duration_override_v2 is 'WA-AUTO L2 procedure-specific duration overrides over family defaults.';
comment on table public.aos_booking_commercial_capacity_policy_v2 is 'WA-AUTO L2 site commercial capacity: 30-minute grid, soft capacity 5, governed overflow 6 by owner revalidation 2026-09-01.';
comment on function public.aos_booking_availability_v3(uuid,date,text,text,boolean) is 'Dormant L2 availability authority using 30-minute commercial grid + site capacity + governed clinical duration metadata. Existing live v2 remains untouched.';

commit;
