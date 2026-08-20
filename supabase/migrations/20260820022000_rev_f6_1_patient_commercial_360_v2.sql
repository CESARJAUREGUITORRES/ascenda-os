-- REV-F6.1 — Patient Commercial 360 V2 + Identity Bridge V2
-- Read/intelligence layer only. No patient merge, no business-row mutation.

begin;

create or replace function public.aos_rev_normalize_patient_identifier_v2(p_type text, p_value text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_type text := upper(trim(coalesce(p_type,'')));
  v text := trim(coalesce(p_value,''));
  v_digits text;
begin
  if v_type = 'CANONICAL_ID' then
    return nullif(v,'');
  elsif v_type = 'PHONE' then
    v_digits := regexp_replace(v,'[^0-9]','','g');
    if length(v_digits) < 9 then return null; end if;
    return right(v_digits,9);
  elsif v_type = 'DOCUMENT' then
    v_digits := regexp_replace(v,'[^0-9]','','g');
    if length(v_digits) <> 8 then return null; end if;
    return v_digits;
  elsif v_type = 'EMAIL' then
    v := lower(v);
    if position('@' in v) <= 1 then return null; end if;
    return v;
  end if;
  return null;
end;
$$;

revoke all on function public.aos_rev_normalize_patient_identifier_v2(text,text) from public, anon, authenticated;
grant execute on function public.aos_rev_normalize_patient_identifier_v2(text,text) to service_role;

create or replace view public.aos_rev_patient_identity_alias_v2 as
with raw_alias as (
  select
    'CANONICAL_ID'::text identifier_type,
    p."ID_PACIENTE"::text identifier_key,
    p."ID_PACIENTE"::text canonical_patient_id,
    'CANONICAL_CURRENT'::text source_scope
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'

  union all

  select
    'PHONE',
    public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")),
    p."ID_PACIENTE"::text,
    'CANONICAL_CURRENT'
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")) is not null

  union all

  select
    'DOCUMENT',
    public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p."N° documento"),
    p."ID_PACIENTE"::text,
    'CANONICAL_CURRENT'
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p."N° documento") is not null

  union all

  select
    'EMAIL',
    public.aos_rev_normalize_patient_identifier_v2('EMAIL',p."Email"),
    p."ID_PACIENTE"::text,
    'CANONICAL_CURRENT'
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2('EMAIL',p."Email") is not null

  union all

  select 'PHONE',s.phone_key,c.target_patient_id,'F5_REVIEWED_MATCH'
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  where c.classification='MATCH' and c.target_patient_id is not null and s.phone_key is not null

  union all

  select 'DOCUMENT',s.document_key,c.target_patient_id,'F5_REVIEWED_MATCH'
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  where c.classification='MATCH' and c.target_patient_id is not null and s.document_key is not null

  union all

  select 'EMAIL',s.email_key,c.target_patient_id,'F5_REVIEWED_MATCH'
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  where c.classification='MATCH' and c.target_patient_id is not null and s.email_key is not null
), per_candidate as (
  select
    identifier_type,
    identifier_key,
    canonical_patient_id,
    count(*)::integer evidence_rows,
    bool_or(source_scope='F5_REVIEWED_MATCH') has_reviewed_match,
    jsonb_agg(distinct source_scope order by source_scope) evidence_scopes
  from raw_alias
  where identifier_key is not null and identifier_key <> '' and canonical_patient_id is not null
  group by identifier_type,identifier_key,canonical_patient_id
), scored as (
  select
    pc.*,
    count(*) over(partition by identifier_type,identifier_key)::integer candidate_count
  from per_candidate pc
)
select
  identifier_type,
  identifier_key,
  canonical_patient_id,
  evidence_rows,
  evidence_scopes,
  candidate_count,
  case when candidate_count=1 then 'RESOLVED' else 'CONFLICT' end::text status,
  case
    when identifier_type='CANONICAL_ID' then 'EXACT'
    when has_reviewed_match then 'HIGH'
    else 'MEDIUM'
  end::text confidence_band,
  has_reviewed_match
from scored;

comment on view public.aos_rev_patient_identity_alias_v2 is
'REV-F6.1 private identity lookup bridge. Phone/document/email are governed lookup aliases; canonical_patient_id remains the subject. Conflicting aliases stay explicit.';

revoke all on public.aos_rev_patient_identity_alias_v2 from public, anon, authenticated;
grant select on public.aos_rev_patient_identity_alias_v2 to service_role;

