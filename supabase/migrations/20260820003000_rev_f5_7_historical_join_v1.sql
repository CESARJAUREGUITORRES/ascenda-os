-- ASCENDA OS — REV-F5.7 Historical JOIN v1
-- Read-first cross-domain bridge: F5 canonical patient identity -> sale -> F3 product -> F4 reconciliation.
-- Does not mutate aos_pacientes, aos_ventas, F3 facts, F4 facts, payments or cartera.
-- Does not infer sale/debt/payment from Último presupuesto, ADELANTO text or sale status strings.

create extension if not exists pgcrypto;

create table if not exists public.aos_f5_historical_join_v1 (
  sale_id bigint primary key references public.aos_ventas(id) on delete cascade,
  sale_date date null,
  sale_year integer null,
  sede text null,

  canonical_patient_id text null,
  patient_link_status text not null check (patient_link_status in ('MATCH','REVIEW','UNRESOLVED')),
  patient_link_method text not null,
  patient_candidate_count integer not null default 0 check (patient_candidate_count >= 0),

  historical_cluster_id uuid null references public.aos_f5_identity_clusters_v1(id) on delete set null,
  historical_match_cluster_count integer not null default 0 check (historical_match_cluster_count >= 0),
  historical_source_row_count integer not null default 0 check (historical_source_row_count >= 0),

  product_applicable boolean not null default false,
  product_resolution_status text not null check (product_resolution_status in ('RESOLVED','REVIEW_REQUIRED','EXCLUDED','NOT_APPLICABLE','MISSING_F3_FACT')),
  product_key text null references public.aos_product_identity_v1(product_key) on delete restrict,
  product_resolution_source text null,

  cartera_link_status text not null check (cartera_link_status in ('F4_LINKED','NO_F4_RECONCILIATION_EVIDENCE')),
  cartera_row_count integer not null default 0 check (cartera_row_count >= 0),
  cartera_active_row_count integer not null default 0 check (cartera_active_row_count >= 0),
  payment_evidence_row_count integer not null default 0 check (payment_evidence_row_count >= 0),
  confirmed_balance_row_count integer not null default 0 check (confirmed_balance_row_count >= 0),

  evidence jsonb not null default '{}'::jsonb,
  semantic_hash text not null,
  generated_at timestamptz not null default now()
);

create index if not exists aos_f5_historical_join_patient_v1_idx
  on public.aos_f5_historical_join_v1(canonical_patient_id)
  where canonical_patient_id is not null;
create index if not exists aos_f5_historical_join_product_v1_idx
  on public.aos_f5_historical_join_v1(product_key)
  where product_key is not null;
create index if not exists aos_f5_historical_join_status_v1_idx
  on public.aos_f5_historical_join_v1(patient_link_status,product_resolution_status,cartera_link_status);

alter table public.aos_f5_historical_join_v1 enable row level security;
revoke all on table public.aos_f5_historical_join_v1 from public, anon, authenticated;
grant all on table public.aos_f5_historical_join_v1 to service_role;

create or replace function public.aos_f5_build_historical_join_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_source_rows bigint;
  v_members bigint;
  v_clusters bigint;
  v_classifications bigint;
  v_match bigint;
  v_review bigint;
  v_new bigint;

  v_sales_before bigint;
  v_sales_after bigint;
  v_sales_fp_before text;
  v_sales_fp_after text;
  v_patients_before bigint;
  v_patients_after bigint;
  v_patients_fp_before text;
  v_patients_fp_after text;
  v_f3_before bigint;
  v_f3_after bigint;
  v_f3_fp_before text;
  v_f3_fp_after text;
  v_f4_before bigint;
  v_f4_after bigint;
  v_f4_fp_before text;
  v_f4_fp_after text;

  v_bridge_rows bigint;
  v_patient_match bigint;
  v_patient_review bigint;
  v_patient_unresolved bigint;
  v_historical_linked_sales bigint;
  v_f3_applicable bigint;
  v_f3_resolved bigint;
  v_f3_review bigint;
  v_f3_excluded bigint;
  v_f3_missing bigint;
  v_f3_not_applicable bigint;
  v_f4_linked bigint;
  v_f4_unlinked bigint;
  v_payment_evidence bigint;
  v_confirmed_balance_evidence bigint;
  v_bridge_fp text;
