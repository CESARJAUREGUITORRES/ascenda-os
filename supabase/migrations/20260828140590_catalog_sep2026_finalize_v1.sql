-- CATALOG SEP2026.1 — historical/toppings/final certification
begin;

create temp table _hist(name text primary key) on commit drop;
insert into _hist(name) values
('OZONO HEMOTERAPIA MENOR'),
('OZONO HEMOTERAPIA x6'),
('GENEFILL PLUS 1ML (KOREA)'),
('MESO CAPILAR MINOXIDIL'),
('OZONIFICACIÓN CAPILAR'),
('PRP + OZONO x1'),
('PRP + OZONO x3'),
('BCN LUMEN 1ML'),
('ORGANIC SILICA DMA 2.5ML'),
('DERMAPEN PRP+VIT x1'),
('DERMAPEN PRP+VIT x3'),
('DERMAPEN VITAL FACE x1'),
('DERMAPEN VITAL FACE x3');

do $$
begin
  if (select count(*) from _hist)<>13 then raise exception 'SEP26 historical service set !=13'; end if;
  if (select count(*) from _hist h join public.aos_catalogo_servicios c
      on c.tipo='SERVICIO' and c.estado='ACTIVO' and c.nombre=h.name)<>13
    then raise exception 'SEP26 historical service resolution !=13'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='UPDATED_CURRENT')<>154
    then raise exception 'SEP26 mapped lineage before final !=154'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='INSERTED_CURRENT')<>30
    then raise exception 'SEP26 inserted lineage before final !=30'; end if;
end $$;

insert into public.aos_catalogo_reconciliation_lineage_v1
(reconciliation_code,entity_kind,entity_id,action,old_name,new_name,snapshot_before,source_payload)
select 'CATALOG_SEP2026_V1','SERVICE',c.id::text,'INACTIVATED_HISTORICAL',c.nombre,c.nombre,
 jsonb_build_object(
   'nombre',c.nombre,'nombre_corto',c.nombre_corto,'categoria',c.categoria,
   'num_sesiones',c.num_sesiones,'precio_base',c.precio_base,'precio_oferta',c.precio_oferta,
   'moneda',c.moneda,'estado',c.estado,'requiere_doctora',c.requiere_doctora,
   'requiere_enfermeria',c.requiere_enfermeria,'composicion',c.composicion,
   'info_extendida',c.info_extendida,'updated_at',c.updated_at
 ),
 jsonb_build_object(
   'reconciliation_code','CATALOG_SEP2026_V1',
   'source_file','LISTA DE PRECIOS SEPTIEMBRE - 2026 - SERVICIOS',
   'disposition','ABSENT_FROM_SEP2026_CURRENT',
   'verified_at','2026-08-28'
 )
from _hist h
join public.aos_catalogo_servicios c
  on c.tipo='SERVICIO' and c.estado='ACTIVO' and c.nombre=h.name;

update public.aos_catalogo_servicios c
set estado='INACTIVO',
    info_extendida=coalesce(c.info_extendida,'{}'::jsonb)
      || jsonb_build_object(
           'catalog_sep2026',
           jsonb_build_object(
             'reconciliation_code','CATALOG_SEP2026_V1',
             'source_file','LISTA DE PRECIOS SEPTIEMBRE - 2026 - SERVICIOS',
             'disposition','ABSENT_FROM_SEP2026_CURRENT',
             'verified_at','2026-08-28'
           )
         )
      || jsonb_build_object(
           'treatment_identity',
           coalesce(c.info_extendida->'treatment_identity','{}'::jsonb)
             || jsonb_build_object(
                  'current_status','DISCONTINUED',
                  'public_catalog',false,
                  'recommendable',false,
                  'source','SEP2026_PRICE_LIST',
                  'verified_at','2026-08-28'
                )
         ),
    updated_at=now()
from _hist h
where c.tipo='SERVICIO' and c.estado='ACTIVO' and c.nombre=h.name;

update public.aos_catalogo_reconciliation_lineage_v1 l
set snapshot_after=jsonb_build_object(
      'nombre',c.nombre,'nombre_corto',c.nombre_corto,'categoria',c.categoria,
      'num_sesiones',c.num_sesiones,'precio_base',c.precio_base,'precio_oferta',c.precio_oferta,
      'moneda',c.moneda,'estado',c.estado,'requiere_doctora',c.requiere_doctora,
      'requiere_enfermeria',c.requiere_enfermeria,'composicion',c.composicion,
      'info_extendida',c.info_extendida,'updated_at',c.updated_at
    )
