-- P0 Marketing investment integrity guard
-- Applied to production on 2026-09-29 before merge.
-- Canonical grain: one investment row per year/month/treatment/platform.

with ranked as (
  select id,
         row_number() over (
           partition by anio, mes_num, upper(btrim(tratamiento)), upper(btrim(plataforma))
           order by created_at nulls last, id
         ) as rn
  from public.aos_inversion_campanas
)
delete from public.aos_inversion_campanas i
using ranked r
where i.id = r.id
  and r.rn > 1;

create unique index if not exists aos_inversion_campanas_period_trat_platform_uq
on public.aos_inversion_campanas (
  anio,
  mes_num,
  upper(btrim(tratamiento)),
  upper(btrim(plataforma))
);
