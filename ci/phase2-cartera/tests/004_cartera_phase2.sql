begin;

select plan(96);

select has_table('public','aos_cartera_reconciliacion','bridge exists');
select is((select relrowsecurity from pg_class where oid='public.aos_cartera_reconciliacion'::regclass),true,'bridge has RLS');
select is(has_table_privilege('anon','public.aos_cartera_reconciliacion','SELECT'),false,'anon cannot read bridge');
select is(has_table_privilege('authenticated','public.aos_cartera_reconciliacion','SELECT'),false,'authenticated cannot read bridge');
select is((select relrowsecurity from pg_class where oid='public.aos_cotizaciones'::regclass),true,'quotes have RLS');
select is(has_table_privilege('anon','public.aos_cotizaciones','SELECT'),false,'anon cannot read quotes directly');
select is((select relrowsecurity from pg_class where oid='public.aos_cotizacion_items'::regclass),true,'quote items have RLS');
select is(has_table_privilege('anon','public.aos_cotizacion_items','SELECT'),false,'anon cannot read quote items directly');
select is((select relrowsecurity from pg_class where oid='public.aos_pagos'::regclass),true,'payments have RLS');
select is(has_table_privilege('anon','public.aos_pagos','SELECT'),false,'anon cannot read payments directly');
select is((select count(*) from pg_trigger where tgrelid='public.aos_ventas'::regclass and tgname='trg_aos_cartera_sync_venta' and not tgisinternal),0::bigint,'legacy sales cannot launder rows into bridge through trigger');
select has_column('public','aos_pagos','request_id','payment idempotency key exists');
select has_column('public','aos_pagos','request_hash','payment request fingerprint exists');
select has_column('public','aos_pagos','cash_session_id','payment cash session binding exists');
select has_column('public','aos_pagos','registrado_por_user_id','payment actor binding exists');
select has_index('public','aos_pagos','aos_pagos_request_id_uidx','payment request id is unique');
select has_column('public','aos_caja_sesiones','abierto_por_user_id','cash session owner id exists');
select is(has_table_privilege('anon','public.aos_caja_sesiones','INSERT'),false,'anon cannot insert cash sessions directly');
select is(has_table_privilege('anon','public.aos_caja_sesiones','UPDATE'),false,'anon cannot update cash sessions directly');
select is((select count(*) from public.aos_cartera_reconciliacion where source_type='VENTA'),2::bigint,'two advances seeded');
select is((select count(*) from public.aos_cartera_reconciliacion where source_type='COTIZACION'),2::bigint,'two partial quotes seeded');
select is((select count(*) from public.aos_cartera_reconciliacion where estado_reconciliacion='SALDO_CONFIRMADO'),0::bigint,'nothing becomes debt automatically');
select is((select count(*) from pg_constraint where conrelid='public.aos_cartera_reconciliacion'::regclass and conname='aos_cartera_monto_finite_chk'),1::bigint,'recorded payment amount has finite-value constraint');

select is((select prosecdef from pg_proc where oid='public.aos_cartera_actor(text,text)'::regprocedure),true,'actor validator is definer');
select is((select prosecdef from pg_proc where oid='public.aos_cartera_gateway(text,text,text,integer,integer)'::regprocedure),true,'gateway is definer');
select is((select prosecdef from pg_proc where oid='public.aos_caja_cotizaciones_gateway(text,text,text,text)'::regprocedure),true,'quote gateway is definer');
select is((select prosecdef from pg_proc where oid='public.aos_cartera_reconcile(text,uuid,timestamp with time zone,text,text,numeric,numeric,text,text,text)'::regprocedure),true,'reconcile is definer');
select is((select prosecdef from pg_proc where oid='public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text)'::regprocedure),true,'abono v2 is definer');
select ok(coalesce((select array_to_string(proconfig,',') from pg_proc where oid='public.aos_cartera_gateway(text,text,text,integer,integer)'::regprocedure),'') like '%search_path=""%','gateway pins empty search_path');
select ok(coalesce((select array_to_string(proconfig,',') from pg_proc where oid='public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text)'::regprocedure),'') like '%search_path=""%','abono v2 pins empty search_path');
select is(has_function_privilege('anon','public.aos_abonar_cotizacion(text,numeric,text,text,text,text,text,text,text,text,text)','EXECUTE'),false,'legacy abono denied to anon');
select is(has_function_privilege('anon','public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text)','EXECUTE'),true,'tokenized abono callable by anon transport');
select is(has_function_privilege('anon','public.aos_caja_cotizaciones_gateway(text,text,text,text)','EXECUTE'),true,'quote gateway callable by anon transport');
select is(to_regprocedure('public.aos_cartera_reconcile(text,uuid,text,text,numeric,numeric,text,text,text)') is null,true,'obsolete reconcile overload is absent');
select is(to_regprocedure('public.aos_abonar_cotizacion_v2(text,text,numeric,text,text,text,text,text,text,text,text,text)') is null,true,'obsolete payment overload is absent');
select ok(pg_get_functiondef('public.aos_sales_intelligence_claim_session(text,text,text,text)'::regprocedure) like '%aos_sales_intelligence_access%','certified Phase 1 session issuer is restored');

