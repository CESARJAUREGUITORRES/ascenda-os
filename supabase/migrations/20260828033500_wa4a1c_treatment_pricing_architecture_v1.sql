-- WA-4A.1C — Treatment & Pricing Architecture V1
-- TEST-first / PROD-ready. Reuses canonical catalog/quotes/toppings and WA-4A.1B semantics.
-- No patient, price, quote, payment or AI-send mutation.
begin;

create table public.aos_wa4_process_role_policy_v1 (
  role_code text primary key,
  title text not null,
  semantics text not null,
  can_auto_assign boolean not null default false,
  requires_authorized_plan boolean not null default false,
  allowed_entity_types text[] not null,
  public_exposable boolean not null default false,
  created_at timestamptz not null default now()
);
revoke all on table public.aos_wa4_process_role_policy_v1 from public,anon,authenticated;
grant select on table public.aos_wa4_process_role_policy_v1 to service_role;

insert into public.aos_wa4_process_role_policy_v1
(role_code,title,semantics,can_auto_assign,requires_authorized_plan,allowed_entity_types,public_exposable)
values
('REQUIRED_BY_PLAN','Requerido por plan','Solo puede marcarse como requerido cuando un plan autorizado lo selecciona expresamente.',false,true,array['SERVICIO'],false),
('OPTIONAL_SUPPORT','Soporte opcional','Puede apoyar el proceso pero no es obligatorio ni debe presentarse como necesidad clínica.',false,false,array['SERVICIO','PRODUCTO'],false),
('ALTERNATIVE','Alternativa','Opción sustitutiva que exige elección autorizada; nunca se auto-selecciona por similitud.',false,true,array['SERVICIO','PRODUCTO'],false),
('DEPENDENT','Dependiente','Solo tiene sentido cuando existe el componente del que depende; la dependencia debe ser explícita.',false,true,array['SERVICIO','PRODUCTO'],false),
('CONTROL','Control','Seguimiento/control de un componente o fase ya indicada.',false,true,array['SERVICIO'],true),
('MAINTENANCE','Mantenimiento','Continuidad posterior; no modifica retrospectivamente la intervención principal.',false,false,array['SERVICIO','PRODUCTO'],true),
('PRODUCT_SUPPORT','Producto de soporte','Producto domiciliario o de continuidad aprobado; nunca universal ni obligatorio por categoría.',false,false,array['PRODUCTO'],true),
('TOPPING_ELIGIBLE','Topping elegible','Beneficio/add-on candidato sujeto a coherencia, autorización y reglas de no-descuento.',false,false,array['TOPPING'],false);

create table public.aos_wa4_process_templates_v1 (
  template_code text primary key,
  domain_code text not null references public.aos_knowledge_nodes_v1(code),
  approach_code text not null references public.aos_knowledge_nodes_v1(code),
  title text not null,
  public_summary text not null,
  advisor_summary text not null,
  phase_sequence text[] not null default array['COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F2_INTERVENTION','COMMERCIAL_F3_CONTINUITY'],
  clinical_scope text not null default 'STRUCTURAL_NOT_PRESCRIPTIVE' check (clinical_scope='STRUCTURAL_NOT_PRESCRIPTIVE'),
  price_authority text not null default 'aos_catalogo_servicios',
  template_state text not null default 'APPROVED' check (template_state in ('DRAFT','APPROVED','RETIRED')),
  source_code text not null default 'ZV_COMMERCIAL_ARCH_2026' references public.aos_knowledge_sources_v1(source_code),
  evidence_note text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(domain_code,approach_code)
);
revoke all on table public.aos_wa4_process_templates_v1 from public,anon,authenticated;
grant select on table public.aos_wa4_process_templates_v1 to service_role;

