-- ASCENDA Conversations — WA-2 Conversation Store + Live Inbox V1
-- Additive over WA-1. No direct client access to conversation/message tables.
begin;

create table if not exists public.aos_wa_conversations_v1 (
  id uuid primary key default gen_random_uuid(),
  business_phone_key text not null default 'default',
  contact_number text not null,
  contact_name text,
  state text not null default 'OPEN' check (state in ('OPEN','WAITING_CUSTOMER','CLOSED')),
  last_message_preview text,
  last_message_type text,
  last_message_at timestamptz,
  last_inbound_at timestamptz,
  last_outbound_at timestamptz,
  unread_count integer not null default 0 check (unread_count>=0),
  message_count integer not null default 0 check (message_count>=0),
  campaign_source text,
  ad_id text,
  lead_id text,
  customer_service_window_expires_at timestamptz,
  free_entry_candidate_expires_at timestamptz,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_phone_key,contact_number)
);
create index if not exists aos_wa_conversations_v1_inbox_idx on public.aos_wa_conversations_v1(state,last_message_at desc nulls last);
create index if not exists aos_wa_conversations_v1_unread_idx on public.aos_wa_conversations_v1(unread_count,last_message_at desc nulls last) where unread_count>0;
create index if not exists aos_wa_conversations_v1_contact_idx on public.aos_wa_conversations_v1(contact_number);
alter table public.aos_wa_conversations_v1 enable row level security;
alter table public.aos_wa_conversations_v1 force row level security;
revoke all on table public.aos_wa_conversations_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_wa_conversations_v1 to service_role;

