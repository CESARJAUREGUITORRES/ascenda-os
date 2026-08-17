-- K1-C — keep the legacy RRHH identity projection synchronized server-side.
-- Browser writes to aos_rrhh are closed by K1-B; authorized aos_usuarios changes
-- remain compatible with modules that still read nombre/puesto/sede from RRHH.

begin;

create or replace function public.aos_k1_sync_usuario_rrhh_v3()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  if new.codigo_asesor is not null then
    update public.aos_rrhh
    set nombre=coalesce(nullif(new.nombre,''),nombre),
        puesto=coalesce(nullif(new.cargo,''),puesto),
        sede=coalesce(nullif(new.sede,''),sede),
        updated_at=now()
    where codigo_asesor=new.codigo_asesor;
  end if;
  return new;
end
$function$;

revoke all on function public.aos_k1_sync_usuario_rrhh_v3() from public,anon,authenticated;
drop trigger if exists trg_k1_sync_usuario_rrhh_v3 on public.aos_usuarios;
create trigger trg_k1_sync_usuario_rrhh_v3
after insert or update of nombre,cargo,sede,codigo_asesor on public.aos_usuarios
for each row execute function public.aos_k1_sync_usuario_rrhh_v3();

commit;
