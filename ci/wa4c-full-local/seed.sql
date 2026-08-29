-- FULL LOCAL WA beta seed. Synthetic identities only; never apply to PROD.

update public.aos_usuarios
set paneles_acceso = case
  when not ('whatsapp-agent'=any(coalesce(paneles_acceso,'{}'::text[]))) then array_append(coalesce(paneles_acceso,'{}'::text[]),'whatsapp-agent')
  else paneles_acceso end,
  two_factor=true, activo=true
where id='44444444-4444-4444-8444-444444444444'::uuid;

update public.aos_usuarios
set paneles_acceso = case
  when not ('admin-whatsapp'=any(coalesce(paneles_acceso,'{}'::text[]))) then array_append(coalesce(paneles_acceso,'{}'::text[]),'admin-whatsapp')
  else paneles_acceso end,
  two_factor=true, activo=true
where id='11111111-1111-4111-8111-111111111111'::uuid;

insert into public.aos_wa_boxes_v1(
  id,code,name,status,routing_strategy,is_default,priority,created_by,updated_by
) values (
  '77777777-7777-4777-8777-777777777777'::uuid,
  'FULL_LOCAL','FULL LOCAL Beta','ACTIVE','MANUAL',true,100,
  '11111111-1111-4111-8111-111111111111'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid
)
on conflict(id) do update set status='ACTIVE',is_default=true,updated_at=now();

insert into public.aos_wa_box_members_v1(
  box_id,user_id,active,max_active,priority,created_by,updated_by
) values (
  '77777777-7777-4777-8777-777777777777'::uuid,
  '44444444-4444-4444-8444-444444444444'::uuid,
  true,20,100,
  '11111111-1111-4111-8111-111111111111'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid
)
on conflict(box_id,user_id) do update set active=true,max_active=20,priority=100,updated_at=now();

update public.aos_wa_routing_control_v1
set auto_routing_enabled=false,human_send_enabled=true,ai_send_enabled=false,
    updated_by='11111111-1111-4111-8111-111111111111'::uuid,updated_at=now()
where id=1;

update public.aos_wa_ai_control_v1
set copilot_enabled=true,auto_reply_enabled=false,daily_budget_usd=5.0000,
    updated_by='11111111-1111-4111-8111-111111111111'::uuid,updated_at=now()
where id=1;

-- PROD currently has no governed active promotion. Keep the beta truth aligned.
delete from public.aos_promociones;

notify pgrst, 'reload schema';
