-- Phase 2 hardening synthetic-only schema. No production identities/PII.

create table if not exists public.aos_integraciones (
  id uuid primary key default extensions.gen_random_uuid(),
  tipo text,nombre text,api_key text,estado text,principal boolean default false,updated_at timestamptz default now()
);
insert into public.aos_integraciones(tipo,nombre,api_key,estado,principal)
values ('resend','Resend Test','re_test_not_a_secret','ACTIVO',true);

create table if not exists public.aos_catalogo_categorias (
  id uuid primary key default extensions.gen_random_uuid(),nombre text,tipo text,rol_profesional text,estado text
);
create table if not exists public.aos_catalogo_servicios (
  id uuid primary key default extensions.gen_random_uuid(),nombre text,categoria text,tipo text,estado text,
  descripcion_clinica text,descripcion_comercial text,composicion text,beneficios text,contraindicaciones text,
  perfil_paciente text,indicaciones text,updated_at timestamptz default now()
);
create table if not exists public.aos_catalogo_toppings (
  id uuid primary key default extensions.gen_random_uuid(),nombre text,categoria text,estado text,precio numeric default 0
);
create table if not exists public.aos_catalogo_productos_detalle (
  id uuid primary key default extensions.gen_random_uuid(),nombre text,estado text,updated_at timestamptz default now()
);
create table if not exists public.aos_planes_trabajo (
  id text primary key,numero_limpio text,fecha date,estado text,nombre text,updated_at timestamptz default now()
);
create table if not exists public.aos_plan_trabajo_items (
  id text primary key,plan_id text,numero_limpio text,fecha date,nombre text,estado text,updated_at timestamptz default now()
);

grant select,insert,update,delete,truncate,references,trigger on public.aos_catalogo_categorias to anon,authenticated;
grant select,insert,update,delete,truncate,references,trigger on public.aos_catalogo_servicios to anon,authenticated;
grant select,insert,update,delete,truncate,references,trigger on public.aos_catalogo_toppings to anon,authenticated;
grant select,insert,update,delete,truncate,references,trigger on public.aos_catalogo_productos_detalle to anon,authenticated;
grant select,insert,update,delete,truncate,references,trigger on public.aos_planes_trabajo to anon,authenticated;
grant select,insert,update,delete,truncate,references,trigger on public.aos_plan_trabajo_items to anon,authenticated;
grant select,insert,update,delete,truncate,references,trigger on public.aos_ventas to anon,authenticated;

-- Legacy auth stubs required by the final revoke contract.
create or replace function public.aos_login_v2(text,text) returns json
language sql security definer as $$select json_build_object('ok',true)$$;
create or replace function public.aos_cia_claim_admin_session_v1(text,text) returns jsonb
language sql security definer as $$select jsonb_build_object('ok',true)$$;
grant execute on function public.aos_login_v2(text,text) to anon,authenticated;
grant execute on function public.aos_cia_claim_admin_session_v1(text,text) to anon,authenticated;

-- Legacy Caja stubs used only to prove v2 wrappers discard caller-supplied identity.
create or replace function public.aos_caja_abrir(text,text,numeric,numeric,numeric,date) returns jsonb
language sql security definer as $$select jsonb_build_object('ok',true,'sesion_id','test-session','actor',$2)$$;
create or replace function public.aos_caja_cerrar(text,text,numeric,numeric,numeric,numeric,text) returns jsonb
language sql security definer as $$select jsonb_build_object('ok',true,'actor',$2)$$;
create or replace function public.aos_caja_editar_pago(text,text,text,text,numeric,text,text,text,text,text,uuid) returns jsonb
language sql security definer as $$select jsonb_build_object('ok',true,'actor',$3)$$;
create or replace function public.aos_caja_eliminar_venta(text,text,text) returns jsonb
language sql security definer as $$select jsonb_build_object('ok',true,'actor',$3)$$;
create or replace function public.aos_caja_ingreso_extra(text,text,date,text,numeric,text,text) returns jsonb
language sql security definer as $$select jsonb_build_object('ok',true,'actor',$7)$$;
create or replace function public.aos_caja_registrar_gasto(text,text,date,text,numeric,text,text,text) returns jsonb
language sql security definer as $$select jsonb_build_object('ok',true,'actor',$8)$$;

grant execute on function public.aos_caja_abrir(text,text,numeric,numeric,numeric,date) to anon,authenticated;
grant execute on function public.aos_caja_cerrar(text,text,numeric,numeric,numeric,numeric,text) to anon,authenticated;
grant execute on function public.aos_caja_editar_pago(text,text,text,text,numeric,text,text,text,text,text,uuid) to anon,authenticated;
grant execute on function public.aos_caja_eliminar_venta(text,text,text) to anon,authenticated;
grant execute on function public.aos_caja_ingreso_extra(text,text,date,text,numeric,text,text) to anon,authenticated;
grant execute on function public.aos_caja_registrar_gasto(text,text,date,text,numeric,text,text,text) to anon,authenticated;
