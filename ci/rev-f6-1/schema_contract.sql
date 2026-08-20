\set ON_ERROR_STOP on
create extension if not exists pgcrypto;
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin create role service_role nologin; exception when duplicate_object then null; end $$;

create table public.aos_f5_source_batches_v1(id uuid primary key default gen_random_uuid(),status text,source_rows integer,source_year integer,updated_at timestamptz default now());
create table public.aos_f5_patient_source_rows_v1(
 id bigint primary key,batch_id uuid,source_row_num integer,source_patient_id text,phone_key text,document_key text,email_key text
);
create table public.aos_f5_identity_clusters_v1(id uuid primary key,status text,confidence text,source_row_count integer,updated_at timestamptz default now());
create table public.aos_f5_identity_cluster_members_v1(cluster_id uuid,source_row_id bigint,match_rule text,match_score numeric,created_at timestamptz default now());
create table public.aos_f5_canonical_classification_v1(
 cluster_id uuid primary key,target_patient_id text,source_match_status text,classification text,reason text,match_method text,match_score numeric,
 canonical_dni_conflict boolean default false,canonical_email_conflict boolean default false,canonical_dob_conflict boolean default false,canonical_sex_conflict boolean default false,
 target_missing boolean default false,target_collision boolean default false,source_strong_conflict boolean default false,classified_at timestamptz default now()
);

create table public.aos_pacientes(
 "ID_PACIENTE" text primary key,"Nombres" text,"Apellidos" text,"Teléfono" text,"Email" text,"N° documento" text,"Sexo" text,
 "Fecha de nacimiento" text,"Dirección" text,"Ocupación" text,"SEDE_PRINCIPAL" text,"FUENTE" text,"FECHA_REGISTRO" text,
 "TOTAL_COMPRAS" integer default 0,"TOTAL_FACTURADO" numeric default 0,"ULTIMA_VISITA" text,"TOTAL_LLAMADAS" integer default 0,"TOTAL_CITAS" integer default 0,
 "ESTADO_PACIENTE" text,"NOTAS" text,"ETIQUETA_BASE" text,"SCORE_ESTADO" text,"DIAS_ULTIMA_VISITA" integer,
 created_at timestamptz default now(),updated_at timestamptz default now(),ult_visita date,numero_limpio text,n_leads integer,n_llamadas integer,n_citas integer,n_ventas integer,
 primera_llamada date,primera_venta date,tratamiento_principal text,fuente_datos text,pais text,departamento text,ciudad text,distrito text,contacto_emergencia text,estado_civil text,etiqueta_vip text,codigo_hc text
);
create table public.aos_ventas(
 id bigint primary key,venta_id text,fecha date,nombres text,apellidos text,dni text,celular text,tratamiento text,descripcion text,pago text,monto numeric,
 estado_pago text,asesor text,atendio text,sede text,tipo text,numero_limpio text,created_at timestamptz default now(),updated_at timestamptz default now(),cotizacion_id text
);
create table public.aos_agenda_citas(
 id text primary key,fecha_cita date,tratamiento text,tipo_cita text,sede text,numero text,nombre text,apellido text,dni text,correo text,asesor text,
 estado_cita text,venta_id_match text,obs text,ts_creado timestamptz default now(),ts_actualizado timestamptz default now(),hora_cita text,doctora text,tipo_atencion text,numero_limpio text,
 lead_id_origen bigint,llamada_id_origen bigint
);
create table public.aos_llamadas(
 id bigint primary key,fecha date,numero text,tratamiento text,estado text,observacion text,hora_llamada text,asesor text,numero_limpio text,sub_estado text,
 created_at timestamptz default now(),lead_id_origen bigint
);
create table public.aos_leads(id bigint primary key,fecha date,celular text,tratamiento text,hora_ingreso timestamptz,numero_limpio text,created_at timestamptz default now());
create table public.aos_notas_pacientes(
 id text primary key,fecha date,numero text,texto text,usuario text,tipo_nota text,ts_creado timestamptz default now(),evolucion text,diagnostico text,plan_trabajo text,
 resultado_estudios text,triaje text,nota_adicional text,rol_autor text,sede text,pronostico text
);
create table public.aos_documentos_pacientes(id text primary key,fecha date,tipo text,url_drive text,nombre_archivo text,usuario text,numero text,ts_creado timestamptz default now());
create table public.aos_seguimientos("ID" text primary key,"FECHA_PROGRAMADA" text,"TRATAMIENTO" text,"NUMERO" text,"OBS_RECONTACTO" text,"ESTADO" text,"ASESOR" text);