create or replace function public.aos_rev_resolve_patient_identity_v2(p_lookup_type text, p_lookup_value text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_type text := upper(trim(coalesce(p_lookup_type,'')));
  v_key text;
  v_candidates integer := 0;
  v_patient text;
  v_confidence text;
  v_evidence jsonb := '[]'::jsonb;
begin
  if v_type not in ('CANONICAL_ID','PHONE','DOCUMENT','EMAIL') then
    return jsonb_build_object('status','INVALID_LOOKUP_TYPE','canonical_patient_id',null,'candidate_count',0);
  end if;

  v_key := public.aos_rev_normalize_patient_identifier_v2(v_type,p_lookup_value);
  if v_key is null then
    return jsonb_build_object('status','INVALID_IDENTIFIER','lookup_type',v_type,'canonical_patient_id',null,'candidate_count',0);
  end if;

  select count(distinct a.canonical_patient_id), min(a.canonical_patient_id)
  into v_candidates,v_patient
  from public.aos_rev_patient_identity_alias_v2 a
  where a.identifier_type=v_type and a.identifier_key=v_key;

  if v_candidates=0 then
    return jsonb_build_object('status','UNRESOLVED','lookup_type',v_type,'canonical_patient_id',null,'candidate_count',0);
  elsif v_candidates>1 then
    return jsonb_build_object('status','IDENTITY_CONFLICT','lookup_type',v_type,'canonical_patient_id',null,'candidate_count',v_candidates);
  end if;

  select a.confidence_band,a.evidence_scopes
  into v_confidence,v_evidence
  from public.aos_rev_patient_identity_alias_v2 a
  where a.identifier_type=v_type and a.identifier_key=v_key and a.canonical_patient_id=v_patient
  limit 1;

  return jsonb_build_object(
    'status','MATCH',
    'lookup_type',v_type,
    'canonical_patient_id',v_patient,
    'candidate_count',1,
    'confidence_band',v_confidence,
    'evidence_scopes',coalesce(v_evidence,'[]'::jsonb)
  );
end;
$$;

comment on function public.aos_rev_resolve_patient_identity_v2(text,text) is
'REV-F6.1 service-only identity resolver. Never resolves a conflicting alias and never uses fuzzy/phone-proximity identity.';

revoke all on function public.aos_rev_resolve_patient_identity_v2(text,text) from public, anon, authenticated;
grant execute on function public.aos_rev_resolve_patient_identity_v2(text,text) to service_role;

create or replace function public.aos_patient_search_v2(p_token text, p_query text, p_limit integer default 20)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_q text := trim(coalesce(p_query,''));
  v_digits text := regexp_replace(trim(coalesce(p_query,'')),'[^0-9]','','g');
  v_email text := public.aos_rev_normalize_patient_identifier_v2('EMAIL',p_query);
  v_phone text := public.aos_rev_normalize_patient_identifier_v2('PHONE',p_query);
  v_doc text := public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p_query);
  v_limit integer := least(greatest(coalesce(p_limit,20),1),50);
  v_alias_candidates integer := 0;
  v_alias_status text := 'NORMAL';
  v_rows jsonb;
