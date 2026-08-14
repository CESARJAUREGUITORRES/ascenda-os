\set ON_ERROR_STOP on
create extension if not exists pgcrypto;

-- Minimal production-shaped schema required to compile and exercise K1.
create table public.aos_rrhh(
  codigo_asesor text primary key,
  nombre text, apellido text, puesto text, sueldo numeric, fecha_ingreso date,
  fecha_salida date, estado text default 'ACTIVO', meta numeric default 0,
  bonus_pct numeric default 0, sede text, label text, usuario text,
  password_hash text, numero text, tiene_agenda text default 'NO', permisos jsonb,
  foto_url text, created_at timestamptz default now(), updated_at timestamptz default now()
);

create table public.aos_usuarios(
  id uuid primary key default gen_random_uuid(), auth_id uuid, nombre text, email text,
  telefono text, rol text, sede text, activo boolean default true, permisos jsonb,
  avatar_url text, ultimo_login timestamptz, login_method text, two_factor boolean default false,
  created_at timestamptz default now(), updated_at timestamptz default now(), cargo text,
  sueldo numeric, fecha_ingreso date, dni text, telefono_personal text, direccion text,
  contacto_emergencia text, paneles_acceso text[], area text, nivel_jerarquia integer,
  invitacion_enviada boolean, cuenta_activada boolean, apellidos text, fecha_nacimiento date,
  lugar_nacimiento text, pais text, departamento text, provincia text, distrito text,
  tipo_contrato text, rh text, bono_metas numeric, codigo_asesor text, acceso_geo text,
  sedes_permitidas text[], cmp text, servicios text[]
);

create table public.aos_configuracion(
  clave text primary key, valor text, descripcion text, updated_at timestamptz default now(), updated_by text
);

create table public.aos_auth_codes(
  id uuid primary key default gen_random_uuid(), usuario text not null, email text not null,
  codigo text not null, usado boolean default false, expira_at timestamptz not null,
  created_at timestamptz default now()
);

create table public.aos_security_log(
  id uuid primary key default gen_random_uuid(), usuario text, accion text not null, ip text,
  user_agent text, detalles jsonb default '{}'::jsonb, created_at timestamptz default now()
);

create table public.aos_kronia_tokens(
  id bigserial primary key, token text not null, usuario text not null, id_asesor text,
  rol text not null, sede text, email text, device_info text, ip_origen text,
  emitido_at timestamptz not null default now(), expira_at timestamptz not null,
  ultimo_uso timestamptz not null default now(), revocado boolean not null default false,
  origen text not null default 'chrome_extension'
);

create table public.aos_kronia_acciones(
  id text primary key default gen_random_uuid()::text, usuario text not null, rol text,
  accion text not null, objeto_tipo text, objeto_id text, cambios jsonb, resultado text,
  exitoso boolean, session_id text, created_at timestamptz default now()
);

create table public.aos_kronia_conversaciones(
  id bigserial primary key, ts timestamptz default now(), usuario text default 'admin',
  rol text default 'admin', sede text, pregunta text not null, intencion text,
  tablas_usadas text[], respuesta text not null, fue_exitosa boolean default true,
  fue_redundante boolean default false, session_id text, metadata jsonb default '{}'::jsonb
);

create table public.aos_agente_logs(
  id text primary key default gen_random_uuid()::text, agente_id text not null, tarea_id text,
  accion text not null, input_resumen text default '', output_resumen text default '',
  resultado jsonb default '{}'::jsonb, motor_usado text default 'script', modelo_usado text default '',
  tokens_input integer default 0, tokens_output integer default 0, costo_usd numeric default 0,
  duracion_ms integer default 0, exitoso boolean default true, error text default '',
  created_at timestamptz default now()
);

create table public.aos_agente_acciones(
  id uuid primary key default gen_random_uuid(), agente_id text not null, tipo_accion text not null,
  descripcion text, metadata jsonb, created_at timestamptz default now()
);

create table public.aos_log_auditoria(
  id bigserial primary key, timestamp_reg timestamptz default now(), asesor text, accion text,
  referencia text, detalle text, ts timestamptz default now(), tabla text, usuario text default 'sistema',
  registro_id text, datos_new jsonb, datos_old jsonb, metadata jsonb default '{}'::jsonb
);

create table public.aos_integraciones(
  id uuid primary key default gen_random_uuid(), tipo text, nombre text, cuenta text, config jsonb,
  estado text, principal boolean, created_at timestamptz default now(), updated_at timestamptz default now(),
  categoria text, icono text, descripcion text, api_key text, api_secret text, webhook_url text,
  pasos_guia jsonb, uso_para text[], orden integer, url_api text, url_docs text, url_signup text,
  multi_cuenta boolean, logo_url text
);

