-- ASCENDA OS — Sales Intelligence V2 / Receivables summary
-- Aggregate-only, read-only. Does not infer that stored balances are enforceable debt.

CREATE OR REPLACE FUNCTION public.aos_sales_receivables_summary()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
WITH partials AS (
  SELECT
    count(*)::int AS n,
    coalesce(sum(subtotal),0) AS subtotal,
    coalesce(sum(total_pagado),0) AS pagado,
    coalesce(sum(saldo_pendiente),0) AS saldo,
    min(fecha_creacion) AS primera_fecha,
    max(fecha_creacion) AS ultima_fecha,
    count(*) FILTER (WHERE current_date-fecha_creacion <= 30)::int AS b0_30,
    count(*) FILTER (WHERE current_date-fecha_creacion BETWEEN 31 AND 60)::int AS b31_60,
    count(*) FILTER (WHERE current_date-fecha_creacion BETWEEN 61 AND 90)::int AS b61_90,
    count(*) FILTER (WHERE current_date-fecha_creacion > 90)::int AS b90_plus,
    coalesce(sum(saldo_pendiente) FILTER (WHERE current_date-fecha_creacion <= 30),0) AS s0_30,
    coalesce(sum(saldo_pendiente) FILTER (WHERE current_date-fecha_creacion BETWEEN 31 AND 60),0) AS s31_60,
    coalesce(sum(saldo_pendiente) FILTER (WHERE current_date-fecha_creacion BETWEEN 61 AND 90),0) AS s61_90,
    coalesce(sum(saldo_pendiente) FILTER (WHERE current_date-fecha_creacion > 90),0) AS s90_plus
  FROM public.aos_cotizaciones
  WHERE estado='PAGADO_PARCIAL'
), legacy AS (
  SELECT count(*)::int AS n, coalesce(sum(monto),0) AS monto, min(fecha) AS primera_fecha, max(fecha) AS ultima_fecha
  FROM public.aos_ventas
  WHERE estado_pago='ADELANTO'
), pipeline AS (
  SELECT count(*)::int AS n, coalesce(sum(saldo_pendiente),0) AS saldo
  FROM public.aos_cotizaciones
  WHERE estado IN ('CREADO','POR_PAGAR')
), annulled AS (
  SELECT count(*)::int AS n, coalesce(sum(saldo_pendiente),0) AS saldo
  FROM public.aos_cotizaciones
  WHERE estado='ANULADO'
), ledger AS (
  SELECT count(*)::int AS n, coalesce(sum(monto),0) AS monto, max(fecha_pago) AS ultimo_pago
  FROM public.aos_pagos
)
SELECT jsonb_build_object(
  'partialCandidates',jsonb_build_object(
    'count',p.n,'subtotal',p.subtotal,'paidRecorded',p.pagado,'balance',p.saldo,
    'firstDate',p.primera_fecha,'lastDate',p.ultima_fecha,
    'ageing',jsonb_build_array(
      jsonb_build_object('bucket','0-30','count',p.b0_30,'balance',p.s0_30),
      jsonb_build_object('bucket','31-60','count',p.b31_60,'balance',p.s31_60),
      jsonb_build_object('bucket','61-90','count',p.b61_90,'balance',p.s61_90),
      jsonb_build_object('bucket','90+','count',p.b90_plus,'balance',p.s90_plus)
    )
  ),
  'legacyAdvances',jsonb_build_object('count',l.n,'amount',l.monto,'firstDate',l.primera_fecha,'lastDate',l.ultima_fecha),
  'pipeline',jsonb_build_object('count',pi.n,'balance',pi.saldo),
  'annulledExcluded',jsonb_build_object('count',a.n,'residualBalance',a.saldo),
  'paymentLedger',jsonb_build_object('count',g.n,'amount',g.monto,'lastPaymentDate',g.ultimo_pago),
  'policy',jsonb_build_object(
    'confirmedDebt',0,
    'status','PENDING_RECONCILIATION',
    'note','Stored partial balances are candidates only until historical payments are reconciled.'
  )
)
FROM partials p CROSS JOIN legacy l CROSS JOIN pipeline pi CROSS JOIN annulled a CROSS JOIN ledger g;
$function$;

COMMENT ON FUNCTION public.aos_sales_receivables_summary() IS
'Aggregate-only receivables overview. Separates partial-balance candidates, legacy advances, pipeline, annulled balances and payment-ledger coverage.';
