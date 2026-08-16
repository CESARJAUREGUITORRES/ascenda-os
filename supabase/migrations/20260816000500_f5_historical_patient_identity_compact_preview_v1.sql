-- ASCENDA OS — F5 compact historical ingest + identity/link preview v1
-- Private, idempotent, preview-only. Does NOT mutate public.aos_pacientes.

create extension if not exists pgcrypto;

create or replace function public.aos_f5_norm_name_v1(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(
    btrim(
      regexp_replace(
        regexp_replace(
          translate(
            upper(coalesce(p_value,'')),
            'ÁÀÂÄÃÅÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ',
            'AAAAAAEEEEIIIIOOOOOUUUUNC'
          ),
          '[^A-Z0-9 ]+', ' ', 'g'
        ),
        '[[:space:]]+', ' ', 'g'
      )
    ),
    ''
  )
$$;

create or replace function public.aos_f5_norm_phone_v1(p_value text)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_raw text := nullif(btrim(coalesce(p_value,'')),'');
  v_digits text;
begin
  if v_raw is null then
    return jsonb_build_object('raw',null,'key',null,'type','MISSING');
  end if;
  v_digits := regexp_replace(v_raw,'[^0-9]','','g');
  if left(v_digits,4)='0051' then v_digits := substr(v_digits,5); end if;
  if left(v_digits,2)='51' and length(v_digits)=11 then v_digits := substr(v_digits,3); end if;
  if v_digits ~ '^9[0-9]{8}$' then
    return jsonb_build_object('raw',v_raw,'key',v_digits,'type','PERU_9');
  elsif length(v_digits) between 8 and 15 then
    return jsonb_build_object('raw',v_raw,'key',v_digits,'type','NON_STANDARD');
  end if;
  return jsonb_build_object('raw',v_raw,'key',null,'type','INVALID');
end
$$;

create or replace function public.aos_f5_norm_doc_v1(p_value text)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_raw text := nullif(btrim(coalesce(p_value,'')),'');
  v_digits text;
  v_key text;
begin
  if v_raw is null then
    return jsonb_build_object('raw',null,'key',null,'type','MISSING');
  end if;
  v_digits := regexp_replace(v_raw,'[^0-9]','','g');
  if v_digits ~ '^[0-9]{8}$' then
    return jsonb_build_object('raw',v_raw,'key',v_digits,'type','DNI8');
  end if;
  v_key := nullif(regexp_replace(upper(v_raw),'[^A-Z0-9]','','g'),'');
  return jsonb_build_object('raw',v_raw,'key',v_key,'type',case when v_key is null then 'INVALID' else 'NON_DNI' end);
end
$$;

create or replace function public.aos_f5_norm_email_v1(p_value text)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_raw text := nullif(btrim(coalesce(p_value,'')),'');
  v_key text;
begin
  if v_raw is null then return jsonb_build_object('raw',null,'key',null); end if;
  v_key := lower(v_raw);
  if v_key ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    return jsonb_build_object('raw',v_raw,'key',v_key);
  end if;
  return jsonb_build_object('raw',v_raw,'key',null);
end
$$;

create or replace function public.aos_f5_parse_date_v1(p_value text)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := btrim(coalesce(p_value,''));
  d date;
  y int; m int; dd int;
begin
  if v='' then return null; end if;
  if v ~ '^[0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}' then
    y := (regexp_match(v,'^([0-9]{4})'))[1]::int;
    m := (regexp_match(v,'^[0-9]{4}[-/]([0-9]{1,2})'))[1]::int;
    dd := (regexp_match(v,'^[0-9]{4}[-/][0-9]{1,2}[-/]([0-9]{1,2})'))[1]::int;
  elsif v ~ '^[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4}' then
    dd := (regexp_match(v,'^([0-9]{1,2})'))[1]::int;
    m := (regexp_match(v,'^[0-9]{1,2}[-/]([0-9]{1,2})'))[1]::int;
    y := (regexp_match(v,'^[0-9]{1,2}[-/][0-9]{1,2}[-/]([0-9]{4})'))[1]::int;
  else
    return null;
  end if;
  d := make_date(y,m,dd);
  return d;
exception when others then
  return null;
end
$$;

create or replace function public.aos_f5_compact_raw_payload_v1(p_map jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'F. creación de paciente',coalesce(p_map->>'0',''),
    'ID del paciente',coalesce(p_map->>'1',''),
    'Teléfono',coalesce(p_map->>'2',''),
    'Nombres',coalesce(p_map->>'3',''),
    'Apellidos',coalesce(p_map->>'4',''),
    'Email',coalesce(p_map->>'5',''),
    'N° documento',coalesce(p_map->>'6',''),
    'Sexo',coalesce(p_map->>'7',''),
    'Fecha de nacimiento',coalesce(p_map->>'8',''),
    'Dirección',coalesce(p_map->>'9',''),
    'Ocupación',coalesce(p_map->>'10',''),
    'Apoderado',coalesce(p_map->>'11',''),
    '¿Cómo nos conoció?',coalesce(p_map->>'12',''),
    'Referencia de Procedencia',coalesce(p_map->>'13',''),
    'Campo opcional 1',coalesce(p_map->>'14',''),
    'Campo opcional 2',coalesce(p_map->>'15',''),
    'Nota clínica',coalesce(p_map->>'16',''),
    'Alergias',coalesce(p_map->>'17',''),
    'Grupo',coalesce(p_map->>'18',''),
    'Línea de negocio',coalesce(p_map->>'19',''),
    'N° HC',coalesce(p_map->>'20',''),
    'Inactivo',coalesce(p_map->>'21',''),
    'Etiquetas',coalesce(p_map->>'22',''),
    'Última cita',coalesce(p_map->>'23',''),
    'Próxima cita',coalesce(p_map->>'24',''),
    'Tarea',coalesce(p_map->>'25',''),
    'Último presupuesto',coalesce(p_map->>'26','')
  )
$$;

create or replace function public.aos_f5_normalize_compact_row_v1(
  p_source_sha256 text,
  p_item jsonb
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_row integer;
  v_map jsonb;
  v_raw jsonb;
  v_phone jsonb;
  v_doc jsonb;
  v_email jsonb;
  v_name text;
  v_birth date;
  v_birth_raw text;
  v_birth_quality text;
  v_addr text;
  v_parts text[];
  v_part_count integer;
  v_street text;
  v_district text;
  v_province text;
  v_department text;
  v_addr_status text;
  v_budget text;
  v_budget_m text[];
  v_budget_a numeric;
  v_budget_b numeric;
  v_seed text;
begin
  if jsonb_typeof(p_item) <> 'array' or jsonb_array_length(p_item) <> 2 then
    raise exception 'COMPACT_ROW_SHAPE_INVALID';
  end if;
  v_row := nullif(p_item->>0,'')::integer;
  v_map := p_item->1;
  if v_row is null or v_row < 2 or jsonb_typeof(v_map) <> 'object' then
    raise exception 'COMPACT_ROW_INVALID';
  end if;
  v_raw := public.aos_f5_compact_raw_payload_v1(v_map);
  if nullif(v_raw->>'ID del paciente','') is null then
    raise exception 'SOURCE_PATIENT_ID_MISSING';
  end if;

  v_phone := public.aos_f5_norm_phone_v1(v_raw->>'Teléfono');
  v_doc := public.aos_f5_norm_doc_v1(v_raw->>'N° documento');
  v_email := public.aos_f5_norm_email_v1(v_raw->>'Email');
  v_name := public.aos_f5_norm_name_v1(concat_ws(' ',nullif(v_raw->>'Nombres',''),nullif(v_raw->>'Apellidos','')));

  v_birth_raw := nullif(v_raw->>'Fecha de nacimiento','');
  v_birth := public.aos_f5_parse_date_v1(v_birth_raw);
  if v_birth_raw is null then v_birth_quality := 'MISSING';
  elsif v_birth is null then v_birth_quality := 'UNPARSEABLE';
  elsif extract(year from v_birth) > extract(year from current_date) then v_birth := null; v_birth_quality := 'FUTURE';
  elsif extract(year from v_birth) < 1900 then v_birth := null; v_birth_quality := 'IMPLAUSIBLE_OLD';
  else v_birth_quality := 'VALID';
  end if;

  v_addr := nullif(v_raw->>'Dirección','');
  if v_addr is null then
    v_addr_status := 'MISSING';
  else
    select array_agg(btrim(x)) filter (where btrim(x)<>'')
      into v_parts
    from unnest(string_to_array(v_addr,',')) x;
    v_part_count := coalesce(array_length(v_parts,1),0);
    if v_part_count >= 3 then
      v_district := v_parts[v_part_count-2];
      v_province := v_parts[v_part_count-1];
      v_department := v_parts[v_part_count];
      if v_part_count > 3 then
        v_street := array_to_string(v_parts[1:v_part_count-3],', ');
      else
        v_street := null;
      end if;
      v_addr_status := 'PARSED_RIGHT';
    else
      v_street := v_addr;
      v_addr_status := 'UNPARSEABLE';
    end if;
  end if;

  v_budget := nullif(v_raw->>'Último presupuesto','');
  if v_budget ~ '^\s*[\d.,]+\s*/\s*[\d.,]+\s*$' then
    v_budget_m := regexp_match(v_budget,'^\s*([\d.,]+)\s*/\s*([\d.,]+)\s*$');
    begin
      v_budget_a := replace(v_budget_m[1],',','')::numeric;
      v_budget_b := replace(v_budget_m[2],',','')::numeric;
    exception when others then
      v_budget_a := null; v_budget_b := null;
    end;
  end if;

  if v_email->>'key' is not null then
    v_seed := 'EMAIL:'||(v_email->>'key');
  elsif v_doc->>'type'='DNI8' and v_doc->>'key' is not null and v_name is not null then
    v_seed := 'DNI_NAME:'||(v_doc->>'key')||'|'||v_name;
  elsif v_phone->>'type'='PERU_9' and v_phone->>'key' is not null and v_name is not null then
    v_seed := 'PHONE_NAME:'||(v_phone->>'key')||'|'||v_name;
  else
    v_seed := 'ROW:'||lower(btrim(p_source_sha256))||':'||v_row;
  end if;

  return jsonb_build_object(
    'source_row_num',v_row,
    'source_patient_id',v_raw->>'ID del paciente',
    'source_created_date',public.aos_f5_parse_date_v1(v_raw->>'F. creación de paciente'),
    'phone_raw',v_phone->>'raw','phone_key',v_phone->>'key','phone_type',v_phone->>'type',
    'names_raw',nullif(v_raw->>'Nombres',''),'surnames_raw',nullif(v_raw->>'Apellidos',''),'name_key',v_name,
    'email_raw',v_email->>'raw','email_key',v_email->>'key',
    'document_raw',v_doc->>'raw','document_key',v_doc->>'key','document_type',v_doc->>'type',
    'sex_raw',nullif(v_raw->>'Sexo',''),
    'birth_date_raw',v_birth_raw,'birth_date',v_birth,'birth_quality',v_birth_quality,
    'address_raw',v_addr,'address_street',v_street,'district',v_district,'province',v_province,'department',v_department,'address_parse_status',v_addr_status,
    'occupation',nullif(v_raw->>'Ocupación',''),'guardian',nullif(v_raw->>'Apoderado',''),
    'acquisition_channel',nullif(v_raw->>'¿Cómo nos conoció?',''),'acquisition_reference',nullif(v_raw->>'Referencia de Procedencia',''),
    'clinical_note',nullif(v_raw->>'Nota clínica',''),'allergies',nullif(v_raw->>'Alergias',''),
    'business_line',nullif(v_raw->>'Línea de negocio',''),'hc_raw',nullif(v_raw->>'N° HC',''),
    'inactive_raw',nullif(v_raw->>'Inactivo',''),'tags_raw',nullif(v_raw->>'Etiquetas',''),
    'last_appointment',public.aos_f5_parse_date_v1(v_raw->>'Última cita'),
    'next_appointment',public.aos_f5_parse_date_v1(v_raw->>'Próxima cita'),
    'task_raw',nullif(v_raw->>'Tarea',''),'last_budget_raw',v_budget,
    'budget_num_a',v_budget_a,'budget_num_b',v_budget_b,
    'row_content_hash',encode(extensions.digest(v_raw::text,'sha256'),'hex'),
    'identity_seed_hash',encode(extensions.digest(v_seed,'sha256'),'hex'),
    'raw_payload',v_raw
  );
end
$$;

create or replace function public.aos_f5_ingest_compact_rows_v1(
  p_source_sha256 text,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = 'public','pg_temp'
as $$
declare
  v_batch public.aos_f5_source_batches_v1%rowtype;
  v_requested integer;
  v_before integer;
  v_after integer;
  v_conflicts integer;
begin
  if p_source_sha256 is null or btrim(p_source_sha256) !~ '^[0-9a-f]{64}$' then
    raise exception 'INVALID_SOURCE_SHA256';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'ROWS_MUST_BE_ARRAY';
  end if;
  v_requested := jsonb_array_length(p_rows);
  if v_requested < 1 or v_requested > 5000 then
    raise exception 'COMPACT_BATCH_SIZE_OUT_OF_RANGE';
  end if;

  select * into v_batch
  from public.aos_f5_source_batches_v1
  where source_sha256=lower(btrim(p_source_sha256));
  if not found then raise exception 'SOURCE_BATCH_NOT_FOUND'; end if;

  drop table if exists pg_temp.tmp_f5_compact_norm;
  create temporary table tmp_f5_compact_norm(
    source_row_num integer primary key,
    norm jsonb not null
  ) on commit drop;

  insert into tmp_f5_compact_norm(source_row_num,norm)
  select (n->>'source_row_num')::integer,n
  from (
    select public.aos_f5_normalize_compact_row_v1(lower(btrim(p_source_sha256)),e) n
    from jsonb_array_elements(p_rows) e
  ) q;

  if (select count(*) from tmp_f5_compact_norm) <> v_requested then
    raise exception 'DUPLICATE_SOURCE_ROW_IN_REQUEST';
  end if;
  if exists (
    select 1 from tmp_f5_compact_norm
    where source_row_num < 2 or source_row_num > v_batch.source_rows+1
  ) then raise exception 'SOURCE_ROW_OUT_OF_RANGE'; end if;

  select count(*) into v_conflicts
  from tmp_f5_compact_norm n
  join public.aos_f5_patient_source_rows_v1 e
    on e.batch_id=v_batch.id and e.source_row_num=n.source_row_num
  where e.raw_payload is distinct from n.norm->'raw_payload';
  if v_conflicts>0 then raise exception 'SOURCE_ROW_RAW_CONFLICT'; end if;

  select count(*) into v_before
  from public.aos_f5_patient_source_rows_v1 where batch_id=v_batch.id;

  insert into public.aos_f5_patient_source_rows_v1(
    batch_id,source_row_num,source_patient_id,source_created_date,
    phone_raw,phone_key,phone_type,names_raw,surnames_raw,name_key,
    email_raw,email_key,document_raw,document_key,document_type,sex_raw,
    birth_date_raw,birth_date,birth_quality,address_raw,address_street,district,province,department,address_parse_status,
    occupation,guardian,acquisition_channel,acquisition_reference,clinical_note,allergies,business_line,hc_raw,inactive_raw,tags_raw,
    last_appointment,next_appointment,task_raw,last_budget_raw,budget_num_a,budget_num_b,row_content_hash,identity_seed_hash,raw_payload
  )
  select
    v_batch.id,n.source_row_num,n.norm->>'source_patient_id',(n.norm->>'source_created_date')::date,
    n.norm->>'phone_raw',n.norm->>'phone_key',n.norm->>'phone_type',n.norm->>'names_raw',n.norm->>'surnames_raw',n.norm->>'name_key',
    n.norm->>'email_raw',n.norm->>'email_key',n.norm->>'document_raw',n.norm->>'document_key',n.norm->>'document_type',n.norm->>'sex_raw',
    n.norm->>'birth_date_raw',(n.norm->>'birth_date')::date,n.norm->>'birth_quality',n.norm->>'address_raw',n.norm->>'address_street',
    n.norm->>'district',n.norm->>'province',n.norm->>'department',n.norm->>'address_parse_status',
    n.norm->>'occupation',n.norm->>'guardian',n.norm->>'acquisition_channel',n.norm->>'acquisition_reference',n.norm->>'clinical_note',
    n.norm->>'allergies',n.norm->>'business_line',n.norm->>'hc_raw',n.norm->>'inactive_raw',n.norm->>'tags_raw',
    (n.norm->>'last_appointment')::date,(n.norm->>'next_appointment')::date,n.norm->>'task_raw',n.norm->>'last_budget_raw',
    (n.norm->>'budget_num_a')::numeric,(n.norm->>'budget_num_b')::numeric,n.norm->>'row_content_hash',n.norm->>'identity_seed_hash',n.norm->'raw_payload'
  from tmp_f5_compact_norm n
  on conflict(batch_id,source_row_num) do nothing;

  select count(*) into v_after
  from public.aos_f5_patient_source_rows_v1 where batch_id=v_batch.id;

  update public.aos_f5_source_batches_v1
  set metadata=metadata||jsonb_build_object(
      'staged_rows',v_after,
      'staging_complete',(v_after=source_rows),
      'last_staged_at',now(),
      'compact_ingest_version','v1'
    ),
    updated_at=now()
  where id=v_batch.id;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('SOURCE_COMPACT_INGESTED','SOURCE_BATCH',v_batch.id::text,
    jsonb_build_object('requested',v_requested,'inserted',v_after-v_before,'batch_rows_after',v_after,'expected_rows',v_batch.source_rows));

  return jsonb_build_object(
    'ok',true,'batch_id',v_batch.id,'requested',v_requested,
    'inserted',v_after-v_before,'existing',v_requested-(v_after-v_before),
    'batch_rows',v_after,'expected_rows',v_batch.source_rows,'complete',v_after=v_batch.source_rows
  );
end
$$;

-- Existing expanded ingest treats identical raw evidence as idempotent even if hash
-- serialization differs between parser implementations.
create or replace function public.aos_f5_ingest_source_rows_v1(p_source_sha256 text,p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_batch public.aos_f5_source_batches_v1%rowtype;
  v_requested integer;
  v_before integer;
  v_after integer;
  v_conflicts integer;
begin
  if p_source_sha256 is null or btrim(p_source_sha256) !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_SOURCE_SHA256'; end if;
  if p_rows is null or jsonb_typeof(p_rows)<>'array' then raise exception 'ROWS_MUST_BE_ARRAY'; end if;
  v_requested:=jsonb_array_length(p_rows);
  if v_requested<1 or v_requested>500 then raise exception 'CHUNK_SIZE_OUT_OF_RANGE'; end if;

  select * into v_batch from public.aos_f5_source_batches_v1 where source_sha256=lower(btrim(p_source_sha256));
  if not found then raise exception 'SOURCE_BATCH_NOT_FOUND'; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_rows) as r(source_row_num integer,source_patient_id text,row_content_hash text,raw_payload jsonb)
    where r.source_row_num is null or r.source_row_num<2 or r.source_row_num>v_batch.source_rows+1
       or nullif(btrim(r.source_patient_id),'') is null
       or r.row_content_hash !~ '^[0-9a-f]{64}$' or r.raw_payload is null
  ) then raise exception 'INVALID_SOURCE_ROW'; end if;

  select count(*) into v_conflicts
  from jsonb_to_recordset(p_rows) as r(source_row_num integer,raw_payload jsonb)
  join public.aos_f5_patient_source_rows_v1 e
    on e.batch_id=v_batch.id and e.source_row_num=r.source_row_num
  where e.raw_payload is distinct from r.raw_payload;
  if v_conflicts>0 then raise exception 'SOURCE_ROW_RAW_CONFLICT'; end if;

  select count(*) into v_before from public.aos_f5_patient_source_rows_v1 where batch_id=v_batch.id;

  insert into public.aos_f5_patient_source_rows_v1(
    batch_id,source_row_num,source_patient_id,source_created_date,
    phone_raw,phone_key,phone_type,names_raw,surnames_raw,name_key,
    email_raw,email_key,document_raw,document_key,document_type,sex_raw,
    birth_date_raw,birth_date,birth_quality,address_raw,address_street,district,province,department,address_parse_status,
    occupation,guardian,acquisition_channel,acquisition_reference,clinical_note,allergies,business_line,hc_raw,inactive_raw,tags_raw,
    last_appointment,next_appointment,task_raw,last_budget_raw,budget_num_a,budget_num_b,row_content_hash,identity_seed_hash,raw_payload
  )
  select
    v_batch.id,r.source_row_num,r.source_patient_id,r.source_created_date,
    r.phone_raw,r.phone_key,r.phone_type,r.names_raw,r.surnames_raw,r.name_key,
    r.email_raw,r.email_key,r.document_raw,r.document_key,r.document_type,r.sex_raw,
    r.birth_date_raw,r.birth_date,r.birth_quality,r.address_raw,r.address_street,r.district,r.province,r.department,r.address_parse_status,
    r.occupation,r.guardian,r.acquisition_channel,r.acquisition_reference,r.clinical_note,r.allergies,r.business_line,r.hc_raw,r.inactive_raw,r.tags_raw,
    r.last_appointment,r.next_appointment,r.task_raw,r.last_budget_raw,r.budget_num_a,r.budget_num_b,r.row_content_hash,r.identity_seed_hash,r.raw_payload
  from jsonb_to_recordset(p_rows) as r(
    source_row_num integer,source_patient_id text,source_created_date date,
    phone_raw text,phone_key text,phone_type text,names_raw text,surnames_raw text,name_key text,
    email_raw text,email_key text,document_raw text,document_key text,document_type text,sex_raw text,
    birth_date_raw text,birth_date date,birth_quality text,address_raw text,address_street text,district text,province text,department text,address_parse_status text,
    occupation text,guardian text,acquisition_channel text,acquisition_reference text,clinical_note text,allergies text,business_line text,hc_raw text,inactive_raw text,tags_raw text,
    last_appointment date,next_appointment date,task_raw text,last_budget_raw text,budget_num_a numeric,budget_num_b numeric,row_content_hash text,identity_seed_hash text,raw_payload jsonb
  )
  on conflict(batch_id,source_row_num) do nothing;

  select count(*) into v_after from public.aos_f5_patient_source_rows_v1 where batch_id=v_batch.id;

  update public.aos_f5_source_batches_v1
  set metadata=metadata||jsonb_build_object('staged_rows',v_after,'staging_complete',(v_after=source_rows),'last_staged_at',now()),
      updated_at=now()
  where id=v_batch.id;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('SOURCE_ROWS_CHUNK_INGESTED','SOURCE_BATCH',v_batch.id::text,
    jsonb_build_object('requested',v_requested,'inserted',v_after-v_before,'batch_rows_after',v_after,'expected_rows',v_batch.source_rows));

  return jsonb_build_object('ok',true,'batch_id',v_batch.id,'requested',v_requested,'inserted',v_after-v_before,
    'existing',v_requested-(v_after-v_before),'batch_rows',v_after,'expected_rows',v_batch.source_rows,'complete',v_after=v_batch.source_rows);
end
$$;

create or replace function public.aos_f5_rebuild_identity_preview_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_expected bigint;
  v_rows bigint;
  v_changed bigint;
  v_clusters bigint;
  v_members bigint;
  v_auto bigint;
  v_review bigint;
  v_unmatched bigint;
  v_source_conflicts bigint;
  v_patient_count bigint;
begin
  select coalesce(sum(source_rows),0) into v_expected from public.aos_f5_source_batches_v1;
  select count(*) into v_rows from public.aos_f5_patient_source_rows_v1;
  if v_expected=0 or v_rows<>v_expected or exists(
    select 1 from public.aos_f5_source_batches_v1
    where coalesce((metadata->>'staging_complete')::boolean,false) is not true
  ) then
    raise exception 'SOURCE_STAGING_INCOMPLETE';
  end if;
  if exists(select 1 from public.aos_f5_patient_link_preview_v1 where reviewed_at is not null or applied_at is not null) then
    raise exception 'PREVIEW_ALREADY_REVIEWED';
  end if;

  select count(*) into v_patient_count from public.aos_pacientes;

  drop table if exists pg_temp.tmp_f5_edges;
  drop table if exists pg_temp.tmp_f5_roots;
  drop table if exists pg_temp.tmp_f5_summary;
  drop table if exists pg_temp.tmp_f5_latest;
  drop table if exists pg_temp.tmp_f5_patients;
  drop table if exists pg_temp.tmp_f5_candidate_signals;
  drop table if exists pg_temp.tmp_f5_candidate_scores;
  drop table if exists pg_temp.tmp_f5_ranked;

  delete from public.aos_f5_patient_link_preview_v1;
  delete from public.aos_f5_identity_cluster_members_v1;
  delete from public.aos_f5_identity_clusters_v1;

  create temporary table tmp_f5_edges(
    a bigint not null,
    b bigint not null,
    rule text not null,
    score numeric not null,
    primary key(a,b,rule)
  ) on commit drop;

  insert into tmp_f5_edges(a,b,rule,score)
  select anchor,id,'EMAIL_EXACT',100
  from (
    select id,email_key,min(id) over(partition by email_key) anchor
    from public.aos_f5_patient_source_rows_v1
    where email_key is not null
  ) q where id<>anchor
  on conflict do nothing;

  insert into tmp_f5_edges(a,b,rule,score)
  select anchor,id,'DNI_NAME_EXACT',90
  from (
    select id,document_key,name_key,min(id) over(partition by document_key,name_key) anchor
    from public.aos_f5_patient_source_rows_v1
    where document_type='DNI8' and document_key is not null and name_key is not null
  ) q where id<>anchor
  on conflict do nothing;

  insert into tmp_f5_edges(a,b,rule,score)
  select anchor,id,'PHONE_NAME_EXACT',80
  from (
    select id,phone_key,name_key,min(id) over(partition by phone_key,name_key) anchor
    from public.aos_f5_patient_source_rows_v1
    where phone_type='PERU_9' and phone_key is not null and name_key is not null
  ) q where id<>anchor
  on conflict do nothing;

  create temporary table tmp_f5_roots(
    row_id bigint primary key,
    root_id bigint not null
  ) on commit drop;
  insert into tmp_f5_roots select id,id from public.aos_f5_patient_source_rows_v1;

  loop
    with candidates as (
      select e.a row_id,least(ra.root_id,rb.root_id) root_id
      from tmp_f5_edges e join tmp_f5_roots ra on ra.row_id=e.a join tmp_f5_roots rb on rb.row_id=e.b
      union all
      select e.b,least(ra.root_id,rb.root_id)
      from tmp_f5_edges e join tmp_f5_roots ra on ra.row_id=e.a join tmp_f5_roots rb on rb.row_id=e.b
    ), mins as (
      select row_id,min(root_id) root_id from candidates group by row_id
    )
    update tmp_f5_roots r set root_id=m.root_id
    from mins m
    where r.row_id=m.row_id and m.root_id<r.root_id;
    get diagnostics v_changed=row_count;
    exit when v_changed=0;
  end loop;

  create temporary table tmp_f5_summary on commit drop as
  with base as (
    select rt.root_id,r.*,b.source_sede,b.source_year,b.source_sha256
    from tmp_f5_roots rt
    join public.aos_f5_patient_source_rows_v1 r on r.id=rt.row_id
    join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
  ), ag as (
    select
      root_id,
      encode(extensions.digest(string_agg(source_sha256||':'||source_row_num::text,'|' order by source_sha256,source_row_num),'sha256'),'hex') cluster_hash,
      count(*)::int source_row_count,
      count(distinct document_key) filter(where document_type='DNI8' and document_key is not null) dni_count,
      count(distinct email_key) filter(where email_key is not null) email_count,
      count(distinct phone_key) filter(where phone_type='PERU_9' and phone_key is not null) phone_count,
      count(distinct name_key) filter(where name_key is not null) name_count,
      count(distinct birth_date) filter(where birth_date is not null) birth_count,
      count(distinct upper(left(btrim(sex_raw),1))) filter(where sex_raw is not null and btrim(sex_raw)<>'') sex_count,
      min(document_key) filter(where document_type='DNI8' and document_key is not null) dni_key,
      min(email_key) filter(where email_key is not null) email_key,
      min(phone_key) filter(where phone_type='PERU_9' and phone_key is not null) phone_key,
      min(name_key) filter(where name_key is not null) name_key,
      min(birth_date) filter(where birth_date is not null) birth_date,
      min(upper(left(btrim(sex_raw),1))) filter(where sex_raw is not null and btrim(sex_raw)<>'') sex_key,
      max(last_appointment) last_appointment,
      jsonb_agg(distinct source_sede) sedes,
      jsonb_agg(distinct source_year) years
    from base group by root_id
  )
  select ag.*,
    (dni_count>1 or birth_count>1 or sex_count>1) hard_conflict,
    jsonb_build_object(
      'DNI_CONFLICT',dni_count>1,
      'DOB_CONFLICT',birth_count>1,
      'SEX_CONFLICT',sex_count>1,
      'NAME_VARIANTS',name_count,
      'EMAIL_VARIANTS',email_count,
      'PHONE_VARIANTS',phone_count
    ) conflicts
  from ag;

  alter table tmp_f5_summary
    add column latest_names text,
    add column latest_surnames text,
    add column latest_address text,
    add column latest_street text,
    add column latest_district text,
    add column latest_province text,
    add column latest_department text,
    add column latest_occupation text,
    add column latest_tags text,
    add column latest_acquisition text,
    add column source_hc text;

  create temporary table tmp_f5_latest on commit drop as
  select distinct on (rt.root_id)
    rt.root_id,r.names_raw,r.surnames_raw,r.address_raw,r.address_street,r.district,r.province,r.department,
    r.occupation,r.tags_raw,r.acquisition_channel,r.hc_raw
  from tmp_f5_roots rt
  join public.aos_f5_patient_source_rows_v1 r on r.id=rt.row_id
  join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
  order by rt.root_id,coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc;

  update tmp_f5_summary s set
    latest_names=x.names_raw,
    latest_surnames=x.surnames_raw,
    latest_address=x.address_raw,
    latest_street=x.address_street,
    latest_district=x.district,
    latest_province=x.province,
    latest_department=x.department,
    latest_occupation=x.occupation,
    latest_tags=x.tags_raw,
    latest_acquisition=x.acquisition_channel,
    source_hc=x.hc_raw
  from tmp_f5_latest x
  where x.root_id=s.root_id;

  insert into public.aos_f5_identity_clusters_v1(
    cluster_key,status,confidence,source_row_count,canonical_preview,evidence,conflicts
  )
  select
    'F5:'||cluster_hash,
    case when hard_conflict then 'REVIEW_REQUIRED' else 'PROPOSED' end,
    case
      when hard_conflict then 'REVIEW'
      when source_row_count=1 then 'SINGLETON'
      when email_count>0 or dni_count>0 then 'HIGH'
      when phone_count>0 then 'MEDIUM'
      else 'LOW'
    end,
    source_row_count,
    jsonb_strip_nulls(jsonb_build_object(
      'nombres',latest_names,'apellidos',latest_surnames,
      'phone_key',case when phone_count=1 then phone_key end,
      'document_key',case when dni_count=1 then dni_key end,
      'email_key',case when email_count=1 then email_key end,
      'sex',case when sex_count=1 then sex_key end,
      'birth_date',case when birth_count=1 then birth_date end,
      'address',latest_address,'address_street',latest_street,
      'district',latest_district,'province',latest_province,'department',latest_department,
      'occupation',latest_occupation,'last_appointment',last_appointment
    )),
    jsonb_strip_nulls(jsonb_build_object(
      'source_rows',source_row_count,'sedes',sedes,'years',years,
      'tags_latest',latest_tags,'acquisition_latest',latest_acquisition,
      'source_hc_latest',source_hc,'budget_semantics','EVIDENCE_ONLY'
    )),
    conflicts
  from tmp_f5_summary;

  insert into public.aos_f5_identity_cluster_members_v1(cluster_id,source_row_id,match_rule,match_score)
  select c.id,r.id,
    case
      when exists(select 1 from public.aos_f5_patient_source_rows_v1 z join tmp_f5_roots rz on rz.row_id=z.id
                  where rz.root_id=rt.root_id and z.id<>r.id and r.email_key is not null and z.email_key=r.email_key) then 'EMAIL_EXACT'
      when exists(select 1 from public.aos_f5_patient_source_rows_v1 z join tmp_f5_roots rz on rz.row_id=z.id
                  where rz.root_id=rt.root_id and z.id<>r.id and r.document_type='DNI8' and r.document_key=z.document_key and r.name_key=z.name_key) then 'DNI_NAME_EXACT'
      when exists(select 1 from public.aos_f5_patient_source_rows_v1 z join tmp_f5_roots rz on rz.row_id=z.id
                  where rz.root_id=rt.root_id and z.id<>r.id and r.phone_type='PERU_9' and r.phone_key=z.phone_key and r.name_key=z.name_key) then 'PHONE_NAME_EXACT'
      else 'SOURCE_SINGLETON'
    end,
    case
      when exists(select 1 from public.aos_f5_patient_source_rows_v1 z join tmp_f5_roots rz on rz.row_id=z.id
                  where rz.root_id=rt.root_id and z.id<>r.id and r.email_key is not null and z.email_key=r.email_key) then 100
      when exists(select 1 from public.aos_f5_patient_source_rows_v1 z join tmp_f5_roots rz on rz.row_id=z.id
                  where rz.root_id=rt.root_id and z.id<>r.id and r.document_type='DNI8' and r.document_key=z.document_key and r.name_key=z.name_key) then 90
      when exists(select 1 from public.aos_f5_patient_source_rows_v1 z join tmp_f5_roots rz on rz.row_id=z.id
                  where rz.root_id=rt.root_id and z.id<>r.id and r.phone_type='PERU_9' and r.phone_key=z.phone_key and r.name_key=z.name_key) then 80
      else 20
    end
  from tmp_f5_roots rt
  join public.aos_f5_patient_source_rows_v1 r on r.id=rt.row_id
  join tmp_f5_summary s on s.root_id=rt.root_id
  join public.aos_f5_identity_clusters_v1 c on c.cluster_key='F5:'||s.cluster_hash;

  create temporary table tmp_f5_patients on commit drop as
  select
    "ID_PACIENTE" patient_id,
    public.aos_f5_norm_name_v1(concat_ws(' ',nullif("Nombres",''),nullif("Apellidos",''))) name_key,
    (public.aos_f5_norm_phone_v1(coalesce(nullif(numero_limpio,''),nullif("Teléfono",'')))->>'key') phone_key,
    (public.aos_f5_norm_doc_v1("N° documento")->>'key') document_key,
    (public.aos_f5_norm_email_v1("Email")->>'key') email_key,
    public.aos_f5_parse_date_v1("Fecha de nacimiento") birth_date,
    jsonb_strip_nulls(jsonb_build_object(
      'ID_PACIENTE',"ID_PACIENTE",'Nombres',"Nombres",'Apellidos',"Apellidos",
      'Teléfono',"Teléfono",'Email',"Email",'N° documento',"N° documento",'Sexo',"Sexo",
      'Fecha de nacimiento',"Fecha de nacimiento",'Dirección',"Dirección",'Ocupación',"Ocupación",
      'distrito',distrito,'departamento',departamento,'ciudad',ciudad
    )) snapshot,
    nullif("Email",'') email_current,
    nullif("N° documento",'') doc_current,
    nullif("Sexo",'') sex_current,
    nullif("Fecha de nacimiento",'') dob_current,
    nullif("Dirección",'') address_current,
    nullif("Ocupación",'') occupation_current,
    nullif(distrito,'') district_current,
    nullif(departamento,'') department_current,
    nullif(ciudad,'') city_current
  from public.aos_pacientes;

  create temporary table tmp_f5_candidate_signals(
    cluster_id uuid not null,
    patient_id text not null,
    signal text not null,
    score numeric not null
  ) on commit drop;

  insert into tmp_f5_candidate_signals
  select distinct c.id,p.patient_id,'DNI_NAME',70
  from public.aos_f5_identity_cluster_members_v1 m
  join public.aos_f5_identity_clusters_v1 c on c.id=m.cluster_id
  join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
  join tmp_f5_patients p on p.document_key=r.document_key and p.name_key=r.name_key
  where r.document_type='DNI8' and r.document_key is not null and r.name_key is not null;

  insert into tmp_f5_candidate_signals
  select distinct c.id,p.patient_id,'EMAIL',60
  from public.aos_f5_identity_cluster_members_v1 m
  join public.aos_f5_identity_clusters_v1 c on c.id=m.cluster_id
  join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
  join tmp_f5_patients p on p.email_key=r.email_key
  where r.email_key is not null;

  insert into tmp_f5_candidate_signals
  select distinct c.id,p.patient_id,'PHONE_NAME',50
  from public.aos_f5_identity_cluster_members_v1 m
  join public.aos_f5_identity_clusters_v1 c on c.id=m.cluster_id
  join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
  join tmp_f5_patients p on p.phone_key=r.phone_key and p.name_key=r.name_key
  where r.phone_type='PERU_9' and r.phone_key is not null and r.name_key is not null;

  insert into tmp_f5_candidate_signals
  select distinct c.id,p.patient_id,'NAME_DOB',40
  from public.aos_f5_identity_cluster_members_v1 m
  join public.aos_f5_identity_clusters_v1 c on c.id=m.cluster_id
  join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
  join tmp_f5_patients p on p.name_key=r.name_key and p.birth_date=r.birth_date
  where r.name_key is not null and r.birth_date is not null;

  create temporary table tmp_f5_candidate_scores on commit drop as
  select cluster_id,patient_id,sum(score) score,jsonb_agg(signal order by signal) signals
  from tmp_f5_candidate_signals
  group by cluster_id,patient_id;

  create temporary table tmp_f5_ranked on commit drop as
  select s.*,row_number() over(partition by cluster_id order by score desc,patient_id) rn,
         count(*) over(partition by cluster_id,score) tied_at_score
  from tmp_f5_candidate_scores s;

  insert into public.aos_f5_patient_link_preview_v1(
    cluster_id,target_patient_id,match_status,match_method,match_score,evidence,conflicts,current_snapshot,proposed_patch,requires_human
  )
  select
    c.id,
    p.patient_id,
    case
      when (c.conflicts->>'DNI_CONFLICT')::boolean or (c.conflicts->>'DOB_CONFLICT')::boolean or (c.conflicts->>'SEX_CONFLICT')::boolean then 'REVIEW_REQUIRED'
      when p.patient_id is null then 'UNMATCHED'
      when p.tied_at_score>1 then 'REVIEW_REQUIRED'
      when (p.signals ? 'DNI_NAME') or ((p.signals ? 'EMAIL') and ((p.signals ? 'PHONE_NAME') or (p.signals ? 'NAME_DOB'))) then 'AUTO_CANDIDATE'
      else 'REVIEW_REQUIRED'
    end,
    case when p.patient_id is null then null else array_to_string(array(select jsonb_array_elements_text(p.signals)), '+') end,
    p.score,
    c.evidence||jsonb_build_object('candidate_signals',coalesce(p.signals,'[]'::jsonb)),
    c.conflicts||jsonb_build_object('candidate_tie',coalesce(p.tied_at_score,0)>1),
    coalesce(cp.snapshot,'{}'::jsonb),
    case when p.patient_id is null then '{}'::jsonb else
      jsonb_strip_nulls(jsonb_build_object(
        'Email',case when cp.email_current is null and nullif(c.canonical_preview->>'email_key','') is not null then c.canonical_preview->>'email_key' end,
        'N° documento',case when cp.doc_current is null and nullif(c.canonical_preview->>'document_key','') is not null then c.canonical_preview->>'document_key' end,
        'Sexo',case when cp.sex_current is null and nullif(c.canonical_preview->>'sex','') is not null then c.canonical_preview->>'sex' end,
        'Fecha de nacimiento',case when cp.dob_current is null and nullif(c.canonical_preview->>'birth_date','') is not null then c.canonical_preview->>'birth_date' end,
        'Dirección',case when cp.address_current is null and nullif(c.canonical_preview->>'address','') is not null then c.canonical_preview->>'address' end,
        'Ocupación',case when cp.occupation_current is null and nullif(c.canonical_preview->>'occupation','') is not null then c.canonical_preview->>'occupation' end,
        'distrito',case when cp.district_current is null and nullif(c.canonical_preview->>'district','') is not null then c.canonical_preview->>'district' end,
        'departamento',case when cp.department_current is null and nullif(c.canonical_preview->>'department','') is not null then c.canonical_preview->>'department' end,
        'ciudad',case when cp.city_current is null and nullif(c.canonical_preview->>'province','') is not null then c.canonical_preview->>'province' end
      ))
    end,
    true
  from public.aos_f5_identity_clusters_v1 c
  left join tmp_f5_ranked p on p.cluster_id=c.id and p.rn=1
  left join tmp_f5_patients cp on cp.patient_id=p.patient_id;

  update public.aos_f5_identity_clusters_v1 c
  set status=case
      when lp.match_status='AUTO_CANDIDATE' then 'READY_TO_LINK'
      when lp.match_status='UNMATCHED' then 'NEW_CANDIDATE'
      else 'REVIEW_REQUIRED'
    end,
    updated_at=now()
  from public.aos_f5_patient_link_preview_v1 lp
  where lp.cluster_id=c.id;

  update public.aos_f5_source_batches_v1
  set status='MATCHED',
      metadata=metadata||jsonb_build_object('identity_preview_version','v1','identity_preview_at',now()),
      updated_at=now()
  where coalesce((metadata->>'staging_complete')::boolean,false)=true;

  select count(*) into v_clusters from public.aos_f5_identity_clusters_v1;
  select count(*) into v_members from public.aos_f5_identity_cluster_members_v1;
  select count(*) into v_auto from public.aos_f5_patient_link_preview_v1 where match_status='AUTO_CANDIDATE';
  select count(*) into v_review from public.aos_f5_patient_link_preview_v1 where match_status='REVIEW_REQUIRED';
  select count(*) into v_unmatched from public.aos_f5_patient_link_preview_v1 where match_status='UNMATCHED';
  select count(*) into v_source_conflicts from public.aos_f5_identity_clusters_v1 where confidence='REVIEW';

  if v_members<>v_rows then raise exception 'CLUSTER_MEMBER_COVERAGE_MISMATCH'; end if;
  if (select count(*) from public.aos_pacientes)<>v_patient_count then raise exception 'CANONICAL_PATIENT_COUNT_CHANGED'; end if;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('IDENTITY_PREVIEW_REBUILT','F5','v1',jsonb_build_object(
    'source_rows',v_rows,'clusters',v_clusters,'members',v_members,'auto_candidates',v_auto,
    'review_required',v_review,'unmatched',v_unmatched,'source_conflict_clusters',v_source_conflicts,
    'canonical_patient_count',v_patient_count,'canonical_mutation',false
  ));

  return jsonb_build_object(
    'ok',true,'source_rows',v_rows,'clusters',v_clusters,'members',v_members,
    'auto_candidates',v_auto,'review_required',v_review,'unmatched',v_unmatched,
    'source_conflict_clusters',v_source_conflicts,'canonical_patient_count',v_patient_count,
    'canonical_mutation',false
  );
end
$$;

revoke all on function public.aos_f5_norm_name_v1(text) from public,anon,authenticated;
revoke all on function public.aos_f5_norm_phone_v1(text) from public,anon,authenticated;
revoke all on function public.aos_f5_norm_doc_v1(text) from public,anon,authenticated;
revoke all on function public.aos_f5_norm_email_v1(text) from public,anon,authenticated;
revoke all on function public.aos_f5_parse_date_v1(text) from public,anon,authenticated;
revoke all on function public.aos_f5_compact_raw_payload_v1(jsonb) from public,anon,authenticated;
revoke all on function public.aos_f5_normalize_compact_row_v1(text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_f5_ingest_compact_rows_v1(text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_f5_rebuild_identity_preview_v1() from public,anon,authenticated;
revoke all on function public.aos_f5_ingest_source_rows_v1(text,jsonb) from public,anon,authenticated;

grant execute on function public.aos_f5_ingest_source_rows_v1(text,jsonb) to service_role;
grant execute on function public.aos_f5_ingest_compact_rows_v1(text,jsonb) to service_role;
grant execute on function public.aos_f5_rebuild_identity_preview_v1() to service_role;

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F5_COMPACT_PREVIEW_PIPELINE',jsonb_build_object(
  'version','v1','ingest','service_role_only','preview','service_role_only',
  'canonical_patient_mutation',false,'at',now()
));
