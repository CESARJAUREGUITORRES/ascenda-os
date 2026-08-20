\set ON_ERROR_STOP on
create extension if not exists pgcrypto;

do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin create role service_role nologin; exception when duplicate_object then null; end $$;

create table public.aos_f5_source_batches_v1(id uuid primary key default gen_random_uuid(),status text,source_rows integer,source_year integer,updated_at timestamptz default now());
create table public.aos_f5_patient_source_rows_v1(id uuid primary key default gen_random_uuid());
create table public.aos_f5_identity_cluster_members_v1(id uuid primary key default gen_random_uuid());
create table public.aos_f5_identity_clusters_v1(id uuid primary key default gen_random_uuid());
create table public.aos_f5_canonical_classification_v1(id uuid primary key default gen_random_uuid(),classification text);

create table public.aos_pacientes("ID_PACIENTE" text primary key,"Nombres" text);
create table public.aos_ventas(
 id bigint primary key, fecha date, tratamiento text, monto numeric, sede text,
 celular text, numero_limpio text, updated_at timestamptz default now()
);
create table public.aos_agenda_citas(
 id text primary key,fecha_cita date,hora_cita text,tratamiento text,estado_cita text,sede text,
 numero text,numero_limpio text,ts_creado timestamptz default now()
);
create table public.aos_llamadas(
 id bigint primary key,fecha date,hora_llamada text,tratamiento text,estado text,sub_estado text,
 numero text,numero_limpio text
);
create table public.aos_cartera_reconciliacion(
 id uuid primary key default gen_random_uuid(),venta_row_id bigint,pago_id uuid,saldo_confirmado numeric,updated_at timestamptz default now()
);
create table public.aos_f5_historical_join_v1(
 sale_id bigint primary key,patient_link_status text,product_applicable boolean,
 product_resolution_status text,cartera_link_status text
);
create table public.aos_product_sale_fact_base(sale_id bigint primary key,resolution_status text);
create view public.aos_product_sale_fact_current_v1 as select * from public.aos_product_sale_fact_base;
create table public.aos_cia_contact_identity_base(canonical_patient_id text,identity_conflict boolean,canonical_patient_updated_at timestamptz);
create view public.aos_cia_contact_identity_v1 as select * from public.aos_cia_contact_identity_base;

create table public.aos_usuarios(
 id uuid primary key,nombre text not null,activo boolean default true,paneles_acceso text[] default '{}',nivel_jerarquia integer default 3
);

create or replace function public.aos_app_actor_v3(p_token text,p_required_panel text,p_require_2fa boolean)
returns uuid language plpgsql stable security definer set search_path='' as $$
begin
 if p_token='valid-f6-token-000000000000000000000000' and p_required_panel in ('advisor-patients','admin-patients') then
   return '00000000-0000-0000-0000-000000000601'::uuid;
 end if;
 raise exception 'UNAUTHORIZED';
end $$;

create or replace function public.aos_paciente_360(p_numero text)
returns jsonb language sql stable security definer as $$ select jsonb_build_object('paciente',jsonb_build_object('dni','SENSITIVE'),'notas',jsonb_build_array('CLINICAL'),'documentos',jsonb_build_array('PRIVATE')) $$;
grant execute on function public.aos_paciente_360(text) to public,anon,authenticated,service_role;

insert into public.aos_f5_source_batches_v1(status,source_rows,source_year) values ('MATCHED',1,2024),('MATCHED',1,2025),('MATCHED',1,2026);
insert into public.aos_f5_patient_source_rows_v1 default values;
insert into public.aos_f5_identity_cluster_members_v1 default values;
insert into public.aos_f5_identity_clusters_v1 default values;
insert into public.aos_f5_canonical_classification_v1(classification) values ('MATCH');
insert into public.aos_pacientes values ('P1','Paciente Test');
insert into public.aos_ventas(id,fecha,tratamiento,monto,sede,celular,numero_limpio) values (1,'2026-08-15','TEST',100,'SAN ISIDRO','987654321','987654321');
insert into public.aos_agenda_citas(id,fecha_cita,hora_cita,tratamiento,estado_cita,sede,numero,numero_limpio) values ('C1','2026-08-16','10:00','TEST','PENDIENTE','SAN ISIDRO','987654321','987654321');
insert into public.aos_llamadas(id,fecha,hora_llamada,tratamiento,estado,sub_estado,numero,numero_limpio) values (1,'2026-08-14','09:00','TEST','CONTACTADO','OK','987654321','987654321');
insert into public.aos_f5_historical_join_v1 values (1,'MATCH',true,'RESOLVED','F4_LINKED');
insert into public.aos_product_sale_fact_base values (1,'RESOLVED');
insert into public.aos_cartera_reconciliacion(venta_row_id) values (1);
insert into public.aos_cia_contact_identity_base values ('P1',false,now());
insert into public.aos_usuarios(id,nombre,paneles_acceso) values ('00000000-0000-0000-0000-000000000601','F6 Test',array['advisor-patients']);