insert into public.aos_wa4_process_templates_v1
(template_code,domain_code,approach_code,title,public_summary,advisor_summary,evidence_note)
values
('TPL_FACIAL_SKIN','DOMAIN_FACIAL','FACIAL_SKIN_SIGNATURE','Facial · Skin Signature','Proceso orientado a calidad de piel y continuidad según evaluación.','Ordena preparación, intervención de calidad cutánea y mantenimiento sin convertir el enfoque en combo fijo.','WA-4A.1B + Arquitectura Comercial Zi Vital; estructura, no prescripción.'),
('TPL_FACIAL_HARMONY','DOMAIN_FACIAL','FACIAL_HARMONY_DESIGN','Facial · Harmony Design','Proceso orientado a armonía y soporte facial definido por evaluación.','Permite explicar intervención estructural y controles sin inferir material, dosis, ml o zonas.','WA-4A.1B + Arquitectura Comercial Zi Vital; selección clínica permanece profesional.'),
('TPL_FACIAL_BIOREGEN','DOMAIN_FACIAL','FACIAL_BIOREGEN_FACE','Facial · BioRegen Face','Proceso orientado a regeneración y sostén progresivo según evaluación.','Ordena intervención regenerativa, control y mantenimiento sin promesas ni selección automática de activos.','WA-4A.1B + Arquitectura Comercial Zi Vital.'),
('TPL_CORPORAL_RESET','DOMAIN_CORPORAL','CORPORAL_BODY_RESET','Corporal · Body Reset','Proceso de preparación corporal cuando corresponde al plan.','F1 puede ser protagonista; nunca presentar detox o soporte como requisito universal.','WA-4A.1B; claims detox/metabólicos permanecen review-gated.'),
('TPL_CORPORAL_SCULPT','DOMAIN_CORPORAL','CORPORAL_SCULPT_BODY','Corporal · Sculpt Body','Proceso de contorno y reducción progresiva definido por evaluación.','Separa preparación, intervención y continuidad; no promete medidas ni rebote cero.','WA-4A.1B + Arquitectura Comercial Zi Vital.'),
('TPL_CORPORAL_BOOTY','DOMAIN_CORPORAL','CORPORAL_SCULPT_BOOTY','Corporal · Sculpt Booty','Proceso de firmeza/proyección y calidad tisular según evaluación.','Estructura opciones sin convertir aparatología, inyectables o sesiones en obligación automática.','WA-4A.1B + Arquitectura Comercial Zi Vital.'),
('TPL_CAPILAR_ACTIVATE','DOMAIN_CAPILAR','CAPILAR_ACTIVACION_REGENERACION','Capilar · Activación & Regeneración','Proceso capilar de activación/regeneración sujeto a evaluación profesional.','Organiza intervención y continuidad; fármacos, dosis, sesiones y activos son autoridad clínica.','WA-4A.1B; protocolos farmacológicos permanecen CLINICAL_RESTRICTED.'),
('TPL_CAPILAR_MAINTAIN','DOMAIN_CAPILAR','CAPILAR_MANTENIMIENTO_PREVENCION','Capilar · Mantenimiento & Prevención','Proceso de continuidad capilar para sostener resultados cuando corresponde.','Permite servicios/productos de soporte sin volverlos add-ons universales.','WA-4A.1B + Arquitectura Comercial Zi Vital.');