from public.aos_catalogo_servicios c
where l.reconciliation_code='CATALOG_SEP2026_V1'
  and l.entity_kind='SERVICE'
  and l.action in ('UPDATED_CURRENT','INACTIVATED_HISTORICAL')
  and c.id::text=l.entity_id;

create temp table _t on commit drop as
select x.r,x.s,x.l,x.n,x.c,x.p,x.ss,x.ps
from jsonb_to_recordset($j$[{"r":3,"s":"MASCARILLA ESTHEMAX","l":"MASCARILLA ESTHEMAX","n":"MASCARILLA ESTHEMAX","c":"FACIALES","p":49,"ss":"1","ps":"SEP2026_PRICE_LIST"},{"r":4,"s":"MASCARILLA Q10","l":"MASCARILLA Q10","n":"MASCARILLA Q10","c":"FACIALES","p":49,"ss":"","ps":"SEP2026_PRICE_LIST"},{"r":5,"s":"TRATAMIENTO DESCONGESTIVO DE PÁRPADOS","l":"TRATAMIENTO DESCONGESTIVO DE PÁRPADOS","n":"TRATAMIENTO DESCONGESTIVO DE PÁRPADOS","c":"FACIALES","p":25,"ss":"1","ps":"SEP2026_PRICE_LIST"},{"r":6,"s":"NANOPLASMA FACIAL (POR ZONA ADICIONAL)","n":"NANOPLASMA FACIAL (POR ZONA ADICIONAL)","c":"FACIALES","p":99,"ss":"1","ps":"SEP2026_PRICE_LIST"},{"r":7,"s":"PINK GLOW ROSTRO (0.5 ML)","l":"PINK GLOW 1ml (POR ZONA) + DERMAPEN","n":"PINK GLOW ROSTRO (0.5 ML)","c":"FACIALES","p":149,"ss":"1","ps":"SEP2026_PRICE_LIST"},{"r":14,"s":"CRIOLIPÓLISIS 1 ZONA ADICIONAL","l":"CRIOLIPÓLISIS 1 ZONA ADICIONAL","n":"CRIOLIPÓLISIS 1 ZONA ADICIONAL","c":"CORPORAL","p":150,"ss":"","ps":"SEP2026_PRICE_LIST"},{"r":15,"s":"PACK APARATOLOGÍA REDUCTOR","l":"PACK APARATOLOGÍA REDUCTOR","n":"PACK APARATOLOGÍA REDUCTOR","c":"CORPORAL","p":279,"ss":"6 Ondas Rusas Reafirmantes + 6 Lipoláser reductor no invasivo + 6 vacuns","ps":"SEP2026_PRICE_LIST"},{"r":16,"s":"DRENAJE LINFÁTICO","l":"DRENAJE LINFÁTICO","n":"DRENAJE LINFÁTICO","c":"CORPORAL","p":0,"ss":"","ps":"CARRY_FORWARD_EXISTING_ZERO"},{"r":19,"s":"SESIÓN CASCO REGENERADOR DE COLÁGENO","l":"SESIÓN CASCO REGENERADOR + PEINE","n":"SESIÓN CASCO REGENERADOR DE COLÁGENO","c":"CAPILAR","p":49,"ss":"1","ps":"SEP2026_PRICE_LIST"}]$j$::jsonb)
as x(r int,s text,l text,n text,c text,p numeric,ss text,ps text);

create temp table _th(name text primary key) on commit drop;
insert into _th(name)
select jsonb_array_elements_text($j$["MESOTERAPIA CAPILAR MINOXIDIL PINEDA","OZONIFICACIÓN CAPILAR","AMBER GLOW 1ML (POR ZONA) + DERMAPEN","BCN LUMEN 1ML (POR ZONA) + DERMAPEN","ORGANIC SILICA & DMA 2.5ML (POR ZONA) + DERMAPEN","Pink Intimate (efecto aclarante)","ZK 1 SESIÓN","1 suplemento","2 suplementos","2da Full B","2da vitamina C","3 suplementos"]$j$::jsonb);