create table if not exists public.aos_wa_conversation_events_v1 (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  conversation_id uuid not null references public.aos_wa_conversations_v1(id) on delete cascade,
  event_type text not null,
  actor_id uuid,
  source text not null default 'SYSTEM',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists aos_wa_conversation_events_v1_conv_idx on public.aos_wa_conversation_events_v1(conversation_id,created_at desc);
alter table public.aos_wa_conversation_events_v1 enable row level security;
alter table public.aos_wa_conversation_events_v1 force row level security;
revoke all on table public.aos_wa_conversation_events_v1 from public,anon,authenticated;
grant select,insert on table public.aos_wa_conversation_events_v1 to service_role;

alter table public.aos_wa_messages_v1 add column if not exists conversation_id uuid references public.aos_wa_conversations_v1(id) on delete set null;
create index if not exists aos_wa_messages_v1_conversation_idx on public.aos_wa_messages_v1(conversation_id,created_at);

create or replace function public.aos_wa_bind_conversation_v1()
returns trigger language plpgsql security definer set search_path='' as $function$
declare
  v_contact text;
  v_business text;
  v_conv uuid;
  v_is_inbound boolean;
  v_ts timestamptz;
begin
  v_is_inbound := new.direction='INBOUND';
  v_contact := regexp_replace(coalesce(case when v_is_inbound then new.from_number else new.to_number end,''),'[^0-9]','','g');
  if coalesce(v_contact,'')='' then return new; end if;
  v_business := coalesce(nullif(trim(new.phone_number_id),''),'default');
  v_ts := coalesce(new.provider_timestamp,new.received_at,new.sent_at,new.created_at,now());

  insert into public.aos_wa_conversations_v1(
    business_phone_key,contact_number,contact_name,state,campaign_source,ad_id,lead_id,
    customer_service_window_expires_at,free_entry_candidate_expires_at,last_message_at,updated_at
  ) values (
    v_business,v_contact,nullif(trim(coalesce(new.contact_name,'')),''),
    case when v_is_inbound then 'OPEN' else 'WAITING_CUSTOMER' end,
    new.campaign_source,new.ad_id,new.lead_id,
    case when v_is_inbound then v_ts+interval '24 hours' end,
    case when v_is_inbound and (new.ad_id is not null or new.raw_referral is not null) then v_ts+interval '72 hours' end,
    v_ts,now()
  )
  on conflict (business_phone_key,contact_number) do update set
    contact_name=coalesce(excluded.contact_name,public.aos_wa_conversations_v1.contact_name),
    state=case when v_is_inbound then 'OPEN' when public.aos_wa_conversations_v1.state='CLOSED' then 'CLOSED' else 'WAITING_CUSTOMER' end,
    campaign_source=coalesce(excluded.campaign_source,public.aos_wa_conversations_v1.campaign_source),
    ad_id=coalesce(excluded.ad_id,public.aos_wa_conversations_v1.ad_id),
    lead_id=coalesce(excluded.lead_id,public.aos_wa_conversations_v1.lead_id),
    customer_service_window_expires_at=case when v_is_inbound then excluded.customer_service_window_expires_at else public.aos_wa_conversations_v1.customer_service_window_expires_at end,
    free_entry_candidate_expires_at=coalesce(excluded.free_entry_candidate_expires_at,public.aos_wa_conversations_v1.free_entry_candidate_expires_at),
    closed_at=case when v_is_inbound then null else public.aos_wa_conversations_v1.closed_at end,
    updated_at=now()
  returning id into v_conv;
  new.conversation_id:=v_conv;
  return new;
end
$function$;

create or replace function public.aos_wa_rollup_conversation_v1()
returns trigger language plpgsql security definer set search_path='' as $function$
declare v_ts timestamptz;
begin
  if new.conversation_id is null then return new; end if;
  v_ts:=coalesce(new.provider_timestamp,new.received_at,new.sent_at,new.created_at,now());
  update public.aos_wa_conversations_v1 set
    last_message_preview=left(coalesce(new.message_body,case when new.media_id is not null then '['||new.message_type||']' else '['||coalesce(new.message_type,'message')||']' end),240),
    last_message_type=new.message_type,
    last_message_at=v_ts,
    last_inbound_at=case when new.direction='INBOUND' then v_ts else last_inbound_at end,
    last_outbound_at=case when new.direction='OUTBOUND' then v_ts else last_outbound_at end,
    unread_count=unread_count+case when new.direction='INBOUND' then 1 else 0 end,
    message_count=message_count+1,
    state=case when new.direction='INBOUND' then 'OPEN' when state='CLOSED' then 'CLOSED' else 'WAITING_CUSTOMER' end,
    updated_at=now()
  where id=new.conversation_id;
  insert into public.aos_wa_conversation_events_v1(event_key,conversation_id,event_type,source,metadata)
  values ('MESSAGE:'||new.provider_message_id,new.conversation_id,case when new.direction='INBOUND' then 'MESSAGE_IN' else 'MESSAGE_OUT' end,'WA_GATEWAY',jsonb_build_object('provider_message_id',new.provider_message_id,'message_type',new.message_type))
  on conflict(event_key) do nothing;
  return new;
end
$function$;

drop trigger if exists trg_aos_wa_bind_conversation_v1 on public.aos_wa_messages_v1;
create trigger trg_aos_wa_bind_conversation_v1 before insert on public.aos_wa_messages_v1 for each row execute function public.aos_wa_bind_conversation_v1();
drop trigger if exists trg_aos_wa_rollup_conversation_v1 on public.aos_wa_messages_v1;
create trigger trg_aos_wa_rollup_conversation_v1 after insert on public.aos_wa_messages_v1 for each row execute function public.aos_wa_rollup_conversation_v1();

create or replace function public.aos_wa_inbox_v1(
  p_token text,
  p_state text default null,
  p_search text default null,
  p_limit integer default 60,
  p_before timestamptz default null
) returns jsonb language plpgsql stable security definer set search_path='' as $function$
declare v_actor uuid; v_rows jsonb; v_limit integer;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-chats',true);
  if v_actor is null then return jsonb_build_object('ok',false,'error','WA_ADMIN_2FA_REQUIRED'); end if;
  v_limit:=greatest(1,least(coalesce(p_limit,60),100));
  select coalesce(jsonb_agg(to_jsonb(x) order by x.last_message_at desc nulls last),'[]'::jsonb) into v_rows
  from (
    select c.id,c.contact_number,c.contact_name,c.state,c.last_message_preview,c.last_message_type,c.last_message_at,
           c.last_inbound_at,c.last_outbound_at,c.unread_count,c.message_count,c.campaign_source,c.ad_id,c.lead_id,
           c.customer_service_window_expires_at,c.free_entry_candidate_expires_at,c.opened_at,c.closed_at
      from public.aos_wa_conversations_v1 c
     where (coalesce(trim(p_state),'')='' or c.state=upper(trim(p_state)))
       and (p_before is null or c.last_message_at<p_before)
       and (coalesce(trim(p_search),'')='' or c.contact_number ilike '%'||regexp_replace(p_search,'[^0-9]','','g')||'%' or c.contact_name ilike '%'||trim(p_search)||'%' or c.last_message_preview ilike '%'||trim(p_search)||'%')
     order by c.last_message_at desc nulls last
     limit v_limit
  ) x;
  return jsonb_build_object('ok',true,'rows',v_rows,'actor_id',v_actor,'server_time',now());
end
$function$;

create or replace function public.aos_wa_conversation_v1(p_token text,p_conversation_id uuid,p_limit integer default 200)
returns jsonb language plpgsql stable security definer set search_path='' as $function$
declare v_actor uuid; v_conv jsonb; v_msgs jsonb; v_limit integer;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-chats',true);
  if v_actor is null then return jsonb_build_object('ok',false,'error','WA_ADMIN_2FA_REQUIRED'); end if;
  select to_jsonb(c) into v_conv from public.aos_wa_conversations_v1 c where c.id=p_conversation_id;
  if v_conv is null then return jsonb_build_object('ok',false,'error','WA_CONVERSATION_NOT_FOUND'); end if;
  v_limit:=greatest(1,least(coalesce(p_limit,200),500));
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]'::jsonb) into v_msgs from (
    select m.id,m.provider_message_id,m.direction,m.message_type,m.message_body,m.media_id,m.status,m.actor_id,
           m.pricing_category,m.pricing_model,m.billable,m.provider_timestamp,m.received_at,m.sent_at,m.delivered_at,m.read_at,m.failed_at,m.created_at
      from public.aos_wa_messages_v1 m where m.conversation_id=p_conversation_id order by m.created_at desc limit v_limit
  ) x;
  return jsonb_build_object('ok',true,'conversation',v_conv,'messages',v_msgs,'actor_id',v_actor);
