begin;

create or replace function public.aos_booking_advisor_permanent_link_v32(p_asesor text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare u record; l record; code text:=trim(coalesce(p_asesor,''));
begin
 if code='' then return jsonb_build_object('ok',false,'error','USER_REQUIRED'); end if;
 select id,nombre,rol into u from public.aos_usuarios where activo=true and id::text=code limit 1;
 if not found then return jsonb_build_object('ok',false,'error','USER_NOT_ACTIVE'); end if;
 select * into l from public.aos_links_agenda where asesor_codigo=code and tipo='asesor_permanente' and coalesce(estado,'ACTIVO')='ACTIVO' limit 1;
 if not found then
   insert into public.aos_links_agenda(tipo,asesor_codigo,expira_at,source_channel,estado)
   values('asesor_permanente',code,now()+interval '10 years','ADVISOR_LINK','ACTIVO') returning * into l;
 elsif l.expira_at is null or l.expira_at<now()+interval '9 years' then
   update public.aos_links_agenda set expira_at=now()+interval '10 years',source_channel='ADVISOR_LINK' where id=l.id returning * into l;
 end if;
 return jsonb_build_object('ok',true,'token',l.token,'advisor_code',code,'advisor_name',u.nombre,'user_role',u.rol,'source_channel','ADVISOR_LINK');
end $$;

-- Materialize one stable link for every active user so attribution exists before sharing.
insert into public.aos_links_agenda(tipo,asesor_codigo,expira_at,source_channel,estado)
select 'asesor_permanente',u.id::text,now()+interval '10 years','ADVISOR_LINK','ACTIVO'
from public.aos_usuarios u
where u.activo=true
  and not exists (
    select 1 from public.aos_links_agenda l
    where l.asesor_codigo=u.id::text and l.tipo='asesor_permanente' and coalesce(l.estado,'ACTIVO')='ACTIVO'
  );

commit;
