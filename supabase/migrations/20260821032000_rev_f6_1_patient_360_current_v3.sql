-- REV patient rebuild — restore the proven Patient 360 reader as a private core
-- and expose a governed canonical-current read that F5/F6 enriches instead of blocks.

alter function public.aos_paciente_360(text)
  set search_path = pg_catalog, public;

revoke all on function public.aos_paciente_360(text) from public, anon, authenticated;
grant execute on function public.aos_paciente_360(text) to service_role;

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
  v_identity jsonb := '{}'::jsonb;
  v_lifecycle jsonb := '{}'::jsonb;
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

  -- Preserve the proven pre-F6 Patient 360 aggregation. It remains browser-closed;
  -- only this Auth V3 wrapper can expose its payload.
  v_core := public.aos_paciente_360(v_phone);

  -- Never allow a phone collision inside the legacy core to substitute another patient.
  -- The current canonical record remains visible; ambiguous cross-source sections fail closed.
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
    -- Canonical row is authority for current demographic fields after F5 enrichment.
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

  begin
    v_identity := coalesce(public.aos_rev_identity_confidence_by_patient_v1(v_pid),'{}'::jsonb);
  exception when others then
    v_identity := jsonb_build_object('confidence_level','UNKNOWN','limitations',jsonb_build_array('IDENTITY_ENRICHMENT_UNAVAILABLE'));
  end;

  begin
    v_lifecycle := coalesce(public.aos_rev_customer_lifecycle_by_patient_v1(v_pid,public.aos_rev_business_date_lima_v1()),'{}'::jsonb);
  exception when others then
    v_lifecycle := jsonb_build_object('classification_status','UNKNOWN','limitations',jsonb_build_array('LIFECYCLE_ENRICHMENT_UNAVAILABLE'));
  end;

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
    'identity_confidence',v_identity,
    'lifecycle',v_lifecycle,
    'sales_intelligence',v_sales_intelligence,
    'provenance',jsonb_build_array('LEGACY_PATIENT_360_RESTORED','CANONICAL_CURRENT','REV-F5','REV-F6')
  );
end;
$$;

revoke all on function public.aos_patient_360_current_v3(text,text) from public;
grant execute on function public.aos_patient_360_current_v3(text,text) to anon, authenticated, service_role;
