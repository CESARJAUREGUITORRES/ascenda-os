-- ASCENDA WA S14 — Web Push + generic notification transport.
-- VAPID private key lives in Supabase Vault; browser receives public key only through app server.

create table if not exists public.aos_push_vapid_settings_v1 (
  id smallint primary key default 1 check (id = 1),
  public_key text not null,
  private_secret_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_push_subscriptions_v1 (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  device_label text,
  user_agent text,
  channel_preferences jsonb not null default '{"WHATSAPP":true,"SENTINEL":true}'::jsonb,
  active boolean not null default true,
  failure_count integer not null default 0 check (failure_count >= 0),
  last_success_at timestamptz,
  last_failure_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aos_push_subscriptions_v1_user_active_idx
  on public.aos_push_subscriptions_v1(user_id, active);

create table if not exists public.aos_push_dispatches_v1 (
  id bigint generated always as identity primary key,
  subscription_id uuid not null references public.aos_push_subscriptions_v1(id) on delete cascade,
  recipient_user_id uuid not null references public.aos_usuarios(id) on delete cascade,
  channel text not null,
  event_type text not null,
  entity_id text,
  dedupe_key text not null,
  status text not null default 'PENDING' check (status in ('PENDING','DELIVERED','FAILED','GONE')),
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(subscription_id, dedupe_key)
);

create index if not exists aos_push_dispatches_v1_recipient_created_idx
  on public.aos_push_dispatches_v1(recipient_user_id, created_at desc);

alter table public.aos_push_vapid_settings_v1 enable row level security;
alter table public.aos_push_subscriptions_v1 enable row level security;
alter table public.aos_push_dispatches_v1 enable row level security;

revoke all on public.aos_push_vapid_settings_v1 from anon, authenticated;
revoke all on public.aos_push_subscriptions_v1 from anon, authenticated;
revoke all on public.aos_push_dispatches_v1 from anon, authenticated;
grant select, insert, update, delete on public.aos_push_vapid_settings_v1 to service_role;
grant select, insert, update, delete on public.aos_push_subscriptions_v1 to service_role;
grant select, insert, update, delete on public.aos_push_dispatches_v1 to service_role;
grant usage, select on sequence public.aos_push_dispatches_v1_id_seq to service_role;

create or replace function public.aos_push_vapid_config_v1(p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, vault, pg_temp
as $$
declare
  v_row public.aos_push_vapid_settings_v1%rowtype;
  v_private text;
begin
  select * into v_row from public.aos_push_vapid_settings_v1 where id = 1;
  if not found then
    return jsonb_build_object('ok', true, 'configured', false);
  end if;
  select decrypted_secret into v_private
  from vault.decrypted_secrets
  where id = v_row.private_secret_id;
  if coalesce(v_private,'') = '' then
    return jsonb_build_object('ok', false, 'configured', false, 'error', 'VAPID_PRIVATE_SECRET_MISSING');
  end if;
  return jsonb_build_object(
    'ok', true,
    'configured', true,
    'public_key', v_row.public_key,
    'private_key', v_private,
    'updated_at', v_row.updated_at
  );
end;
$$;

create or replace function public.aos_push_vapid_store_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, vault, pg_temp
as $$
declare
  v_public text := trim(coalesce(p_payload->>'public_key',''));
  v_private text := trim(coalesce(p_payload->>'private_key',''));
  v_secret_id uuid;
  v_existing public.aos_push_vapid_settings_v1%rowtype;
begin
  if length(v_public) < 40 or length(v_private) < 20 then
    return jsonb_build_object('ok', false, 'error', 'INVALID_VAPID_KEYPAIR');
  end if;
  perform pg_advisory_xact_lock(hashtext('aos_push_vapid_v1'));
  select * into v_existing from public.aos_push_vapid_settings_v1 where id = 1 for update;
  if found then
    return public.aos_push_vapid_config_v1('{}'::jsonb);
  end if;
  v_secret_id := vault.create_secret(v_private, 'aos_push_vapid_private_v1', 'ASCENDA S14 Web Push VAPID private key', null);
  insert into public.aos_push_vapid_settings_v1(id, public_key, private_secret_id)
  values (1, v_public, v_secret_id);
  return public.aos_push_vapid_config_v1('{}'::jsonb);
end;
$$;

create or replace function public.aos_push_subscription_upsert_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_endpoint text := trim(coalesce(p_payload->>'endpoint',''));
  v_p256dh text := trim(coalesce(p_payload->>'p256dh',''));
  v_auth text := trim(coalesce(p_payload->>'auth',''));
  v_id uuid;
begin
  begin v_user := (p_payload->>'user_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_USER_ID'); end;
  if length(v_endpoint) < 20 or length(v_endpoint) > 4096 or length(v_p256dh) < 20 or length(v_auth) < 8 then
    return jsonb_build_object('ok', false, 'error', 'INVALID_PUSH_SUBSCRIPTION');
  end if;
  if not exists(select 1 from public.aos_usuarios where id=v_user and activo=true) then
    return jsonb_build_object('ok', false, 'error', 'ACTIVE_USER_REQUIRED');
  end if;
  insert into public.aos_push_subscriptions_v1(user_id,endpoint,p256dh,auth,device_label,user_agent,active,failure_count,updated_at)
  values(
    v_user,v_endpoint,v_p256dh,v_auth,
    left(nullif(trim(coalesce(p_payload->>'device_label','')),''),160),
    left(nullif(trim(coalesce(p_payload->>'user_agent','')),''),500),
    true,0,now()
  )
  on conflict(endpoint) do update set
    user_id=excluded.user_id,
    p256dh=excluded.p256dh,
    auth=excluded.auth,
    device_label=excluded.device_label,
    user_agent=excluded.user_agent,
    active=true,
    failure_count=0,
    updated_at=now()
  returning id into v_id;
  return jsonb_build_object('ok',true,'subscription_id',v_id);
end;
$$;

create or replace function public.aos_push_subscription_disable_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_endpoint text := trim(coalesce(p_payload->>'endpoint',''));
  v_count integer;
begin
  begin v_user := (p_payload->>'user_id')::uuid; exception when others then return jsonb_build_object('ok',false,'error','INVALID_USER_ID'); end;
  update public.aos_push_subscriptions_v1
     set active=false, updated_at=now()
   where user_id=v_user and endpoint=v_endpoint;
  get diagnostics v_count = row_count;
  return jsonb_build_object('ok',true,'disabled',v_count);
end;
$$;

create or replace function public.aos_push_targets_for_wa_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_contact text := regexp_replace(coalesce(p_payload->>'contact_number',''),'\D','','g');
  v_phone text := trim(coalesce(p_payload->>'phone_number_id',''));
  v_provider_id text := trim(coalesce(p_payload->>'provider_message_id',''));
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_subs jsonb;
begin
  if length(v_contact) < 8 or v_provider_id='' then
    return jsonb_build_object('ok',false,'eligible',false,'error','INVALID_WA_TARGET');
  end if;
  select * into v_conv
  from public.aos_wa_conversations_v1 c
  where regexp_replace(c.contact_number,'\D','','g')=v_contact
    and (v_phone='' or c.phone_number_id=v_phone)
    and c.last_message_id=v_provider_id
  order by c.updated_at desc
  limit 1;
  if not found then return jsonb_build_object('ok',true,'eligible',false,'reason','CONVERSATION_NOT_CURRENT'); end if;
  if v_conv.state <> 'HUMAN_ACTIVE' or v_conv.owner_user_id is null or v_conv.last_message_direction <> 'INBOUND' then
    return jsonb_build_object('ok',true,'eligible',false,'reason','HUMAN_OWNER_REQUIRED');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',s.id,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth
  ) order by s.updated_at desc),'[]'::jsonb)
  into v_subs
  from public.aos_push_subscriptions_v1 s
  where s.user_id=v_conv.owner_user_id
    and s.active=true
    and coalesce((s.channel_preferences->>'WHATSAPP')::boolean,true)=true;
  return jsonb_build_object(
    'ok',true,'eligible',true,
    'conversation_id',v_conv.id,
    'owner_user_id',v_conv.owner_user_id,
    'contact_name',v_conv.contact_name,
    'contact_number',v_conv.contact_number,
    'subscriptions',v_subs
  );
