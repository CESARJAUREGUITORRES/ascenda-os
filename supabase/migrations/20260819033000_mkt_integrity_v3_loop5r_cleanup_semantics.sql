-- MKT-INTEGRITY-HOTFIX-V3 / LOOP 5R
-- Additive semantic exception only. Existing LLAMADA behavior remains unchanged.

create or replace function public.aos_hotfix_manual_agenda_cleanup_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_call_ts timestamptz;
  v_agenda_ts timestamptz;
  v_num text;
begin
  if tg_table_name='aos_agenda_citas' then
    if upper(coalesce(new.origen_cita,''))<>'CITA_MANUAL' then
      return new;
    end if;

    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_agenda_ts:=coalesce(new.ts_creado,now());

    delete from public.aos_llamadas l
    where l.numero_limpio=v_num
      and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,''))
      and upper(coalesce(l.tipo_gestion,'LLAMADA')) not in (
        'LLAMADA_MANUAL_COMERCIAL',
        'CALLBACK_INBOUND',
        'INFERIDA_HISTORICA'
      )
      and (
        upper(coalesce(l.estado,''))='CITA CONFIRMADA'
        or (
          upper(coalesce(l.estado,''))='SEGUIMIENTO'
          and upper(coalesce(l.sub_estado,''))='CITA YA EXISTENTE'
        )
      )
      and abs(extract(epoch from(
        public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)-v_agenda_ts
      )))<=10;

    return new;
  end if;

  if tg_table_name='aos_llamadas' then
    if upper(coalesce(new.tipo_gestion,'LLAMADA')) in (
      'LLAMADA_MANUAL_COMERCIAL',
      'CALLBACK_INBOUND',
      'INFERIDA_HISTORICA'
    ) then
      return new;
    end if;

    if not (
      upper(coalesce(new.estado,''))='CITA CONFIRMADA'
      or (
        upper(coalesce(new.estado,''))='SEGUIMIENTO'
        and upper(coalesce(new.sub_estado,''))='CITA YA EXISTENTE'
      )
    ) then
      return new;
    end if;

    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');
    v_call_ts:=public.aos_llamada_event_ts(new.fecha,new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);

    if exists(
      select 1
      from public.aos_agenda_citas a
      where a.numero_limpio=v_num
        and upper(coalesce(a.asesor,''))=upper(coalesce(new.asesor,''))
        and upper(coalesce(a.origen_cita,''))='CITA_MANUAL'
        and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-v_call_ts)))<=10
    ) then
      delete from public.aos_llamadas where id=new.id;
    end if;

    return new;
  end if;

  return new;
end;
$function$;
