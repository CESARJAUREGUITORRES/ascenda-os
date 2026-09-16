-- BOOKING-V3.2 — one reusable permanent public-booking token per active advisor/admin.
begin;
create unique index if not exists aos_links_agenda_advisor_permanent_uq on public.aos_links_agenda(asesor_codigo) where tipo='asesor_permanente' and expira_at is null and coalesce(estado,'ACTIVO')='ACTIVO';

create or replace function public.aos_booking_advisor_permanent_link_v32(p_asesor text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare u record; l record; code text:=trim(coalesce(p_asesor,''));
begin
 if code='' then return jsonb_build_object('ok',false,'error','ADVISOR_REQUIRED'); end if;
 select id,nombre,rol into u from public.aos_usuarios where activo=true and id::text=code and upper(coalesce(rol,'')) in ('ASESOR','ADMIN') limit 1;
 if not found then return jsonb_build_object('ok',false,'error','ADVISOR_NOT_ACTIVE'); end if;
 select * into l from public.aos_links_agenda where asesor_codigo=code and tipo='asesor_permanente' and expira_at is null and coalesce(estado,'ACTIVO')='ACTIVO' limit 1;
 if not found then insert into public.aos_links_agenda(tipo,asesor_codigo,expira_at,source_channel,estado) values('asesor_permanente',code,null,'ADVISOR_LINK','ACTIVO') returning * into l; end if;
 return jsonb_build_object('ok',true,'token',l.token,'advisor_code',code,'advisor_name',u.nombre,'source_channel','ADVISOR_LINK');
end $$;
revoke all on function public.aos_booking_advisor_permanent_link_v32(text) from public;
grant execute on function public.aos_booking_advisor_permanent_link_v32(text) to anon,authenticated,service_role;

create or replace function public.aos_booking_attribution_v1(p_token text)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare l record; ch text; camp text;
begin
 if coalesce(trim(p_token),'') in ('','__permanent__') then return jsonb_build_object('source_channel','WEB','source_campaign',null,'advisor_code','ORGANICO','link_type','permanent'); end if;
 select * into l from public.aos_links_agenda where token=p_token and (expira_at is null or expira_at>now()) and coalesce(estado,'ACTIVO')='ACTIVO';
 if not found then return jsonb_build_object('source_channel','UNKNOWN','advisor_code','ORGANICO'); end if;
 ch:=upper(coalesce(nullif(trim(l.source_channel),''),case when lower(coalesce(l.tipo,'')) in ('asesor','asesor_permanente','paciente_especifico') then 'ADVISOR_LINK' else 'LINK' end));
 camp:=nullif(coalesce(nullif(trim(l.campaign_code),''),nullif(trim(l.campaign_name),'')),'');
 return jsonb_build_object('source_channel',ch,'source_campaign',camp,'advisor_code',coalesce(nullif(trim(l.asesor_codigo),''),'ORGANICO'),'link_type',l.tipo);
end $$;
revoke all on function public.aos_booking_attribution_v1(text) from public;
grant execute on function public.aos_booking_attribution_v1(text) to anon,authenticated,service_role;

-- Permanent tokens are valid in the write authority; expiring patient/advisor links retain the same validation.
create or replace function public.aos_booking_link_valid_v32(p_token text)
returns boolean language sql stable security definer set search_path='public' as $$ select exists(select 1 from public.aos_links_agenda where token=$1 and (expira_at is null or expira_at>now()) and coalesce(estado,'ACTIVO')='ACTIVO') $$;
revoke all on function public.aos_booking_link_valid_v32(text) from public;
grant execute on function public.aos_booking_link_valid_v32(text) to anon,authenticated,service_role;
commit;
