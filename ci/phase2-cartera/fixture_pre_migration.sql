-- Synthetic FASE 2 fixture. No production identities or patient data.

insert into public.aos_rrhh(
  codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,permisos,estado
) values
  ('CAROWNER','CARTERA OWNER','TEST','DIRECTOR GENERAL','SAN ISIDRO','cartera.owner','owner-pass','{}','ACTIVO'),
  ('CARNOPE','CARTERA NO ACCESS','TEST','ADMINISTRADOR','PUEBLO LIBRE','cartera.nope','nope-pass','{}','ACTIVO'),
  ('CARSINGLE','CARTERA SINGLE','TEST','ADMINISTRADOR','SAN ISIDRO','cartera.single','single-pass','{}','ACTIVO'),
  ('CARNULL','CARTERA NULL SITE','TEST','ADMINISTRADOR','SAN ISIDRO','cartera.nullsite','null-pass','{}','ACTIVO');

insert into public.aos_usuarios(
  codigo_asesor,nombre,email,rol,paneles_acceso,nivel_jerarquia,
  sedes_permitidas,area,cargo,two_factor,activo
) values
  ('CAROWNER','CARTERA OWNER','owner@example.invalid','admin',
   array['admin-sales-intelligence','admin-cartera','admin-caja'],1,
   array['SAN ISIDRO','PUEBLO LIBRE'],'DIRECCION','DIRECTOR GENERAL',true,true),
  ('CARNOPE','CARTERA NO ACCESS','nope@example.invalid','admin',
   array['admin-home'],1,array['PUEBLO LIBRE'],'ADMIN','ADMINISTRADOR',true,true),
  ('CARSINGLE','CARTERA SINGLE','single@example.invalid','admin',
   array['admin-cartera','admin-caja'],2,array['SAN ISIDRO'],'ADMIN','ADMINISTRADOR',true,true),
  ('CARNULL','CARTERA NULL SITE','nullsite@example.invalid','admin',
   array['admin-cartera','admin-caja'],2,array[null::text,'SAN ISIDRO'],'ADMIN','ADMINISTRADOR',true,true);

insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at)
select encode(extensions.digest('phase2-owner-token-0000000000000000000001','sha256'),'hex'),
       id,nombre,now()+interval '8 hours'
from public.aos_usuarios where codigo_asesor='CAROWNER';

insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at)
select encode(extensions.digest('phase2-no-panel-token-000000000000000001','sha256'),'hex'),
       id,nombre,now()+interval '8 hours'
from public.aos_usuarios where codigo_asesor='CARNOPE';

insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at)
select encode(extensions.digest('phase2-single-site-token-00000000000000001','sha256'),'hex'),
       id,nombre,now()+interval '8 hours'
from public.aos_usuarios where codigo_asesor='CARSINGLE';

insert into public.aos_cia_admin_sessions(token_hash,user_id,usuario,expires_at)
select encode(extensions.digest('phase2-null-site-token-000000000000000001','sha256'),'hex'),
       id,nombre,now()+interval '8 hours'
from public.aos_usuarios where codigo_asesor='CARNULL';

insert into public.aos_caja_sesiones(
  id,sede,fecha,estado,abierto_por,abierto_por_user_id
)
select x.id,x.sede,(now() at time zone 'America/Lima')::date,'ABIERTA',u.nombre,u.id
from (values
  ('CASH-SI-TODAY','SAN ISIDRO','CAROWNER'),
  ('CASH-PL-TODAY','PUEBLO LIBRE','CAROWNER'),
  ('CASH-SINGLE-SI','SAN ISIDRO','CARSINGLE')
) as x(id,sede,codigo_asesor)
join public.aos_usuarios u using (codigo_asesor);

insert into public.aos_cotizaciones(
  id,numero_limpio,nombre_paciente,dni_paciente,estado,subtotal,total_pagado,
  saldo_pendiente,sede,asesor,fecha_creacion
) values
  ('Q-PART-1','999000001','PACIENTE UNO','10000001','PAGADO_PARCIAL',1000,300,700,'SAN ISIDRO','ASESOR A','2026-01-10'),
  ('Q-PART-2','999000002','PACIENTE DOS','10000002','PAGADO_PARCIAL',800,200,600,'PUEBLO LIBRE','ASESOR B','2026-02-10'),
  ('Q-DONE-1','999000003','PACIENTE TRES','10000003','PAGADO_COMPLETO',500,500,0,'SAN ISIDRO','ASESOR A','2026-03-10'),
  ('Q-CANCEL-1','999000004','PACIENTE CUATRO','10000004','ANULADO',900,0,900,'PUEBLO LIBRE','ASESOR B','2026-04-10'),
  ('Q-CANCEL-2','999000002','PACIENTE DOS','10000002','ANULADO',800,200,600,'PUEBLO LIBRE','ASESOR B','2026-02-11');

insert into public.aos_cotizacion_items(cotizacion_id,tipo,nombre,descripcion,cantidad,precio_unitario,subtotal)
values
  ('Q-PART-1','SERVICIO','TRATAMIENTO A','TRATAMIENTO A',1,1000,1000),
  ('Q-PART-2','OTROS','OTROS','OTROS',1,800,800),
  ('Q-DONE-1','PRODUCTO','PRODUCTO X','PRODUCTO X',1,500,500);

insert into public.aos_ventas(
  fecha,nombres,apellidos,dni,celular,numero_limpio,tratamiento,descripcion,pago,
  monto,estado_pago,asesor,sede,tipo,venta_id,created_at,updated_at
) values
  ('2026-01-10','PACIENTE UNO','TEST','10000001','999000001','999000001',
   'TRATAMIENTO A','ADELANTO TRATAMIENTO A','EFECTIVO',300,'ADELANTO','ASESOR A','SAN ISIDRO','SERVICIO','V-ADV-1',now(),now()),
  ('2026-02-10','PACIENTE DOS','TEST','10000002','999000002','999000002',
   'OTROS','PRIMERA PARTE OTROS','EFECTIVO',50,'ADELANTO','ASESOR B','PUEBLO LIBRE','SERVICIO','V-ADV-2',now(),now()),
  ('2026-01-20','PACIENTE UNO','TEST','10000001','999000001','999000001',
   'TRATAMIENTO A','SALDO TRATAMIENTO A','EFECTIVO',700,'PAGO COMPLETO','ASESOR A','SAN ISIDRO','SERVICIO','V-PAY-1',now(),now());