begin
  v_actor := public.aos_app_actor_v3(p_token,'advisor-patients',true);
  if v_actor is null then v_actor := public.aos_app_actor_v3(p_token,'admin-patients',true); end if;
  if v_actor is null then raise exception 'UNAUTHORIZED'; end if;
  if length(v_q)<2 then return jsonb_build_object('ok',true,'lookup_status','QUERY_TOO_SHORT','results','[]'::jsonb); end if;

  if v_phone is not null then
    select coalesce(max(candidate_count),0) into v_alias_candidates
    from public.aos_rev_patient_identity_alias_v2
    where identifier_type='PHONE' and identifier_key=v_phone;
  elsif v_doc is not null then
    select coalesce(max(candidate_count),0) into v_alias_candidates
    from public.aos_rev_patient_identity_alias_v2
    where identifier_type='DOCUMENT' and identifier_key=v_doc;
  elsif v_email is not null then
    select coalesce(max(candidate_count),0) into v_alias_candidates
    from public.aos_rev_patient_identity_alias_v2
    where identifier_type='EMAIL' and identifier_key=v_email;
  end if;
  if v_alias_candidates>1 then v_alias_status := 'IDENTITY_CONFLICT'; end if;

  with alias_hit as (
    select distinct canonical_patient_id
    from public.aos_rev_patient_identity_alias_v2
    where (v_phone is not null and identifier_type='PHONE' and identifier_key=v_phone)
       or (v_doc is not null and identifier_type='DOCUMENT' and identifier_key=v_doc)
       or (v_email is not null and identifier_type='EMAIL' and identifier_key=v_email)
  ), direct_hit as (
    select p."ID_PACIENTE"::text canonical_patient_id
    from public.aos_pacientes p
    where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
      and (
        upper(coalesce(p."Nombres",'')||' '||coalesce(p."Apellidos",'')) like '%'||upper(v_q)||'%'
        or (length(v_digits)>=3 and regexp_replace(coalesce(nullif(p.numero_limpio,''),p."Teléfono",''),'[^0-9]','','g') like '%'||v_digits||'%')
        or (length(v_digits)>=3 and regexp_replace(coalesce(p."N° documento",''),'[^0-9]','','g') like '%'||v_digits||'%')
        or (position('@' in v_q)>0 and lower(coalesce(p."Email",''))=lower(v_q))
      )
    limit 100
  ), ids as (
    select canonical_patient_id from alias_hit
    union
    select canonical_patient_id from direct_hit
  ), ranked as (
    select
      p."ID_PACIENTE"::text canonical_patient_id,
      p."Nombres"::text nombres,
      p."Apellidos"::text apellidos,
      coalesce(nullif(p.numero_limpio,''),p."Teléfono")::text telefono,
      p."N° documento"::text dni,
      p."SEDE_PRINCIPAL"::text sede,
      p."ESTADO_PACIENTE"::text estado,
      exists(select 1 from alias_hit a where a.canonical_patient_id=p."ID_PACIENTE") alias_match,
      (select count(*) from public.aos_f5_canonical_classification_v1 c where c.target_patient_id=p."ID_PACIENTE" and c.classification='MATCH')::integer reviewed_match_clusters,
      (select count(*) from public.aos_f5_canonical_classification_v1 c where c.target_patient_id=p."ID_PACIENTE" and c.classification='REVIEW')::integer review_clusters
    from ids i
    join public.aos_pacientes p on p."ID_PACIENTE"=i.canonical_patient_id
    where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
    order by alias_match desc, upper(coalesce(p."Nombres",'')||' '||coalesce(p."Apellidos",'')),p."ID_PACIENTE"
    limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'canonical_patient_id',canonical_patient_id,
    'nombres',nombres,
    'apellidos',apellidos,
    'telefono',telefono,
    'dni',dni,
    'sede',sede,
    'estado',estado,
    'alias_match',alias_match,
    'identity_status',case when review_clusters>0 then 'REVIEW_REQUIRED' when reviewed_match_clusters>0 then 'REVIEWED_MATCH' else 'CANONICAL_ONLY' end,
    'confidence_band',case when reviewed_match_clusters>0 then 'HIGH' else 'MEDIUM' end
  ) order by alias_match desc,nombres,apellidos),'[]'::jsonb)
  into v_rows from ranked;

  return jsonb_build_object(
    'ok',true,
    'lookup_status',v_alias_status,
    'alias_candidate_count',v_alias_candidates,
    'results',v_rows
  );
end;
$$;

comment on function public.aos_patient_search_v2(text,text,integer) is
'Auth V3 + PASSWORD_2FA Patient 360 search. Exact historical aliases can locate canonical patients; conflicts remain visible and are never auto-assigned.';

revoke all on function public.aos_patient_search_v2(text,text,integer) from public;
grant execute on function public.aos_patient_search_v2(text,text,integer) to anon, authenticated, service_role;