create table public.aos_f5_historical_join_v1(
 sale_id bigint primary key,sale_date date,sale_year integer,sede text,canonical_patient_id text,patient_link_status text,patient_link_method text,patient_candidate_count integer,
 historical_cluster_id uuid,historical_match_cluster_count integer,historical_source_row_count integer,product_applicable boolean,product_resolution_status text,product_key text,
 product_resolution_source text,cartera_link_status text,cartera_row_count integer,cartera_active_row_count integer,payment_evidence_row_count integer,confirmed_balance_row_count integer,
 evidence jsonb default '{}'::jsonb,semantic_hash text,generated_at timestamptz default now()
);
create table public.aos_product_sale_fact_base(
 sale_id bigint primary key,fecha date,sede text,raw_description text,raw_alias_key text,resolution_status text,resolution_source text,physical_qty numeric,is_pack boolean,locked boolean,
 product_key text,canonical_name text,lifecycle_status text,catalog_service_id uuid
);
create view public.aos_product_sale_fact_current_v1 as select * from public.aos_product_sale_fact_base;
create table public.aos_cartera_reconciliacion(
 id uuid primary key default gen_random_uuid(),source_type text,venta_row_id bigint,cotizacion_id text,pago_id text,grupo_pago_id uuid,rol_pago text,estado_reconciliacion text,
 confianza text,monto_registrado numeric,total_compra_esperado numeric,saldo_confirmado numeric,source_active boolean default true,evidencia jsonb,observacion text,
 confirmado_por uuid,confirmed_at timestamptz,created_at timestamptz default now(),updated_at timestamptz default now()
);
create table public.aos_cia_contact_identity_base(
 identity_version integer default 1,contact_key text,phone_valid boolean,identity_status text,canonical_patient_id text,audit_selected_patient_id text,identity_conflict boolean,
 has_fused_rows boolean,patient_rows integer,non_fused_count integer,fused_count integer,has_patient_source boolean,has_lead boolean,has_call boolean,has_appointment boolean,has_sale boolean,
 source_flags jsonb,canonical_names text,canonical_surnames text,canonical_email text,canonical_patient_state text,canonical_patient_updated_at timestamptz
);
create view public.aos_cia_contact_identity_v1 as select * from public.aos_cia_contact_identity_base;

create table public.aos_usuarios(id uuid primary key,nombre text not null,activo boolean default true,paneles_acceso text[] default '{}',nivel_jerarquia integer default 3);
create or replace function public.aos_app_actor_v3(p_token text,p_required_panel text,p_require_2fa boolean)
returns uuid language sql stable security definer set search_path='' as $$
 select case
  when p_token='advisor-f61-token-00000000000000000000' and p_required_panel='advisor-patients' then '00000000-0000-0000-0000-000000000611'::uuid
  when p_token='admin-f61-token-0000000000000000000000' and p_required_panel='admin-patients' then '00000000-0000-0000-0000-000000000612'::uuid
  else null::uuid end
$$;
create or replace function public.aos_paciente_360(p_numero text)
returns jsonb language sql stable security definer set search_path='' as $$ select jsonb_build_object('legacy',true,'sensitive','SHOULD_NOT_BE_BROWSER_EXECUTABLE') $$;
grant execute on function public.aos_paciente_360(text) to public,anon,authenticated,service_role;

insert into public.aos_f5_source_batches_v1(status,source_rows,source_year) values ('MATCHED',2,2024),('MATCHED',1,2025),('MATCHED',1,2026);
insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono","Email","N° documento","Sexo","Fecha de nacimiento","Dirección","Ocupación","SEDE_PRINCIPAL","FUENTE","FECHA_REGISTRO","ESTADO_PACIENTE",numero_limpio,ult_visita,tratamiento_principal,pais,departamento,ciudad,distrito,estado_civil,contacto_emergencia)
values
 ('P1','Ana','Prueba','999111111','ana@example.test','12345678','F','1990-01-01','Dir 1','Ing','SAN ISIDRO','TEST','2026-01-01','PACIENTE','999111111','2026-08-15','LASER','Peru','Lima','Lima','Miraflores','SOLTERA','999999999'),
 ('P2','Beto','Prueba','999222222','beto@example.test','87654321','M','1988-02-02','Dir 2','Doc','PUEBLO LIBRE','TEST','2026-01-02','PACIENTE','999222222','2026-08-10','BOTOX','Peru','Lima','Lima','Pueblo Libre','SOLTERO','988888888');

