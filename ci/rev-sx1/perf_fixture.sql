\set ON_ERROR_STOP on
insert into public.aos_usuarios(id,codigo_asesor,nombre,rol,nivel_jerarquia,activo,two_factor,paneles_acceso,sedes_permitidas)
values('00000000-0000-0000-0000-000000000061','SX1-PERF','SX1 PERF','admin',1,true,true,array['admin-sales'],'{}') on conflict do nothing;
insert into public.aos_rrhh(codigo_asesor,nombre,estado) values('SX1-PERF','SX1 PERF','ACTIVO') on conflict do nothing;
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
values(encode(extensions.digest('SX1-PERF-TOKEN','sha256'),'hex'),'00000000-0000-0000-0000-000000000061','PASSWORD_2FA',now()+interval '8 hours') on conflict do nothing;
insert into public.aos_product_identity_v1(product_key,canonical_name) values('SX1:PERF-A','PERF PRODUCT A'),('SX1:PERF-B','PERF PRODUCT B') on conflict do nothing;
insert into public.aos_product_alias_v2(alias_key,alias_text,product_key,default_qty,default_is_pack) values
(public.aos_product_normalize_alias_v2('PERF PRODUCT A'),'PERF PRODUCT A','SX1:PERF-A',1,false),
(public.aos_product_normalize_alias_v2('PERF PACK A'),'PERF PACK A','SX1:PERF-A',2,true),
(public.aos_product_normalize_alias_v2('PERF PRODUCT B'),'PERF PRODUCT B','SX1:PERF-B',1,false)
on conflict do nothing;
insert into public.aos_ventas(fecha,nombres,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,atendio,sede,tipo)
select date '2026-01-01'+(g%230), 'PX'||g, '91'||lpad(g::text,7,'0'), '91'||lpad(g::text,7,'0'), 'COMPRA DE PRODUCTO',
       case when g%3=0 then 'PERF PACK A' when g%2=0 then 'PERF PRODUCT A' else 'PERF PRODUCT B' end,
       'QR',100+(g%7)*10,'PAGO COMPLETO','WILMER','DOC',case when g%2=0 then 'SAN ISIDRO' else 'PUEBLO LIBRE' end,'PRODUCTO'
from generate_series(1,800) g;
insert into public.aos_ventas(fecha,nombres,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,atendio,sede,tipo)
select date '2026-01-01'+(g%230), 'SX'||g, '92'||lpad(g::text,7,'0'), '92'||lpad(g::text,7,'0'), case when g%2=0 then 'HIFU' else 'TOXINA' end,
       case when g%2=0 then 'HIFU' else 'TOXINA' end,'QR',300+(g%9)*20,'PAGO COMPLETO','WILMER','DOC',case when g%2=0 then 'SAN ISIDRO' else 'PUEBLO LIBRE' end,'SERVICIO'
from generate_series(1,800) g;
