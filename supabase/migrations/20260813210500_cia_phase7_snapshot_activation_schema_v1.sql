-- ASCENDA CIA Phase 7 — immutable snapshots + activation core schema.
-- Additive. No operational source tables are modified.

alter table public.aos_audiencia_versiones
  drop constraint if exists aos_audiencia_versiones_id_audiencia_uidx;

alter table public.aos_audiencia_versiones
  add constraint aos_audiencia_versiones_id_audiencia_uidx unique (id,audiencia_id);

create table if not exists public.aos_audiencia_snapshots (
  id uuid primary key default gen_random_uuid(),
  audiencia_id uuid not null references public.aos_audiencias(id) on delete restrict,
  audiencia_version_id uuid not null,
  estado text not null default 'BUILDING',
  member_count integer not null default 0,
  membership_hash text not null default '',
  filter_hash text not null,
  resolved_at timestamptz not null default now(),
  sealed_at timestamptz,
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint aos_audiencia_snapshots_version_fk
    foreign key (audiencia_version_id,audiencia_id)
    references public.aos_audiencia_versiones(id,audiencia_id) on delete restrict,
  constraint aos_audiencia_snapshots_estado_chk check (estado in ('BUILDING','READY')),
  constraint aos_audiencia_snapshots_count_chk check (member_count between 0 and 100000),
  constraint aos_audiencia_snapshots_membership_hash_chk check (
    (estado='BUILDING' and membership_hash='') or
    (estado='READY' and membership_hash ~ '^[0-9a-f]{64}$')
  ),
  constraint aos_audiencia_snapshots_filter_hash_chk check (filter_hash ~ '^[0-9a-f]{64}$'),
  constraint aos_audiencia_snapshots_seal_chk check (
    (estado='BUILDING' and sealed_at is null) or
    (estado='READY' and sealed_at is not null)
  ),
  constraint aos_audiencia_snapshots_identity_uidx unique (id,audiencia_version_id,audiencia_id)
);

create index if not exists aos_audiencia_snapshots_audience_created_idx
  on public.aos_audiencia_snapshots(audiencia_id,created_at desc);
create index if not exists aos_audiencia_snapshots_version_created_idx
  on public.aos_audiencia_snapshots(audiencia_version_id,created_at desc);

create table if not exists public.aos_audiencia_snapshot_miembros (
  snapshot_id uuid not null references public.aos_audiencia_snapshots(id) on delete restrict,
  contact_key text not null,
  identity_status text,
  identity_conflict boolean not null default false,
  resolved_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key(snapshot_id,contact_key),
  constraint aos_audiencia_snapshot_miembros_key_len_chk check (char_length(contact_key) between 3 and 128),
  constraint aos_audiencia_snapshot_miembros_identity_status_len_chk check (identity_status is null or char_length(identity_status)<=80)
);

create index if not exists aos_audiencia_snapshot_miembros_contact_idx
  on public.aos_audiencia_snapshot_miembros(contact_key,snapshot_id);

