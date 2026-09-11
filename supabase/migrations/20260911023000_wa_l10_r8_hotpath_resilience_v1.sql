-- WA-L10 R8 hotpath resilience: collapse internal canary authorization and
-- serve toxin price cards from the already-certified WA4A1C price authority.
-- No autonomous mode transition is performed by this migration.

create or replace function public.aos_wa_l10_internal_canary_authorize_v1(
  p_conversation_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_conv public.aos_wa_conversations_v1%rowtype;
  v_mode text;
  v_kill boolean;
  v_copilot boolean;
  v_auto_reply boolean;
  v_max_context integer;
  v_max_catalog integer;
  v_ai_send boolean;
  v_auto_routing boolean;
  v_human_send boolean;
  v_allow boolean:=false;
begin
  if p_conversation_id is null then
    return jsonb_build_object('ok',false,'error','WA_L10_CONVERSATION_ID_REQUIRED');
  end if;

  select * into v_conv
  from public.aos_wa_conversations_v1
  where id=p_conversation_id;

  if v_conv.id is null then
    return jsonb_build_object('ok',false,'error','WA_L10_CONVERSATION_NOT_FOUND');
  end if;

  select a.mode,a.kill_switch_engaged,
         ai.copilot_enabled,ai.auto_reply_enabled,ai.max_context_messages,ai.max_catalog_items,
         r.ai_send_enabled,r.auto_routing_enabled,r.human_send_enabled
    into v_mode,v_kill,v_copilot,v_auto_reply,v_max_context,v_max_catalog,
         v_ai_send,v_auto_routing,v_human_send
  from public.aos_wa_auto_authority_v1 a
  cross join public.aos_wa_ai_control_v1 ai
  cross join public.aos_wa_routing_control_v1 r
  where a.id=1 and ai.id=1 and r.id=1;

  select exists(
    select 1
    from public.aos_wa_auto_allowlist_v1 w
    where w.subject_kind='CONVERSATION'
      and w.subject_key=p_conversation_id::text
      and w.active is true
      and (w.expires_at is null or w.expires_at>now())
  ) into v_allow;

  if not coalesce(v_allow,false) then
    return jsonb_build_object('ok',false,'error','WA_L10_INTERNAL_CANARY_NOT_SCOPED');
  end if;

  if v_mode is distinct from 'CANARY'
     or v_kill is distinct from false
     or v_copilot is distinct from true
     or v_auto_reply is distinct from true
     or v_ai_send is distinct from true
     or v_auto_routing is distinct from false
     or v_human_send is distinct from true then
    return jsonb_build_object('ok',false,'error','WA_L10_INTERNAL_CANARY_NOT_EFFECTIVE');
  end if;

  if v_conv.state is distinct from 'AI_ACTIVE'
     or v_conv.owner_user_id is not null
     or v_conv.human_takeover_at is not null
     or v_conv.handoff_requested_at is not null then
    return jsonb_build_object('ok',false,'error','WA_L10_INTERNAL_HUMAN_BOUNDARY_ACTIVE');
  end if;

  return jsonb_build_object(
    'ok',true,
    'actor_id',null,
    'internal_canary',true,
    'max_context_messages',greatest(4,least(coalesce(v_max_context,24),40)),
    'max_catalog_items',greatest(4,least(coalesce(v_max_catalog,12),24))
  );
end
$$;

revoke all on function public.aos_wa_l10_internal_canary_authorize_v1(uuid) from public,anon,authenticated;
grant execute on function public.aos_wa_l10_internal_canary_authorize_v1(uuid) to service_role;

create or replace function public.aos_wa4_toxin_price_fast_v1()
returns table(
  entity_id uuid,
  entity_type text,
  entity_name text,
  category text,
  mapping_state text,
  mapping_confidence numeric,
  precio_base numeric,
  precio_oferta numeric,
  quote_price numeric,
  price_state text,
  freshness_state text,
  ready_for_quote boolean,
  moneda text,
  price_evidence_ref text
)
language sql
stable
security definer
set search_path=''
as $$
  select c.entity_id,c.entity_type,c.entity_name,c.category,c.mapping_state,c.mapping_confidence,
         c.precio_base,c.precio_oferta,c.quote_price,c.price_state,c.freshness_state,c.ready_for_quote,
         c.moneda,c.price_evidence_ref
  from public.aos_wa4_process_entity_context_v1 c
  where c.mapping_state='MAPPED'
    and c.ready_for_quote is true
    and c.price_state='READY'
    and c.freshness_state='FRESH'
    and upper(c.category)='TOXINA'
    and upper(c.entity_name) ~ '^(NABOTA|HUTOX) [13] ZONA(S)? [0-9]+U$'
  order by
    case when upper(c.entity_name) like '%1 ZONA %' then 1 else 3 end,
    c.quote_price,
    c.entity_name
  limit 8
$$;

revoke all on function public.aos_wa4_toxin_price_fast_v1() from public,anon,authenticated;
grant execute on function public.aos_wa4_toxin_price_fast_v1() to service_role;

comment on function public.aos_wa_l10_internal_canary_authorize_v1(uuid)
is 'WA-L10 R8 server-only single-RPC internal CANARY authorization snapshot. No mode mutation.';

comment on function public.aos_wa4_toxin_price_fast_v1()
is 'WA4A1C-governed, service-role-only toxin price fast lane. Reads only mapped READY/FRESH canonical price authority rows.';
