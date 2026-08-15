-- ASCENDA OS — F4 emergency recovery (fail closed).
-- Do not restore weak legacy mutation paths. Keep read-only F4 visibility available,
-- disable new revenue mutations/candidate reconciliation until a corrected release is ready.

revoke execute on function public.aos_editar_venta_v4(text,bigint,timestamptz,jsonb,text) from public,anon,authenticated;
revoke execute on function public.aos_importar_ventas_v4(text,jsonb) from public,anon,authenticated;
revoke execute on function public.aos_grabar_venta_caja_v4(text,text,text,text,text,text,text,text,text,text,text,jsonb,text,numeric,text,text,text,text,text,text,text,text,numeric) from public,anon,authenticated;
revoke execute on function public.aos_cartera_reconcile_v2(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text,text) from public,anon,authenticated;

-- Read-only operations remain available for diagnosis.
grant execute on function public.aos_sales_admin_gateway_v4(text,integer,integer,text,text,text) to anon,authenticated;
grant execute on function public.aos_sales_admin_sale_v4(text,bigint) to anon,authenticated;
grant execute on function public.aos_importar_ventas_preview_v4(text,jsonb) to anon,authenticated;
grant execute on function public.aos_cartera_candidates_v2(text,uuid) to anon,authenticated;

-- Legacy mutation functions intentionally remain revoked after recovery.
revoke execute on function public.aos_editar_venta(bigint,jsonb,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_importar_ventas(jsonb) from public,anon,authenticated;
revoke execute on function public.aos_grabar_venta_caja(text,text,text,text,text,text,text,text,text,text,jsonb,text,numeric,text,text,text,text,text,text,text,text,numeric) from public,anon,authenticated;
revoke execute on function public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text) from public,anon,authenticated;

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F4_REVENUE_RECOVERY',jsonb_build_object('mode','FAIL_CLOSED','at',now()));