end
$function$;

create or replace function public.aos_wa_mark_inbox_read_v1(p_token text,p_conversation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_actor uuid; v_changed integer;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-chats',true);
  if v_actor is null then return jsonb_build_object('ok',false,'error','WA_ADMIN_2FA_REQUIRED'); end if;
  update public.aos_wa_conversations_v1 set unread_count=0,updated_at=now() where id=p_conversation_id;
  get diagnostics v_changed=row_count;
  if v_changed=0 then return jsonb_build_object('ok',false,'error','WA_CONVERSATION_NOT_FOUND'); end if;
  insert into public.aos_wa_conversation_events_v1(event_key,conversation_id,event_type,actor_id,source)
  values ('READ:'||p_conversation_id::text||':'||v_actor::text||':'||extract(epoch from clock_timestamp())::bigint,p_conversation_id,'INBOX_READ',v_actor,'HUMAN');
  return jsonb_build_object('ok',true,'conversation_id',p_conversation_id);
end
$function$;

create or replace function public.aos_wa_close_conversation_v1(p_token text,p_conversation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_actor uuid; v_changed integer;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'admin-chats',true);
  if v_actor is null then return jsonb_build_object('ok',false,'error','WA_ADMIN_2FA_REQUIRED'); end if;
  update public.aos_wa_conversations_v1 set state='CLOSED',closed_at=now(),updated_at=now() where id=p_conversation_id;
  get diagnostics v_changed=row_count;
  if v_changed=0 then return jsonb_build_object('ok',false,'error','WA_CONVERSATION_NOT_FOUND'); end if;
  insert into public.aos_wa_conversation_events_v1(event_key,conversation_id,event_type,actor_id,source)
  values ('CLOSE:'||p_conversation_id::text||':'||extract(epoch from clock_timestamp())::bigint,p_conversation_id,'CLOSED',v_actor,'HUMAN');
  return jsonb_build_object('ok',true,'conversation_id',p_conversation_id,'state','CLOSED');
end
$function$;

revoke all on function public.aos_wa_inbox_v1(text,text,text,integer,timestamptz) from public;
revoke all on function public.aos_wa_conversation_v1(text,uuid,integer) from public;
revoke all on function public.aos_wa_mark_inbox_read_v1(text,uuid) from public;
revoke all on function public.aos_wa_close_conversation_v1(text,uuid) from public;
grant execute on function public.aos_wa_inbox_v1(text,text,text,integer,timestamptz) to anon,authenticated,service_role;
grant execute on function public.aos_wa_conversation_v1(text,uuid,integer) to anon,authenticated,service_role;
grant execute on function public.aos_wa_mark_inbox_read_v1(text,uuid) to anon,authenticated,service_role;
grant execute on function public.aos_wa_close_conversation_v1(text,uuid) to anon,authenticated,service_role;

comment on table public.aos_wa_conversations_v1 is 'WA-2 canonical WhatsApp conversation rollup. FORCE RLS; accessible to clients only through strong-session RPCs.';
comment on table public.aos_wa_conversation_events_v1 is 'WA-2 append-only conversation audit/event ledger. FORCE RLS.';
comment on column public.aos_wa_conversations_v1.free_entry_candidate_expires_at is 'Operational candidate window derived from ad/referral evidence; not authoritative Meta billing eligibility.';

commit;
