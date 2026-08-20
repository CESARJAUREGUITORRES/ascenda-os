\set ON_ERROR_STOP on

-- REV-F6.4 synthetic-only additions on top of certified F6.0–F6.3 fixtures.
create table if not exists public.aos_metas_ventas(
  id uuid primary key default gen_random_uuid(),periodo text unique,meta numeric,moneda text,descripcion text,created_at timestamptz default now(),updated_at timestamptz default now()
);
alter table public.aos_leads add column if not exists anuncio text;
alter table public.aos_agenda_citas add column if not exists etiqueta_campana text;
alter table public.aos_agenda_citas add column if not exists origen_cita text;

-- Auth compatibility stub: F6.4 browser gateway must rely on the existing Sales Intelligence guard.
create or replace function public.aos_sales_intelligence_gateway(p_token text,p_anio integer,p_sede text default '',p_asesor text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if p_token='admin-f64-token-00000000000000000000' then
    return jsonb_build_object('hasData',true,'anio',p_anio,'authorized',true);
  end if;
  return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
end $$;
grant execute on function public.aos_sales_intelligence_gateway(text,integer,text,text) to public,anon,authenticated,service_role;

insert into public.aos_metas_ventas(periodo,meta,moneda,descripcion)
values ('2026-07',1000,'PEN','F6.4 test'),('2026-08',1000,'PEN','F6.4 test')
on conflict(periodo) do update set meta=excluded.meta,moneda=excluded.moneda,descripcion=excluded.descripcion,updated_at=now();

insert into public.aos_ventas(id,venta_id,fecha,celular,numero_limpio,tratamiento,descripcion,monto,estado_pago,asesor,sede,tipo)
values
 (6401,'V6401','2026-08-18','999111111','999111111','BOTOX','BOTOX CANONICO',200,'REGISTRADO','ASESOR','SAN ISIDRO','SERVICIO'),
 (6402,'V6402','2026-08-19','999111111','999111111','PEEL','PEEL CANONICO',150,'REGISTRADO','ASESOR','SAN ISIDRO','SERVICIO'),
 (6403,'V6403','2026-07-10','999630001','999630001','LASER','LASER CANONICO',300,'REGISTRADO','ASESOR 2','PUEBLO LIBRE','SERVICIO')
on conflict(id) do nothing;

insert into public.aos_f5_historical_join_v1(
 sale_id,sale_date,sale_year,sede,canonical_patient_id,patient_link_status,patient_link_method,patient_candidate_count,
 product_applicable,product_resolution_status,product_key,product_resolution_source,cartera_link_status,cartera_row_count,cartera_active_row_count,payment_evidence_row_count,confirmed_balance_row_count
)
values
 (6401,'2026-08-18',2026,'SAN ISIDRO','P1','MATCH','F5_CERTIFIED',1,true,'RESOLVED','BOTOX','F3','F4_LINKED',1,1,1,0),
 (6402,'2026-08-19',2026,'SAN ISIDRO','P1','MATCH','F5_CERTIFIED',1,true,'RESOLVED','PEEL','F3','NO_F4_LINK',0,0,0,0),
 (6403,'2026-07-10',2026,'PUEBLO LIBRE','F63-HIGH','MATCH','F5_CERTIFIED',1,true,'RESOLVED','LASER','F3','NO_F4_LINK',0,0,0,0)
on conflict(sale_id) do nothing;

insert into public.aos_product_sale_fact_base(sale_id,fecha,sede,resolution_status,resolution_source,product_key,canonical_name)
values
 (6401,'2026-08-18','SAN ISIDRO','RESOLVED','F3','BOTOX','Botox Canonico'),
 (6402,'2026-08-19','SAN ISIDRO','RESOLVED','F3','PEEL','Peel Canonico'),
 (6403,'2026-07-10','PUEBLO LIBRE','RESOLVED','F3','LASER','Laser Canonico')
on conflict(sale_id) do nothing;

insert into public.aos_cartera_reconciliacion(source_type,venta_row_id,rol_pago,estado_reconciliacion,monto_registrado,source_active)
select 'VENTA',6401,'PAGO','EVIDENCIA_REGISTRADA',200,true
where not exists(select 1 from public.aos_cartera_reconciliacion where venta_row_id=6401);

insert into public.aos_leads(id,fecha,celular,numero_limpio,tratamiento,hora_ingreso,anuncio)
values (6401,'2026-08-01','999111111','999111111','BOTOX','2026-08-01 10:00+00','F64-CAMPAIGN')
on conflict(id) do nothing;

insert into public.aos_agenda_citas(id,fecha_cita,hora_cita,tratamiento,tipo_cita,sede,numero,numero_limpio,estado_cita,asesor,venta_id_match,lead_id_origen,etiqueta_campana,origen_cita)
values ('F64-ACQ-1','2026-08-17','11:00','BOTOX','PRIMERA','SAN ISIDRO','999111111','999111111','ASISTIO','ASESOR','6401',6401,'F64-CAMPAIGN','META')
on conflict(id) do nothing;
