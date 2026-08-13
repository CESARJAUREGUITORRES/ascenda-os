-- ASCENDA OS — Sales Intelligence V2 / Phase B
-- Minimal reconciliation bridge. It does NOT duplicate monetary facts.
-- Financial truth remains in aos_ventas / aos_cotizaciones / aos_pagos.

CREATE TABLE IF NOT EXISTS public.aos_venta_pago_vinculos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venta_row_id bigint NOT NULL REFERENCES public.aos_ventas(id) ON DELETE RESTRICT,
  cotizacion_id text NULL REFERENCES public.aos_cotizaciones(id) ON DELETE SET NULL,
  grupo_pago_id uuid NOT NULL DEFAULT gen_random_uuid(),
  rol_pago text NOT NULL DEFAULT 'ADELANTO' CHECK (rol_pago IN ('UNICO','ADELANTO','PARTE_1','PARTE_2','SALDO','COMPLEMENTO')),
  estado_reconciliacion text NOT NULL DEFAULT 'PENDIENTE_RECONCILIAR' CHECK (estado_reconciliacion IN ('PENDIENTE_RECONCILIAR','SALDO_CONFIRMADO','PAGO_RECONCILIADO','CERRADO','NO_ES_DEUDA','REVISAR')),
  confianza numeric(5,2) NULL CHECK (confianza IS NULL OR (confianza >= 0 AND confianza <= 100)),
  match_reason jsonb NOT NULL DEFAULT '{}'::jsonb,
  confirmado_por text NULL,
  confirmed_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT aos_venta_pago_vinculos_venta_unique UNIQUE (venta_row_id)
);

CREATE INDEX IF NOT EXISTS idx_aos_venta_pago_vinculos_cotizacion
  ON public.aos_venta_pago_vinculos(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_aos_venta_pago_vinculos_grupo
  ON public.aos_venta_pago_vinculos(grupo_pago_id);
CREATE INDEX IF NOT EXISTS idx_aos_venta_pago_vinculos_estado
  ON public.aos_venta_pago_vinculos(estado_reconciliacion);

ALTER TABLE public.aos_venta_pago_vinculos ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.aos_venta_pago_vinculos IS
'Bridge/audit table for reconciling legacy sales payment rows with cotizaciones. Stores links/status only; never becomes a parallel financial ledger.';