with b as (select id bid from public.aos_f5_source_batches_v1 order by id::text limit 1)
insert into public.aos_f5_patient_source_rows_v1(id,batch_id,source_row_num,source_patient_id,phone_key,document_key,email_key)
select * from (
 select 1,b.bid,1,'S-P1-A','999000111','12345678','ana@example.test' from b
 union all select 2,b.bid,2,'S-P1-B','999333333','12345678','ana@example.test' from b
 union all select 3,b.bid,3,'S-P2-A','999333333','87654321','beto@example.test' from b
) x;

insert into public.aos_f5_identity_clusters_v1(id,status,confidence,source_row_count) values
 ('11111111-1111-1111-1111-111111111111','AUTO_CANDIDATE','HIGH',2),
 ('22222222-2222-2222-2222-222222222222','AUTO_CANDIDATE','HIGH',1);
insert into public.aos_f5_identity_cluster_members_v1(cluster_id,source_row_id,match_rule,match_score) values
 ('11111111-1111-1111-1111-111111111111',1,'TEST',100),('11111111-1111-1111-1111-111111111111',2,'TEST',100),
 ('22222222-2222-2222-2222-222222222222',3,'TEST',100);
insert into public.aos_f5_canonical_classification_v1(cluster_id,target_patient_id,source_match_status,classification,reason,match_method,match_score)
values
 ('11111111-1111-1111-1111-111111111111','P1','AUTO_CANDIDATE','MATCH','TEST','DNI_NAME+PHONE_NAME',100),
 ('22222222-2222-2222-2222-222222222222','P2','AUTO_CANDIDATE','MATCH','TEST','DNI_NAME+PHONE_NAME',100);

insert into public.aos_ventas(id,venta_id,fecha,celular,numero_limpio,tratamiento,descripcion,monto,estado_pago,asesor,sede,tipo)
values (1,'V1','2026-08-15','999111111','999111111','LASER','LASER CANONICO',100,'REGISTRADO','ASESOR','SAN ISIDRO','SERVICIO');
insert into public.aos_f5_historical_join_v1(sale_id,sale_date,sale_year,sede,canonical_patient_id,patient_link_status,patient_link_method,patient_candidate_count,product_applicable,product_resolution_status,product_key,product_resolution_source,cartera_link_status,cartera_row_count,cartera_active_row_count,payment_evidence_row_count,confirmed_balance_row_count)
values (1,'2026-08-15',2026,'SAN ISIDRO','P1','MATCH','F5_CERTIFIED',1,true,'RESOLVED','LASER','F3','F4_LINKED',1,1,0,0);
insert into public.aos_product_sale_fact_base(sale_id,fecha,sede,resolution_status,resolution_source,product_key,canonical_name) values (1,'2026-08-15','SAN ISIDRO','RESOLVED','F3','LASER','Laser Canonico');
insert into public.aos_cartera_reconciliacion(source_type,venta_row_id,rol_pago,estado_reconciliacion,monto_registrado,source_active) values ('VENTA',1,'ADELANTO','PENDIENTE_RECONCILIAR',20,true);
insert into public.aos_agenda_citas(id,fecha_cita,hora_cita,tratamiento,tipo_cita,sede,numero,numero_limpio,estado_cita,asesor) values ('C1','2026-08-20','10:00','LASER','CONTROL','SAN ISIDRO','999000111','999000111','PENDIENTE','ASESOR');
insert into public.aos_llamadas(id,fecha,numero,numero_limpio,tratamiento,estado,sub_estado,observacion,hora_llamada,asesor) values (1,'2026-08-14','999000111','999000111','LASER','CONTACTADO','OK','Comercial','09:00','ASESOR');
insert into public.aos_leads(id,fecha,celular,numero_limpio,tratamiento,hora_ingreso) values (1,'2026-08-01','999000111','999000111','LASER','2026-08-01 10:00+00');
insert into public.aos_notas_pacientes(id,fecha,numero,texto,usuario,tipo_nota,sede) values ('N1','2026-08-10','999000111','NOTA CLINICA TEST','DR','DOCTORA','SAN ISIDRO');
insert into public.aos_documentos_pacientes(id,fecha,tipo,url_drive,nombre_archivo,usuario,numero) values ('D1','2026-08-10','CONSENTIMIENTO','https://example.test/doc','doc.pdf','DR','999000111');
insert into public.aos_cia_contact_identity_base(contact_key,phone_valid,identity_status,canonical_patient_id,identity_conflict,canonical_patient_updated_at) values ('999111111',true,'RESOLVED','P1',false,now()),('999222222',true,'RESOLVED','P2',false,now());
insert into public.aos_usuarios(id,nombre,paneles_acceso) values
 ('00000000-0000-0000-0000-000000000611','Advisor Test',array['advisor-patients']),
 ('00000000-0000-0000-0000-000000000612','Admin Test',array['admin-patients']);
