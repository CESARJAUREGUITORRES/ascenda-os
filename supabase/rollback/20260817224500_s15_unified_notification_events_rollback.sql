-- ASCENDA S15 rollback — removes unified business notification events while preserving historical notification rows.

drop trigger if exists trg_aos_notification_sale_v1 on public.aos_ventas;
drop trigger if exists trg_aos_notification_commission_adjust_v1 on public.aos_ajustes_comision;
drop trigger if exists trg_aos_notification_agenda_insert_v1 on public.aos_agenda_citas;
drop trigger if exists trg_aos_notification_agenda_update_v1 on public.aos_agenda_citas;
drop trigger if exists trg_aos_notification_message_v1 on public.aos_mensajes;
drop trigger if exists trg_aos_notification_task_v1 on public.aos_tareas;

drop function if exists public.aos_notification_sales_trigger_v1();
drop function if exists public.aos_notification_commission_adjust_trigger_v1();
drop function if exists public.aos_notification_agenda_trigger_v1();
drop function if exists public.aos_notification_message_trigger_v1();
drop function if exists public.aos_notification_task_trigger_v1();
drop function if exists public.aos_notification_push_complete_v1(jsonb);
drop function if exists public.aos_notification_push_claim_v1(jsonb);
drop function if exists public.aos_admin_notificaciones_v1(integer);
drop function if exists public.aos_mis_notificaciones_v1(text,integer);
drop function if exists public.aos_notification_emit_v1(jsonb);
drop function if exists public.aos_notification_format_v1(text,jsonb);
drop function if exists public.aos_notification_sale_commission_v1(text,numeric);
drop function if exists public.aos_notification_resolve_user_v1(text);

-- Restore pre-S15 manual notification behavior.
create or replace function public.aos_enviar_notificacion(
  p_titulo text,
  p_contenido text default null,
  p_para text default null,
  p_tipo text default 'INFO',
  p_prioridad text default 'NORMAL',
  p_expira timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare v_id uuid;
begin
  insert into public.aos_notificaciones(titulo,contenido,para,tipo,prioridad,expira_at)
  values(p_titulo,p_contenido,p_para,p_tipo,p_prioridad,p_expira) returning id into v_id;
  return jsonb_build_object('ok',true,'id',v_id);
end;
$$;

-- Restore pre-S15 coordination payload.
create or replace function public.aos_mis_mensajes(p_usuario text)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare v_result jsonb;
begin
  select jsonb_build_object(
    'canales',(select coalesce(jsonb_agg(row_to_json(c) order by c.ultimo_mensaje_at desc nulls last),'[]'::jsonb) from (
      select ch.id,ch.nombre,ch.tipo,ch.ultimo_mensaje,ch.ultimo_mensaje_at,ch.cerrado,ch.participantes,
        (select count(*) from public.aos_mensajes m where m.canal=ch.id and not (m.leido_por ? p_usuario) and m.de<>p_usuario) as no_leidos
      from public.aos_canales ch where (ch.participantes ? p_usuario) and (ch.cerrado=false or ch.cerrado is null)
    ) c),
    'grupos',(select coalesce(jsonb_agg(row_to_json(g)),'[]'::jsonb) from (
      select g.id,g.nombre,g.color,g.tipo,jsonb_array_length(g.miembros) as n_miembros from public.aos_grupos g where g.activo=true and g.miembros ? p_usuario
    ) g),
    'tareas',(select coalesce(jsonb_agg(row_to_json(t)),'[]'::jsonb) from (
      select id,titulo,estado,prioridad,items,fecha_limite,vencida,tiempo_estimado_min,asignado_grupo,created_at from public.aos_tareas
      where (asignado_a=p_usuario or asignado_grupo in (select g.id from public.aos_grupos g where g.miembros ? p_usuario)) and estado<>'COMPLETADA'
      order by case when vencida then 0 else 1 end,case prioridad when 'URGENTE' then 0 when 'ALTA' then 1 else 2 end,fecha_limite asc nulls last
    ) t),
    'notificaciones',(select coalesce(jsonb_agg(row_to_json(n)),'[]'::jsonb) from (
      select id,titulo,contenido,tipo,prioridad,created_at,(n.leido_por ? p_usuario) as leido
      from public.aos_notificaciones n
      where (n.para is null or n.para=p_usuario) and (n.expira_at is null or n.expira_at>now())
      order by created_at desc limit 20
    ) n)
  ) into v_result;
  return v_result;
end;
$$;

drop table if exists public.aos_notification_policies_v1;
drop index if exists public.aos_notificaciones_dedupe_v1_uq;
drop index if exists public.aos_notificaciones_recipient_v1_idx;
drop index if exists public.aos_notificaciones_push_v1_idx;

alter table public.aos_notificaciones drop column if exists para_user_id;
alter table public.aos_notificaciones drop column if exists channel;
alter table public.aos_notificaciones drop column if exists event_type;
alter table public.aos_notificaciones drop column if exists route;
alter table public.aos_notificaciones drop column if exists entity_id;
alter table public.aos_notificaciones drop column if exists icon;
alter table public.aos_notificaciones drop column if exists metadata;
alter table public.aos_notificaciones drop column if exists dedupe_key;
alter table public.aos_notificaciones drop column if exists in_app_enabled;
alter table public.aos_notificaciones drop column if exists push_enabled;
alter table public.aos_notificaciones drop column if exists push_after;
alter table public.aos_notificaciones drop column if exists push_status;
alter table public.aos_notificaciones drop column if exists push_claimed_at;
alter table public.aos_notificaciones drop column if exists push_attempts;
alter table public.aos_notificaciones drop column if exists updated_at;
