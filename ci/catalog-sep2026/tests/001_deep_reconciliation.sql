\set ON_ERROR_STOP on

do $$ begin
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO')<>184 then raise exception 'active services !=184'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='PRODUCTO' and estado='ACTIVO')<>50 then raise exception 'products mutated'; end if;
 if (select count(*) from public.aos_catalogo_toppings where estado='ACTIVO')<>9 then raise exception 'active toppings !=9'; end if;
 if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1 where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='UPDATED_CURRENT')<>154 then raise exception 'updated lineage !=154'; end if;
 if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1 where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='INSERTED_CURRENT')<>30 then raise exception 'inserted lineage !=30'; end if;
 if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1 where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='INACTIVATED_HISTORICAL')<>13 then raise exception 'inactive lineage !=13'; end if;
 if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1 where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='TOPPING' and action='UPDATED_CURRENT')<>8 then raise exception 'topping updated lineage !=8'; end if;
 if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1 where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='TOPPING' and action='INSERTED_CURRENT')<>1 then raise exception 'topping inserted lineage !=1'; end if;
 if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1 where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='TOPPING' and action='INACTIVATED_HISTORICAL')<>12 then raise exception 'topping inactive lineage !=12'; end if;
end $$;

do $$ begin
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and categoria='TOXINA')<>8 then raise exception 'toxina !=8'; end if;
 if exists(select 1 from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and categoria='TOXINA' and num_sesiones<>'1') then raise exception 'toxina sessions semantics wrong'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and info_extendida#>>'{treatment_identity,brand}'='NABOTA')<>2 then raise exception 'NABOTA variants !=2'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and info_extendida#>>'{treatment_identity,brand}'='HUTOX')<>2 then raise exception 'HUTOX variants !=2'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and categoria='TOXINA' and (info_extendida#>>'{treatment_identity,brand}') is null)<>4 then raise exception 'unspecified-brand TOXINA !=4'; end if;
 if exists(select 1 from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and categoria='TOXINA' and (info_extendida#>>'{treatment_identity,brand}') is null and coalesce(composicion,'') ilike '%nabota%') then raise exception 'brand fabrication remains'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and moneda='USD')<>3 then raise exception 'USD rows !=3'; end if;
 if exists(select 1 from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and moneda='USD' and categoria<>'GLÚTEOS') then raise exception 'USD outside gluteos'; end if;
 if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and info_extendida#>>'{treatment_identity,entity_kind}'='OPERATIONAL_SUPPLY')<>2 then raise exception 'operational supplies !=2'; end if;
 if exists(select 1 from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and info_extendida#>>'{treatment_identity,entity_kind}'='OPERATIONAL_SUPPLY' and ((info_extendida#>>'{treatment_identity,public_catalog}')::boolean or (info_extendida#>>'{treatment_identity,recommendable}')::boolean)) then raise exception 'operational supply leaked public'; end if;
 if not exists(select 1 from public.aos_catalogo_servicios where nombre='NABOTA 3 ZONAS 50U' and precio_oferta=999 and num_sesiones='1' and info_extendida#>>'{treatment_identity,zones}'='3' and info_extendida#>>'{treatment_identity,unit_cap}'='50') then raise exception 'Nabota 3Z structured semantics missing'; end if;
 if not exists(select 1 from public.aos_catalogo_servicios where nombre='HUTOX 3 ZONAS 50U' and precio_oferta=799 and num_sesiones='1' and info_extendida#>>'{treatment_identity,zones}'='3') then raise exception 'Hutox 3Z missing'; end if;
 if not exists(select 1 from public.aos_catalogo_servicios where nombre='HIPERHIDROSIS AXILAS' and precio_oferta=1399 and info_extendida#>>'{treatment_identity,indication}'='HIPERHIDROSIS') then raise exception 'axillary hyperhidrosis mismatch'; end if;
 if not exists(select 1 from public.aos_catalogo_servicios where nombre='BIOESTIMULADOR GLÚTEOS POWERFILL' and moneda='USD' and precio_oferta=1699) then raise exception 'Powerfill USD mismatch'; end if;
end $$;

do $$ begin
 if exists(select 1 from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' and info_extendida ? 'catalog_sep2026' and precio_base is distinct from precio_oferta) then raise exception 'current price split detected'; end if;
 if exists(
   select 1
   from public.aos_catalogo_reconciliation_lineage_v1 l
   join public.aos_catalogo_servicios c on c.id::text=l.entity_id
   where l.reconciliation_code='CATALOG_SEP2026_V1' and l.entity_kind='SERVICE'
     and l.action='UPDATED_CURRENT' and not (coalesce(c.info_extendida,'{}') ? 'preexisting')
 ) then raise exception 'preexisting info_extendida was overwritten on mapped rows'; end if;
 if exists(select nombre from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' group by nombre having count(*)>1) then raise exception 'duplicate current service name'; end if;
end $$;

select 'CATALOG_SEP2026_DEEP_RECONCILIATION_PASS' as certification;
