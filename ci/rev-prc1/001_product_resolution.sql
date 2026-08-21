\set ON_ERROR_STOP on
begin;
select plan(20);

insert into public.aos_usuarios(id,codigo_asesor,nombre,rol,nivel_jerarquia,activo,two_factor,paneles_acceso,sedes_permitidas)
values('00000000-0000-0000-0000-000000000111','PRC-OWNER','PRC OWNER','admin',1,true,true,array['admin-sales','admin-import-ventas'],'{}');
insert into public.aos_rrhh(codigo_asesor,nombre,estado) values('PRC-OWNER','PRC OWNER','ACTIVO');
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
values(encode(extensions.digest('PRC-TEST-TOKEN','sha256'),'hex'),'00000000-0000-0000-0000-000000000111','PASSWORD_2FA',now()+interval '2 hours');

insert into public.aos_product_identity_v1(product_key,canonical_name,lifecycle_status,active)
values('CAT:HYDRA','HYDRA INTENSIVE','CURRENT_CATALOG',true),('CAT:NFCMEN','NF CAPS MEN','CURRENT_UNCATALOGED',true);
insert into public.aos_product_alias_v2(alias_key,alias_text,product_key,default_qty,default_is_pack,source,confidence,active)
values(public.aos_product_normalize_alias_v2('HYDRA INTENSIVE'),'HYDRA INTENSIVE','CAT:HYDRA',1,false,'FIXTURE','OWNER_CONFIRMED',true);

insert into public.aos_ventas(fecha,nombres,apellidos,tratamiento,descripcion,pago,monto,estado_pago,asesor,atendio,sede,tipo) values
('2025-04-10','ANA','UNO','COMPRA DE PRODUCTO','EXOFUSION ESSENCE','QR',200,'PAGO COMPLETO','WILMER','WILMER','SAN ISIDRO','PRODUCTO'),
('2026-08-10','ANA','DOS','COMPRA DE PRODUCTO','EXOFUSION ESSENCE','QR',300,'PAGO COMPLETO','WILMER','WILMER','PUEBLO LIBRE','PRODUCTO'),
('2026-08-11','ANA','TRES','COMPRA DE PRODUCTO','HYDRA INTENSIVE','QR',189,'PAGO COMPLETO','WILMER','WILMER','PUEBLO LIBRE','PRODUCTO'),
('2026-08-12','ANA','CUATRO','COMPRA DE PRODUCTO','DESCARTAR','QR',50,'PAGO COMPLETO','WILMER','WILMER','PUEBLO LIBRE','PRODUCTO'),
('2026-08-13','ANA','CINCO','OTROS','OTROS','QR',40,'PAGO COMPLETO','WILMER','WILMER','PUEBLO LIBRE','SERVICIO');
update public.aos_product_sale_fact_v1 set resolution_status='EXCLUDED',resolution_source='OWNER_REVIEW_CENTER',locked=true,note='fixture' where sale_id=(select id from public.aos_ventas where descripcion='DESCARTAR');

select is((public.aos_product_review_admin_v2('bad','ALL',null,null,'','')->>'ok')::boolean,false,'1 invalid auth rejected');
select is((public.aos_product_review_admin_v2('PRC-TEST-TOKEN','ALL',null,null,'','')->>'ok')::boolean,true,'2 strong admin auth accepted');
select ok((public.aos_product_review_admin_v2('PRC-TEST-TOKEN','ALL',null,null,'','')->'availableYears') @> '[2025,2026]'::jsonb,'3 historical years exposed');
select is((public.aos_product_review_admin_v2('PRC-TEST-TOKEN','REVIEW_REQUIRED',2025,null,'','')->>'selectedLines')::integer,1,'4 year filter isolates 2025 review');
select is((public.aos_product_review_admin_v2('PRC-TEST-TOKEN','REVIEW_REQUIRED',2026,null,'PUEBLO LIBRE','EXOFUSION')->>'selectedLines')::integer,1,'5 year sede search filters compose');
select is((public.aos_product_review_admin_v2('PRC-TEST-TOKEN','RESOLVED',null,null,'','HYDRA')->>'selectedLines')::integer,1,'6 resolved tab surfaces known mapping');
select is((public.aos_product_review_admin_v2('PRC-TEST-TOKEN','EXCLUDED',null,null,'','')->>'selectedLines')::integer,1,'7 excluded tab surfaces owner exclusion');

create temporary table prc_batch(j jsonb);insert into prc_batch values('[{"tratamiento":"OTROS","descripcion":"OTROS"},{"tratamiento":"COMPRA DE PRODUCTO","descripcion":"NUEVO X"}]');
select is((public.aos_product_batch_review_v1('PRC-TEST-TOKEN',(select j from prc_batch))->>'reviewLines')::integer,1,'8 OTROS remains service and does not enter product review');
select is((public.aos_product_batch_review_v1('PRC-TEST-TOKEN',(select j from prc_batch))->>'uniqueAliases')::integer,1,'9 batch reports one unique unresolved alias');

select is((public.aos_product_review_resolve_v2('PRC-TEST-TOKEN','EXOFUSIONESSENCE','LINK_EXISTING',2,'CAT:NFCMEN',null,'CURRENT_UNCATALOGED',2,true,'fixture link')->>'ok')::boolean,true,'10 owner links pending alias');
select is((select default_qty from public.aos_product_alias_v2 where alias_key='EXOFUSIONESSENCE'),2::numeric,'11 learned alias stores physical quantity');
select is((select default_is_pack from public.aos_product_alias_v2 where alias_key='EXOFUSIONESSENCE'),true,'12 learned alias stores pack flag');
select is((select count(*) from public.aos_product_sale_fact_v1 where raw_alias_key='EXOFUSIONESSENCE' and resolution_status='RESOLVED' and physical_qty=2 and is_pack=true),2::bigint,'13 current facts receive physical units');
select is((select count(*) from public.aos_ventas where descripcion='EXOFUSION ESSENCE'),2::bigint,'14 raw sale description preserved after mapping');
select is(public.aos_product_review_resolve_v2('PRC-TEST-TOKEN','MISSING','LINK_EXISTING',1,'CAT:NFCMEN',null,'CURRENT_UNCATALOGED',0,false,'')->>'error','INVALID_PHYSICAL_QTY','15 invalid quantity fails closed');

select is((public.aos_product_review_reopen_v1('PRC-TEST-TOKEN','EXOFUSIONESSENCE','RESOLVED','CAT:NFCMEN','correct mapping')->>'ok')::boolean,true,'16 resolved mapping can be reopened by strong owner');
select is((select count(*) from public.aos_product_sale_fact_v1 where raw_alias_key='EXOFUSIONESSENCE' and resolution_status='REVIEW_REQUIRED'),2::bigint,'17 reopen returns facts to review');
select is((select active from public.aos_product_alias_v2 where alias_key='EXOFUSIONESSENCE'),false,'18 reopen deactivates learned alias until corrected');
select is((public.aos_product_review_reopen_v1('PRC-TEST-TOKEN','DESCARTAR','EXCLUDED',null,'owner reconsidered')->>'ok')::boolean,true,'19 excluded case can be deliberately reopened');
select ok((select count(*) from public.aos_security_log where accion in ('REV_PRC1_PRODUCT_RESOLVE','REV_PRC1_PRODUCT_REOPEN'))>=3,'20 decisions are audit logged');

select * from finish();
rollback;
