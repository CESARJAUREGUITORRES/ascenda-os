-- WA-4C · Team Skill Catalog Classification V3
-- User-confirmed clinical/catalog corrections:
-- 1) CÁNULAS are products, not bookable services.
-- 2) HIFU is doctor-only.
-- This runs after Team Skill Authority V2 and preserves HUMAN_ONLY / SAFE-OFF boundaries.

begin;

-- Product category required so cannulas remain visible/manageable in Admin > Catálogo > Productos.
insert into public.aos_catalogo_categorias(
  nombre,tipo,icono,rol_profesional,estado,orden,updated_at
)
values (
  'INSUMOS CLÍNICOS','PRODUCTO','🧰','AMBOS','ACTIVO',990,now()
)
on conflict(nombre) do update
set tipo='PRODUCTO',
    icono=excluded.icono,
    rol_profesional='AMBOS',
    estado='ACTIVO',
    updated_at=now();

-- Cannulas are billable catalog products/clinical supplies, never booking treatments.
update public.aos_catalogo_servicios
set tipo='PRODUCTO',
    categoria='INSUMOS CLÍNICOS',
    requiere_doctora=false,
    requiere_enfermeria=false,
    updated_at=now()
where nombre in ('CÁNULAS AZULES 23G','CÁNULAS ROSADAS 18G')
  and upper(coalesce(estado,'ACTIVO'))='ACTIVO';

-- HIFU is doctor-only at all authority layers used by catalog, Team skills and WhatsApp booking.
update public.aos_catalogo_categorias
set rol_profesional='DOCTORA',
    updated_at=now()
where upper(nombre)='HIFU'
  and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';

update public.aos_catalogo_servicios
set requiere_doctora=true,
    requiere_enfermeria=false,
    updated_at=now()
where upper(coalesce(categoria,''))='HIFU'
  and upper(coalesce(tipo,'SERVICIO'))='SERVICIO'
  and upper(coalesce(estado,'ACTIVO'))='ACTIVO';

update public.aos_cat_tratamientos
set requiere_doctora=true,
    requiere_enfermeria=false,
    ultima_edicion=now(),
    editado_por='WA4C_TEAM_SKILL_V3'
where upper(tratamiento)='HIFU';

-- Fail closed if the user-confirmed classification did not converge exactly.
do $$
begin
  if exists (
    select 1 from public.aos_catalogo_servicios
    where nombre in ('CÁNULAS AZULES 23G','CÁNULAS ROSADAS 18G')
      and (
        upper(coalesce(tipo,''))<>'PRODUCTO'
        or upper(coalesce(categoria,''))<>'INSUMOS CLÍNICOS'
        or coalesce(requiere_doctora,false)
        or coalesce(requiere_enfermeria,false)
      )
  ) then
    raise exception 'WA4C_CANNULA_PRODUCT_CLASSIFICATION_FAILED';
  end if;

  if exists (
    select 1 from public.aos_catalogo_servicios
    where upper(coalesce(categoria,''))='HIFU'
      and upper(coalesce(tipo,'SERVICIO'))='SERVICIO'
      and upper(coalesce(estado,'ACTIVO'))='ACTIVO'
      and (coalesce(requiere_doctora,false) is not true or coalesce(requiere_enfermeria,false) is true)
  ) then
    raise exception 'WA4C_HIFU_DOCTOR_ONLY_SERVICE_FAILED';
  end if;

  if exists (
    select 1 from public.aos_cat_tratamientos
    where upper(tratamiento)='HIFU'
      and (coalesce(requiere_doctora,false) is not true or coalesce(requiere_enfermeria,false) is true)
  ) then
    raise exception 'WA4C_HIFU_DOCTOR_ONLY_SKILL_FAILED';
  end if;
end
$$;

commit;
