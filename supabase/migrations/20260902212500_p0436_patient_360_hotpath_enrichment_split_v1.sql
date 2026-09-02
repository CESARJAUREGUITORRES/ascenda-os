-- ASCENDA OS · P0 #436 · Patient 360 hot-path/enrichment split V1
-- Root cause: anon PostgREST has statement_timeout=3s while the current Patient 360
-- executes legacy core + identity confidence + lifecycle synchronously (~4s+ on P-5549).
-- Invariant: do NOT raise statement_timeout. Operational Patient 360 must render first;
-- analytical context is requested later, serially, through the governed wrapper below.

begin;

create or replace function public.aos_patient_360_current_v3(
  p_token text,
  p_canonical_patient_id text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_admin uuid;
  v_pid text := trim(coalesce(p_canonical_patient_id,''));
  v_phone text;
  v_patient jsonb;
  v_core jsonb;
  v_sales_intelligence jsonb := '{}'::jsonb;
  v_review_clusters integer := 0;
  v_match_clusters integer := 0;
  v_strong_conflicts integer := 0;
begin
  v_actor := public.aos_app_actor_v3(p_token,'advisor-patients',true);
  if v_actor is null then
    v_actor := public.aos_app_actor_v3(p_token,'admin-patients',true);
  end if;
  if v_actor is null then
    raise exception 'UNAUTHORIZED';
  end if;

  v_admin := public.aos_app_actor_v3(p_token,'admin-patients',true);

  if v_pid = '' then
    return jsonb_build_object(
      'ok',true,'found',false,'contract','REV-PATIENT-360-CURRENT-V3',
      'identity_resolution',jsonb_build_object('status','INVALID_CANONICAL_ID')
    );
  end if;

  select
    jsonb_build_object(
      'id',p."ID_PACIENTE",
      'canonical_patient_id',p."ID_PACIENTE",
      'nombres',p."Nombres",
      'apellidos',p."Apellidos",
      'telefono',coalesce(nullif(p.numero_limpio,''),regexp_replace(coalesce(p."Teléfono",''),'[^0-9]','','g')),
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
      'notas',p."NOTAS",
      'etiqueta',p."ETIQUETA_BASE",
      'score',p."SCORE_ESTADO",
      'trat_principal',p.tratamiento_principal,
      'pais',p.pais,
      'departamento',p.departamento,
      'ciudad',p.ciudad,
      'distrito',p.distrito,
      'contacto_emergencia',case when v_admin is not null then p.contacto_emergencia else null end,
      'estado_civil',p.estado_civil,
      'etiqueta_vip',coalesce(p.etiqueta_vip,'NORMAL'),
      'dias_ultima_visita',p."DIAS_ULTIMA_VISITA"
    ),
    coalesce(nullif(p.numero_limpio,''),regexp_replace(coalesce(p."Teléfono",''),'[^0-9]','','g'))
  into v_patient,v_phone
  from public.aos_pacientes p
  where p."ID_PACIENTE"=v_pid
    and coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
  limit 1;

  if v_patient is null then
    return jsonb_build_object(
      'ok',true,'found',false,'contract','REV-PATIENT-360-CURRENT-V3',
      'identity_resolution',jsonb_build_object('status','CANONICAL_TARGET_MISSING','canonical_patient_id',v_pid)
    );
  end if;

  -- Operational history is the only substantial synchronous read left in the hot path.
  -- Keep canonical-ID authority and fail closed if the legacy phone core resolves another subject.
  v_core := public.aos_paciente_360(v_phone);

  if not coalesce((v_core->>'found')::boolean,false)
     or coalesce(v_core#>>'{paciente,id}','') <> v_pid then
    v_core := jsonb_build_object(
      'found',true,
      'paciente',v_patient,
      'compras','[]'::jsonb,
      'totalFacturado',null,
      'totalCompras',null,
      'citas','[]'::jsonb,
      'llamadas','[]'::jsonb,
      'seguimientos','[]'::jsonb,
      'duplicados','[]'::jsonb,
      'notas','[]'::jsonb,
      'documentos','[]'::jsonb,
      'completitud',jsonb_build_object('pct',null,'faltantes','[]'::jsonb),
      'legacy_link_status','AMBIGUOUS_OR_UNAVAILABLE'
    );
  else
    v_core := jsonb_set(v_core,'{paciente}',v_patient,true);
    v_core := v_core || jsonb_build_object('legacy_link_status','MATCH');
  end if;

  select
    count(*) filter(where c.classification='REVIEW')::integer,
    count(*) filter(where c.classification='MATCH')::integer,
    count(*) filter(where c.source_strong_conflict)::integer
  into v_review_clusters,v_match_clusters,v_strong_conflicts
  from public.aos_f5_canonical_classification_v1 c
  where c.target_patient_id=v_pid;

  -- Patient-value enrichment is currently a cheap targeted read and stays in the hot path.
  -- If it ever becomes expensive, it must move behind the same deferred boundary.
  begin
    v_sales_intelligence := coalesce(public.aos_rev_si_patient_value_by_patient_v1(v_pid),'{}'::jsonb);
  exception when others then
    v_sales_intelligence := jsonb_build_object('source_status','UNKNOWN','limitations',jsonb_build_array('SALES_INTELLIGENCE_ENRICHMENT_UNAVAILABLE'));
  end;

  if v_admin is null then
    v_core := jsonb_set(v_core,'{notas}','[]'::jsonb,true);
    v_core := jsonb_set(v_core,'{documentos}','[]'::jsonb,true);
  end if;

  return v_core || jsonb_build_object(
    'ok',true,
    'found',true,
    'contract','REV-PATIENT-360-CURRENT-V3',
    'readOnly',true,
    'clinical_access',(v_admin is not null),
    'identity',jsonb_build_object(
      'canonical_patient_id',v_pid,
      'current_status','RESOLVED',
      'historical_status',case when v_review_clusters>0 then 'REVIEW_REQUIRED' else 'NO_PENDING_REVIEW' end,
      'historical_review_required',(v_review_clusters>0),
      'review_clusters',v_review_clusters,
      'reviewed_match_clusters',v_match_clusters,
      'strong_conflicts',v_strong_conflicts
    ),
    'identity_confidence',jsonb_build_object('enrichment_status','DEFERRED'),
    'lifecycle',jsonb_build_object('enrichment_status','DEFERRED'),
    'sales_intelligence',v_sales_intelligence,
    'enrichment_status',jsonb_build_object(
      'mode','SERIAL_DEFERRED',
      'identity_confidence','PENDING',
      'lifecycle','PENDING'
    ),
    'provenance',jsonb_build_array('LEGACY_PATIENT_360_RESTORED','CANONICAL_CURRENT','REV-F5','REV-F6','P0436_HOTPATH_SPLIT')
  );
end;
$$;

revoke all on function public.aos_patient_360_current_v3(text,text) from public;
grant execute on function public.aos_patient_360_current_v3(text,text) to anon, authenticated, service_role;

-- One analytical section per call. This is deliberately NOT a combined enrichment RPC:
-- identity confidence and lifecycle are each below the anon 3s budget in LIVE profiling,
-- while their combined execution would again create a fragile near-timeout path.
create or replace function public.aos_patient_360_enrichment_v1(
  p_token text,
  p_canonical_patient_id text,
  p_section text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_pid text := trim(coalesce(p_canonical_patient_id,''));
  v_section text := upper(trim(coalesce(p_section,'')));
  v_payload jsonb;
begin
  v_actor := public.aos_app_actor_v3(p_token,'advisor-patients',true);
  if v_actor is null then
    v_actor := public.aos_app_actor_v3(p_token,'admin-patients',true);
  end if;
  if v_actor is null then
    raise exception 'UNAUTHORIZED';
  end if;

  if v_pid='' or not exists(
    select 1 from public.aos_pacientes p
    where p."ID_PACIENTE"=v_pid and coalesce(p."ESTADO_PACIENTE",'')<>'FUSIONADO'
  ) then
    return jsonb_build_object(
      'ok',true,'found',false,'contract','P0436-PATIENT-360-ENRICHMENT-V1',
      'canonical_patient_id',v_pid,'section',v_section,
      'status','CANONICAL_TARGET_MISSING'
    );
  end if;

  if v_section='IDENTITY_CONFIDENCE' then
    v_payload := coalesce(public.aos_rev_identity_confidence_by_patient_v1(v_pid),'{}'::jsonb);
  elsif v_section='LIFECYCLE' then
    v_payload := coalesce(
      public.aos_rev_customer_lifecycle_by_patient_v1(v_pid,public.aos_rev_business_date_lima_v1()),
      '{}'::jsonb
    );
  else
    return jsonb_build_object(
      'ok',false,'found',true,'contract','P0436-PATIENT-360-ENRICHMENT-V1',
      'canonical_patient_id',v_pid,'section',v_section,'error','SECTION_NOT_ALLOWED'
    );
  end if;

  return jsonb_build_object(
    'ok',true,'found',true,'contract','P0436-PATIENT-360-ENRICHMENT-V1',
    'canonical_patient_id',v_pid,'section',v_section,
    'payload',v_payload
  );
end;
$$;

revoke all on function public.aos_patient_360_enrichment_v1(text,text,text) from public;
grant execute on function public.aos_patient_360_enrichment_v1(text,text,text) to anon, authenticated, service_role;

select pg_notify('pgrst','reload schema');
commit;
