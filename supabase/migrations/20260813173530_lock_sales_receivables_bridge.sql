-- ASCENDA OS — lock reconciliation bridge from direct client access.
-- Future writes must go through an explicit reviewed admin RPC.

REVOKE ALL ON TABLE public.aos_venta_pago_vinculos FROM anon, authenticated;
GRANT ALL ON TABLE public.aos_venta_pago_vinculos TO service_role;

COMMENT ON TABLE public.aos_venta_pago_vinculos IS
'Internal reconciliation bridge. Direct anon/authenticated access revoked; future mutations require reviewed administrative RPC.';
