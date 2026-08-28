-- CATALOG SEP2026 — explicit price currency
-- Business price lists now contain PEN and USD. Never infer currency from numeric value.
begin;

alter table public.aos_catalogo_servicios
  add column if not exists moneda text not null default 'PEN';

alter table public.aos_catalogo_servicios
  drop constraint if exists aos_catalogo_servicios_moneda_check;
alter table public.aos_catalogo_servicios
  add constraint aos_catalogo_servicios_moneda_check
  check (moneda in ('PEN','USD'));

comment on column public.aos_catalogo_servicios.moneda is
  'ISO-like operational price currency for precio_base/precio_oferta. Current allowed values: PEN, USD.';

alter table public.aos_catalogo_toppings
  add column if not exists moneda text not null default 'PEN';

alter table public.aos_catalogo_toppings
  drop constraint if exists aos_catalogo_toppings_moneda_check;
alter table public.aos_catalogo_toppings
  add constraint aos_catalogo_toppings_moneda_check
  check (moneda in ('PEN','USD'));

comment on column public.aos_catalogo_toppings.moneda is
  'Operational price currency for topping precio. Current allowed values: PEN, USD.';

commit;