begin
  -- F5 identity prerequisites.
  select count(*) into v_source_rows from public.aos_f5_patient_source_rows_v1;
  select count(*) into v_members from public.aos_f5_identity_cluster_members_v1;
  select count(*) into v_clusters from public.aos_f5_identity_clusters_v1;
  select count(*),
         count(*) filter(where classification='MATCH'),
         count(*) filter(where classification='REVIEW'),
         count(*) filter(where classification='NEW')
    into v_classifications,v_match,v_review,v_new
  from public.aos_f5_canonical_classification_v1;

  if v_source_rows=0 or v_members<>v_source_rows then
    raise exception 'F5_7_MEMBERSHIP_COVERAGE_INVALID';
  end if;
  if v_classifications<>v_clusters or v_match+v_review+v_new<>v_clusters then
    raise exception 'F5_7_CLASSIFICATION_COVERAGE_INVALID';
  end if;
  if exists(
    select 1
    from public.aos_f5_canonical_classification_v1
    where classification='MATCH'
      and (target_patient_id is null or canonical_dni_conflict or canonical_email_conflict
           or canonical_dob_conflict or canonical_sex_conflict or target_missing
           or target_collision or source_strong_conflict)
  ) then
    raise exception 'F5_7_UNSAFE_F5_MATCH_PRESENT';
  end if;
  if exists(
    select 1 from public.aos_f5_canonical_classification_v1
    where classification='MATCH'
    group by target_patient_id
    having count(*)>1
  ) then
    raise exception 'F5_7_F5_MATCH_TARGET_COLLISION';
  end if;

  -- Protected-domain snapshots. The builder must leave all four domains unchanged.
  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_patients_before,v_patients_fp_before from public.aos_pacientes p;
  select count(*),md5(string_agg(md5(to_jsonb(v)::text),',' order by v.id))
    into v_sales_before,v_sales_fp_before from public.aos_ventas v;
  select count(*),md5(string_agg(md5(to_jsonb(f)::text),',' order by f.sale_id))
    into v_f3_before,v_f3_fp_before from public.aos_product_sale_fact_current_v1 f;
  select count(*),md5(string_agg(md5(to_jsonb(c)::text),',' order by c.id))
    into v_f4_before,v_f4_fp_before from public.aos_cartera_reconciliacion c;

  drop table if exists pg_temp.tmp_f57_sales;
  drop table if exists pg_temp.tmp_f57_patients;
  drop table if exists pg_temp.tmp_f57_dni;
  drop table if exists pg_temp.tmp_f57_phone;
  drop table if exists pg_temp.tmp_f57_hist;
  drop table if exists pg_temp.tmp_f57_f4;

  create temporary table tmp_f57_sales on commit drop as
  select
    v.id sale_id,
    v.fecha sale_date,
    extract(year from v.fecha)::integer sale_year,
    v.sede,
    upper(btrim(coalesce(v.tipo,''))) sale_type,
    upper(btrim(coalesce(v.tratamiento,''))) treatment_upper,
    public.aos_f5_norm_name_v1(concat_ws(' ',nullif(v.nombres,''),nullif(v.apellidos,''))) name_key,
    (public.aos_f5_norm_doc_v1(v.dni)->>'key') dni_key,
    (public.aos_f5_norm_doc_v1(v.dni)->>'type') dni_type,
    (public.aos_f5_norm_phone_v1(coalesce(nullif(v.numero_limpio,''),nullif(v.celular,'')))->>'key') phone_key
  from public.aos_ventas v;
  create index on tmp_f57_sales(dni_key);
  create index on tmp_f57_sales(phone_key,name_key);

  create temporary table tmp_f57_patients on commit drop as
  select
    p."ID_PACIENTE" patient_id,
    public.aos_f5_norm_name_v1(concat_ws(' ',nullif(p."Nombres",''),nullif(p."Apellidos",''))) name_key,
    (public.aos_f5_norm_doc_v1(p."N° documento")->>'key') dni_key,
    (public.aos_f5_norm_doc_v1(p."N° documento")->>'type') dni_type,
    (public.aos_f5_norm_phone_v1(coalesce(nullif(p.numero_limpio,''),nullif(p."Teléfono",'')))->>'key') phone_key
  from public.aos_pacientes p;
  create index on tmp_f57_patients(dni_key);
  create index on tmp_f57_patients(phone_key,name_key);

  create temporary table tmp_f57_dni on commit drop as
  select
    s.sale_id,
    count(p.patient_id)::integer dni_candidates,
    count(p.patient_id) filter(where p.name_key=s.name_key and s.name_key is not null)::integer dni_name_candidates,
    min(p.patient_id) filter(where p.name_key=s.name_key and s.name_key is not null) match_patient_id
  from tmp_f57_sales s
  left join tmp_f57_patients p
    on s.dni_type='DNI8' and p.dni_type='DNI8' and p.dni_key=s.dni_key
  group by s.sale_id;
  create unique index on tmp_f57_dni(sale_id);

  create temporary table tmp_f57_phone on commit drop as
  select
    s.sale_id,
    count(p.patient_id)::integer phone_name_candidates
  from tmp_f57_sales s
  left join tmp_f57_patients p
    on s.phone_key is not null and s.name_key is not null
   and p.phone_key=s.phone_key and p.name_key=s.name_key
  group by s.sale_id;
  create unique index on tmp_f57_phone(sale_id);

  create temporary table tmp_f57_hist on commit drop as
  select
    c.target_patient_id,
    c.cluster_id,
    ic.source_row_count
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_identity_clusters_v1 ic on ic.id=c.cluster_id
  where c.classification='MATCH';
  create unique index on tmp_f57_hist(target_patient_id);

  create temporary table tmp_f57_f4 on commit drop as
  select
    cr.venta_row_id sale_id,
    count(*)::integer cartera_rows,
    count(*) filter(where cr.source_active)::integer active_rows,
    count(*) filter(where cr.pago_id is not null)::integer payment_evidence_rows,
    count(*) filter(where cr.saldo_confirmado is not null)::integer confirmed_balance_rows
  from public.aos_cartera_reconciliacion cr
  where cr.venta_row_id is not null
  group by cr.venta_row_id;
  create unique index on tmp_f57_f4(sale_id);

  truncate table public.aos_f5_historical_join_v1;

  insert into public.aos_f5_historical_join_v1(
    sale_id,sale_date,sale_year,sede,
    canonical_patient_id,patient_link_status,patient_link_method,patient_candidate_count,
    historical_cluster_id,historical_match_cluster_count,historical_source_row_count,
    product_applicable,product_resolution_status,product_key,product_resolution_source,
    cartera_link_status,cartera_row_count,cartera_active_row_count,payment_evidence_row_count,confirmed_balance_row_count,
    evidence,semantic_hash,generated_at
  )
  select
    s.sale_id,s.sale_date,s.sale_year,s.sede,
    case when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then d.match_patient_id else null end canonical_patient_id,
    case
      when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then 'MATCH'
      when s.dni_type='DNI8' and d.dni_candidates>0 then 'REVIEW'
      when coalesce(ph.phone_name_candidates,0)>0 then 'REVIEW'
      else 'UNRESOLVED'
    end patient_link_status,
    case
      when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then 'DNI_NAME_EXACT'
      when s.dni_type='DNI8' and d.dni_candidates>1 then 'DNI_CANONICAL_COLLISION'
      when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=0 then 'DNI_NAME_MISMATCH'
      when s.dni_type='DNI8' and d.dni_candidates=0 then 'DNI_NO_CANONICAL_MATCH'
      when coalesce(ph.phone_name_candidates,0)>0 then 'PHONE_NAME_SUPPORT_ONLY'
      else 'NO_STRONG_IDENTITY_EVIDENCE'
    end patient_link_method,
    case
      when s.dni_type='DNI8' then d.dni_candidates
      else coalesce(ph.phone_name_candidates,0)
    end patient_candidate_count,
    case when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then h.cluster_id else null end historical_cluster_id,
    case when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 and h.cluster_id is not null then 1 else 0 end historical_match_cluster_count,
    case when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then coalesce(h.source_row_count,0) else 0 end historical_source_row_count,
    (s.sale_type='PRODUCTO' or s.treatment_upper like '%COMPRA%PRODUCTO%') product_applicable,
    case
      when pf.sale_id is not null then coalesce(pf.resolution_status,'REVIEW_REQUIRED')
      when (s.sale_type='PRODUCTO' or s.treatment_upper like '%COMPRA%PRODUCTO%') then 'MISSING_F3_FACT'
      else 'NOT_APPLICABLE'
    end product_resolution_status,
    pf.product_key,
    pf.resolution_source,
    case when f4.sale_id is not null then 'F4_LINKED' else 'NO_F4_RECONCILIATION_EVIDENCE' end cartera_link_status,
    coalesce(f4.cartera_rows,0),coalesce(f4.active_rows,0),coalesce(f4.payment_evidence_rows,0),coalesce(f4.confirmed_balance_rows,0),
    jsonb_build_object(
      'identity',jsonb_build_object(
        'dni_type',coalesce(s.dni_type,'MISSING'),
        'dni_candidates',coalesce(d.dni_candidates,0),
        'dni_name_candidates',coalesce(d.dni_name_candidates,0),
        'phone_name_candidates',coalesce(ph.phone_name_candidates,0),
        'phone_name_is_support_only',true
      ),
      'historical',jsonb_build_object(
        'f5_match_cluster_attached',h.cluster_id is not null,
        'source_row_count',coalesce(h.source_row_count,0)
      ),
      'product',jsonb_build_object(
        'source','aos_product_sale_fact_current_v1',
        'applicable',(s.sale_type='PRODUCTO' or s.treatment_upper like '%COMPRA%PRODUCTO%')
      ),
      'finance',jsonb_build_object(
        'source','aos_cartera_reconciliacion',
        'cartera_rows',coalesce(f4.cartera_rows,0),
        'payment_evidence_rows',coalesce(f4.payment_evidence_rows,0),
        'confirmed_balance_rows',coalesce(f4.confirmed_balance_rows,0),
        'sale_status_used_as_payment_truth',false,
        'ultimo_presupuesto_used_as_financial_fact',false,
        'adelanto_inferred',false
      )
    ),
    encode(extensions.digest(convert_to(concat_ws('|',
      s.sale_id::text,
      case when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then coalesce(d.match_patient_id,'') else '' end,
      case
        when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then 'MATCH'
        when s.dni_type='DNI8' and d.dni_candidates>0 then 'REVIEW'
        when coalesce(ph.phone_name_candidates,0)>0 then 'REVIEW'
        else 'UNRESOLVED'
      end,
      coalesce(h.cluster_id::text,''),coalesce(h.source_row_count,0)::text,
      coalesce(pf.resolution_status,case when (s.sale_type='PRODUCTO' or s.treatment_upper like '%COMPRA%PRODUCTO%') then 'MISSING_F3_FACT' else 'NOT_APPLICABLE' end),
      coalesce(pf.product_key,''),
      case when f4.sale_id is not null then 'F4_LINKED' else 'NO_F4_RECONCILIATION_EVIDENCE' end,
      coalesce(f4.cartera_rows,0)::text,coalesce(f4.payment_evidence_rows,0)::text,coalesce(f4.confirmed_balance_rows,0)::text
    ),'UTF8'),'sha256'),'hex'),
    now()
  from tmp_f57_sales s
  join tmp_f57_dni d on d.sale_id=s.sale_id
  join tmp_f57_phone ph on ph.sale_id=s.sale_id
  left join tmp_f57_patients mp on mp.patient_id=d.match_patient_id
  left join tmp_f57_hist h on h.target_patient_id=case when s.dni_type='DNI8' and d.dni_candidates=1 and d.dni_name_candidates=1 then d.match_patient_id else null end
  left join public.aos_product_sale_fact_current_v1 pf on pf.sale_id=s.sale_id
  left join tmp_f57_f4 f4 on f4.sale_id=s.sale_id;

  select
    count(*),
    count(*) filter(where patient_link_status='MATCH'),
    count(*) filter(where patient_link_status='REVIEW'),
    count(*) filter(where patient_link_status='UNRESOLVED'),
    count(*) filter(where historical_cluster_id is not null),
    count(*) filter(where product_applicable),
    count(*) filter(where product_resolution_status='RESOLVED'),
    count(*) filter(where product_resolution_status='REVIEW_REQUIRED'),
    count(*) filter(where product_resolution_status='EXCLUDED'),
    count(*) filter(where product_resolution_status='MISSING_F3_FACT'),
    count(*) filter(where product_resolution_status='NOT_APPLICABLE'),
    count(*) filter(where cartera_link_status='F4_LINKED'),
    count(*) filter(where cartera_link_status='NO_F4_RECONCILIATION_EVIDENCE'),
    coalesce(sum(payment_evidence_row_count),0),
    coalesce(sum(confirmed_balance_row_count),0)
  into
    v_bridge_rows,v_patient_match,v_patient_review,v_patient_unresolved,v_historical_linked_sales,
    v_f3_applicable,v_f3_resolved,v_f3_review,v_f3_excluded,v_f3_missing,v_f3_not_applicable,
    v_f4_linked,v_f4_unlinked,v_payment_evidence,v_confirmed_balance_evidence
  from public.aos_f5_historical_join_v1;

  -- Exhaustive/safety gates: classify every sale exactly once and never elevate phone-only support to MATCH.
  if v_bridge_rows<>v_sales_before then raise exception 'F5_7_SALE_COVERAGE_MISMATCH'; end if;
  if v_patient_match+v_patient_review+v_patient_unresolved<>v_bridge_rows then raise exception 'F5_7_IDENTITY_CLASSIFICATION_MISMATCH'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 where patient_link_status='MATCH' and (canonical_patient_id is null or patient_link_method<>'DNI_NAME_EXACT')) then raise exception 'F5_7_UNSAFE_PATIENT_MATCH'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 j left join public.aos_pacientes p on p."ID_PACIENTE"=j.canonical_patient_id where j.patient_link_status='MATCH' and p."ID_PACIENTE" is null) then raise exception 'F5_7_MATCH_TARGET_MISSING'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 where patient_link_status<>'MATCH' and canonical_patient_id is not null) then raise exception 'F5_7_REVIEW_TARGET_LEAK'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 where patient_link_method='PHONE_NAME_SUPPORT_ONLY' and patient_link_status='MATCH') then raise exception 'F5_7_PHONE_ONLY_AUTHORITY_FORBIDDEN'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 where historical_cluster_id is not null and patient_link_status<>'MATCH') then raise exception 'F5_7_HISTORICAL_CLUSTER_TARGET_INVALID'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 where cartera_link_status='F4_LINKED' and cartera_row_count=0) then raise exception 'F5_7_F4_LINK_WITHOUT_EVIDENCE'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 where cartera_link_status='NO_F4_RECONCILIATION_EVIDENCE' and cartera_row_count<>0) then raise exception 'F5_7_F4_UNLINKED_WITH_ROWS'; end if;
  if exists(select 1 from public.aos_f5_historical_join_v1 where product_resolution_status='RESOLVED' and product_key is null) then raise exception 'F5_7_RESOLVED_PRODUCT_WITHOUT_KEY'; end if;

  select md5(string_agg(semantic_hash,',' order by sale_id))
    into v_bridge_fp from public.aos_f5_historical_join_v1;

  -- Protected-domain post-checks.
  select count(*),md5(string_agg(md5(to_jsonb(p)::text),',' order by p."ID_PACIENTE"))
    into v_patients_after,v_patients_fp_after from public.aos_pacientes p;
  select count(*),md5(string_agg(md5(to_jsonb(v)::text),',' order by v.id))
    into v_sales_after,v_sales_fp_after from public.aos_ventas v;
  select count(*),md5(string_agg(md5(to_jsonb(f)::text),',' order by f.sale_id))
    into v_f3_after,v_f3_fp_after from public.aos_product_sale_fact_current_v1 f;
  select count(*),md5(string_agg(md5(to_jsonb(c)::text),',' order by c.id))
    into v_f4_after,v_f4_fp_after from public.aos_cartera_reconciliacion c;

  if v_patients_after<>v_patients_before or v_patients_fp_after is distinct from v_patients_fp_before then raise exception 'F5_7_PATIENT_MUTATION_DETECTED'; end if;
  if v_sales_after<>v_sales_before or v_sales_fp_after is distinct from v_sales_fp_before then raise exception 'F5_7_SALES_MUTATION_DETECTED'; end if;
  if v_f3_after<>v_f3_before or v_f3_fp_after is distinct from v_f3_fp_before then raise exception 'F5_7_F3_MUTATION_DETECTED'; end if;
  if v_f4_after<>v_f4_before or v_f4_fp_after is distinct from v_f4_fp_before then raise exception 'F5_7_F4_MUTATION_DETECTED'; end if;

  insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
  values('HISTORICAL_COMMERCIAL_JOIN_BUILT','F5','REV-F5.7',jsonb_build_object(
    'sales',v_bridge_rows,
    'patient_match',v_patient_match,'patient_review',v_patient_review,'patient_unresolved',v_patient_unresolved,
    'historical_linked_sales',v_historical_linked_sales,
    'f3_applicable',v_f3_applicable,'f3_resolved',v_f3_resolved,'f3_review_required',v_f3_review,'f3_excluded',v_f3_excluded,'f3_missing_fact',v_f3_missing,'f3_not_applicable',v_f3_not_applicable,
    'f4_linked',v_f4_linked,'f4_unlinked',v_f4_unlinked,'payment_evidence_rows',v_payment_evidence,'confirmed_balance_evidence_rows',v_confirmed_balance_evidence,
    'bridge_fingerprint',v_bridge_fp,
    'canonical_patient_count',v_patients_after,'canonical_patient_fingerprint',v_patients_fp_after,
    'sale_count',v_sales_after,'sale_fingerprint',v_sales_fp_after,
    'f3_fact_count',v_f3_after,'f3_fingerprint',v_f3_fp_after,
    'f4_reconciliation_count',v_f4_after,'f4_fingerprint',v_f4_fp_after,
    'protected_domains_mutated',false,
    'ultimo_presupuesto_financial_inference',false,
    'adelanto_inference',false
  ));

  return jsonb_build_object(
    'ok',true,
    'source_rows',v_source_rows,'members',v_members,'clusters',v_clusters,
    'f5_match',v_match,'f5_review',v_review,'f5_new',v_new,
    'sales',v_bridge_rows,
    'patient_match',v_patient_match,'patient_review',v_patient_review,'patient_unresolved',v_patient_unresolved,
    'historical_linked_sales',v_historical_linked_sales,
    'f3_applicable',v_f3_applicable,'f3_resolved',v_f3_resolved,'f3_review_required',v_f3_review,'f3_excluded',v_f3_excluded,'f3_missing_fact',v_f3_missing,'f3_not_applicable',v_f3_not_applicable,
    'f4_linked',v_f4_linked,'f4_unlinked',v_f4_unlinked,
    'payment_evidence_rows',v_payment_evidence,'confirmed_balance_evidence_rows',v_confirmed_balance_evidence,
    'bridge_fingerprint',v_bridge_fp,
    'canonical_patient_count',v_patients_after,'canonical_patient_fingerprint',v_patients_fp_after,
    'sale_count',v_sales_after,'sale_fingerprint',v_sales_fp_after,
    'f3_fact_count',v_f3_after,'f3_fingerprint',v_f3_fp_after,
    'f4_reconciliation_count',v_f4_after,'f4_fingerprint',v_f4_fp_after,
    'protected_domains_mutated',false,
    'ultimo_presupuesto_financial_inference',false,
    'adelanto_inference',false
  );
