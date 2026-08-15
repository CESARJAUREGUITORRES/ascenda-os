\set ON_ERROR_STOP on
begin;
select plan(38);

insert into public.aos_usuarios(id,codigo_asesor,nombre,rol,nivel_jerarquia,activo,two_factor,paneles_acceso,sedes_permitidas)
values('00000000-0000-0000-0000-000000000001','ZIV-001','OWNER','admin',1,true,true,array['admin-sales','admin-import-ventas','admin-caja','admin-cartera'],'{}');
insert into public.aos_rrhh(codigo_asesor,nombre,estado) values('ZIV-001','OWNER','ACTIVO');
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
values(encode(extensions.digest('F4-TEST-TOKEN','sha256'),'hex'),'00000000-0000-0000-0000-000000000001','PASSWORD_2FA',now()+interval '8 hours');

insert into public.aos_product_identity_v1(product_key,canonical_name) values('F3:LIFTINGB30GR','LIFTING B 30GR'),('F3:SPRAYMINOX','SPRAY MINOX');
insert into public.aos_product_alias_v2(alias_key,alias_text,product_key,default_qty,default_is_pack) values
(public.aos_product_normalize_alias_v2('LIFTIN B'),'LIFTIN B','F3:LIFTINGB30GR',1,false),
(public.aos_product_normalize_alias_v2('SPRAY MINOX'),'SPRAY MINOX','F3:SPRAYMINOX',2,true);

insert into public.aos_ventas(fecha,nombres,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,sede,tipo) values
('2026-08-10','A','999111111','999111111','HIFU','HIFU','EFECTIVO',100,'PAGO COMPLETO','WILMER','SAN ISIDRO','SERVICIO'),
('2026-08-11','B','999222222','999222222','COMPRA DE PRODUCTO','LIFTIN B','QR',200,'PAGO COMPLETO','WILMER','SAN ISIDRO','PRODUCTO'),
('2026-08-12','C','999333333','999333333','COMPRA DE PRODUCTO','SPRAY MINOX','QR',300,'PAGO COMPLETO','WILMER','SAN ISIDRO','PRODUCTO'),
('2026-08-12','D','999444444','999444444','COMPRA DE PRODUCTO','INDICACION ESPECIAL','QR',50,'PAGO COMPLETO','WILMER','SAN ISIDRO','PRODUCTO');
update public.aos_product_sale_fact_v1 set resolution_status='EXCLUDED',resolution_source='OWNER_REVIEW',physical_qty=null,is_pack=false where sale_id=4;

select ok(public.aos_f4_actor('F4-TEST-TOKEN','admin-sales') is not null,'1 strong actor accepted');
select ok(public.aos_f4_actor('bad','admin-sales') is null,'2 bad actor rejected');
select is((public.aos_sales_admin_gateway_v4('bad',8,2026,'SAN ISIDRO','WILMER','MES')->>'ok')::boolean,false,'3 unauthorized sales gateway rejected');
select is((public.aos_sales_admin_gateway_v4('F4-TEST-TOKEN',8,2026,'SAN ISIDRO','WILMER','MES')->>'ok')::boolean,true,'4 sales gateway authorized');
select ok(exists(select 1 from jsonb_array_elements(public.aos_sales_admin_gateway_v4('F4-TEST-TOKEN',8,2026,'SAN ISIDRO','WILMER','MES')->'detalle') e where e->>'rawDescription'='LIFTIN B' and e->>'canonicalProductName'='LIFTING B 30GR'),'5 raw description preserved beside canonical identity');
select is(jsonb_array_length(public.aos_sales_admin_gateway_v4('F4-TEST-TOKEN',8,2026,'SAN ISIDRO','WILMER','MES')->'canonicalProducts'),2,'6 two canonical products ranked');
select is((public.aos_sales_admin_gateway_v4('F4-TEST-TOKEN',8,2026,'SAN ISIDRO','WILMER','MES')->>'physicalUnits')::numeric,3::numeric,'7 physical units aggregated');
select is((public.aos_sales_admin_gateway_v4('F4-TEST-TOKEN',8,2026,'SAN ISIDRO','WILMER','MES')->>'productPackLines')::integer,1,'8 pack lines aggregated');
select is((public.aos_sales_admin_gateway_v4('F4-TEST-TOKEN',8,2026,'SAN ISIDRO','WILMER','MES')->'productResolution'->>'resolved')::integer,2,'9 resolution count');
select is((public.aos_sales_admin_gateway_v4('F4-TEST-TOKEN',8,2026,'SAN ISIDRO','WILMER','MES')->'productResolution'->>'excluded')::integer,1,'10 excluded count');
select is((public.aos_sales_admin_sale_v4('F4-TEST-TOKEN',2)->>'ok')::boolean,true,'11 secure sale read works');
select is(public.aos_sales_admin_sale_v4('F4-TEST-TOKEN',2)->'row'->>'canonicalProductName','LIFTING B 30GR','12 secure sale read canonical identity');
select is((public.aos_editar_venta_v4('bad',2,(select updated_at from public.aos_ventas where id=2),'{"descripcion":"SPRAY MINOX"}','test')->>'ok')::boolean,false,'13 unauthorized edit rejected');

