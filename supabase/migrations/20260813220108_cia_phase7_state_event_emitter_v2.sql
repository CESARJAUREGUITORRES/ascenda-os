-- ASCENDA CIA Phase 7 — DB-owned lifecycle event emission.
-- Applied live as schema_migrations version 20260813220108.

create or replace function public.aos_cia_activation_state_event_emit_v2()
returns trigger
language plpgsql
set search_path=public
as $$
declare ev text;
begin
  if tg_op='INSERT' then
    insert into public.aos_audiencia_activacion_eventos(activacion_id,event_type,actor_user_id,from_state,to_state,metadata)
    values(new.activacion_id,'CREATE',new.updated_by_user_id,null,new.estado,jsonb_build_object('source','STATE_TRIGGER'));
    return new;
  end if;
  ev:=case
    when old.estado='DRAFT' and new.estado='ACTIVE' then 'START'
    when old.estado='ACTIVE' and new.estado='PAUSED' then 'PAUSE'
    when old.estado='PAUSED' and new.estado='ACTIVE' then 'RESUME'
    when new.estado='COMPLETED' then 'COMPLETE'
    when new.estado='CANCELLED' then 'CANCEL'
    else null
  end;
  if ev is null then raise exception 'ACTIVATION_EVENT_UNMAPPED'; end if;
  insert into public.aos_audiencia_activacion_eventos(activacion_id,event_type,actor_user_id,from_state,to_state,metadata)
  values(new.activacion_id,ev,new.updated_by_user_id,old.estado,new.estado,jsonb_build_object('source','STATE_TRIGGER'));
  return new;
end;$$;