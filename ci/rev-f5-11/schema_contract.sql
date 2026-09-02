\set ON_ERROR_STOP on
create extension if not exists pgcrypto;

create table public.aos_pacientes(
  "ID_PACIENTE" text primary key,
  "Nombres" text,"Apellidos" text,"Teléfono" text,"Email" text,"N° documento" text,"Sexo" text,"Fecha de nacimiento" text,
  "ESTADO_PACIENTE" text default 'NUEVO',numero_limpio text,fuente_datos text,"FUENTE" text,"FECHA_REGISTRO" text,
  created_at timestamptz default now(),updated_at timestamptz default now(),pais text default 'Perú',etiqueta_vip text default 'NORMAL'
);
create table public.aos_f5_identity_clusters_v1(
  id uuid primary key,status text not null,confidence text not null,source_row_count integer not null,
  canonical_preview jsonb not null default '{}'::jsonb,evidence jsonb not null default '{}'::jsonb,conflicts jsonb not null default '{}'::jsonb
);
create table public.aos_f5_canonical_classification_v1(
  cluster_id uuid primary key references public.aos_f5_identity_clusters_v1(id),target_patient_id text,source_match_status text,classification text not null,reason text not null,
  match_method text,match_score numeric,canonical_dni_conflict boolean not null default false,canonical_email_conflict boolean not null default false,
  canonical_dob_conflict boolean not null default false,canonical_sex_conflict boolean not null default false,target_missing boolean not null default false,
  target_collision boolean not null default false,source_strong_conflict boolean not null default false
);
create table public.aos_f5_patient_source_rows_v1(
  id bigint primary key,phone_key text,phone_type text,names_raw text,surnames_raw text,name_key text,email_key text,document_key text,document_type text,
  sex_raw text,birth_date date,source_created_date date,last_appointment date
);
create table public.aos_f5_identity_cluster_members_v1(cluster_id uuid not null references public.aos_f5_identity_clusters_v1(id),source_row_id bigint not null references public.aos_f5_patient_source_rows_v1(id),primary key(cluster_id,source_row_id));
create table public.aos_ventas(id bigserial primary key,fecha date);
create table public.aos_f5_audit_v1(id bigserial primary key,action text,entity_type text,entity_key text,actor_user_id uuid,details jsonb,created_at timestamptz default now());

create or replace function public.aos_f5_norm_name_v1(v text) returns text language sql immutable as $$
 select nullif(regexp_replace(upper(btrim(coalesce(v,''))),'[^A-Z0-9]+','','g'),'')
$$;
create or replace function public.aos_rev_normalize_patient_identifier_v2(p_type text,p_value text) returns text language plpgsql immutable as $$
declare v text:=nullif(btrim(coalesce(p_value,'')),''); d text;
begin
 if v is null then return null; end if;
 if upper(p_type)='EMAIL' then return lower(v); end if;
 if upper(p_type)='PHONE' then d:=regexp_replace(v,'[^0-9]','','g'); if length(d)>9 and right(d,9)<>'' then d:=right(d,9); end if; if length(d)<>9 then return null; end if; return d; end if;
 if upper(p_type)='DOCUMENT' then d:=regexp_replace(upper(v),'[^A-Z0-9]','','g'); return nullif(d,''); end if;
 return v;
end $$;

-- Current canonical patients. P-A/P-B must remain byte-for-byte unchanged.
insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono",numero_limpio,"Email","N° documento","Sexo","ESTADO_PACIENTE",fuente_datos) values
('P-A','Ana','Actual','999111222','999111222','ana@clinic.test','11111111','F','ACTIVO','historico'),
('P-B','Bruno','Base','988777666','988777666','bruno@clinic.test','22222222','M','ACTIVO','historico'),
('P-C','Shared','One','977555444','977555444',null,'33333333','F','ACTIVO','historico'),
('P-D','Shared','Two','977555444','977555444',null,'44444444','M','ACTIVO','historico'),
('P-OLD','Old','Merged','966000111','966000111','old@clinic.test','55555555','F','FUSIONADO','historico');