do $$
begin
  if (select count(*) from _t)<>9 then raise exception 'SEP26 toppings source !=9'; end if;
  if (select count(*) from _t where l is not null)<>8 then raise exception 'SEP26 topping mapped !=8'; end if;
  if (select count(*) from _t where l is null)<>1 then raise exception 'SEP26 topping new !=1'; end if;
  if (select count(*) from _th)<>12 then raise exception 'SEP26 topping historical !=12'; end if;
  if exists (
    select 1 from _t s
    left join public.aos_catalogo_toppings t on t.estado='ACTIVO' and t.nombre=s.l
    where s.l is not null
    group by s.r having count(t.id)<>1
  ) then raise exception 'SEP26 topping mapping did not resolve exactly once'; end if;
  if (select count(*) from _th h join public.aos_catalogo_toppings t
      on t.estado='ACTIVO' and t.nombre=h.name)<>12
    then raise exception 'SEP26 historical topping resolution !=12'; end if;
end $$;

insert into public.aos_catalogo_reconciliation_lineage_v1
(reconciliation_code,entity_kind,entity_id,action,source_row,source_name,old_name,new_name,snapshot_before,source_payload)
select 'CATALOG_SEP2026_V1','TOPPING',t.id::text,'UPDATED_CURRENT',
       s.r,s.s,t.nombre,s.n,
       jsonb_build_object(
         'nombre',t.nombre,'categoria_vinculada',t.categoria_vinculada,'precio',t.precio,
         'sesiones',t.sesiones,'tipo_pago',t.tipo_pago,'estado',t.estado,'moneda',t.moneda
       ),
       jsonb_build_object(
         'source_file','LISTA DE PRECIOS SEPTIEMBRE - 2026 - TOPPINGS',
         'source_row',s.r,'source_name',s.s,'authoritative_current_price',s.p,
         'currency','PEN','price_source',s.ps,'verified_at','2026-08-28'
       )
from _t s
join public.aos_catalogo_toppings t on t.estado='ACTIVO' and t.nombre=s.l
where s.l is not null;

insert into public.aos_catalogo_reconciliation_lineage_v1
(reconciliation_code,entity_kind,entity_id,action,old_name,new_name,snapshot_before,source_payload)
select 'CATALOG_SEP2026_V1','TOPPING',t.id::text,'INACTIVATED_HISTORICAL',
       t.nombre,t.nombre,
       jsonb_build_object(
         'nombre',t.nombre,'categoria_vinculada',t.categoria_vinculada,'precio',t.precio,
         'sesiones',t.sesiones,'tipo_pago',t.tipo_pago,'estado',t.estado,'moneda',t.moneda
       ),
       jsonb_build_object(
         'source_file','LISTA DE PRECIOS SEPTIEMBRE - 2026 - TOPPINGS',
         'disposition','ABSENT_FROM_SEP2026_CURRENT','verified_at','2026-08-28'
       )
from _th h
join public.aos_catalogo_toppings t on t.estado='ACTIVO' and t.nombre=h.name;

update public.aos_catalogo_toppings t
set nombre=s.n,
    categoria_vinculada=s.c,
    precio=s.p,
    sesiones=coalesce(s.ss,''),
    tipo_pago='SOLO_CON_SERVICIO',
    estado='ACTIVO',
    moneda='PEN'
from _t s
where s.l is not null and t.estado='ACTIVO' and t.nombre=s.l;

insert into public.aos_catalogo_toppings
(id,nombre,categoria_vinculada,precio,descripcion,tipo_pago,sesiones,estado,moneda)
select gen_random_uuid()::text,s.n,s.c,s.p,
       'Topping CURRENT SEP2026; solo con una venta de servicio.',
       'SOLO_CON_SERVICIO',coalesce(s.ss,''),'ACTIVO','PEN'
from _t s where s.l is null;

insert into public.aos_catalogo_reconciliation_lineage_v1
(reconciliation_code,entity_kind,entity_id,action,source_row,source_name,old_name,new_name,snapshot_before,snapshot_after,source_payload)
select 'CATALOG_SEP2026_V1','TOPPING',t.id::text,'INSERTED_CURRENT',
       s.r,s.s,null,t.nombre,null,
       jsonb_build_object(
         'nombre',t.nombre,'categoria_vinculada',t.categoria_vinculada,'precio',t.precio,
         'sesiones',t.sesiones,'tipo_pago',t.tipo_pago,'estado',t.estado,'moneda',t.moneda
       ),
       jsonb_build_object(
         'source_file','LISTA DE PRECIOS SEPTIEMBRE - 2026 - TOPPINGS',
         'source_row',s.r,'source_name',s.s,'authoritative_current_price',s.p,
         'currency','PEN','price_source',s.ps,'verified_at','2026-08-28'
       )
from _t s
join public.aos_catalogo_toppings t on t.estado='ACTIVO' and t.nombre=s.n
where s.l is null;

