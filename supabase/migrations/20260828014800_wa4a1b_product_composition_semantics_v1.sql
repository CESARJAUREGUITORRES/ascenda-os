-- WA-4A.1B: physical applicator has no clinical formula; distinguish N/A from missing evidence.
begin;
update public.aos_knowledge_entity_map_v1
set composition_state='NOT_APPLICABLE_OPERATIONAL',
    advisor_positioning='Accesorio interno de apoyo capilar. No requiere fórmula clínica; material/especificación física se gestiona como dato de producto cuando exista ficha del proveedor.',
    source_locator='WA-4A.1B product semantics · canonical Aplicador Multizona',
    updated_at=now()
where entity_type='PRODUCT' and upper(entity_name)='APLICADOR MULTIZONA CAPILAR';
commit;
