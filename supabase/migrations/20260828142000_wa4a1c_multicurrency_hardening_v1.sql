-- WA-4A.1C V2 — explicit multi-currency safety contract
-- Applies after WA-4A.1C V1 when promoted. Catalog/toppings remain the only price masters.
-- No FX conversion is performed. A quote preview may contain exactly one currency.
begin;

create or replace view public.aos_wa4_price_authority_v1 as
select
  c.id as entity_id,
  c.tipo as entity_type,
  c.nombre as entity_name,
  c.categoria,
  c.precio_base,
  c.precio_oferta,
  c.moneda,
  coalesce(c.precio_oferta,c.precio_base) as quote_price,
  c.num_sesiones,
  c.frecuencia,
  c.updated_at as price_source_updated_at,
  greatest(0,(current_date-c.updated_at::date))::integer as age_days,
  case
    when c.moneda not in ('PEN','USD') then 'INVALID_CURRENCY'
    when c.precio_oferta is null and c.precio_base is null then 'MISSING_PRICE'
    when coalesce(c.precio_oferta,c.precio_base,0)<=0 then 'INVALID_NONPOSITIVE_PRICE'
    when c.precio_base is not null and c.precio_oferta is not null and c.precio_oferta>c.precio_base then 'REVIEW_REQUIRED_OFFER_ABOVE_BASE'
    else 'READY'
  end as price_state,
  case when current_date-c.updated_at::date<=180 then 'FRESH' else 'STALE_REVIEW' end as freshness_state,
  (
    c.moneda in ('PEN','USD')
    and coalesce(c.precio_oferta,c.precio_base,0)>0
    and not (c.precio_base is not null and c.precio_oferta is not null and c.precio_oferta>c.precio_base)
    and current_date-c.updated_at::date<=180
  ) as ready_for_quote,
  'aos_catalogo_servicios:'||c.id::text||':'||c.moneda||':'||
    to_char(c.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS') as evidence_ref
from public.aos_catalogo_servicios c
where c.estado='ACTIVO' and c.tipo in ('SERVICIO','PRODUCTO');

revoke all on table public.aos_wa4_price_authority_v1 from public,anon,authenticated;
grant select on table public.aos_wa4_price_authority_v1 to service_role;

create or replace view public.aos_wa4_topping_authority_v1 as
select
  t.id as topping_id,
  t.nombre,
  t.categoria_vinculada,
  t.precio,
  t.moneda,
  t.tipo_pago,
  t.sesiones,
  t.descripcion,
  case
    when t.moneda not in ('PEN','USD') then 'INVALID_CURRENCY'
    when t.precio is null or t.precio<0 then 'INVALID_PRICE'
    when t.precio=0 then 'ZERO_PRICE_BENEFIT_CANDIDATE'
    else 'PAID_ADDON'
  end as benefit_mode,
  (t.moneda in ('PEN','USD') and t.precio is not null and t.precio>=0 and t.estado='ACTIVO') as ready_for_consideration,
  'aos_catalogo_toppings:'||t.id::text||':'||t.moneda as evidence_ref
from public.aos_catalogo_toppings t
where t.estado='ACTIVO';

revoke all on table public.aos_wa4_topping_authority_v1 from public,anon,authenticated;
grant select on table public.aos_wa4_topping_authority_v1 to service_role;

create or replace view public.aos_wa4_process_entity_context_v1 as
select
  m.entity_id,
  p.entity_type,
  m.entity_type as knowledge_entity_type,
  m.entity_name,
  m.category,
  m.domain_codes,
  m.approach_codes,
  m.commercial_phase_codes,
  m.clinical_lifecycle,
  m.zi_function,
  m.mapping_state,
  m.mapping_confidence,
  p.precio_base,
  p.precio_oferta,
  p.moneda,
  p.quote_price,
  p.price_state,
  p.freshness_state,
  p.ready_for_quote,
  p.num_sesiones,
  p.frecuencia,
  p.price_source_updated_at,
  p.evidence_ref as price_evidence_ref
from public.aos_knowledge_entity_map_v1 m
join public.aos_wa4_price_authority_v1 p on p.entity_id=m.entity_id;

revoke all on table public.aos_wa4_process_entity_context_v1 from public,anon,authenticated;
grant select on table public.aos_wa4_process_entity_context_v1 to service_role;

create or replace function public.aos_wa4_price_fingerprint_v1()
returns text
language sql
security definer
set search_path=''
as $$
  select md5(coalesce(string_agg(x.payload,'|' order by x.sort_key),'EMPTY'))
  from (
    select 'C:'||c.id::text as sort_key,
           'C:'||c.id::text||':'||coalesce(c.precio_base::text,'NULL')||':'||
           coalesce(c.precio_oferta::text,'NULL')||':'||coalesce(c.moneda,'NULL')||':'||
           coalesce(c.updated_at::text,'NULL') as payload
    from public.aos_catalogo_servicios c
    where c.estado='ACTIVO' and c.tipo in ('SERVICIO','PRODUCTO')
    union all
    select 'T:'||t.id::text,
           'T:'||t.id::text||':'||coalesce(t.precio::text,'NULL')||':'||
           coalesce(t.moneda,'NULL')||':'||coalesce(t.estado,'NULL')
    from public.aos_catalogo_toppings t
    where t.estado='ACTIVO'
  ) x;
$$;

revoke all on function public.aos_wa4_price_fingerprint_v1() from public,anon,authenticated;
grant execute on function public.aos_wa4_price_fingerprint_v1() to service_role;

create or replace function public.aos_wa4_quote_preview_v1(
  p_components jsonb,
  p_payment_mode text default 'COMPLETE',
  p_authorized_plan boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_item jsonb;
  v_source_type text;
  v_source_id text;
  v_role text;
  v_phase text;
  v_qty integer;
  v_qty_text text;
  v_ctx record;
  v_top record;
  v_role_policy record;
  v_unit numeric;
  v_subtotal numeric;
  v_total numeric:=0;
  v_lines jsonb:='[]'::jsonb;
  v_phase_totals jsonb:='{"COMMERCIAL_F1_PREP_ACT":0,"COMMERCIAL_F2_INTERVENTION":0,"COMMERCIAL_F3_CONTINUITY":0}'::jsonb;
  v_prev numeric;
  v_mode text:=upper(trim(coalesce(p_payment_mode,'')));
  v_count integer;
  v_currency text:=null;
  v_item_currency text;
begin
  if p_components is null or jsonb_typeof(p_components)<>'array' then
    return jsonb_build_object('ok',false,'error','INVALID_COMPONENT_ARRAY');
  end if;
  v_count:=jsonb_array_length(p_components);
  if v_count<1 or v_count>50 then
    return jsonb_build_object('ok',false,'error','INVALID_COMPONENT_COUNT','count',v_count);
  end if;
  if v_mode not in ('COMPLETE','PROGRESSIVE') then
    return jsonb_build_object('ok',false,'error','INVALID_PAYMENT_MODE');
  end if;

  for v_item in select value from jsonb_array_elements(p_components)
  loop
    v_source_type:=upper(trim(coalesce(v_item->>'source_type','CATALOG')));
    v_source_id:=trim(coalesce(v_item->>'source_id',''));
    v_role:=upper(trim(coalesce(v_item->>'role','')));
    v_phase:=upper(trim(coalesce(v_item->>'phase_code','')));
    v_qty_text:=trim(coalesce(v_item->>'quantity','1'));

    if v_qty_text !~ '^[1-9][0-9]*$' then
      return jsonb_build_object('ok',false,'error','INVALID_QUANTITY','source_id',v_source_id);
    end if;
    v_qty:=v_qty_text::integer;
    if v_qty>100 then
      return jsonb_build_object('ok',false,'error','QUANTITY_LIMIT','source_id',v_source_id);
    end if;
    if v_phase not in ('COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F2_INTERVENTION','COMMERCIAL_F3_CONTINUITY') then
      return jsonb_build_object('ok',false,'error','INVALID_PHASE','source_id',v_source_id,'phase_code',v_phase);
    end if;

    select * into v_role_policy
    from public.aos_wa4_process_role_policy_v1 r
    where r.role_code=v_role;
    if v_role_policy.role_code is null then
      return jsonb_build_object('ok',false,'error','INVALID_COMPONENT_ROLE','source_id',v_source_id,'role',v_role);
    end if;
    if v_role_policy.requires_authorized_plan and not p_authorized_plan then
      return jsonb_build_object('ok',false,'error','AUTHORIZED_PLAN_REQUIRED','source_id',v_source_id,'role',v_role);
    end if;

    if v_source_type='CATALOG' then
      if v_source_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
        return jsonb_build_object('ok',false,'error','INVALID_CATALOG_ID','source_id',v_source_id);
      end if;
      select * into v_ctx
      from public.aos_wa4_process_entity_context_v1 c
      where c.entity_id=v_source_id::uuid;
      if v_ctx.entity_id is null then
        return jsonb_build_object('ok',false,'error','CATALOG_ENTITY_NOT_FOUND','source_id',v_source_id);
      end if;
      if not (v_ctx.entity_type=any(v_role_policy.allowed_entity_types)) then
        return jsonb_build_object('ok',false,'error','ROLE_ENTITY_TYPE_MISMATCH','source_id',v_source_id,'role',v_role,'entity_type',v_ctx.entity_type);
      end if;
      if not (v_phase=any(v_ctx.commercial_phase_codes)) then
        return jsonb_build_object('ok',false,'error','PHASE_NOT_ALLOWED_FOR_ENTITY','source_id',v_source_id,'phase_code',v_phase);
      end if;
      if not coalesce(v_ctx.ready_for_quote,false) then
        return jsonb_build_object('ok',false,'error','PRICE_NOT_READY','source_id',v_source_id,'price_state',v_ctx.price_state,'freshness_state',v_ctx.freshness_state);
      end if;
      v_item_currency:=v_ctx.moneda;
      v_unit:=v_ctx.quote_price;
      v_subtotal:=round(v_unit*v_qty,2);
      if v_currency is null then
        v_currency:=v_item_currency;
      elsif v_currency<>v_item_currency then
        return jsonb_build_object(
          'ok',false,'error','MIXED_CURRENCY_NOT_SUPPORTED',
          'quote_currency',v_currency,'conflicting_currency',v_item_currency,
          'source_id',v_source_id
        );
      end if;
      v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
        'source_type','CATALOG','source_id',v_source_id,'entity_type',v_ctx.entity_type,
        'name',v_ctx.entity_name,'role',v_role,'phase_code',v_phase,'quantity',v_qty,
        'currency',v_item_currency,'unit_price',v_unit,'subtotal',v_subtotal,
        'price_evidence_ref',v_ctx.price_evidence_ref,
        'clinical_scope_authority','AUTHORIZED_PLAN_OR_PROFESSIONAL',
        'price_authority','aos_catalogo_servicios'
      ));
    elsif v_source_type='TOPPING' then
      if v_role<>'TOPPING_ELIGIBLE' then
        return jsonb_build_object('ok',false,'error','TOPPING_ROLE_REQUIRED','source_id',v_source_id);
      end if;
      select * into v_top
      from public.aos_wa4_topping_authority_v1 t
      where t.topping_id=v_source_id;
      if v_top.topping_id is null then
        return jsonb_build_object('ok',false,'error','TOPPING_NOT_FOUND','source_id',v_source_id);
      end if;
      if not coalesce(v_top.ready_for_consideration,false) then
        return jsonb_build_object('ok',false,'error','TOPPING_NOT_READY','source_id',v_source_id);
      end if;
      v_item_currency:=v_top.moneda;
      v_unit:=v_top.precio;
      v_subtotal:=round(v_unit*v_qty,2);
      if v_currency is null then
        v_currency:=v_item_currency;
      elsif v_currency<>v_item_currency then
        return jsonb_build_object(
          'ok',false,'error','MIXED_CURRENCY_NOT_SUPPORTED',
          'quote_currency',v_currency,'conflicting_currency',v_item_currency,
          'source_id',v_source_id
        );
      end if;
      v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
        'source_type','TOPPING','source_id',v_source_id,'name',v_top.nombre,
        'role',v_role,'phase_code',v_phase,'quantity',v_qty,
        'currency',v_item_currency,'unit_price',v_unit,'subtotal',v_subtotal,
        'benefit_mode',v_top.benefit_mode,'price_evidence_ref',v_top.evidence_ref,
        'requires_context_approval',true,'no_discount_semantics',true
      ));
    else
      return jsonb_build_object('ok',false,'error','INVALID_SOURCE_TYPE','source_type',v_source_type);
    end if;

    v_total:=v_total+v_subtotal;
    v_prev:=coalesce((v_phase_totals->>v_phase)::numeric,0);
    v_phase_totals:=jsonb_set(v_phase_totals,array[v_phase],to_jsonb(round(v_prev+v_subtotal,2)),true);
  end loop;

  return jsonb_build_object(
    'ok',true,
    'currency',v_currency,
    'payment_mode',v_mode,
    'canonical_total',round(v_total,2),
    'phase_totals',v_phase_totals,
    'progressive_view',case when v_mode='PROGRESSIVE' then v_phase_totals else null end,
    'scope_preserved',true,
    'discount_applied',false,
    'fx_conversion_applied',false,
    'price_fingerprint',public.aos_wa4_price_fingerprint_v1(),
    'lines',v_lines,
    'warnings',jsonb_build_array(
      'Preview is read-only and does not create a quotation.',
      'Payment mode does not alter clinical scope.',
      'No FX conversion is performed; mixed currencies fail closed.',
      'Required/alternative/dependent roles require authorized plan evidence.',
      'Toppings are candidates only and are never auto-added.'
    )
  );
end;
$$;

revoke all on function public.aos_wa4_quote_preview_v1(jsonb,text,boolean) from public,anon,authenticated;
grant execute on function public.aos_wa4_quote_preview_v1(jsonb,text,boolean) to service_role;

comment on view public.aos_wa4_price_authority_v1 is
'WA-4A.1C V2 governed read model. Live catalog price + currency are authority; stale/anomalous/invalid currency fails closed.';
comment on function public.aos_wa4_quote_preview_v1(jsonb,text,boolean) is
'Private read-only quote preview. Exactly one currency per preview; no FX conversion; mixed currencies fail closed.';

commit;