select is(public.aos_cartera_gateway('','','',50,0)->>'error','UNAUTHORIZED','blank token denied');
select is(public.aos_cartera_gateway('phase2-no-panel-token-000000000000000001','','',50,0)->>'error','UNAUTHORIZED','admin without panel denied');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)->>'ok')::boolean,true,'authorized owner gateway works');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,activeCases}')::bigint,4::bigint,'gateway reports four active candidates');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,historicalAdvancesCutoff}')::bigint,2::bigint,'historical advance count certified');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,historicalAdvancePayments}')::numeric,350::numeric,'advance amounts are payments');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,confirmedAmount}')::numeric,0::numeric,'unreviewed payments are not receivables');
select is((public.aos_cartera_gateway('phase2-single-site-token-00000000000000001','','',50,0)->>'ok')::boolean,true,'single-site gateway works');
select is((public.aos_cartera_gateway('phase2-single-site-token-00000000000000001','','',50,0)#>>'{summary,activeCases}')::bigint,2::bigint,'single-site gateway is server scoped');
select is(public.aos_cartera_gateway('phase2-single-site-token-00000000000000001','','PUEBLO LIBRE',50,0)->>'error','FORBIDDEN_SEDE','single-site admin cannot request another site');
select is(public.aos_cartera_gateway('phase2-null-site-token-000000000000000001','','PUEBLO LIBRE',50,0)->>'error','FORBIDDEN_SEDE','NULL site entry cannot bypass gateway scope');
select is(jsonb_array_length(public.aos_caja_cotizaciones_gateway('phase2-single-site-token-00000000000000001','LIST','999000001',null)->'rows'),1,'quote list returns permitted site');
select is(jsonb_array_length(public.aos_caja_cotizaciones_gateway('phase2-single-site-token-00000000000000001','LIST','999000002',null)->'rows'),0,'quote list hides forbidden site');
select is(public.aos_caja_cotizaciones_gateway('phase2-single-site-token-00000000000000001','DETAIL',null,'Q-PART-2')->>'error','QUOTE_NOT_FOUND','quote detail hides forbidden site');

create temporary table phase2_case_versions as
select id,updated_at,source_type,cotizacion_id from public.aos_cartera_reconciliacion;

select is(public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  (select p.updated_at from phase2_case_versions p join public.aos_cartera_reconciliacion cr on cr.id=p.id join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'SALDO_CONFIRMADO','CONFIRMADA',800,null,null,'ADELANTO','falta monto'
)->>'error','CONFIRMED_BALANCE_REQUIRED','confirmed debt needs explicit total and balance');
select is(public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-1'),
  (select p.updated_at from phase2_case_versions p join public.aos_cartera_reconciliacion cr on cr.id=p.id join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-1'),
  'SALDO_CONFIRMADO','CONFIRMADA','NaN'::numeric,'NaN'::numeric,null,'ADELANTO','non finite'
)->>'error','INVALID_AMOUNT','non-finite values cannot poison confirmed totals');

select is(public.aos_cartera_reconcile(
  'phase2-single-site-token-00000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  (select p.updated_at from phase2_case_versions p join public.aos_cartera_reconciliacion cr on cr.id=p.id join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'REVISAR','ALTA',null,null,null,'ADELANTO','cross site'
)->>'error','FORBIDDEN_SEDE','single-site admin cannot reconcile another site');
select is(public.aos_cartera_reconcile(
  'phase2-null-site-token-000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  (select p.updated_at from phase2_case_versions p join public.aos_cartera_reconciliacion cr on cr.id=p.id join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'REVISAR','ALTA',null,null,null,'ADELANTO','null array attack'
)->>'error','FORBIDDEN_SEDE','NULL site entry cannot bypass reconciliation scope');

select is(public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  (select p.updated_at from phase2_case_versions p join public.aos_cartera_reconciliacion cr on cr.id=p.id join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'SALDO_CONFIRMADO','CONFIRMADA',800,600,'Q-CANCEL-2','ADELANTO','cancelled quote'
)->>'error','QUOTE_NOT_COLLECTIBLE','cancelled quote cannot confirm receivable');

select is((public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  (select p.updated_at from phase2_case_versions p join public.aos_cartera_reconciliacion cr on cr.id=p.id join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'SALDO_CONFIRMADO','CONFIRMADA',800,600,'Q-PART-2','ADELANTO','revisado manualmente'
)->>'ok')::boolean,true,'manual reconciliation succeeds');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,confirmedBalances}')::bigint,1::bigint,'one confirmed receivable');
select is((public.aos_cartera_gateway('phase2-owner-token-0000000000000000000001','','',50,0)#>>'{summary,confirmedAmount}')::numeric,600::numeric,'confirmed amount exactly matches quote evidence');
select is(public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select cr.id from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  (select p.updated_at from phase2_case_versions p join public.aos_cartera_reconciliacion cr on cr.id=p.id join public.aos_ventas v on v.id=cr.venta_row_id where v.venta_id='V-ADV-2'),
  'REVISAR','ALTA',800,null,'Q-PART-2','ADELANTO','stale'
)->>'error','STALE_CASE','stale reconciliation is rejected');
select is(public.aos_cartera_reconcile(
  'phase2-owner-token-0000000000000000000001',
  (select id from public.aos_cartera_reconciliacion where source_type='COTIZACION' and cotizacion_id='Q-PART-1'),
  (select updated_at from public.aos_cartera_reconciliacion where source_type='COTIZACION' and cotizacion_id='Q-PART-1'),
  'SALDO_CONFIRMADO','CONFIRMADA',1000,1100,null,'ADELANTO','imposible'
)->>'error','BALANCE_EXCEEDS_EXPECTED_TOTAL','impossible receivable is rejected');

select is(public.aos_abonar_cotizacion_v2(
  '', '00000000-0000-0000-0000-000000000001','Q-PART-1',200,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'error','UNAUTHORIZED','abono rejects missing token');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000021','Q-PART-1','NaN'::numeric,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'error','INVALID_PAYMENT','payment rejects non-finite amount');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-single-site-token-00000000000000001','00000000-0000-0000-0000-000000000002','Q-PART-2',100,'EFECTIVO','BOLETA','','','CASH-SINGLE-SI'
)->>'error','FORBIDDEN_SEDE','single-site admin cannot pay another site');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-null-site-token-000000000000000001','00000000-0000-0000-0000-000000000020','Q-PART-2',100,'EFECTIVO','BOLETA','','','CASH-SINGLE-SI'
)->>'error','FORBIDDEN_SEDE','NULL site entry cannot bypass payment scope');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000003','Q-PART-2',100,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'error','INVALID_CASH_SESSION','cash session must match quote site');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000004','Q-PART-1',701,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'error','OVERPAYMENT','abono blocks overpayment');
select is((select count(*) from public.aos_pagos),0::bigint,'blocked payments create no ledger row');

