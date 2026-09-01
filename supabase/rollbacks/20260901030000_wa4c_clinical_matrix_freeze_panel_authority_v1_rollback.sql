-- Rollback WA-4C.1 Clinical Matrix Freeze + Panel Authority V1

drop trigger if exists trg_aos_guard_user_access_direct_write_v1 on public.aos_usuarios;
drop function if exists public.aos_guard_user_access_direct_write_v1();
drop function if exists public.aos_team_set_access_v1(text,uuid,text[],integer);

-- Remove only scope rows created by the freeze. Existing ADMIN_TEAM explicit truth
-- (for example Carolina/Biorevitalización) remains untouched.
delete from public.aos_professional_procedure_scope_v1
where source='CLINICAL_MATRIX_FREEZE_V1';

-- Remove the newly registered surfaces from user assignments, then registry.
update public.aos_usuarios u
set paneles_acceso=array(
      select x
      from unnest(coalesce(u.paneles_acceso,'{}'::text[])) x
      where x not in ('admin-catalogo','admin-inventario','admin-studio','admin-sentinel')
    ),
    updated_at=now()
where coalesce(u.paneles_acceso,'{}'::text[]) && array['admin-catalogo','admin-inventario','admin-studio','admin-sentinel']::text[];

delete from public.aos_paneles_disponibles
where id in ('admin-catalogo','admin-inventario','admin-studio','admin-sentinel');