update public.aos_catalogo_toppings t
set estado='INACTIVO'
from _th h
where t.estado='ACTIVO' and t.nombre=h.name;

update public.aos_catalogo_reconciliation_lineage_v1 l
set snapshot_after=jsonb_build_object(
      'nombre',t.nombre,'categoria_vinculada',t.categoria_vinculada,'precio',t.precio,
      'sesiones',t.sesiones,'tipo_pago',t.tipo_pago,'estado',t.estado,'moneda',t.moneda
    )
from public.aos_catalogo_toppings t
where l.reconciliation_code='CATALOG_SEP2026_V1'
  and l.entity_kind='TOPPING'
  and l.action in ('UPDATED_CURRENT','INACTIVATED_HISTORICAL')
  and t.id::text=l.entity_id;

drop trigger if exists trg_aos_catalogo_reconciliation_lineage_immutable_v1
on public.aos_catalogo_reconciliation_lineage_v1;
create trigger trg_aos_catalogo_reconciliation_lineage_immutable_v1
before update or delete on public.aos_catalogo_reconciliation_lineage_v1
for each row execute function public.aos_catalogo_reconciliation_lineage_immutable_guard_v1();

drop function if exists public.aos_apply_catalog_sep26_service_row_v1(jsonb);

do $$
begin
  if (select count(*) from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO')<>184
    then raise exception 'SEP26 final services !=184'; end if;
  if (select count(*) from public.aos_catalogo_servicios where tipo='PRODUCTO' and estado='ACTIVO')<>50
    then raise exception 'SEP26 products mutated'; end if;
  if (select count(*) from public.aos_catalogo_toppings where estado='ACTIVO')<>9
    then raise exception 'SEP26 final toppings !=9'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='UPDATED_CURRENT')<>154
    then raise exception 'SEP26 final UPDATED_CURRENT !=154'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='INSERTED_CURRENT')<>30
    then raise exception 'SEP26 final INSERTED_CURRENT !=30'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='SERVICE' and action='INACTIVATED_HISTORICAL')<>13
    then raise exception 'SEP26 final INACTIVATED_HISTORICAL !=13'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='TOPPING' and action='UPDATED_CURRENT')<>8
    then raise exception 'SEP26 final topping UPDATED_CURRENT !=8'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='TOPPING' and action='INSERTED_CURRENT')<>1
    then raise exception 'SEP26 final topping INSERTED_CURRENT !=1'; end if;
  if (select count(*) from public.aos_catalogo_reconciliation_lineage_v1
      where reconciliation_code='CATALOG_SEP2026_V1' and entity_kind='TOPPING' and action='INACTIVATED_HISTORICAL')<>12
    then raise exception 'SEP26 final topping INACTIVATED_HISTORICAL !=12'; end if;
  if (select count(*) from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO' and moneda='USD')<>3
    then raise exception 'SEP26 final USD !=3'; end if;
  if exists(select 1 from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO' and moneda='USD' and categoria<>'GLÚTEOS')
    then raise exception 'SEP26 USD outside GLÚTEOS'; end if;
  if (select count(*) from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO' and categoria='TOXINA')<>8
    then raise exception 'SEP26 TOXINA !=8'; end if;
  if exists(select 1 from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO' and categoria='TOXINA' and num_sesiones<>'1')
    then raise exception 'SEP26 TOXINA clinical sessions !=1'; end if;
  if (select count(*) from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO'
        and info_extendida#>>'{treatment_identity,entity_kind}'='OPERATIONAL_SUPPLY')<>2
    then raise exception 'SEP26 operational supplies !=2'; end if;
  if exists(select 1 from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO'
        and info_extendida#>>'{treatment_identity,entity_kind}'='OPERATIONAL_SUPPLY'
        and ((info_extendida#>>'{treatment_identity,public_catalog}')::boolean
             or (info_extendida#>>'{treatment_identity,recommendable}')::boolean))
    then raise exception 'SEP26 operational supplies leaked public'; end if;
  if exists(select 1 from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO' and categoria='TOXINA'
        and (info_extendida#>>'{treatment_identity,brand}') is null
        and coalesce(composicion,'') ilike '%Nabota%')
    then raise exception 'SEP26 brand fabrication remains'; end if;
  if exists(select nombre from public.aos_catalogo_servicios
      where tipo='SERVICIO' and estado='ACTIVO'
      group by nombre having count(*)>1)
    then raise exception 'SEP26 duplicate CURRENT service'; end if;
end $$;

commit;
