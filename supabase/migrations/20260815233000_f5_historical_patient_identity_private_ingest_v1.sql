-- ASCENDA OS — F5 Historical Patient Identity private ingest v1
-- CRITICAL PII boundary: service-side/private staging only. No canonical patient mutation.

create or replace function public.aos_f5_ingest_source_rows_v1(
  p_source_sha256 text,
  p_rows jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
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
  if v_requested < 1 or v_requested > 500 then
    raise exception 'CHUNK_SIZE_OUT_OF_RANGE';
  end if;

  select * into v_batch
  from public.aos_f5_source_batches_v1
  where source_sha256 = lower(btrim(p_source_sha256));
  if not found then raise exception 'SOURCE_BATCH_NOT_FOUND'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_rows) as r(source_row_num integer, source_patient_id text, row_content_hash text, raw_payload jsonb)
    where r.source_row_num is null
       or r.source_row_num < 2
       or r.source_row_num > v_batch.source_rows + 1
       or nullif(btrim(r.source_patient_id),'') is null
       or r.row_content_hash !~ '^[0-9a-f]{64}$'
       or r.raw_payload is null
  ) then raise exception 'INVALID_SOURCE_ROW'; end if;

  select count(*) into v_conflicts
  from jsonb_to_recordset(p_rows) as r(source_row_num integer,row_content_hash text)
  join public.aos_f5_patient_source_rows_v1 e
    on e.batch_id=v_batch.id and e.source_row_num=r.source_row_num
  where e.row_content_hash <> r.row_content_hash;
  if v_conflicts > 0 then raise exception 'SOURCE_ROW_HASH_CONFLICT'; end if;

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
  set metadata = metadata || jsonb_build_object(
        'staged_rows',v_after,
        'staging_complete',(v_after=source_rows),
        'last_staged_at',now()
      ),
      updated_at=now()
  where id=v_batch.id;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('SOURCE_ROWS_CHUNK_INGESTED','SOURCE_BATCH',v_batch.id::text,
    jsonb_build_object('requested',v_requested,'inserted',v_after-v_before,'batch_rows_after',v_after,'expected_rows',v_batch.source_rows));

  return jsonb_build_object('ok',true,'batch_id',v_batch.id,'requested',v_requested,'inserted',v_after-v_before,
    'existing',v_requested-(v_after-v_before),'batch_rows',v_after,'expected_rows',v_batch.source_rows,'complete',v_after=v_batch.source_rows);
end;
$$;

revoke all on function public.aos_f5_ingest_source_rows_v1(text,jsonb) from public, anon, authenticated;
grant execute on function public.aos_f5_ingest_source_rows_v1(text,jsonb) to service_role;

comment on function public.aos_f5_ingest_source_rows_v1(text,jsonb) is
'Private F5 idempotent ingestion of normalized historical source evidence. Never mutates aos_pacientes.';

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F5_PRIVATE_INGEST_V1',jsonb_build_object('browser_access',false,'canonical_patient_mutation',false,'max_chunk',500,'at',now()));