create or replace view public.aos_wa4_price_authority_v1 as
select
  c.id as entity_id,
  c.tipo as entity_type,
  c.nombre as entity_name,
  c.categoria,
  c.precio_base,
  c.precio_oferta,
  coalesce(c.precio_oferta,c.precio_base) as quote_price,
  c.num_sesiones,
  c.frecuencia,
  c.updated_at as price_source_updated_at,
  greatest(0,(current_date-c.updated_at::date))::integer as age_days,
  case
    when c.precio_oferta is null and c.precio_base is null then 'MISSING_PRICE'
    when coalesce(c.precio_oferta,c.precio_base,0)<=0 then 'INVALID_NONPOSITIVE_PRICE'
    when c.precio_base is not null and c.precio_oferta is not null and c.precio_oferta>c.precio_base then 'REVIEW_REQUIRED_OFFER_ABOVE_BASE'
    else 'READY'
  end as price_state,
  case when current_date-c.updated_at::date<=180 then 'FRESH' else 'STALE_REVIEW' end as freshness_state,
  (
    coalesce(c.precio_oferta,c.precio_base,0)>0
    and not (c.precio_base is not null and c.precio_oferta is not null and c.precio_oferta>c.precio_base)
    and current_date-c.updated_at::date<=180
  ) as ready_for_quote,
  'aos_catalogo_servicios:'||c.id::text||':'||to_char(c.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS') as evidence_ref
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
  t.tipo_pago,
  t.sesiones,
  t.descripcion,
  case
    when t.precio is null or t.precio<0 then 'INVALID_PRICE'
    when t.precio=0 then 'ZERO_PRICE_BENEFIT_CANDIDATE'
    else 'PAID_ADDON'
  end as benefit_mode,
  (t.precio is not null and t.precio>=0 and t.estado='ACTIVO') as ready_for_consideration,
  'aos_catalogo_toppings:'||t.id::text as evidence_ref
from public.aos_catalogo_toppings t
where t.estado='ACTIVO';
revoke all on table public.aos_wa4_topping_authority_v1 from public,anon,authenticated;
grant select on table public.aos_wa4_topping_authority_v1 to service_role;

-- Contract bridge: WA-4A.1B maps knowledge entity types as SERVICE/PRODUCT,
-- while the canonical runtime catalog uses SERVICIO/PRODUCTO. The pricing layer
-- exposes the canonical catalog type and preserves the 1B mapping type separately.
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
           'C:'||c.id::text||':'||coalesce(c.precio_base::text,'NULL')||':'||coalesce(c.precio_oferta::text,'NULL')||':'||coalesce(c.updated_at::text,'NULL') as payload
    from public.aos_catalogo_servicios c
    where c.estado='ACTIVO' and c.tipo in ('SERVICIO','PRODUCTO')
    union all
    select 'T:'||t.id::text,
           'T:'||t.id::text||':'||coalesce(t.precio::text,'NULL')||':'||coalesce(t.estado,'NULL')
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
      v_unit:=v_ctx.quote_price;
      v_subtotal:=round(v_unit*v_qty,2);
      v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
        'source_type','CATALOG','source_id',v_source_id,'entity_type',v_ctx.entity_type,
        'name',v_ctx.entity_name,'role',v_role,'phase_code',v_phase,'quantity',v_qty,
        'unit_price',v_unit,'subtotal',v_subtotal,'price_evidence_ref',v_ctx.price_evidence_ref,
        'clinical_scope_authority','AUTHORIZED_PLAN_OR_PROFESSIONAL','price_authority','aos_catalogo_servicios'
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
      v_unit:=v_top.precio;
      v_subtotal:=round(v_unit*v_qty,2);
      v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
        'source_type','TOPPING','source_id',v_source_id,'name',v_top.nombre,
        'role',v_role,'phase_code',v_phase,'quantity',v_qty,'unit_price',v_unit,
        'subtotal',v_subtotal,'benefit_mode',v_top.benefit_mode,
        'price_evidence_ref',v_top.evidence_ref,'requires_context_approval',true,
        'no_discount_semantics',true
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
    'currency','PEN',
    'payment_mode',v_mode,
    'canonical_total',round(v_total,2),
    'phase_totals',v_phase_totals,
    'progressive_view',case when v_mode='PROGRESSIVE' then v_phase_totals else null end,
    'scope_preserved',true,
    'discount_applied',false,
    'price_fingerprint',public.aos_wa4_price_fingerprint_v1(),
    'lines',v_lines,
    'warnings',jsonb_build_array(
      'Preview is read-only and does not create a quotation.',
      'Payment mode does not alter clinical scope.',
      'Required/alternative/dependent roles require authorized plan evidence.',
      'Toppings are candidates only and are never auto-added.'
    )
  );
end;
$$;
revoke all on function public.aos_wa4_quote_preview_v1(jsonb,text,boolean) from public,anon,authenticated;
grant execute on function public.aos_wa4_quote_preview_v1(jsonb,text,boolean) to service_role;

comment on view public.aos_wa4_price_authority_v1 is 'WA-4A.1C governed read model. Live catalog remains price authority; anomalous/stale prices fail closed.';
comment on view public.aos_wa4_topping_authority_v1 is 'WA-4A.1C topping read model. Zero-price benefits are explicit candidates, never hidden discounts.';
comment on table public.aos_wa4_process_templates_v1 is 'Structural Zi Vital process templates. Never patient-specific prescriptions and never price masters.';
comment on function public.aos_wa4_quote_preview_v1(jsonb,text,boolean) is 'Private read-only quote preview. Uses live governed prices; does not create quote/payment/plan or mutate scope.';

commit;