create or replace function public.aos_patient_commercial_360_v2(p_token text, p_lookup_type text, p_lookup_value text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_admin_actor uuid;
  v_is_admin boolean := false;
  v_resolution jsonb;
  v_pid text;
  v_pac jsonb;
  v_completitud jsonb;
  v_missing text[] := '{}';
  v_populated integer := 0;
  v_compras jsonb := '[]'::jsonb;
  v_citas jsonb := '[]'::jsonb;
  v_llamadas jsonb := '[]'::jsonb;
  v_notas jsonb := '[]'::jsonb;
  v_docs jsonb := '[]'::jsonb;
  v_timeline jsonb := '[]'::jsonb;
  v_top_products jsonb := '[]'::jsonb;
  v_sede_history jsonb := '[]'::jsonb;
  v_aliases_admin jsonb := '[]'::jsonb;
  v_total_fact numeric := 0;
  v_total_compras integer := 0;
  v_first_sale date;
  v_last_sale date;
  v_first_activity date;
  v_last_activity date;
  v_future_appointment date;
  v_match_clusters integer := 0;
  v_review_clusters integer := 0;
  v_strong_conflicts integer := 0;
  v_alias_count integer := 0;
  v_phone_alias_count integer := 0;
  v_hist_phone_alias_count integer := 0;
  v_alias_conflicts integer := 0;
  v_f4_rows integer := 0;
  v_confirmed_balance_rows integer := 0;
  v_payment_evidence_rows integer := 0;
  v_f6 jsonb;
  v_identity_confidence text;
  v_duplicate_class text;
  v_vip text;
begin
  v_actor := public.aos_app_actor_v3(p_token,'advisor-patients',true);
  if v_actor is null then v_actor := public.aos_app_actor_v3(p_token,'admin-patients',true); end if;
  if v_actor is null then raise exception 'UNAUTHORIZED'; end if;

  v_admin_actor := public.aos_app_actor_v3(p_token,'admin-patients',true);
  v_is_admin := v_admin_actor is not null;

  v_resolution := public.aos_rev_resolve_patient_identity_v2(p_lookup_type,p_lookup_value);
  if coalesce(v_resolution->>'status','') <> 'MATCH' then
    return jsonb_build_object(
      'found',false,
      'ok',true,
      'contract','REV-F6.1_PATIENT_COMMERCIAL_360_V2',
      'identity_resolution',v_resolution,
      'clinical_access',v_is_admin
    );
  end if;
  v_pid := v_resolution->>'canonical_patient_id';

  select jsonb_build_object(
    'id',p."ID_PACIENTE",
    'canonical_patient_id',p."ID_PACIENTE",
    'nombres',p."Nombres",
    'apellidos',p."Apellidos",
    'telefono',coalesce(nullif(p.numero_limpio,''),p."Teléfono"),
    'dni',p."N° documento",
    'correo',p."Email",
    'sexo',p."Sexo",
    'fecha_nac',p."Fecha de nacimiento",
    'direccion',p."Dirección",
    'ocupacion',p."Ocupación",
    'sede',p."SEDE_PRINCIPAL",
    'fuente',p."FUENTE",
    'fecha_registro',p."FECHA_REGISTRO",
    'estado',p."ESTADO_PACIENTE",
    'etiqueta',p."ETIQUETA_BASE",
    'score',p."SCORE_ESTADO",
    'trat_principal',p.tratamiento_principal,
    'pais',p.pais,
    'departamento',p.departamento,
    'ciudad',p.ciudad,
    'distrito',p.distrito,
    'contacto_emergencia',case when v_is_admin then p.contacto_emergencia else null end,
    'estado_civil',p.estado_civil,
    'dias_ultima_visita',p."DIAS_ULTIMA_VISITA"
  ) into v_pac
  from public.aos_pacientes p
  where p."ID_PACIENTE"=v_pid and coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
  limit 1;

  if v_pac is null then
    return jsonb_build_object('found',false,'ok',true,'contract','REV-F6.1_PATIENT_COMMERCIAL_360_V2','identity_resolution',jsonb_set(v_resolution,'{status}','"CANONICAL_TARGET_MISSING"'::jsonb));
  end if;

  -- Commercial completeness uses the same 14 fields frozen by REV-F5.9; null is not automatically an error.
  if nullif(trim(coalesce(v_pac->>'nombres','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Nombres'); end if;
  if nullif(trim(coalesce(v_pac->>'apellidos','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Apellidos'); end if;
  if nullif(trim(coalesce(v_pac->>'telefono','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Teléfono'); end if;
  if nullif(trim(coalesce(v_pac->>'correo','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Email'); end if;
  if nullif(trim(coalesce(v_pac->>'dni','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Documento'); end if;
  if nullif(trim(coalesce(v_pac->>'sexo','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Sexo'); end if;
  if nullif(trim(coalesce(v_pac->>'fecha_nac','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Fecha nacimiento'); end if;
  if nullif(trim(coalesce(v_pac->>'direccion','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Dirección'); end if;
  if nullif(trim(coalesce(v_pac->>'distrito','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Distrito'); end if;
  if nullif(trim(coalesce(v_pac->>'ciudad','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Ciudad'); end if;
  if nullif(trim(coalesce(v_pac->>'departamento','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Departamento'); end if;
  if nullif(trim(coalesce(v_pac->>'ocupacion','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Ocupación'); end if;
  if nullif(trim(coalesce(v_pac->>'sede','')),'') is not null then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Sede principal'); end if;
  if exists(select 1 from public.aos_pacientes p where p."ID_PACIENTE"=v_pid and p.ult_visita is not null) then v_populated:=v_populated+1; else v_missing:=array_append(v_missing,'Última visita'); end if;
  v_completitud := jsonb_build_object('pct',round(100.0*v_populated/14.0,2),'populated',v_populated,'denominator',14,'faltantes',to_jsonb(v_missing));

  select
    count(*) filter(where c.classification='MATCH')::integer,
    count(*) filter(where c.classification='REVIEW')::integer,
    count(*) filter(where c.source_strong_conflict)::integer
  into v_match_clusters,v_review_clusters,v_strong_conflicts
  from public.aos_f5_canonical_classification_v1 c
  where c.target_patient_id=v_pid;

  select
    count(distinct identifier_type||':'||identifier_key)::integer,
    count(distinct identifier_key) filter(where identifier_type='PHONE' and candidate_count=1)::integer,
    count(distinct identifier_key) filter(where identifier_type='PHONE' and candidate_count=1 and evidence_scopes @> '["F5_REVIEWED_MATCH"]'::jsonb)::integer,
    count(distinct identifier_type||':'||identifier_key) filter(where candidate_count>1)::integer
  into v_alias_count,v_phone_alias_count,v_hist_phone_alias_count,v_alias_conflicts
  from public.aos_rev_patient_identity_alias_v2
  where canonical_patient_id=v_pid;

  v_identity_confidence := case
    when v_strong_conflicts>0 or v_alias_conflicts>0 then 'CONFLICT'
    when v_match_clusters>0 then 'HIGH'
    else coalesce(v_resolution->>'confidence_band','MEDIUM')
  end;
  v_duplicate_class := case
    when v_strong_conflicts>0 or v_alias_conflicts>0 then 'IDENTITY_CONFLICT'
    when v_review_clusters>0 then 'STRONG_REVIEW'
    when v_match_clusters>0 then 'EXACT_SAFE_CANDIDATE'
    else 'HOMONYM / DO_NOT_MERGE'
  end;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'sale_id',v.id,
      'fecha',v.fecha,
      'tratamiento',v.tratamiento,
      'descripcion',v.descripcion,
      'monto',v.monto,
      'tipo',v.tipo,
      'sede',v.sede,
      'asesor',v.asesor,
      'pago',v.pago,
      'estado_pago',v.estado_pago,
      'product_key',j.product_key,
      'product_resolution_status',j.product_resolution_status,
      'cartera_link_status',j.cartera_link_status
    ) order by v.fecha desc,v.id desc),'[]'::jsonb),
    coalesce(sum(v.monto),0),count(*)::integer,min(v.fecha),max(v.fecha)
  into v_compras,v_total_fact,v_total_compras,v_first_sale,v_last_sale
  from public.aos_f5_historical_join_v1 j
  join public.aos_ventas v on v.id=j.sale_id
  where j.patient_link_status='MATCH' and j.canonical_patient_id=v_pid;

  select
    count(*)::integer,
    count(*) filter(where coalesce(r.payment_evidence_row_count,0)>0)::integer,
    count(*) filter(where coalesce(r.confirmed_balance_row_count,0)>0)::integer
  into v_f4_rows,v_payment_evidence_rows,v_confirmed_balance_rows
  from public.aos_f5_historical_join_v1 r
  where r.patient_link_status='MATCH' and r.canonical_patient_id=v_pid and r.cartera_link_status='F4_LINKED';

  select coalesce(jsonb_agg(x order by x.cnt desc,x.canonical_name),'[]'::jsonb)
  into v_top_products
  from (
    select f.product_key,f.canonical_name,count(*)::integer cnt
    from public.aos_f5_historical_join_v1 j
    join public.aos_product_sale_fact_current_v1 f on f.sale_id=j.sale_id
    where j.patient_link_status='MATCH' and j.canonical_patient_id=v_pid and f.resolution_status='RESOLVED'
    group by f.product_key,f.canonical_name
    order by count(*) desc,f.canonical_name
    limit 10
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'fecha',c.fecha_cita,'hora',c.hora_cita,'tratamiento',c.tratamiento,'tipo_cita',c.tipo_cita,
    'sede',c.sede,'estado',c.estado_cita,'doctora',c.doctora,'asesor',c.asesor,'link_method','IDENTITY_BRIDGE_V2'
  ) order by c.fecha_cita desc,c.ts_creado desc nulls last),'[]'::jsonb),
  min(c.fecha_cita),max(c.fecha_cita),min(c.fecha_cita) filter(where c.fecha_cita>=current_date)
  into v_citas,v_first_activity,v_last_activity,v_future_appointment
  from public.aos_agenda_citas c
  where public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(c.numero_limpio,''),c.numero)) in (
    select identifier_key from public.aos_rev_patient_identity_alias_v2
    where identifier_type='PHONE' and canonical_patient_id=v_pid and candidate_count=1
  );

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',l.id,'fecha',l.fecha,'hora',l.hora_llamada,'tratamiento',l.tratamiento,'estado',l.estado,'sub_estado',l.sub_estado,
    'obs',l.observacion,'asesor',l.asesor,'lead_id_origen',l.lead_id_origen,'link_method','IDENTITY_BRIDGE_V2'
  ) order by l.fecha desc,l.id desc),'[]'::jsonb)
  into v_llamadas
  from (
    select * from public.aos_llamadas l
    where public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(l.numero_limpio,''),l.numero)) in (
      select identifier_key from public.aos_rev_patient_identity_alias_v2
      where identifier_type='PHONE' and canonical_patient_id=v_pid and candidate_count=1
    )
    order by l.fecha desc,l.id desc
    limit 100
  ) l;

  if v_is_admin then
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',n.id,'tipo_nota',n.tipo_nota,'contenido',n.texto,'evolucion',n.evolucion,'diagnostico',n.diagnostico,
      'plan_trabajo',n.plan_trabajo,'pronostico',n.pronostico,'resultado_estudios',n.resultado_estudios,'triaje',n.triaje,
      'nota_adicional',n.nota_adicional,'autor',n.usuario,'rol_autor',n.rol_autor,'sede',n.sede,'created_at',n.ts_creado
    ) order by n.ts_creado desc),'[]'::jsonb)
    into v_notas
    from public.aos_notas_pacientes n
    where public.aos_rev_normalize_patient_identifier_v2('PHONE',n.numero) in (
      select identifier_key from public.aos_rev_patient_identity_alias_v2
      where identifier_type='PHONE' and canonical_patient_id=v_pid and candidate_count=1
    );

    select coalesce(jsonb_agg(jsonb_build_object(
      'id',d.id,'tipo_documento',d.tipo,'nombre_archivo',d.nombre_archivo,'url_archivo',d.url_drive,
      'fecha',d.fecha,'autor',d.usuario,'created_at',d.ts_creado
    ) order by d.ts_creado desc),'[]'::jsonb)
    into v_docs
    from public.aos_documentos_pacientes d
    where public.aos_rev_normalize_patient_identifier_v2('PHONE',d.numero) in (
      select identifier_key from public.aos_rev_patient_identity_alias_v2
      where identifier_type='PHONE' and canonical_patient_id=v_pid and candidate_count=1
    );

    select coalesce(jsonb_agg(jsonb_build_object(
      'type',a.identifier_type,
      'masked',case
        when a.identifier_type='PHONE' then '*****'||right(a.identifier_key,4)
        when a.identifier_type='DOCUMENT' then '****'||right(a.identifier_key,4)
        when a.identifier_type='EMAIL' then left(a.identifier_key,1)||'***@'||split_part(a.identifier_key,'@',2)
        else left(a.identifier_key,4)||'…'
      end,
      'status',a.status,
      'confidence_band',a.confidence_band,
      'evidence_scopes',a.evidence_scopes
    ) order by a.identifier_type,a.identifier_key),'[]'::jsonb)
    into v_aliases_admin
    from public.aos_rev_patient_identity_alias_v2 a
    where a.canonical_patient_id=v_pid and a.identifier_type<>'CANONICAL_ID';
  end if;

  with phone_alias as (
    select identifier_key from public.aos_rev_patient_identity_alias_v2
    where identifier_type='PHONE' and canonical_patient_id=v_pid and candidate_count=1
  ), sale_event as (
    select v.fecha::date event_date,coalesce(v.created_at,v.fecha::timestamptz) event_ts,
      'SALE'::text event_type,('sale:'||v.id)::text event_id,
      coalesce(f.canonical_name,v.tratamiento,'Venta')::text label,v.sede::text sede,null::text status,v.monto::numeric amount,'F5_SALE_MATCH'::text provenance
    from public.aos_f5_historical_join_v1 j
    join public.aos_ventas v on v.id=j.sale_id
    left join public.aos_product_sale_fact_current_v1 f on f.sale_id=v.id
    where j.patient_link_status='MATCH' and j.canonical_patient_id=v_pid
  ), appointment_event as (
    select c.fecha_cita::date event_date,coalesce(c.ts_creado,c.fecha_cita::timestamptz) event_ts,
      'APPOINTMENT'::text event_type,('appointment:'||c.id)::text event_id,
      coalesce(c.tratamiento,'Cita')::text label,c.sede::text sede,c.estado_cita::text status,null::numeric amount,'IDENTITY_BRIDGE_V2'::text provenance
    from public.aos_agenda_citas c
    where public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(c.numero_limpio,''),c.numero)) in (select identifier_key from phone_alias)
  ), call_event as (
    select l.fecha::date event_date,coalesce(l.created_at,l.fecha::timestamptz) event_ts,
      'CALL'::text event_type,('call:'||l.id)::text event_id,
      coalesce(l.tratamiento,'Contacto')::text label,null::text sede,coalesce(l.sub_estado,l.estado)::text status,null::numeric amount,'IDENTITY_BRIDGE_V2'::text provenance
    from public.aos_llamadas l
    where public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(l.numero_limpio,''),l.numero)) in (select identifier_key from phone_alias)
  ), lead_event as (
    select l.fecha::date event_date,coalesce(l.hora_ingreso,l.created_at,l.fecha::timestamptz) event_ts,
      'LEAD'::text event_type,('lead:'||l.id)::text event_id,
      coalesce(l.tratamiento,'Lead')::text label,null::text sede,null::text status,null::numeric amount,'IDENTITY_BRIDGE_V2'::text provenance
    from public.aos_leads l
    where public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(l.numero_limpio,''),l.celular)) in (select identifier_key from phone_alias)
  ), f4_event as (
    select coalesce(r.confirmed_at,r.updated_at,r.created_at)::date event_date,coalesce(r.confirmed_at,r.updated_at,r.created_at) event_ts,
      'FINANCIAL_EVIDENCE'::text event_type,('f4:'||r.id)::text event_id,
      coalesce(r.source_type,'F4')::text label,null::text sede,r.estado_reconciliacion::text status,null::numeric amount,'F4_RECONCILIATION'::text provenance
    from public.aos_cartera_reconciliacion r
    join public.aos_f5_historical_join_v1 j on j.sale_id=r.venta_row_id
    where j.patient_link_status='MATCH' and j.canonical_patient_id=v_pid
  ), all_events as (
    select * from sale_event union all select * from appointment_event union all select * from call_event union all select * from lead_event union all select * from f4_event
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'event_date',event_date,'event_ts',event_ts,'event_type',event_type,'event_id',event_id,
    'label',label,'sede',sede,'status',status,'amount',amount,'provenance',provenance
  ) order by event_ts desc nulls last,event_type,event_id),'[]'::jsonb)
  into v_timeline
  from (select * from all_events order by event_ts desc nulls last limit 200) e;

  select coalesce(jsonb_agg(jsonb_build_object('sede',sede,'sales_count',cnt,'observed_amount',amount) order by cnt desc,sede),'[]'::jsonb)
  into v_sede_history
  from (
    select coalesce(v.sede,'SIN_SEDE') sede,count(*)::integer cnt,coalesce(sum(v.monto),0) amount
    from public.aos_f5_historical_join_v1 j join public.aos_ventas v on v.id=j.sale_id
    where j.patient_link_status='MATCH' and j.canonical_patient_id=v_pid
    group by coalesce(v.sede,'SIN_SEDE')
  ) s;

  v_vip := case when v_total_fact>=20000 then 'DIAMANTE' when v_total_fact>=15000 then 'VIP' when v_total_fact>=5000 then 'PREMIUM' else 'NORMAL' end;
  v_pac := jsonb_set(v_pac,'{etiqueta_vip}',to_jsonb(v_vip));

  v_f6 := public.aos_rev_f6_data_contract_v1()->'contract';

  return jsonb_build_object(
    'ok',true,
    'found',true,
    'contract','REV-F6.1_PATIENT_COMMERCIAL_360_V2',
    'readOnly',true,
    'paciente',v_pac,
    'identity_resolution',v_resolution,
    'identity',jsonb_build_object(
      'canonical_patient_id',v_pid,
      'status',case when v_review_clusters>0 then 'REVIEW_REQUIRED' when v_match_clusters>0 then 'REVIEWED_MATCH' else 'CANONICAL_ONLY' end,
      'confidence_band',v_identity_confidence,
      'duplicate_evidence_class',v_duplicate_class,
      'reviewed_match_clusters',v_match_clusters,
      'review_clusters',v_review_clusters,
      'strong_conflicts',v_strong_conflicts,
      'alias_count',v_alias_count,
      'phone_alias_count',v_phone_alias_count,
      'historical_phone_alias_count',v_hist_phone_alias_count,
      'alias_conflicts',v_alias_conflicts,
      'historical_contact_indicator',(v_hist_phone_alias_count>0),
      'aliases_admin',case when v_is_admin then v_aliases_admin else null end
    ),
    'commercial_summary',jsonb_build_object(
      'observed_sales_amount',v_total_fact,
      'purchase_count',v_total_compras,
      'first_observed_sale',v_first_sale,
      'last_observed_sale',v_last_sale,
      'first_observed_appointment',v_first_activity,
      'last_observed_appointment',v_last_activity,
      'future_appointment',v_future_appointment,
      'top_products',v_top_products,
      'sede_history',v_sede_history,
      'lifecycle_state','PENDING_REV_F6_2',
      'reactivation_count_status','PENDING_REV_F6_2',
      'observed_paid_amount',null,
      'payment_truth_status',case when v_payment_evidence_rows>0 then 'PAYMENT_EVIDENCE_PRESENT_REVIEW_F4' else 'NO_CONFIRMED_PAYMENT_EVIDENCE' end,
      'f4_linked_sales',v_f4_rows,
      'payment_evidence_rows',v_payment_evidence_rows,
      'confirmed_balance_rows',v_confirmed_balance_rows
    ),
    'metric_trust',jsonb_build_object(
      'coverage',jsonb_build_object(
        'identity',v_f6->'coverage'->'identity',
        'sales_linkage',v_f6->'coverage'->'sales_linkage',
        'f3_product',v_f6->'coverage'->'f3_product',
        'f4_financial_evidence',v_f6->'coverage'->'f4_financial_evidence',
        'historical_transaction_source_availability',v_f6->'coverage'->'historical_transaction_source_availability'
      ),
      'confidence',v_identity_confidence,
      'freshness',v_f6->'freshness_sources',
      'sample_size',jsonb_build_object('patient_observed_sales',v_total_compras,'timeline_events',jsonb_array_length(v_timeline)),
      'coverage_period',jsonb_build_object('sales_min_date',v_f6->'canonical_state'->'sales_min_date','sales_max_date',v_f6->'canonical_state'->'sales_max_date'),
      'historical_warning','2024/2025 transactional sales = NO_CERTIFIED_SOURCE; observed totals are not lifetime truth'
    ),
    'intelligence',jsonb_build_object('lifecycle','PENDING_REV_F6_2','metric_trust_enrichment','PENDING_REV_F6_3','sales_intelligence','PENDING_REV_F6_4'),
    'timeline',v_timeline,
    'clinical_access',v_is_admin,
    -- compatibility payload for the existing Patient 360 and Citas surfaces
    'compras',v_compras,
    'totalFacturado',v_total_fact,
    'totalCompras',v_total_compras,
    'citas',v_citas,
    'llamadas',v_llamadas,
    'seguimientos','[]'::jsonb,
    'duplicados','[]'::jsonb,
    'notas',v_notas,
    'documentos',v_docs,
    'completitud',v_completitud
  );
end;
$$;

comment on function public.aos_patient_commercial_360_v2(text,text,text) is
'REV-F6.1 identity-aware Patient Commercial 360. Canonical identity + governed aliases + certified sale/F3/F4 facts + explicit trust metadata. Clinical arrays are admin+2FA only.';

revoke all on function public.aos_patient_commercial_360_v2(text,text,text) from public;
grant execute on function public.aos_patient_commercial_360_v2(text,text,text) to anon, authenticated, service_role;

select pg_notify('pgrst','reload schema');

commit;
