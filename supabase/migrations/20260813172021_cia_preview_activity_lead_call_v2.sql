create or replace function public.aos_cia_preview_lead_v2(p_key text)
returns text language sql stable security invoker as $$
select nullif(upper(btrim(l.tratamiento)),'')
from public.aos_leads l
where public.aos_cia_normalize_contact_key_v1(l.numero_limpio)=p_key
order by coalesce(l.hora_ingreso,l.created_at,l.fecha::timestamp at time zone 'America/Lima') desc,l.id desc limit 1;
$$;
create or replace function public.aos_cia_preview_call_v2(p_key text)
returns table(last_call_at timestamptz,latest_call_status text)
language sql stable security invoker as $$
select c.created_at,nullif(upper(btrim(c.estado)),'')
from public.aos_llamadas c
where public.aos_cia_normalize_contact_key_v1(c.numero_limpio)=p_key
order by c.created_at desc nulls last,c.fecha desc,c.id desc limit 1;
$$;
revoke all on function public.aos_cia_preview_lead_v2(text),public.aos_cia_preview_call_v2(text) from public,anon,authenticated;
grant execute on function public.aos_cia_preview_lead_v2(text),public.aos_cia_preview_call_v2(text) to service_role;