alter table public.aos_integraciones enable row level security;
alter table public.aos_usuarios enable row level security;
alter table public.aos_kronia_acciones enable row level security;
alter table public.aos_kronia_conversaciones enable row level security;
create policy anon_integ_read on public.aos_integraciones for select to anon using (true);
create policy anon_integ_write on public.aos_integraciones for all to anon using (true) with check (true);
create policy anon_usuarios_all on public.aos_usuarios for all to anon using (true) with check (true);
create policy kronia_acc_all on public.aos_kronia_acciones for all to anon,authenticated using (true) with check (true);
create policy aos_kronia_conv_all on public.aos_kronia_conversaciones for all to anon,authenticated using (true) with check (true);

grant all on all tables in schema public to anon,authenticated;
grant usage,select on all sequences in schema public to anon,authenticated;

-- Production signatures used by the gateway. These stubs expose the actor/role
-- they receive so tests can prove that the gateway, not p_params, supplies them.
create or replace function public.aos_editar_venta(p_venta_id bigint,p_campos jsonb,p_editado_por text,p_rol text default 'asesor',p_origen text default 'manual') returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_editado_por,'role',p_rol,'origin',p_origen,'id',p_venta_id) $$;
create or replace function public.aos_kronia_editar_cita(p_cita_id bigint,p_campos jsonb,p_usuario text,p_rol text default 'asesor') returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_usuario,'role',p_rol) $$;
create or replace function public.aos_kronia_editar_paciente(p_paciente_id text,p_campos jsonb,p_usuario text) returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_usuario) $$;
create or replace function public.aos_kronia_reprogramar_seguimiento(p_seg_id text,p_nueva_fecha text,p_nueva_hora text,p_usuario text,p_rol text default 'asesor') returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_usuario,'role',p_rol) $$;
create or replace function public.aos_kronia_marcar_estado_cita(p_cita_id bigint,p_nuevo_estado text,p_usuario text,p_rol text default 'asesor') returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_usuario,'role',p_rol) $$;
create or replace function public.aos_kronia_agregar_nota_paciente(p_numero_paciente text,p_nota text,p_usuario text) returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_usuario) $$;
create or replace function public.aos_kronia_buscar_venta(p_filtro text,p_usuario text,p_rol text) returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_usuario,'role',p_rol) $$;
create or replace function public.aos_kronia_buscar_cita(p_filtro text,p_usuario text,p_rol text) returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'actor',p_usuario,'role',p_rol) $$;
create or replace function public.aos_kronia_buscar_paciente(p_filtro text) returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'filter',p_filtro) $$;
create or replace function public.aos_kronia_stats_leads() returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_kronia_stats_agenda() returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_kronia_stats_llamadas() returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_kronia_stats_pacientes() returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_kronia_obtener_insights_sofia() returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_kronia_explorar(p_modulo text,p_accion text,p_params jsonb) returns jsonb language sql security definer as $$ select jsonb_build_object('ok',true,'module',p_modulo) $$;
create or replace function public.aos_kronia_emitir_token(p_usuario text,p_id_asesor text default null,p_rol text default 'ASESOR',p_sede text default null,p_email text default null,p_device_info text default null,p_ip_origen text default null) returns jsonb language sql security definer as $$ select '{"ok":false}'::jsonb $$;
create or replace function public.aos_kronia_limpiar_tokens_expirados() returns integer language sql security definer as $$ select 0 $$;

grant execute on all functions in schema public to anon,authenticated;

insert into public.aos_configuracion(clave,valor) values ('seg_2fa_habilitado','true');
insert into public.aos_rrhh(codigo_asesor,nombre,puesto,sede,usuario,password_hash,estado) values
 ('A001','Alice Admin','Administradora','SAN ISIDRO','alice','pw-admin','ACTIVO'),
 ('A002','Eve Advisor','Asesora','PUEBLO LIBRE','eve','pw-eve','ACTIVO'),
 ('A003','Bob TwoFactor','Asesor','SAN ISIDRO','bob','pw-bob','ACTIVO');
insert into public.aos_usuarios(nombre,email,rol,cargo,sede,activo,two_factor,codigo_asesor) values
 ('Alice Admin','alice@example.test','ADMIN','Administradora','SAN ISIDRO',true,false,'A001'),
 ('Eve Advisor','eve@example.test','ASESOR','Asesora','PUEBLO LIBRE',true,false,'A002'),
 ('Bob TwoFactor','bob@example.test','ASESOR','Asesor','SAN ISIDRO',true,true,'A003');
insert into public.aos_integraciones(tipo,nombre,estado,api_key,api_secret,config,webhook_url,url_api,url_docs) values
 ('groq','Groq','conectado','TEST_SECRET_KEY','TEST_SECRET_2','{"private":true}','https://secret.invalid/hook','https://secret.invalid/api','https://docs.invalid');
