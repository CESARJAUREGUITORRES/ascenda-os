-- K1 — Privileged ADMIN identity must always be enrolled in 2FA.
-- Complements the global seg_2fa_habilitado=true invariant: canonical ADMIN
-- rows (rol=admin + nivel_jerarquia 1/2) cannot drift to two_factor=false.

begin;

-- Normalize existing privileged identities before enforcing the invariant.
update public.aos_usuarios
set two_factor=true,updated_at=now()
where lower(coalesce(rol,''))='admin'
  and coalesce(nivel_jerarquia,99) in (1,2)
  and not coalesce(two_factor,false);

create or replace function public.aos_k1_guard_admin_role()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog'
as $function$
begin
  if lower(coalesce(new.rol,''))='admin' then
    if coalesce(new.nivel_jerarquia,99) not in (1,2) then
      raise exception 'K1_ADMIN_ROLE_REQUIRES_PRIVILEGED_LEVEL';
    end if;
    if not coalesce(new.two_factor,false) then
      raise exception 'K1_ADMIN_TWO_FACTOR_REQUIRED';
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function public.aos_k1_guard_admin_role() from public,anon,authenticated;

-- Recreate trigger so the guarded column set explicitly includes two_factor.
drop trigger if exists trg_k1_guard_admin_role on public.aos_usuarios;
create trigger trg_k1_guard_admin_role
before insert or update of rol,nivel_jerarquia,two_factor on public.aos_usuarios
for each row execute function public.aos_k1_guard_admin_role();

commit;
