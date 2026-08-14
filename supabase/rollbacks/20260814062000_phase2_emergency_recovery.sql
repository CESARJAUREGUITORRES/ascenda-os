-- ASCENDA OS — Phase 2 emergency recovery / security-preserving isolation.
-- Purpose: isolate Cartera if a production regression is detected while keeping
-- login v3, Caja tokenization and hardened ACLs operational.
-- This intentionally NEVER restores legacy anon execution or direct financial writes.

begin;

-- Disable the Cartera surface for every user without deleting reconciliation evidence.
update public.aos_usuarios
set paneles_acceso=array_remove(coalesce(paneles_acceso,'{}'::text[]),'admin-cartera'),
    updated_at=now()
where coalesce(paneles_acceso,'{}'::text[]) @> array['admin-cartera']::text[];

-- Stop browser access to Cartera review/reconciliation only.
revoke execute on function public.aos_cartera_gateway(text,text,text,integer,integer)
  from public,anon,authenticated;
revoke execute on function public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text)
  from public,anon,authenticated;

-- Keep the secured payment/Caja path callable because it is part of continuity of care.
grant execute on function public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text)
  to anon,authenticated,service_role;
grant execute on function public.aos_caja_cotizaciones_gateway(text,text,text,text)
  to anon,authenticated,service_role;
grant execute on function public.aos_caja_abrir_v2(text,text,numeric,numeric,numeric,date)
  to anon,authenticated,service_role;
grant execute on function public.aos_caja_cerrar_v2(text,text,numeric,numeric,numeric,numeric,text)
  to anon,authenticated,service_role;

-- Security invariants are explicitly reasserted during recovery.
revoke execute on function public.aos_login_v2(text,text) from public,anon,authenticated;
revoke execute on function public.aos_verificar_2fa(text,text) from public,anon,authenticated;
revoke execute on function public.aos_sales_intelligence_claim_session(text,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_cia_claim_admin_session_v1(text,text) from public,anon,authenticated;
revoke execute on function public.aos_abonar_cotizacion(text,numeric,text,text,text,text,text,text,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_caja_abrir(text,text,numeric,numeric,numeric,date) from public,anon,authenticated;
revoke execute on function public.aos_caja_cerrar(text,text,numeric,numeric,numeric,numeric,text) from public,anon,authenticated;

revoke insert,update,delete,truncate,references,trigger on table public.aos_ventas from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_categorias from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_servicios from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_toppings from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_catalogo_productos_detalle from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_planes_trabajo from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.aos_plan_trabajo_items from anon,authenticated;

insert into public.aos_security_log(usuario,accion,detalles)
values ('SYSTEM','PHASE2_EMERGENCY_ISOLATION',jsonb_build_object(
  'cartera_surface','disabled',
  'caja_v2','preserved',
  'auth_v3','preserved',
  'legacy_bypass','not_restored',
  'at',now()
));

commit;
