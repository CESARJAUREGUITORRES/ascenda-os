\set ON_ERROR_STOP on
begin;
select plan(15);

insert into public.aos_usuarios(id,codigo_asesor,nombre,rol,nivel_jerarquia,activo,two_factor,paneles_acceso,sedes_permitidas)
values('00000000-0000-0000-0000-000000000051','SX1-OWNER','SX1 OWNER','admin',1,true,true,array['admin-sales'],'{}');
insert into public.aos_rrhh(codigo_asesor,nombre,estado) values('SX1-OWNER','SX1 OWNER','ACTIVO');
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
values(encode(extensions.digest('SX1-TEST-TOKEN','sha256'),'hex'),'00000000-0000-0000-0000-000000000051','PASSWORD_2FA',now()+interval '8 hours');

insert into public.aos_product_identity_v1(product_key,canonical_name) values
('SX1:PRODUCT-A','PRODUCT A'),('SX1:PRODUCT-B','PRODUCT B');
insert into public.aos_product_alias_v2(alias_key,alias_text,product_key,default_qty,default_is_pack) values
(public.aos_product_normalize_alias_v2('PRODUCT A'),'PRODUCT A','SX1:PRODUCT-A',1,false),
(public.aos_product_normalize_alias_v2('PACK A'),'PACK A','SX1:PRODUCT-A',2,true),
(public.aos_product_normalize_alias_v2('PRODUCT B'),'PRODUCT B','SX1:PRODUCT-B',1,false);

insert into public.aos_ventas(fecha,nombres,apellidos,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,atendio,sede,tipo) values
('2026-07-10','PREV','A','900000001','900000001','COMPRA DE PRODUCTO','PRODUCT A','QR',100,'PAGO COMPLETO','WILMER','DOC','SAN ISIDRO','PRODUCTO'),
('2026-08-05','ANA','A','900000002','900000002','COMPRA DE PRODUCTO','PRODUCT A','QR',200,'PAGO COMPLETO','WILMER','DOC','SAN ISIDRO','PRODUCTO'),
('2026-08-06','BETA','B','900000003','900000003','COMPRA DE PRODUCTO','PACK A','QR',300,'PAGO COMPLETO','WILMER','DOC','SAN ISIDRO','PRODUCTO'),
('2026-08-07','GAMMA','C','900000004','900000004','COMPRA DE PRODUCTO','UNKNOWN','QR',50,'PAGO COMPLETO','WILMER','DOC','SAN ISIDRO','PRODUCTO'),
('2026-07-11','PREV','S','900000010','900000010','HIFU','HIFU','QR',400,'PAGO COMPLETO','WILMER','DOC','SAN ISIDRO','SERVICIO'),
('2026-08-08','DELTA','S','900000011','900000011','HIFU','HIFU','QR',500,'PAGO COMPLETO','WILMER','DOC','SAN ISIDRO','SERVICIO'),
('2026-08-09','EPS','S','900000012','900000012','OTROS','OTROS','QR',75,'PAGO COMPLETO','WILMER','DOC','SAN ISIDRO','SERVICIO');

update public.aos_product_sale_fact_v1 set resolution_status='EXCLUDED',resolution_source='OWNER_REVIEW',physical_qty=null,is_pack=false
where sale_id=(select id from public.aos_ventas where descripcion='UNKNOWN' limit 1);

create temporary table sx1_before(n bigint); insert into sx1_before select count(*) from public.aos_ventas;
create temporary table sx1_product(j jsonb); insert into sx1_product
select public.aos_sales_explorer_history_v1('SX1-TEST-TOKEN','PRODUCT',2026,8,'MES','SAN ISIDRO','WILMER','SX1:PRODUCT-A');
create temporary table sx1_service(j jsonb); insert into sx1_service
select public.aos_sales_explorer_history_v1('SX1-TEST-TOKEN','SERVICE',2026,8,'MES','SAN ISIDRO','WILMER','HIFU');

select is(public.aos_sales_explorer_history_v1('bad','PRODUCT',2026,8,'MES','SAN ISIDRO','WILMER','')->>'error','UNAUTHORIZED','1 unauthorized rejected');
select is((select (j->>'ok')::boolean from sx1_product),true,'2 product explorer authorized');
select is((select j->>'contract' from sx1_product),'REV_SX1_READ_V1','3 contract version');
select is((select (j->'current'->>'sales')::integer from sx1_product),2,'4 product current sales');
select is((select (j->'current'->>'units')::numeric from sx1_product),3::numeric,'5 product physical units preserve pack semantics');
select is((select (j->'current'->>'packs')::integer from sx1_product),1,'6 product pack count');
select is((select j->>'comparisonStatus' from sx1_product),'CERTIFIED','7 previous comparable source detected');
select ok((select jsonb_array_length(j->'history') from sx1_product)>=2,'8 annual monthly history returned');
select is((select jsonb_array_length(j->'sales') from sx1_product),3,'9 entity annual sale drilldown returned');
select ok(exists(select 1 from sx1_product, jsonb_array_elements(j->'sales') x where x->>'rawDescription'='PACK A' and (x->>'units')::numeric=2),'10 raw description and physical units preserved');
select is((select (j->'current'->>'sales')::integer from sx1_service),1,'11 service explorer excludes OTROS and returns selected service');
select is((select (j->'current'->>'revenue')::numeric from sx1_service),500::numeric,'12 service revenue correct');
select is((select count(*) from public.aos_ventas),(select n from sx1_before),'13 explorer calls write zero sales');
select ok(has_function_privilege('anon','public.aos_sales_explorer_history_v1(text,text,integer,integer,text,text,text,text)','EXECUTE'),'14 anon can call token-gated RPC');
select ok(not has_function_privilege('public','public.aos_sales_explorer_history_v1(text,text,integer,integer,text,text,text,text)','EXECUTE'),'15 PUBLIC role revoked');

select * from finish();
rollback;