create table if not exists public.aos_audiencia_activaciones (
  id uuid primary key default gen_random_uuid(),
  audiencia_id uuid not null references public.aos_audiencias(id) on delete restrict,
  audiencia_version_id uuid not null,
  snapshot_id uuid,
  nombre text not null,
  purpose text not null,
  channel text not null,
  mode text not null,
  estado text not null default 'DRAFT',
  baseline_count integer not null default 0,
  baseline_resolved_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  updated_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz,
  constraint aos_audiencia_activaciones_version_fk
    foreign key (audiencia_version_id,audiencia_id)
    references public.aos_audiencia_versiones(id,audiencia_id) on delete restrict,
  constraint aos_audiencia_activaciones_snapshot_fk
    foreign key (snapshot_id,audiencia_version_id,audiencia_id)
    references public.aos_audiencia_snapshots(id,audiencia_version_id,audiencia_id) on delete restrict,
  constraint aos_audiencia_activaciones_nombre_chk check (char_length(btrim(nombre)) between 3 and 120),
  constraint aos_audiencia_activaciones_purpose_chk check (char_length(btrim(purpose)) between 2 and 120),
  constraint aos_audiencia_activaciones_channel_chk check (channel in ('CALL','EMAIL','SMS','WHATSAPP','AUTOMATION','ANALYSIS','OTHER')),
  constraint aos_audiencia_activaciones_mode_chk check (mode in ('BATCH','DYNAMIC')),
  constraint aos_audiencia_activaciones_estado_chk check (estado in ('DRAFT','ACTIVE','PAUSED','COMPLETED','CANCELLED')),
  constraint aos_audiencia_activaciones_baseline_count_chk check (baseline_count between 0 and 100000),
  constraint aos_audiencia_activaciones_metadata_type_chk check (jsonb_typeof(metadata)='object'),
  constraint aos_audiencia_activaciones_metadata_size_chk check (pg_column_size(metadata)<=32768),
  constraint aos_audiencia_activaciones_mode_snapshot_chk check (
    (mode='BATCH' and snapshot_id is not null) or
    (mode='DYNAMIC' and snapshot_id is null)
  ),
  constraint aos_audiencia_activaciones_timestamps_chk check (
    (estado='DRAFT' and started_at is null and ended_at is null) or
    (estado in ('ACTIVE','PAUSED') and started_at is not null and ended_at is null) or
    (estado='COMPLETED' and started_at is not null and ended_at is not null) or
    (estado='CANCELLED' and ended_at is not null)
  )
);

create index if not exists aos_audiencia_activaciones_estado_updated_idx
  on public.aos_audiencia_activaciones(estado,updated_at desc);
create index if not exists aos_audiencia_activaciones_audience_created_idx
  on public.aos_audiencia_activaciones(audiencia_id,created_at desc);

create table if not exists public.aos_audiencia_activacion_eventos (
  id bigint generated by default as identity primary key,
  activacion_id uuid not null references public.aos_audiencia_activaciones(id) on delete restrict,
  event_type text not null,
  actor_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  from_state text,
  to_state text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint aos_audiencia_activacion_eventos_type_chk check (event_type in ('CREATE','START','PAUSE','RESUME','COMPLETE','CANCEL')),
  constraint aos_audiencia_activacion_eventos_from_chk check (from_state is null or from_state in ('DRAFT','ACTIVE','PAUSED','COMPLETED','CANCELLED')),
  constraint aos_audiencia_activacion_eventos_to_chk check (to_state in ('DRAFT','ACTIVE','PAUSED','COMPLETED','CANCELLED')),
  constraint aos_audiencia_activacion_eventos_metadata_type_chk check (jsonb_typeof(metadata)='object'),
  constraint aos_audiencia_activacion_eventos_metadata_size_chk check (pg_column_size(metadata)<=16384)
);

create index if not exists aos_audiencia_activacion_eventos_activation_created_idx
  on public.aos_audiencia_activacion_eventos(activacion_id,created_at,id);

alter table public.aos_audiencia_snapshots enable row level security;
alter table public.aos_audiencia_snapshot_miembros enable row level security;
alter table public.aos_audiencia_activaciones enable row level security;
alter table public.aos_audiencia_activacion_eventos enable row level security;

revoke all on table public.aos_audiencia_snapshots from public,anon,authenticated,service_role;
revoke all on table public.aos_audiencia_snapshot_miembros from public,anon,authenticated,service_role;
revoke all on table public.aos_audiencia_activaciones from public,anon,authenticated,service_role;
revoke all on table public.aos_audiencia_activacion_eventos from public,anon,authenticated,service_role;
revoke all on sequence public.aos_audiencia_activacion_eventos_id_seq from public,anon,authenticated,service_role;

grant select on table public.aos_audiencia_snapshots to service_role;
grant select on table public.aos_audiencia_snapshot_miembros to service_role;
grant select on table public.aos_audiencia_activaciones to service_role;
grant select on table public.aos_audiencia_activacion_eventos to service_role;

