begin;

select plan(46);

select has_table('public','aos_cartera_reconciliacion','bridge exists');
select is((select relrowsecurity from pg_class where oid='public.aos_cartera_reconciliacion'::regclass),true,'bridge has RLS');
select is(has_table_privilege('anon','public.aos_cartera_reconciliacion','SELECT'),false,'anon cannot read bridge');
select is(has_table_privilege('authenticated','public.aos_cartera_reconciliacion','SELECT'),false,'authenticated cannot read bridge');
select is((select count(*) from public.aos_cartera_reconciliacion where source_type='VENTA'),2::bigint,'two advances seeded');
select is((select count(*) from public.aos_cartera_reconciliacion where source_type='COTIZACION'),2::bigint,'two partial quotes seeded');
select is((select count(*) from public.aos_cartera_reconciliacion where estado_reconciliacion='SALDO_CONFIRMADO'),0::bigint,'nothing becomes debt automatically');

select is((select prosecdef from pg_proc where oid='public.aos_sales_intelligence_claim_session(text,text,text,text)'::regprocedure),true,'claim is definer');
select is((select prosecdef from pg_proc where oid='public.aos_cartera_actor(text,text)'::regprocedure),true,'actor validator is definer');
select is((select prosecdef from pg_proc where oid='public.aos_cartera_gateway(text,text,text,integer,integer)'::regprocedure),true,'gateway is definer');
select is((select prosecdef from pg_proc where oid='public.aos_cartera_reconcile(text,uuid,text,text,numeric,numeric,text,text,text)'::regprocedure),true,'reconcile is definer');
select is((select prosecdef from pg_proc where oid='public.aos_abonar_cotizacion_v2(text,text,numeric,text,text,text,text,text,text,text,text,text)'::regprocedure),true,'abono v2 is definer');
select like(coalesce((select array_to_string(proconfig,',') from pg_proc where oid='public.aos_cartera_gateway(text,text,text,integer,integer)'::regprocedure),''),'%search_path=""%','gateway pins empty search_path');
select like(coalesce((select array_to_string(proconfig,',') from pg_proc where oid='public.aos_abonar_cotizacion_v2(text,text,numeric,text,text,text,text,text,text,text,text,text)'::regprocedure),''),'%search_path=""%','abono v2 pins empty search_path');
select is(has_function_privilege('anon','public.aos_abonar_cotizacion(text,numeric,text,text,text,text,text,text,text,text,text)','EXECUTE'),false,'legacy abono denied to anon');
select is(has_function_privilege('anon','public.aos_abonar_cotizacion_v2(text,text,numeric,text,text,text,text,text,text,text,text,text)','EXECUTE'),true,'tokenized abono callable by anon transport');

select is(public.aos_cartera_gateway('','','',50,0)->>'error','UNAUTHORIZED','blank token denied');
select is(public.aos_cartera_gateway('phase2-no-panel-token-000000000000000001','','',50,0)->>'error','UNAUTHORIZED','admin without panel denied');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)->>'ok')::boolean,true,'authorized owner gateway works');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,activeCases}')::bigint,4::bigint,'gateway reports four active candidates');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,historicalAdvancesCutoff}')::bigint,2::bigint,'historical advance count certified');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,historicalAdvancePayments}')::numeric,350::numeric,'advance amounts are payments');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,confirmedAmount}')::numeric,0::numeric,'unreviewed payments are not receivables');

select is(public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'SALDO_CONFIRMADO','CONFIRMADA',800,null,null,'ADELANTO','falta monto'
)->>'error','CONFIRMED_BALANCE_REQUIRED','confirmed debt needs positive balance');

select is((public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'SALDO_CONFIRMADO','CONFIRMADA',800,400,'Q-PART-2','ADELANTO','revisado manualmente'
)->>'ok')::boolean,true,'manual reconciliation succeeds');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,confirmedBalances}')::bigint,1::bigint,'one confirmed receivable');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,confirmedAmount}')::numeric,400::numeric,'confirmed amount is explicit only');

select is(public.aos_abonar_cotizacion_v2(
  '', 'Q-PART-1',200,'EFECTIVO','BOLETA','','SAN ISIDRO','CAJA','','','', '2026-01-25'
)->>'error','UNAUTHORIZED','abono rejects missing token');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','Q-PART-1',701,'EFECTIVO','BOLETA','','SAN ISIDRO','CAJA','','','', '2026-01-25'
)->>'error','OVERPAYMENT','abono blocks overpayment');
select is((select count(*) from public.aos_pagos),0::bigint,'blocked overpayment creates no ledger row');

select is((public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','Q-PART-1',200,'EFECTIVO','BOLETA','','SAN ISIDRO','CAJA','','','', '2026-01-25'
)->>'ok')::boolean,true,'valid partial payment succeeds');
select is((select total_pagado from public.aos_cotizaciones where id='Q-PART-1'),500::numeric,'quote paid total updated atomically');
select is((select saldo_pendiente from public.aos_cotizaciones where id='Q-PART-1'),500::numeric,'quote balance updated atomically');
select is((select estado from public.aos_cotizaciones where id='Q-PART-1'),'PAGADO_PARCIAL','quote remains partial');
select is((select estado_pago from public.aos_ventas where cotizacion_id='Q-PART-1' order by id desc limit 1),'ADELANTO','partial payment is not marked complete');
select is((select tipo from public.aos_ventas where cotizacion_id='Q-PART-1' order by id desc limit 1),'SERVICIO','payment component cannot inflate products');
select is((select count(*) from public.aos_pagos where cotizacion_id='Q-PART-1'),1::bigint,'payment ledger receives one row');
select is((select cr.rol_pago from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.cotizacion_id='Q-PART-1' order by v.id desc limit 1),'COMPLEMENTO','bridge records partial component role');

select is((public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','Q-PART-1',500,'EFECTIVO','BOLETA','','SAN ISIDRO','CAJA','','','', '2026-01-30'
)->>'ok')::boolean,true,'final balance payment succeeds');
select is((select estado from public.aos_cotizaciones where id='Q-PART-1'),'PAGADO_COMPLETO','quote closes after exact balance');
select is((select total_pagado from public.aos_cotizaciones where id='Q-PART-1'),1000::numeric,'final paid total equals quote');
select is((select saldo_pendiente from public.aos_cotizaciones where id='Q-PART-1'),0::numeric,'final balance is zero');
select is((select estado_pago from public.aos_ventas where cotizacion_id='Q-PART-1' order by id desc limit 1),'PAGO COMPLETO','final component is complete');
select is((select cr.rol_pago from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.cotizacion_id='Q-PART-1' order by v.id desc limit 1),'SALDO','bridge records saldo role');
select is((select cr.estado_reconciliacion from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.cotizacion_id='Q-PART-1' order by v.id desc limit 1),'PAGO_RECONCILIADO','final payment is reconciled');
select is((select source_active from public.aos_cartera_reconciliacion where source_type='COTIZACION' and cotizacion_id='Q-PART-1'),false,'closed quote leaves active receivables');

select * from finish();
rollback;
