-- K1-G — authority changes revoke all existing app/admin sessions.
-- Prevents a pre-promotion PASSWORD session from becoming an ADMIN session by
-- live role re-derivation, while ordinary profile edits do not force logout.

begin;

create or replace function public.aos_k1_revoke_sessions_on_authority_change_v3()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  if old.rol is distinct from new.rol
     or old.nivel_jerarquia is distinct from new.nivel_jerarquia
     or old.two_factor is distinct from new.two_factor
     or old.email is distinct from new.email
     or old.activo is distinct from new.activo then
    update public.aos_app_sessions_v3 set revoked=true
      where user_id=new.id and revoked=false;
    update public.aos_cia_admin_sessions set revoked=true
      where user_id=new.id and revoked=false;
  end if;
  return new;
end
$function$;

revoke all on function public.aos_k1_revoke_sessions_on_authority_change_v3() from public,anon,authenticated;
drop trigger if exists trg_k1_revoke_sessions_on_authority_change_v3 on public.aos_usuarios;
create trigger trg_k1_revoke_sessions_on_authority_change_v3
after update of rol,nivel_jerarquia,two_factor,email,activo on public.aos_usuarios
for each row execute function public.aos_k1_revoke_sessions_on_authority_change_v3();

commit;