create temporary table f4_version(v timestamptz);insert into f4_version select updated_at from public.aos_ventas where id=2;
select is((public.aos_editar_venta_v4('F4-TEST-TOKEN',2,(select v from f4_version),'{"descripcion":"SPRAY MINOX"}','test')->>'ok')::boolean,true,'14 tokenized edit succeeds');
select is((select product_key from public.aos_product_sale_fact_v1 where sale_id=2),'F3:SPRAYMINOX','15 edit re-resolves product fact');
-- Production RPC calls are separate DB transactions. This suite intentionally runs inside
-- one pgTAP transaction, where now() is transaction-stable, so advance the row version
-- with the wall clock to model the next request boundary deterministically.
update public.aos_ventas set updated_at=clock_timestamp() where id=2;
select is(public.aos_editar_venta_v4('F4-TEST-TOKEN',2,(select v from f4_version),'{"monto":201}','test')->>'error','STALE_SALE','16 stale edit rejected');
select is(public.aos_editar_venta_v4('F4-TEST-TOKEN',2,(select updated_at from public.aos_ventas where id=2),'{"evil":"x"}','test')->>'error','FIELD_NOT_ALLOWED','17 unknown edit field rejected');

create temporary table f4_count_before(n bigint);insert into f4_count_before select count(*) from public.aos_ventas;
create temporary table f4_batch(j jsonb);insert into f4_batch values('[{"fecha":"2026-08-20","sede":"SAN ISIDRO","nombres":"E","celular":"999555555","tratamiento":"COMPRA DE PRODUCTO","descripcion":"LIFTIN B","pago":"QR","monto":"150","estado_pago":"ADELANTO","asesor":"WILMER","atendio":"DOC"},{"fecha":"2026-08-20","sede":"SAN ISIDRO","nombres":"F","celular":"999666666","tratamiento":"COMPRA DE PRODUCTO","descripcion":"NUEVO ALIAS","pago":"QR","monto":"180","estado_pago":"PAGO COMPLETO","asesor":"WILMER","atendio":"DOC"}]');
create temporary table f4_preview(j jsonb);insert into f4_preview select public.aos_importar_ventas_preview_v4('F4-TEST-TOKEN',(select j from f4_batch));
select is((select (j->>'ok')::boolean from f4_preview),true,'18 import preview valid');
select is((select (j->>'mutates')::boolean from f4_preview),false,'19 preview read-only');
select is((select (j->>'productResolved')::integer from f4_preview),1,'20 preview resolved count');
select is((select (j->>'productReviewRequired')::integer from f4_preview),1,'21 preview review count');
select is((select (j->>'advances')::integer from f4_preview),1,'22 preview advances count');
select is((select count(*) from public.aos_ventas),(select n from f4_count_before),'23 preview creates no sales');
create temporary table f4_import(j jsonb);insert into f4_import select public.aos_importar_ventas_v4('F4-TEST-TOKEN',(select j from f4_batch));
select is((select (j->>'ok')::boolean from f4_import),true,'24 secure import succeeds');
select is((select (j->>'insertados')::integer from f4_import),2,'25 secure import reports inserts');
select is((select count(*) from public.aos_ventas),(select n+2 from f4_count_before),'26 secure import inserts expected rows');
select is((select count(*) from public.aos_product_sale_fact_v1 where resolution_status='REVIEW_REQUIRED'),1::bigint,'27 unknown imported product fails closed');

