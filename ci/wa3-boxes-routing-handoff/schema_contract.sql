\ir ../wa2-conversation-live-inbox/schema_contract.sql

alter table public.aos_usuarios add column if not exists rol text default 'asesor';
alter table public.aos_usuarios add column if not exists cargo text default '';
alter table public.aos_usuarios add column if not exists sede text default '';

insert into public.aos_usuarios(id,nombre,codigo_asesor,activo,two_factor,paneles_acceso,nivel_jerarquia,rol,cargo,sede)
values
 ('44444444-4444-4444-8444-444444444444','ASESOR WA A','WA-001',true,true,array['admin-chats'],3,'asesor','ASESOR','SAN ISIDRO'),
 ('55555555-5555-4555-8555-555555555555','ASESOR WA B','WA-002',true,true,array['admin-chats'],3,'asesor','ASESOR','PUEBLO LIBRE'),
 ('66666666-6666-4666-8666-666666666666','USUARIO SIN 2FA','WA-003',true,false,array['admin-chats'],3,'asesor','ASESOR','SAN ISIDRO')
on conflict(id) do nothing;

-- Deterministic test-only replacement of the production session resolver.
create or replace function public.aos_app_actor_v3(
  p_token text,
  p_required_panel text default null,
  p_require_2fa boolean default false
) returns uuid
language plpgsql stable
set search_path=public,pg_temp
as $$
declare v_uid uuid;
begin
  v_uid:=case p_token
    when 'admin-token-111111111111111111111111111111111111' then '11111111-1111-4111-8111-111111111111'::uuid
    when 'level2-token-2222222222222222222222222222222222' then '22222222-2222-4222-8222-222222222222'::uuid
    when 'agent-a-token-44444444444444444444444444444444444' then '44444444-4444-4444-8444-444444444444'::uuid
    when 'agent-b-token-55555555555555555555555555555555555' then '55555555-5555-4555-8555-555555555555'::uuid
    when 'no2fa-token-66666666666666666666666666666666666' then '66666666-6666-4666-8666-666666666666'::uuid
    else null end;
  if v_uid is null then return null; end if;
  if not exists(
    select 1 from public.aos_usuarios u where u.id=v_uid and u.activo is true
      and (not coalesce(p_require_2fa,false) or u.two_factor is true)
      and (coalesce(trim(p_required_panel),'')='' or coalesce(u.paneles_acceso,'{}'::text[]) @> array[p_required_panel]::text[])
  ) then return null; end if;
  return v_uid;
end
$$;
grant execute on function public.aos_app_actor_v3(text,text,boolean) to anon,authenticated,service_role;