create or replace function public.aos_cia_snapshot_header_guard_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  actual_count integer;
  actual_hash text;
begin
  if tg_op='DELETE' then
    raise exception using errcode='55000',message='SNAPSHOT_IMMUTABLE';
  end if;

  if tg_op='INSERT' then
    if new.estado<>'BUILDING' or new.sealed_at is not null or new.membership_hash<>'' then
      raise exception using errcode='22023',message='SNAPSHOT_MUST_START_BUILDING';
    end if;
    return new;
  end if;

  if old.estado<>'BUILDING' or new.estado<>'READY' then
    raise exception using errcode='55000',message='SNAPSHOT_IMMUTABLE';
  end if;

  if new.id is distinct from old.id
     or new.audiencia_id is distinct from old.audiencia_id
     or new.audiencia_version_id is distinct from old.audiencia_version_id
     or new.filter_hash is distinct from old.filter_hash
     or new.resolved_at is distinct from old.resolved_at
     or new.created_by_user_id is distinct from old.created_by_user_id
     or new.created_at is distinct from old.created_at then
    raise exception using errcode='55000',message='SNAPSHOT_HEADER_FIELDS_IMMUTABLE';
  end if;

  select count(*)::integer,
         encode(digest(coalesce(string_agg(m.contact_key,E'\n' order by m.contact_key),''),'sha256'),'hex')
    into actual_count,actual_hash
  from public.aos_audiencia_snapshot_miembros m
  where m.snapshot_id=old.id;

  if new.member_count<>actual_count or new.membership_hash<>actual_hash or new.sealed_at is null then
    raise exception using errcode='23514',message='SNAPSHOT_SEAL_MISMATCH';
  end if;

  return new;
end;
$$;

create or replace function public.aos_cia_snapshot_member_guard_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare st text;
begin
  if tg_op in ('UPDATE','DELETE') then
    raise exception using errcode='55000',message='SNAPSHOT_MEMBER_IMMUTABLE';
  end if;
  select estado into st from public.aos_audiencia_snapshots where id=new.snapshot_id;
  if st is distinct from 'BUILDING' then
    raise exception using errcode='55000',message='SNAPSHOT_ALREADY_SEALED';
  end if;
  return new;
end;
$$;

create or replace function public.aos_cia_activation_guard_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if tg_op='DELETE' then
    raise exception using errcode='55000',message='ACTIVATION_DELETE_FORBIDDEN';
  end if;

  if tg_op='INSERT' then
    if new.estado not in ('DRAFT','ACTIVE') then
      raise exception using errcode='22023',message='INVALID_INITIAL_ACTIVATION_STATE';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
     or new.audiencia_id is distinct from old.audiencia_id
     or new.audiencia_version_id is distinct from old.audiencia_version_id
     or new.snapshot_id is distinct from old.snapshot_id
     or new.nombre is distinct from old.nombre
     or new.purpose is distinct from old.purpose
     or new.channel is distinct from old.channel
     or new.mode is distinct from old.mode
     or new.baseline_count is distinct from old.baseline_count
     or new.baseline_resolved_at is distinct from old.baseline_resolved_at
     or new.metadata is distinct from old.metadata
     or new.created_by_user_id is distinct from old.created_by_user_id
     or new.created_at is distinct from old.created_at then
    raise exception using errcode='55000',message='ACTIVATION_DEFINITION_IMMUTABLE';
  end if;

  if old.estado=new.estado then
    raise exception using errcode='22023',message='ACTIVATION_NO_STATE_CHANGE';
  end if;

  if not (
    (old.estado='DRAFT' and new.estado in ('ACTIVE','CANCELLED')) or
    (old.estado='ACTIVE' and new.estado in ('PAUSED','COMPLETED','CANCELLED')) or
    (old.estado='PAUSED' and new.estado in ('ACTIVE','COMPLETED','CANCELLED'))
  ) then
    raise exception using errcode='22023',message='INVALID_ACTIVATION_TRANSITION';
  end if;

  if new.estado in ('ACTIVE','PAUSED','COMPLETED') and new.started_at is null then
    raise exception using errcode='23514',message='ACTIVATION_STARTED_AT_REQUIRED';
  end if;
  if new.estado in ('COMPLETED','CANCELLED') and new.ended_at is null then
    raise exception using errcode='23514',message='ACTIVATION_ENDED_AT_REQUIRED';
  end if;
  if new.estado in ('ACTIVE','PAUSED') and new.ended_at is not null then
    raise exception using errcode='23514',message='ACTIVATION_ENDED_AT_FORBIDDEN';
  end if;

  new.updated_at:=now();
  return new;