insert into public.aos_caja_sesiones(id,sede,estado,abierto_por_user_id) values('CAJA-1','SAN ISIDRO','ABIERTA','00000000-0000-0000-0000-000000000001');
create temporary table f4_caja_before(n bigint);insert into f4_caja_before select count(*) from public.aos_ventas;
select is(public.aos_grabar_venta_caja_v4('bad','SAN ISIDRO','spoof','CAJA-1','999777777','G','','999777777','77777777','WILMER','DOC','[{"nombre":"LIFTING B","descripcion":"LIFTIN B"}]','QR',200,'PEN','BOLETA','B1','PAGO COMPLETO','','PRODUCTO','2026-08-21',null,200)->>'error','UNAUTHORIZED','28 unauthorized caja rejected');
select is((select count(*) from public.aos_ventas),(select n from f4_caja_before),'29 unauthorized caja creates no sale');
select ok((public.aos_grabar_venta_caja_v4('F4-TEST-TOKEN','SAN ISIDRO','spoof','CAJA-1','999777777','G','','999777777','77777777','WILMER','DOC','[{"nombre":"LIFTING B","descripcion":"LIFTIN B"}]','QR',200,'PEN','BOLETA','B1','PAGO COMPLETO','','PRODUCTO','2026-08-21',null,200)->>'venta_id') is not null,'30 secure caja sale succeeds');
select is((select count(*) from public.aos_ventas),(select n+1 from f4_caja_before),'31 caja exactly one sale');

insert into public.aos_ventas(fecha,nombres,dni,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,sede,tipo) values('2026-07-01','H','88888888','999888888','999888888','HIFU','HIFU','QR',300,'ADELANTO','WILMER','SAN ISIDRO','SERVICIO');
insert into public.aos_ventas(fecha,nombres,dni,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,sede,tipo) values('2026-07-12','H','88888888','999888888','999888888','HIFU','HIFU','QR',700,'PAGO COMPLETO','WILMER','SAN ISIDRO','SERVICIO');
insert into public.aos_cotizaciones(id,numero_limpio,nombre_paciente,dni_paciente,estado,subtotal,total_pagado,saldo_pendiente,sede,asesor,fecha_creacion) values('Q-1','999888888','H','88888888','PAGADO_PARCIAL',1000,300,700,'SAN ISIDRO','WILMER','2026-07-01');
insert into public.aos_cartera_reconciliacion(id,source_type,venta_row_id,rol_pago,estado_reconciliacion,confianza,monto_registrado,source_active,evidencia,updated_at) values('00000000-0000-0000-0000-000000000099','VENTA',(select max(id)-1 from public.aos_ventas),'ADELANTO','PENDIENTE_RECONCILIAR','NO_EVALUADA',300,true,'{}',now());
create temporary table f4_pay_before(n bigint);insert into f4_pay_before select count(*) from public.aos_pagos;
create temporary table f4_candidates(j jsonb);insert into f4_candidates select public.aos_cartera_candidates_v2('F4-TEST-TOKEN','00000000-0000-0000-0000-000000000099');
select is((select (j->>'ok')::boolean from f4_candidates),true,'32 candidate lookup authorized');
select ok((select jsonb_array_length(j->'candidates') from f4_candidates)>=2,'33 multiple evidence candidates surfaced');
select is((select count(*) from public.aos_pagos),(select n from f4_pay_before),'34 candidate lookup creates no payments');
select is(public.aos_cartera_reconcile_v2('F4-TEST-TOKEN','00000000-0000-0000-0000-000000000099',(select updated_at from public.aos_cartera_reconciliacion where id='00000000-0000-0000-0000-000000000099'),'PAGO_RECONCILIADO','ALTA',1000,0,null,null,'ADELANTO','test')->>'error','EVIDENCE_LINK_REQUIRED','35 payment reconciliation requires evidence');
select is((public.aos_cartera_reconcile_v2('F4-TEST-TOKEN','00000000-0000-0000-0000-000000000099',(select updated_at from public.aos_cartera_reconciliacion where id='00000000-0000-0000-0000-000000000099'),'PAGO_RECONCILIADO','ALTA',1000,0,'VENTA',(select max(id)::text from public.aos_ventas),'ADELANTO','linked existing evidence')->>'ok')::boolean,true,'36 linked sale reconciliation succeeds');
select is((select estado_reconciliacion from public.aos_cartera_reconciliacion where id='00000000-0000-0000-0000-000000000099'),'PAGO_RECONCILIADO','37 state persisted');
select is((select evidencia#>>'{f4_link,type}' from public.aos_cartera_reconciliacion where id='00000000-0000-0000-0000-000000000099'),'VENTA','38 evidence linked without new payment');

select * from finish();
rollback;
