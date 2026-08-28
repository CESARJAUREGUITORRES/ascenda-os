-- CATALOG SEP2026.1 rollback — active-state restoration using immutable lineage.
-- Safe behavior: newly inserted entities are INACTIVATED, not deleted, so any
-- downstream references remain intact. Existing entity UUIDs and pre-SEP fields are restored.
begin;

update public.aos_catalogo_servicios c
set nombre=l.snapshot_before->>'nombre',
    nombre_corto=l.snapshot_before->>'nombre_corto',
    categoria=l.snapshot_before->>'categoria',
    num_sesiones=l.snapshot_before->>'num_sesiones',
    precio_base=nullif(l.snapshot_before->>'precio_base','')::numeric,
    precio_oferta=nullif(l.snapshot_before->>'precio_oferta','')::numeric,
    moneda=coalesce(l.snapshot_before->>'moneda','PEN'),
    estado=l.snapshot_before->>'estado',
    requiere_doctora=coalesce((l.snapshot_before->>'requiere_doctora')::boolean,false),
    requiere_enfermeria=coalesce((l.snapshot_before->>'requiere_enfermeria')::boolean,false),
    composicion=l.snapshot_before->>'composicion',
    info_extendida=coalesce(l.snapshot_before->'info_extendida','{}'::jsonb),
    updated_at=(l.snapshot_before->>'updated_at')::timestamptz
from public.aos_catalogo_reconciliation_lineage_v1 l
where l.reconciliation_code='CATALOG_SEP2026_V1'
  and l.entity_kind='SERVICE'
  and l.action in ('UPDATED_CURRENT','INACTIVATED_HISTORICAL')
  and c.id::text=l.entity_id;

update public.aos_catalogo_servicios c
set estado='INACTIVO',
    info_extendida=coalesce(c.info_extendida,'{}'::jsonb)
      || jsonb_build_object(
           'treatment_identity',
           coalesce(c.info_extendida->'treatment_identity','{}'::jsonb)
             || jsonb_build_object('current_status','ROLLED_BACK','public_catalog',false,'recommendable',false)
         ),
    updated_at=now()
from public.aos_catalogo_reconciliation_lineage_v1 l
where l.reconciliation_code='CATALOG_SEP2026_V1'
  and l.entity_kind='SERVICE'
  and l.action='INSERTED_CURRENT'
  and c.id::text=l.entity_id;

update public.aos_catalogo_toppings t
set nombre=l.snapshot_before->>'nombre',
    categoria_vinculada=l.snapshot_before->>'categoria_vinculada',
    precio=nullif(l.snapshot_before->>'precio','')::numeric,
    sesiones=l.snapshot_before->>'sesiones',
    tipo_pago=l.snapshot_before->>'tipo_pago',
    estado=l.snapshot_before->>'estado',
    moneda=coalesce(l.snapshot_before->>'moneda','PEN')
from public.aos_catalogo_reconciliation_lineage_v1 l
where l.reconciliation_code='CATALOG_SEP2026_V1'
  and l.entity_kind='TOPPING'
  and l.action in ('UPDATED_CURRENT','INACTIVATED_HISTORICAL')
  and t.id::text=l.entity_id;

update public.aos_catalogo_toppings t
set estado='INACTIVO'
from public.aos_catalogo_reconciliation_lineage_v1 l
where l.reconciliation_code='CATALOG_SEP2026_V1'
  and l.entity_kind='TOPPING'
  and l.action='INSERTED_CURRENT'
  and t.id::text=l.entity_id;

do $$ begin
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO')<>167 then raise exception 'SEP26 rollback active services !=167'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='PRODUCTO' and estado='ACTIVO')<>50 then raise exception 'SEP26 rollback mutated products'; end if;
 if (select count(*) from public.aos_catalogo_toppings where estado='ACTIVO')<>20 then raise exception 'SEP26 rollback active toppings !=20'; end if;
end $$;

commit;