-- Eight clusters covering positive and fail-closed branches.
insert into public.aos_f5_identity_clusters_v1(id,status,confidence,source_row_count,canonical_preview,evidence,conflicts) values
('00000000-0000-0000-0000-000000000001','READY_TO_LINK','HIGH',1,'{"nombres":"Ana","apellidos":"Actual","sex":"F"}','{}','{}'),
('00000000-0000-0000-0000-000000000002','REVIEW_REQUIRED','HIGH',1,'{"nombres":"Ana","apellidos":"Actual","sex":"F"}','{}','{}'),
('00000000-0000-0000-0000-000000000003','REVIEW_REQUIRED','MEDIUM',1,'{"nombres":"Ana","apellidos":"Actual","sex":"F"}','{}','{}'),
('00000000-0000-0000-0000-000000000004','REVIEW_REQUIRED','HIGH',1,'{"nombres":"Bruno","apellidos":"Base","sex":"F"}','{}','{}'),
('00000000-0000-0000-0000-000000000005','NEW_CANDIDATE','HIGH',1,'{"nombres":"Bruno","apellidos":"Base","sex":"M"}','{}','{}'),
('00000000-0000-0000-0000-000000000006','NEW_CANDIDATE','HIGH',2,'{"nombres":"Carla","apellidos":"Historica","sex":"F","birth_date":"1990-01-02","document_key":"87654321"}','{}','{}'),
('00000000-0000-0000-0000-000000000007','NEW_CANDIDATE','SINGLETON',1,'{"nombres":"Dario","apellidos":"Dudoso","sex":"M"}','{}','{}'),
('00000000-0000-0000-0000-000000000008','READY_TO_LINK','HIGH',1,'{"nombres":"Old","apellidos":"Merged","sex":"F"}','{}','{}');

insert into public.aos_f5_canonical_classification_v1(cluster_id,target_patient_id,source_match_status,classification,reason,match_method,match_score,canonical_sex_conflict) values
('00000000-0000-0000-0000-000000000001','P-A','AUTO_CANDIDATE','MATCH','EXACT_OR_STRONG_MATCH','DNI_NAME+PHONE_NAME',120,false),
('00000000-0000-0000-0000-000000000002','P-A','REVIEW_REQUIRED','REVIEW','CANONICAL_TARGET_COLLISION','EMAIL',60,false),
('00000000-0000-0000-0000-000000000003','P-A','REVIEW_REQUIRED','REVIEW','AMBIGUOUS_OR_INSUFFICIENT_EVIDENCE','PHONE_NAME',50,false),
('00000000-0000-0000-0000-000000000004','P-B','REVIEW_REQUIRED','REVIEW','CANONICAL_STRONG_FIELD_CONFLICT','DNI_NAME',70,true),
('00000000-0000-0000-0000-000000000005',null,'UNMATCHED','NEW','NO_CANONICAL_MATCH',null,null,false),
('00000000-0000-0000-0000-000000000006',null,'UNMATCHED','NEW','NO_CANONICAL_MATCH',null,null,false),
('00000000-0000-0000-0000-000000000007',null,'UNMATCHED','NEW','NO_CANONICAL_MATCH',null,null,false),
('00000000-0000-0000-0000-000000000008','P-OLD','AUTO_CANDIDATE','MATCH','EXACT_OR_STRONG_MATCH','DNI_NAME+PHONE_NAME',120,false);

insert into public.aos_f5_patient_source_rows_v1(id,phone_key,phone_type,names_raw,surnames_raw,name_key,email_key,document_key,document_type,sex_raw,birth_date,source_created_date,last_appointment) values
(1,'999111222','PERU_9','Ana','Actual','ANAACTUAL','ana@clinic.test','11111111','DNI8','F','1980-01-01','2024-01-01','2024-12-01'),
(2,null,'MISSING','Ana','Actual','ANAACTUAL','ana@clinic.test',null,null,'F',null,'2024-02-01',null),
(3,'999111222','PERU_9','Ana','Actual','ANAACTUAL',null,null,null,'F',null,'2024-03-01',null),
(4,'988777666','PERU_9','Bruno','Base','BRUNOBASE',null,'22222222','DNI8','F',null,'2024-04-01',null),
(5,'988777666','PERU_9','Bruno','Base','BRUNOBASE',null,'22222222','DNI8','M',null,'2025-01-01',null),
(6,'955444333','PERU_9','Carla','Historica','CARLAHISTORICA','carla.hist@test.pe','87654321','DNI8','F','1990-01-02','2024-01-05','2025-01-05'),
(7,'955444333','PERU_9','Carla','Historica','CARLAHISTORICA','carla.hist@test.pe','87654321','DNI8','F','1990-01-02','2025-01-05','2025-02-05'),
(8,'944333222','PERU_9','Dario','Dudoso','DARIODUDOSO',null,null,null,'M',null,'2026-01-01',null),
(9,'966000111','PERU_9','Old','Merged','OLDMERGED','old@clinic.test','55555555','DNI8','F','1975-05-05','2024-06-01',null);
insert into public.aos_f5_identity_cluster_members_v1 values
('00000000-0000-0000-0000-000000000001',1),('00000000-0000-0000-0000-000000000002',2),('00000000-0000-0000-0000-000000000003',3),('00000000-0000-0000-0000-000000000004',4),('00000000-0000-0000-0000-000000000005',5),('00000000-0000-0000-0000-000000000006',6),('00000000-0000-0000-0000-000000000006',7),('00000000-0000-0000-0000-000000000007',8),('00000000-0000-0000-0000-000000000008',9);