select is((public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000005','Q-PART-1',200,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'ok')::boolean,true,'valid partial payment succeeds');
select is((select total_pagado from public.aos_cotizaciones where id='Q-PART-1'),500::numeric,'quote paid total updated atomically');
select is((select saldo_pendiente from public.aos_cotizaciones where id='Q-PART-1'),500::numeric,'quote balance updated atomically');
select is((select estado from public.aos_cotizaciones where id='Q-PART-1'),'PAGADO_PARCIAL','quote remains partial');
select is((select estado_pago from public.aos_ventas where cotizacion_id='Q-PART-1' order by id desc limit 1),'ADELANTO','partial payment is not marked complete');
select is((select tipo from public.aos_ventas where cotizacion_id='Q-PART-1' order by id desc limit 1),'SERVICIO','payment component cannot inflate products');
select is((select count(*) from public.aos_pagos where cotizacion_id='Q-PART-1'),1::bigint,'payment ledger receives one row');
select is((select request_id from public.aos_pagos where cotizacion_id='Q-PART-1'),'00000000-0000-0000-0000-000000000005'::uuid,'idempotency key is persisted');
select is(length((select request_hash from public.aos_pagos where cotizacion_id='Q-PART-1')),64,'request fingerprint is persisted');
select is((select cash_session_id from public.aos_pagos where cotizacion_id='Q-PART-1'),'CASH-SI-TODAY','cash session binding is persisted');
select is((select registrado_por_user_id from public.aos_pagos where cotizacion_id='Q-PART-1'),(select id from public.aos_usuarios where codigo_asesor='CAROWNER'),'verified actor id is persisted');
select is((select registrado_por from public.aos_pagos where cotizacion_id='Q-PART-1'),'CARTERA OWNER','verified actor name is persisted');
select is((select cr.rol_pago from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.cotizacion_id='Q-PART-1' order by v.id desc limit 1),'COMPLEMENTO','bridge records partial component role');

select is((public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000005','Q-PART-1',200,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'ok')::boolean,true,'same idempotency key returns success');
select is((public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000005','Q-PART-1',200,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'replay')::boolean,true,'same idempotency key is marked replay');
select is((select count(*) from public.aos_pagos where cotizacion_id='Q-PART-1'),1::bigint,'replay creates no second payment');
select is((select total_pagado from public.aos_cotizaciones where id='Q-PART-1'),500::numeric,'replay does not change quote total');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000005','Q-PART-1',201,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'error','IDEMPOTENCY_CONFLICT','changed replay is rejected');
select is(public.aos_abonar_cotizacion_v2(
  'phase2-single-site-token-00000000000000001','00000000-0000-0000-0000-000000000005','Q-PART-1',200,'EFECTIVO','BOLETA','','','CASH-SINGLE-SI'
)->>'error','IDEMPOTENCY_CONFLICT','idempotency key cannot be stolen by another actor');

select is((public.aos_abonar_cotizacion_v2(
  'phase2-owner-token-0000000000000000000001','00000000-0000-0000-0000-000000000006','Q-PART-1',500,'EFECTIVO','BOLETA','','','CASH-SI-TODAY'
)->>'ok')::boolean,true,'final balance payment succeeds');
select is((select estado from public.aos_cotizaciones where id='Q-PART-1'),'PAGADO_COMPLETO','quote closes after exact balance');
select is((select total_pagado from public.aos_cotizaciones where id='Q-PART-1'),1000::numeric,'final paid total equals quote');
select is((select saldo_pendiente from public.aos_cotizaciones where id='Q-PART-1'),0::numeric,'final balance is zero');
select is((select estado_pago from public.aos_ventas where cotizacion_id='Q-PART-1' order by id desc limit 1),'PAGO COMPLETO','final component is complete');
select is((select cr.rol_pago from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.cotizacion_id='Q-PART-1' order by v.id desc limit 1),'SALDO','bridge records saldo role');
select is((select cr.estado_reconciliacion from public.aos_cartera_reconciliacion cr join public.aos_ventas v on v.id=cr.venta_row_id where v.cotizacion_id='Q-PART-1' order by v.id desc limit 1),'PAGO_RECONCILIADO','final payment is reconciled');
select is((select source_active from public.aos_cartera_reconciliacion where source_type='COTIZACION' and cotizacion_id='Q-PART-1'),false,'closed quote leaves active receivables');

update public.aos_cotizaciones set total_pagado=250,saldo_pendiente=550,updated_at=now() where id='Q-PART-2';
select is((select estado_reconciliacion from public.aos_cartera_reconciliacion where source_type='VENTA' and venta_row_id=(select id from public.aos_ventas where venta_id='V-ADV-2')),'REVISAR','linked sale approval is invalidated after quote change');
select is((select estado_reconciliacion from public.aos_cartera_reconciliacion where source_type='COTIZACION' and cotizacion_id='Q-PART-2'),'REVISAR','quote source edit invalidates quote approval');

select * from finish();
rollback;