end;
$$;

create or replace function public.aos_push_dispatch_claim_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub uuid;
  v_user uuid;
  v_id bigint;
begin
  begin v_sub := (p_payload->>'subscription_id')::uuid; v_user := (p_payload->>'recipient_user_id')::uuid;
  exception when others then return jsonb_build_object('ok',false,'claimed',false,'error','INVALID_DISPATCH_IDS'); end;
  insert into public.aos_push_dispatches_v1(subscription_id,recipient_user_id,channel,event_type,entity_id,dedupe_key,status)
  values(
    v_sub,v_user,
    upper(left(coalesce(nullif(trim(p_payload->>'channel'),''),'UNKNOWN'),32)),
    left(coalesce(nullif(trim(p_payload->>'event_type'),''),'notification'),80),
    left(nullif(trim(coalesce(p_payload->>'entity_id','')),''),160),
    left(coalesce(nullif(trim(p_payload->>'dedupe_key'),''),'missing'),300),
    'PENDING'
  )
  on conflict(subscription_id,dedupe_key) do nothing
  returning id into v_id;
  return jsonb_build_object('ok',true,'claimed',v_id is not null,'dispatch_id',v_id);
end;
$$;

create or replace function public.aos_push_dispatch_complete_v1(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id bigint;
  v_status text := upper(trim(coalesce(p_payload->>'status','FAILED')));
  v_sub uuid;
  v_terminal boolean := coalesce((p_payload->>'terminal')::boolean,false);
begin
  begin v_id := (p_payload->>'dispatch_id')::bigint; exception when others then return jsonb_build_object('ok',false,'error','INVALID_DISPATCH_ID'); end;
  if v_status not in ('DELIVERED','FAILED','GONE') then v_status := 'FAILED'; end if;
  update public.aos_push_dispatches_v1
     set status=v_status,error_code=left(nullif(trim(coalesce(p_payload->>'error_code','')),''),160),updated_at=now()
   where id=v_id
   returning subscription_id into v_sub;
  if v_sub is null then return jsonb_build_object('ok',false,'error','DISPATCH_NOT_FOUND'); end if;
  if v_status='DELIVERED' then
    update public.aos_push_subscriptions_v1 set last_success_at=now(),failure_count=0,updated_at=now() where id=v_sub;
  else
    update public.aos_push_subscriptions_v1
       set last_failure_at=now(),failure_count=failure_count+1,active=case when v_terminal or v_status='GONE' then false else active end,updated_at=now()
     where id=v_sub;
  end if;
  return jsonb_build_object('ok',true,'status',v_status);
end;
$$;

revoke all on function public.aos_push_vapid_config_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_push_vapid_store_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_push_subscription_upsert_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_push_subscription_disable_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_push_targets_for_wa_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_push_dispatch_claim_v1(jsonb) from public, anon, authenticated;
revoke all on function public.aos_push_dispatch_complete_v1(jsonb) from public, anon, authenticated;

grant execute on function public.aos_push_vapid_config_v1(jsonb) to service_role;
grant execute on function public.aos_push_vapid_store_v1(jsonb) to service_role;
grant execute on function public.aos_push_subscription_upsert_v1(jsonb) to service_role;
grant execute on function public.aos_push_subscription_disable_v1(jsonb) to service_role;
grant execute on function public.aos_push_targets_for_wa_v1(jsonb) to service_role;
grant execute on function public.aos_push_dispatch_claim_v1(jsonb) to service_role;
grant execute on function public.aos_push_dispatch_complete_v1(jsonb) to service_role;

comment on table public.aos_push_subscriptions_v1 is 'S14 device subscriptions for generic ASCENDA Web Push transport.';
comment on table public.aos_push_dispatches_v1 is 'S14 per-device Web Push delivery ledger and dedupe authority.';
