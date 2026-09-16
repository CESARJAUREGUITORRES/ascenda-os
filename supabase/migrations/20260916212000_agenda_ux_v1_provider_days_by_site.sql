begin;

create or replace function public.aos_booking_provider_days_v3(
  p_profesional_id text,
  p_anio integer,
  p_mes integer,
  p_sede text default 'SAN ISIDRO'
)
returns jsonb
language plpgsql
stable
security definer
set search_path='public','pg_temp'
as $$
declare
  v_prof record;
  v_key text;
  v_result jsonb;
begin
  select * into v_prof
  from public.aos_perfiles_profesional
  where id::text=p_profesional_id
    and coalesce(visible,true)=true
  limit 1;

  if not found then return '[]'::jsonb; end if;

  v_key:=public.aos_booking_profile_key_v1(v_prof.nombre_publico);

  select coalesce(jsonb_agg(x.fecha order by x.fecha),'[]'::jsonb)
  into v_result
  from (
    select distinct h.fecha::text as fecha
    from public.aos_horarios_personal h
    where h.activo=true
      and extract(year from h.fecha)=p_anio
      and extract(month from h.fecha)=p_mes
      and upper(coalesce(h.sede,''))=upper(trim(coalesce(p_sede,'SAN ISIDRO')))
      and public.aos_booking_norm_v1(h.personal) like '%'||v_key||'%'
      and h.fecha>=current_date
  ) x;

  return coalesce(v_result,'[]'::jsonb);
end
$$;

revoke all on function public.aos_booking_provider_days_v3(text,integer,integer,text) from public;
grant execute on function public.aos_booking_provider_days_v3(text,integer,integer,text) to anon,authenticated,service_role;

commit;