end;
$$;

create or replace function public.aos_cia_activation_event_guard_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if tg_op in ('UPDATE','DELETE') then
    raise exception using errcode='55000',message='ACTIVATION_EVENT_IMMUTABLE';
  end if;
  return new;
end;
$$;

create or replace function public.aos_cia_activation_event_emit_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare ev text;
begin
  if tg_op='INSERT' then
    ev:='CREATE';
    insert into public.aos_audiencia_activacion_eventos(activacion_id,event_type,actor_user_id,from_state,to_state,metadata)
    values(new.id,ev,new.created_by_user_id,null,new.estado,jsonb_build_object('mode',new.mode,'channel',new.channel,'context_only',true));
    return new;
  end if;

  ev:=case
    when old.estado='DRAFT' and new.estado='ACTIVE' then 'START'
    when old.estado='ACTIVE' and new.estado='PAUSED' then 'PAUSE'
    when old.estado='PAUSED' and new.estado='ACTIVE' then 'RESUME'
    when new.estado='COMPLETED' then 'COMPLETE'
    when new.estado='CANCELLED' then 'CANCEL'
    else null
  end;
  if ev is null then
    raise exception using errcode='22023',message='ACTIVATION_EVENT_UNMAPPED';
  end if;
  insert into public.aos_audiencia_activacion_eventos(activacion_id,event_type,actor_user_id,from_state,to_state,metadata)
  values(new.id,ev,new.updated_by_user_id,old.estado,new.estado,'{}'::jsonb);
  return new;
end;
$$;

revoke all on function public.aos_cia_snapshot_header_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_cia_snapshot_member_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_cia_activation_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_cia_activation_event_guard_v1() from public,anon,authenticated;
revoke all on function public.aos_cia_activation_event_emit_v1() from public,anon,authenticated;

drop trigger if exists trg_aos_cia_snapshot_header_guard_v1 on public.aos_audiencia_snapshots;
create trigger trg_aos_cia_snapshot_header_guard_v1
before insert or update or delete on public.aos_audiencia_snapshots
for each row execute function public.aos_cia_snapshot_header_guard_v1();

drop trigger if exists trg_aos_cia_snapshot_member_guard_v1 on public.aos_audiencia_snapshot_miembros;
create trigger trg_aos_cia_snapshot_member_guard_v1
before insert or update or delete on public.aos_audiencia_snapshot_miembros
for each row execute function public.aos_cia_snapshot_member_guard_v1();

drop trigger if exists trg_aos_cia_activation_guard_v1 on public.aos_audiencia_activaciones;
create trigger trg_aos_cia_activation_guard_v1
before insert or update or delete on public.aos_audiencia_activaciones
for each row execute function public.aos_cia_activation_guard_v1();

drop trigger if exists trg_aos_cia_activation_event_guard_v1 on public.aos_audiencia_activacion_eventos;
create trigger trg_aos_cia_activation_event_guard_v1
before update or delete on public.aos_audiencia_activacion_eventos
for each row execute function public.aos_cia_activation_event_guard_v1();

drop trigger if exists trg_aos_cia_activation_event_emit_v1 on public.aos_audiencia_activaciones;
create trigger trg_aos_cia_activation_event_emit_v1
after insert or update on public.aos_audiencia_activaciones
for each row execute function public.aos_cia_activation_event_emit_v1();
