-- WA-L6 TEST ONLY — minimal sales boundary used by the explicit appointment->sale join.
create table if not exists public.aos_ventas(
  id bigserial primary key,
  venta_id text,
  fecha date,
  monto numeric,
  moneda text
);
alter table public.aos_ventas add column if not exists venta_id text;
alter table public.aos_ventas add column if not exists fecha date;
alter table public.aos_ventas add column if not exists monto numeric;
alter table public.aos_ventas add column if not exists moneda text;

grant select,insert,update,delete on public.aos_ventas to service_role;

-- Deterministic L6 admin authority on the test admin identity.
update public.aos_usuarios
set paneles_acceso=array['admin-chats','admin-marketing','admin-whatsapp']::text[], two_factor=true, activo=true
where id='11111111-1111-4111-8111-111111111111'::uuid;
