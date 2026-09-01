-- Rollback for WA-4C Team Skill Catalog Classification V3.
-- Restores the pre-V3 catalog state only.

begin;

update public.aos_catalogo_servicios
set tipo='SERVICIO',
    categoria='CONSULTA',
    requiere_doctora=false,
    requiere_enfermeria=false,
    updated_at=now()
where nombre in ('CÁNULAS AZULES 23G','CÁNULAS ROSADAS 18G');

update public.aos_catalogo_categorias
set rol_profesional='AMBOS',updated_at=now()
where upper(nombre)='HIFU';

update public.aos_catalogo_servicios
set requiere_doctora=true,
    requiere_enfermeria=true,
    updated_at=now()
where upper(coalesce(categoria,''))='HIFU'
  and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';

update public.aos_cat_tratamientos
set requiere_doctora=true,
    requiere_enfermeria=true,
    ultima_edicion=now(),
    editado_por='WA4C_TEAM_SKILL_V3_ROLLBACK'
where upper(tratamiento)='HIFU';

-- Remove the category only when no products still depend on it.
delete from public.aos_catalogo_categorias c
where c.nombre='INSUMOS CLÍNICOS'
  and not exists (
    select 1 from public.aos_catalogo_servicios s
    where s.categoria=c.nombre
  );

commit;
