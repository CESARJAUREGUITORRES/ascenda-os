-- WA-4A.1B: close the two remaining INTERNAL product commercial-content gaps without inventing exact formulas.
begin;

update public.aos_catalogo_servicios
set descripcion_comercial='Accesorio interno de apoyo capilar diseñado para facilitar una aplicación localizada y uniforme de productos de cuidado en distintas zonas del cuero cabelludo. Se utiliza como complemento de la rutina indicada, no como tratamiento independiente.',
    composicion='NO APLICA — accesorio físico. Material y especificación técnica exacta pendientes de ficha del proveedor.',
    indicaciones='Usar como accesorio de aplicación cuando el protocolo o producto capilar lo requiera. Mantener limpio y seguir las instrucciones del producto aplicado; no sustituye la indicación del tratamiento capilar.',
    info_extendida=coalesce(info_extendida,'{}'::jsonb)||jsonb_build_object('knowledge_enrichment_v1b',jsonb_build_object('sync_version','WA4A1B_INTERNAL_PRODUCTS_20260828_V1','source_kind','ASCENDA_INTERNAL_CONFIRMED','formula_state','NOT_APPLICABLE_OPERATIONAL','public_catalog',false,'enriched_at','2026-08-28T02:10:00-05:00')),
    updated_at=now()
where estado='ACTIVO' and tipo='PRODUCTO' and nombre='APLICADOR MULTIZONA CAPILAR'
  and (descripcion_comercial is null or composicion is null or indicaciones is null);

update public.aos_catalogo_servicios
set descripcion_comercial='Bálsamo labial de venta interna Zi Vital orientado al acondicionamiento, hidratación y cuidado de labios secos o sensibilizados. El aloe vera está declarado en su nombre comercial; la fórmula INCI completa debe confirmarse con el envase o ficha del proveedor.',
    composicion='Aloe vera — activo declarado en el nombre comercial. INCI/fórmula completa pendiente de ficha o etiqueta del proveedor; no asumir ingredientes adicionales.',
    indicaciones='Aplicar sobre los labios según necesidad como producto de cuidado y acondicionamiento. Si existe irritación importante, lesión o un post-procedimiento con indicaciones específicas, seguir primero la recomendación del profesional.',
    info_extendida=coalesce(info_extendida,'{}'::jsonb)||jsonb_build_object('knowledge_enrichment_v1b',jsonb_build_object('sync_version','WA4A1B_INTERNAL_PRODUCTS_20260828_V1','source_kind','ASCENDA_INTERNAL_CONFIRMED','formula_state','PARTIAL_LABEL_EVIDENCE','public_catalog',false,'enriched_at','2026-08-28T02:10:00-05:00')),
    updated_at=now()
where estado='ACTIVO' and tipo='PRODUCTO' and nombre='LIP BALM ALOE VERA'
  and (descripcion_comercial is null or composicion is null or indicaciones is null);

commit;
