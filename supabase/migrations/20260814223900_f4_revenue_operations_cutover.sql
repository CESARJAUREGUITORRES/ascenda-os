-- ASCENDA OS — F4 Revenue Operations controlled cutover.
-- Apply only after F4 browser/proxy code is deployed and owner canary passes.
-- Secure wrappers remain SECURITY DEFINER and can call the retired legacy functions internally.

revoke execute on function public.aos_editar_venta(bigint,jsonb,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_importar_ventas(jsonb) from public,anon,authenticated;
revoke execute on function public.aos_grabar_venta_caja(text,text,text,text,text,text,text,text,text,text,jsonb,text,numeric,text,text,text,text,text,text,text,text,numeric) from public,anon,authenticated;
revoke execute on function public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text) from public,anon,authenticated;

-- Reads remain temporarily compatible because the legacy KronIA context still consumes
-- aos_ventas_admin. F4 secures the operational UI and all revenue mutation paths; the
-- remaining read-only legacy consumer is explicitly tracked for the Intelligence/KronIA stream.

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F4_REVENUE_CUTOVER',jsonb_build_object(
  'legacy_sale_edit_execute',false,
  'legacy_import_execute',false,
  'legacy_caja_sale_execute',false,
  'legacy_cartera_reconcile_execute',false,
  'at',now()
));
