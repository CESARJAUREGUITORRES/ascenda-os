-- WA-4A.1C isolated TEST source fixture. Synthetic only.
-- Assumes WA-4A.1B catalog_fixture already created exactly 167 services + 50 products.

create table if not exists public.aos_catalogo_toppings (
  id text primary key,
  nombre text not null,
  categoria_vinculada text,
  precio numeric,
  descripcion text,
  tipo_pago text,
  sesiones text,
  estado text default 'ACTIVO',
  created_at timestamptz default now()
);

delete from public.aos_catalogo_toppings;
insert into public.aos_catalogo_toppings(id,nombre,categoria_vinculada,precio,descripcion,tipo_pago,sesiones,estado)
select gen_random_uuid()::text,
       'TOPPING TEST '||gs,
       case when gs<=5 then 'FACIALES' when gs<=10 then 'CORPORAL' when gs<=15 then 'CAPILAR' else 'VITAMINAS' end,
       case when gs=1 then 0 else 49+gs end,
       'Topping sintético de contrato','SOLO_CON_SERVICIO',
       case when gs=2 then 'X 3 SESIONES' else '' end,'ACTIVO'
from generate_series(1,20) gs;

-- One intentional price anomaly to prove fail-closed behavior.
update public.aos_catalogo_servicios
set precio_base=100,precio_oferta=120,updated_at=now()
where id=(select id from public.aos_catalogo_servicios where tipo='SERVICIO' and estado='ACTIVO' order by nombre limit 1);

-- One intentional stale row to prove freshness fail-closed behavior.
update public.aos_catalogo_servicios
set updated_at=now()-interval '181 days'
where id=(select id from public.aos_catalogo_servicios where tipo='PRODUCTO' and estado='ACTIVO' order by nombre limit 1);

do $$ begin
  if (select count(*) from public.aos_catalogo_servicios where estado='ACTIVO' and tipo='SERVICIO')<>167 then
    raise exception '1C fixture service shape drift';
  end if;
  if (select count(*) from public.aos_catalogo_servicios where estado='ACTIVO' and tipo='PRODUCTO')<>50 then
    raise exception '1C fixture product shape drift';
  end if;
  if (select count(*) from public.aos_catalogo_toppings where estado='ACTIVO')<>20 then
    raise exception '1C fixture toppings shape drift';
  end if;
end $$;
