-- K1 — Fail-secure global 2FA invariant.
-- Prevent accidental/manual removal or disabling of the global 2FA switch.

begin;

create or replace function public.aos_k1_enforce_2fa_config()
returns trigger
language plpgsql
security definer
set search_path = 'pg_catalog'
as $function$
begin
  if tg_op='DELETE' and old.clave='seg_2fa_habilitado' then
    raise exception 'K1_TWO_FACTOR_CONFIG_REQUIRED';
  end if;
  if tg_op in ('INSERT','UPDATE') and new.clave='seg_2fa_habilitado' then
    if lower(trim(coalesce(new.valor,'')))<>'true' then
      raise exception 'K1_TWO_FACTOR_CANNOT_BE_DISABLED';
    end if;
    new.valor:='true';
  end if;
  return case when tg_op='DELETE' then old else new end;
end;
$function$;

revoke all on function public.aos_k1_enforce_2fa_config() from public,anon,authenticated;

drop trigger if exists trg_k1_2fa_config_invariant on public.aos_configuracion;
create trigger trg_k1_2fa_config_invariant
before insert or update or delete on public.aos_configuracion
for each row execute function public.aos_k1_enforce_2fa_config();

-- Reassert secure state after trigger installation.
update public.aos_configuracion set valor='true',updated_at=now() where clave='seg_2fa_habilitado';

commit;
