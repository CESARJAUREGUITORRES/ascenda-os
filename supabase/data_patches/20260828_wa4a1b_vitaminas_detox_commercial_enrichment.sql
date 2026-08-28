-- WA-4A.1B business-content patch (PROD-safe DML, no schema changes)
-- Scope: exactly active SERVICIO rows in VITAMINAS / DETOX whose commercial description or indications are empty.
-- Sources: existing canonical row identity + Zi Vital Commercial Architecture 2026.
-- This patch intentionally DOES NOT rewrite formulas/composition. Vitamin formulas remain CATEGORY_TEMPLATE_REVIEW until exact authoritative formula evidence exists.
begin;

update public.aos_catalogo_servicios
set
  descripcion_comercial = case
    when categoria='DETOX' then
      nombre || ' se integra en Zi Vital como una herramienta de preparación y acompañamiento dentro de Body Reset. Se comunica como una experiencia de soporte, descarga y acondicionamiento previo cuando el plan lo contempla, no como una solución milagrosa ni como extracción demostrada de toxinas.'
    when nombre='HIERRO SACAROSA EV' then
      'HIERRO SACAROSA EV es un servicio de administración endovenosa que se maneja dentro de Zi Vital únicamente bajo evaluación e indicación profesional. No se presenta como vitamina de bienestar general ni como protocolo autónomo; su lugar dentro del proceso depende del criterio clínico.'
    when nombre like 'OZONO HEMOTERAPIA%' then
      nombre || ' es un procedimiento clínico de soporte sistémico que Zi Vital mantiene bajo evaluación profesional. Comercialmente se explica por su función dentro del plan y no mediante promesas universales de bienestar o resultados estéticos.'
    when nombre='B12' or nombre like 'B12 + %' then
      nombre || ' es un protocolo de soporte sistémico centrado en vitamina B12 dentro de la arquitectura Zi Vital. Puede formar parte de preparación o acompañamiento cuando el plan clínico lo indica; la vía, combinación y frecuencia se definen profesionalmente.'
    when nombre='FULL B (EV o IM)' or nombre like 'FULL B + %' or nombre like 'VITC + FULL B + %' or nombre='FULL B VITAL DETOX' then
      nombre || ' es un protocolo de soporte sistémico basado en el concepto Full B dentro de Zi Vital. Se integra como apoyo de preparación o continuidad según evaluación; la formulación exacta, vía y frecuencia pertenecen al plan clínico vigente.'
    when nombre like '%VITAMINA C%' or nombre like 'COC. VITC%' or nombre like 'VITC + B12%' or nombre='DÚO ESENCIAL (VIT C + B12)' or nombre='VITA POWER (VITC+CH+L+P)' then
      nombre || ' es un protocolo de soporte sistémico con vitamina C declarada en su identidad comercial. En Zi Vital se contextualiza dentro de preparación o acompañamiento, sin presentarlo como solución universal; combinación, vía y frecuencia se confirman en evaluación.'
    when nombre in ('1 SUPLEMENTO','2 SUPLEMENTOS','3 SUPLEMENTOS') then
      nombre || ' representa un módulo de suplementación personalizada dentro del proceso Zi Vital. Su contenido no se infiere por el nombre: los componentes concretos deben provenir del plan clínico y de la fórmula vigente del servicio.'
    else
      nombre || ' es un protocolo de soporte sistémico del portafolio Zi Vital. Su valor se explica por la función que cumple dentro de la preparación, acompañamiento o continuidad del proceso, no como una aplicación aislada. La fórmula exacta, vía y frecuencia deben confirmarse en el plan clínico vigente.'
  end,
  indicaciones = case
    when categoria='DETOX' then
      'Puede incorporarse como soporte de Fase 1 — Preparación/Activación o como acompañamiento de Body Reset cuando el plan lo contemple. No sustituye funciones fisiológicas de hígado o riñón, evaluación médica ni tratamiento de una enfermedad; evitar comunicarlo como eliminación comprobada de toxinas.'
    when nombre='HIERRO SACAROSA EV' then
      'Solo debe programarse cuando exista evaluación e indicación profesional específica. La elegibilidad, dosis, vía, controles y frecuencia corresponden al equipo clínico; no debe sugerirse autónomamente por síntomas, cansancio o una consulta comercial.'
    when nombre like 'OZONO HEMOTERAPIA%' then
      'Requiere evaluación profesional previa. Su inclusión, técnica, frecuencia y continuidad dependen del plan clínico; no debe proponerse como respuesta genérica ante fatiga, inflamación u objetivos estéticos sin valoración.'
    else
      'Puede integrarse como soporte transversal en Fase 1 — Preparación/Activación o Fase 3 — Acompañamiento/Continuidad cuando el plan clínico lo justifique. La fórmula exacta, vía, cantidad, frecuencia, contraindicaciones e interacciones deben confirmarse por el profesional responsable antes de su uso.'
  end,
  info_extendida = coalesce(info_extendida,'{}'::jsonb) || jsonb_build_object(
    'knowledge_enrichment_v1b', jsonb_build_object(
      'sync_version','WA4A1B_ZV_COMMERCIAL_20260828_V1',
      'source_code','ZV_COMMERCIAL_ARCH_2026',
      'source_kind','GOVERNED_COMMERCIAL_KNOWLEDGE',
      'commercial_phase', case when categoria='DETOX' then jsonb_build_array('COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F3_CONTINUITY') else jsonb_build_array('COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F3_CONTINUITY') end,
      'formula_state', case when categoria='VITAMINAS' then 'CATEGORY_TEMPLATE_REVIEW' else 'COMPLETE_SOURCE' end,
      'clinical_boundary','PROFESSIONAL_EVALUATION_REQUIRED',
      'price_authority','CATALOG_RUNTIME',
      'enriched_at','2026-08-28T01:55:00-05:00'
    )
  ),
  updated_at = now()
where estado='ACTIVO'
  and tipo='SERVICIO'
  and categoria in ('VITAMINAS','DETOX')
  and (nullif(btrim(descripcion_comercial),'') is null or nullif(btrim(indicaciones),'') is null);

commit;
