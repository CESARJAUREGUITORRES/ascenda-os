-- WA-4A.1B: align internal Prunex knowledge with the governed FAQ safety boundary.
begin;
update public.aos_catalogo_servicios
set descripcion_comercial='PRUNEX es un producto herbal de venta interna Zi Vital orientado al apoyo digestivo y al tránsito intestinal. Se comunica como una herramienta puntual de cuidado intestinal, no como una limpieza general del organismo ni como sustituto de hábitos, evaluación o tratamiento médico.',
    indicaciones='Usar únicamente conforme a la etiqueta/ficha vigente y a la orientación correspondiente. No presentar como método para eliminar toxinas, bajar de peso o tratar una enfermedad. Si existe dolor abdominal, síntomas persistentes, embarazo/lactancia, uso de medicamentos o necesidad de uso frecuente, derivar a evaluación profesional antes de recomendar continuidad.',
    info_extendida=coalesce(info_extendida,'{}'::jsonb)||jsonb_build_object('knowledge_enrichment_v1b',jsonb_build_object('sync_version','WA4A1B_PRUNEX_20260828_V1','source_kind','ASCENDA_INTERNAL + GOVERNED_FAQ','formula_state','INTERNAL_FORMULA_REQUIRES_LABEL_CONFIRMATION','claim_policy','DIGESTIVE_TRANSIT_NOT_SYSTEMIC_DETOX','public_catalog',false,'enriched_at','2026-08-28T02:15:00-05:00')),
    updated_at=now()
where estado='ACTIVO' and tipo='PRODUCTO' and nombre in ('PRUNEX STICK x1','PRUNEX STICK x3');
commit;
