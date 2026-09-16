-- BOOKING-V3.2 — narrow compatibility patch: permanent advisor tokens are valid booking links.
begin;
create or replace function public.aos_booking_resolve_link_v32(p_token text)
returns jsonb language plpgsql stable security definer set search_path='public','pg_temp' as $$
declare l record;
begin
 if coalesce(trim(p_token),'') in ('','__permanent__') then return jsonb_build_object('ok',true,'advisor_code','ORGANICO','kind','web'); end if;
 select * into l from public.aos_links_agenda where token=p_token and (expira_at is null or expira_at>now()) and coalesce(estado,'ACTIVO')='ACTIVO';
 if not found then return jsonb_build_object('ok',false,'error','LINK_INVALID_OR_EXPIRED'); end if;
 return jsonb_build_object('ok',true,'advisor_code',coalesce(nullif(trim(l.asesor_codigo),''),'ORGANICO'),'kind',l.tipo);
end $$;
revoke all on function public.aos_booking_resolve_link_v32(text) from public;
grant execute on function public.aos_booking_resolve_link_v32(text) to anon,authenticated,service_role;
commit;