end
$$;

revoke all on function public.aos_f5_build_historical_join_v1() from public, anon, authenticated;
grant execute on function public.aos_f5_build_historical_join_v1() to service_role;

create or replace function public.aos_f5_historical_join_summary_v1()
returns jsonb
language sql
stable
security definer
set search_path='public','pg_temp'
as $$
  select jsonb_build_object(
    'sales',count(*),
    'patient_match',count(*) filter(where patient_link_status='MATCH'),
    'patient_review',count(*) filter(where patient_link_status='REVIEW'),
    'patient_unresolved',count(*) filter(where patient_link_status='UNRESOLVED'),
    'historical_linked_sales',count(*) filter(where historical_cluster_id is not null),
    'f3_applicable',count(*) filter(where product_applicable),
    'f3_resolved',count(*) filter(where product_resolution_status='RESOLVED'),
    'f3_review_required',count(*) filter(where product_resolution_status='REVIEW_REQUIRED'),
    'f3_excluded',count(*) filter(where product_resolution_status='EXCLUDED'),
    'f3_missing_fact',count(*) filter(where product_resolution_status='MISSING_F3_FACT'),
    'f3_not_applicable',count(*) filter(where product_resolution_status='NOT_APPLICABLE'),
    'f4_linked',count(*) filter(where cartera_link_status='F4_LINKED'),
    'f4_unlinked',count(*) filter(where cartera_link_status='NO_F4_RECONCILIATION_EVIDENCE'),
    'payment_evidence_rows',coalesce(sum(payment_evidence_row_count),0),
    'confirmed_balance_evidence_rows',coalesce(sum(confirmed_balance_row_count),0),
    'bridge_fingerprint',md5(string_agg(semantic_hash,',' order by sale_id))
  )
  from public.aos_f5_historical_join_v1
$$;

revoke all on function public.aos_f5_historical_join_summary_v1() from public, anon, authenticated;
grant execute on function public.aos_f5_historical_join_summary_v1() to service_role;
