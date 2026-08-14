-- ASCENDA OS — Phase 2 owner canary access.
-- Grants admin-cartera only when there is exactly one eligible owner-level admin.

begin;

do $canary$
declare
  v_count integer;
  v_owner uuid;
begin
  select count(*), min(id)
    into v_count, v_owner
  from public.aos_usuarios
  where activo=true
    and two_factor=true
    and nivel_jerarquia=1
    and lower(coalesce(rol,''))='admin'
    and coalesce(paneles_acceso,'{}'::text[]) @> array['admin-team']::text[]
    and coalesce(paneles_acceso,'{}'::text[]) @> array['admin-caja']::text[]
    and coalesce(paneles_acceso,'{}'::text[]) @> array['admin-sales-intelligence']::text[];

  if v_count<>1 or v_owner is null then
    raise exception 'PHASE2_OWNER_CANARY_AMBIGUOUS: expected exactly one eligible owner, found %', v_count;
  end if;

  update public.aos_usuarios
  set paneles_acceso=case
        when coalesce(paneles_acceso,'{}'::text[]) @> array['admin-cartera']::text[]
          then coalesce(paneles_acceso,'{}'::text[])
        else array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-cartera')
      end,
      updated_at=now()
  where id=v_owner;

  insert into public.aos_security_log(usuario,accion,detalles)
  select nombre,'PHASE2_CARTERA_CANARY_GRANTED',jsonb_build_object(
    'user_id',id,
    'panel','admin-cartera',
    'scope','unique_owner_level_1',
    'at',now()
  )
  from public.aos_usuarios where id=v_owner;
end;
$canary$;

commit;
