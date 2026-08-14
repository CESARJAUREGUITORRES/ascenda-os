-- REMOTE SYNC: already applied live as 20260813211724.
-- Mutating RPC requires a valid CIA admin token before any write.
create or replace function public.aos_cia_activation_transition_admin_v1(p_token text,p_activation_id uuid,p_action text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  auth jsonb; uid uuid; st record; act text:=upper(btrim(coalesce(p_action,''))); ns text; ev text; t timestamptz:=clock_timestamp();
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  uid:=(auth->>'user_id')::uuid;
  select * into st from public.aos_audiencia_activacion_estado where activacion_id=p_activation_id for update;
  if st.activacion_id is null then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND'); end if;
  if act='START' and st.estado='DRAFT' then ns:='ACTIVE';ev:='START';
  elsif act='PAUSE' and st.estado='ACTIVE' then ns:='PAUSED';ev:='PAUSE';
  elsif act='RESUME' and st.estado='PAUSED' then ns:='ACTIVE';ev:='RESUME';
  elsif act='COMPLETE' and st.estado in ('ACTIVE','PAUSED') then ns:='COMPLETED';ev:='COMPLETE';
  elsif act='CANCEL' and st.estado in ('DRAFT','ACTIVE','PAUSED') then ns:='CANCELLED';ev:='CANCEL';
  else return jsonb_build_object('ok',false,'error','INVALID_TRANSITION','current_state',st.estado,'action',act);
  end if;
  update public.aos_audiencia_activacion_estado
  set estado=ns,updated_by_user_id=uid,
      started_at=case when ns in ('ACTIVE','PAUSED','COMPLETED') then coalesce(st.started_at,t) else st.started_at end,
      ended_at=case when ns in ('COMPLETED','CANCELLED') then t else null end
  where activacion_id=p_activation_id;
  insert into public.aos_audiencia_activacion_eventos(activacion_id,event_type,actor_user_id,from_state,to_state)
  values(p_activation_id,ev,uid,st.estado,ns);
  return jsonb_build_object('ok',true,'activation_id',p_activation_id,'from_state',st.estado,'state',ns,'event',ev,'updated_at',t);
end;$$;