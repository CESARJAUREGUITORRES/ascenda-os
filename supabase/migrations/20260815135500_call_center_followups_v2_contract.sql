-- Additive Call Center follow-up contract.
-- Preserve the existing {ok,items} envelope and existing keys while exposing
-- scheduled time and explicit lead origin for the frontend compatibility adapter.
create or replace function public.aos_get_seguimientos(
  p_asesor text default ''::text,
  p_id_asesor text default ''::text,
  p_hoy text default ''::text
)
returns jsonb
language plpgsql
security definer
as $function$
declare
  r jsonb;
  v_hoy text := coalesce(nullif(p_hoy,''), current_date::text);
begin
  select jsonb_build_object(
    'ok',true,
    'items',coalesce(jsonb_agg(row_to_json(t)::jsonb),'[]'::jsonb)
  ) into r
  from (
    select
      s."ID" as "segId",
      coalesce(s."FECHA_PROGRAMADA",'') as fecha,
      coalesce(s."HORA_PROGRAMADA",'') as hora,
      coalesce(s."NUMERO",'') as num,
      coalesce(s."TRATAMIENTO",'') as trat,
      coalesce(s."OBS_RECONTACTO",'') as obs,
      s.lead_id_origen as "leadId",
      case
        when s."FECHA_PROGRAMADA" < v_hoy then 'vencido'
        when s."FECHA_PROGRAMADA" = v_hoy then 'hoy'
        else 'proximo'
      end as tipo,
      case when s."FECHA_PROGRAMADA" < v_hoy then true else false end as vencido,
      case when s."FECHA_PROGRAMADA" = v_hoy then true else false end as "esHoy",
      'https://wa.me/51'||regexp_replace(coalesce(s."NUMERO",''),'[^0-9]','','g') as whatsapp
    from public.aos_seguimientos s
    where s."ESTADO" in ('PENDIENTE','VENCIDO')
      and (
        upper(coalesce(s."ASESOR",''))=upper(p_asesor)
        or (p_id_asesor<>'' and coalesce(s."ID_ASESOR",'')=p_id_asesor)
      )
    order by
      case
        when s."FECHA_PROGRAMADA"=v_hoy then 0
        when s."FECHA_PROGRAMADA"<v_hoy then 1
        else 2
      end,
      s."FECHA_PROGRAMADA" asc nulls last,
      s."HORA_PROGRAMADA" asc nulls last
  ) t;

  return coalesce(r,'{"ok":true,"items":[]}'::jsonb);
end;
$function$;
