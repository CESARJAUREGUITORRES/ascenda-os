-- WA-4A.1B — Zi Vital Commercial Knowledge Graph V1
-- TEST-first / PROD-ready. Third source: ARQUITECTURA COMERCIAL ZI VITAL · VERSION 2026.
-- This migration extends governed knowledge. It does not change prices, patients, sales or AI-send controls.
begin;

-- Extend governed node vocabulary without replacing WA-4A.1 semantics.
alter table public.aos_knowledge_nodes_v1 drop constraint if exists aos_knowledge_nodes_v1_node_type_check;
alter table public.aos_knowledge_nodes_v1
  add constraint aos_knowledge_nodes_v1_node_type_check
  check (node_type in (
    'SYSTEM','DOMAIN','APPROACH','PATIENT_JOURNEY','PHASE','ROLE',
    'TAXONOMY','PRINCIPLE','GLOSSARY','COMMERCIAL_RULE','POLICY','KPI','OKR','PLAYBOOK'
  ));

insert into public.aos_knowledge_sources_v1
  (source_code,title,source_kind,file_name,authority_state,version,source_scope,notes)
values
  ('ZV_COMMERCIAL_ARCH_2026','Arquitectura Comercial Zi Vital · Versión 2026','INTERNAL_PDF',
   'ARQUITECTURA_COMERCIAL_ZI_VITAL_.pdf','AUTHORITATIVE_INTERNAL','2026',
   'Commercial philosophy, patient psychology, phases, domains, internal language, quotation, payments, toppings, ethical upselling, continuity, audit metrics and organizational model',
   'Commercial/operating authority only. Example prices are pedagogical and are never price authority. Clinical claims remain review-gated.')
on conflict(source_code) do update set
  title=excluded.title, version=excluded.version, source_scope=excluded.source_scope,
  notes=excluded.notes, updated_at=now();

-- Normalize aliases used by the commercial document without duplicating approaches.
update public.aos_knowledge_nodes_v1
set aliases='["Calidad Cutánea · Salud · Glow Consciente","Skin Quality"]'::jsonb,
    updated_at=now()
where code='FACIAL_SKIN_SIGNATURE';
update public.aos_knowledge_nodes_v1
set aliases='["Equilibrio Estructural · Expresión · Soporte","Harmony Face"]'::jsonb,
    updated_at=now()
where code='FACIAL_HARMONY_DESIGN';
update public.aos_knowledge_nodes_v1
set aliases='["Regeneración · Longevidad · Sostén Biológico","Bioregeneración"]'::jsonb,
    updated_at=now()
where code='FACIAL_BIOREGEN_FACE';

-- Two phase taxonomies coexist by design: clinical lifecycle != commercial phase.
insert into public.aos_knowledge_nodes_v1
(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('TAX_COMMERCIAL_PHASES','TAXONOMY','ZV_SYSTEM','Fases comerciales Zi Vital','[]',
 'Zi Vital organiza el proceso en preparación, intervención y continuidad.',
 'Usa la fase para explicar dónde está el paciente dentro del recorrido, no como un paquete rígido.',
 'Taxonomía comercial oficial: F1 preparación/activación, F2 intervención personalizada, F3 acompañamiento/mantenimiento/continuidad.',
 null,'{"kind":"COMMERCIAL_PHASE","codes":["COMMERCIAL_F1_PREP_ACT","COMMERCIAL_F2_INTERVENTION","COMMERCIAL_F3_CONTINUITY"],"not_a_package":true}',
 array['fase 1','fase 2','fase 3','preparacion','intervencion','continuidad'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.13-17','APPROVED',now()),
('COMMERCIAL_F1_PREP_ACT','PHASE','TAX_COMMERCIAL_PHASES','Fase 1 — Preparación y activación','["Inicio","Preparación"]',
 'Es la etapa que prepara el proceso antes de intervenciones principales cuando corresponde.',
 'Presenta esta fase como preparación y activación; no como un extra obligatorio ni como una promoción.',
 'Puede incluir detox, vitaminas, hidrofacial o activadores según dominio. La indicación concreta depende del plan.',
 'Claims metabólicos, inflamatorios o de detox requieren validación clínica; no afirmar extracción de toxinas.',
 '{"commercial_phase":1,"functions":["PREPARE","ACTIVATE"]}',array['fase 1','preparacion','activacion'],'CLINICAL_REVIEW_REQUIRED','ZV_COMMERCIAL_ARCH_2026','PDF pp.14-15','APPROVED',now()),
('COMMERCIAL_F2_INTERVENTION','PHASE','TAX_COMMERCIAL_PHASES','Fase 2 — Intervención clínica personalizada','["Intervención principal","Corrección"]',
 'Es la etapa donde se ejecuta la intervención personalizada definida por la doctora.',
 'Explica objetivos y función clínica antes de hablar de herramientas, marcas, ml o zonas.',
 'La composición de esta fase es variable por paciente y puede incluir corrección, soporte, bioestimulación, redefinición o regeneración.',
 'La selección de tratamiento, dosis, material, sesiones e intervalos es decisión clínica.',
 '{"commercial_phase":2,"functions":["ACTIVATE","REGENERATE"]}',array['fase 2','intervencion','correccion'],'HIGH','ZV_COMMERCIAL_ARCH_2026','PDF pp.15-16','APPROVED',now()),
('COMMERCIAL_F3_CONTINUITY','PHASE','TAX_COMMERCIAL_PHASES','Fase 3 — Acompañamiento, mantenimiento y continuidad','["Seguimiento","Mantenimiento","Recompra"]',
 'Es la etapa de seguimiento y cuidado para sostener el proceso en el tiempo.',
 'Productos, controles y sesiones futuras se explican como continuidad cuando realmente protegen o sostienen el proceso.',
 'Es la capa de mantenimiento, prevención, programación futura y recompra consciente.',
 null,'{"commercial_phase":3,"functions":["MAINTAIN"]}',array['fase 3','acompanamiento','mantenimiento','continuidad'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.16-17; 96-100','APPROVED',now()),
('TAX_CLINICAL_LIFECYCLE','TAXONOMY','ZV_SYSTEM','Lifecycle clínico Zi Vital','["Preparar → Activar → Regenerar → Mantener"]',
 'Preparar, activar, regenerar y mantener describe la función general de una intervención dentro del recorrido.',
 'No confundas esta taxonomía funcional con las tres fases comerciales: pueden cruzarse.',
 'Taxonomía transversal preservada del Sistema de Dominios; sirve para clasificar servicios y productos por función.',
 null,'{"kind":"CLINICAL_LIFECYCLE","codes":["PREPARE","ACTIVATE","REGENERATE","MAINTAIN"]}',array['preparar','activar','regenerar','mantener'],'LOW','ZV_DOMAINS_2026','PDF Dominios p.1-2','APPROVED',now()),
('CROSS_DOMAIN_SUPPORT','APPROACH','ZV_SYSTEM','Soporte transversal','["Detox y Vitaminas","Preparación transversal"]',
 'Algunos recursos de Zi Vital acompañan más de un dominio como soporte del proceso.',
 'Úsalo para detox, vitaminas y soporte sistémico cuando el plan los integra; no los conviertas en solución universal.',
 'Es una capa transversal, no un cuarto dominio. Puede relacionarse con Facial, Corporal y Capilar.',
 'La indicación clínica de vitaminas, hierro, ozonoterapia u otros protocolos sistémicos requiere evaluación profesional.',
 '{"cross_domain":true,"domains":["FACIAL","CORPORAL","CAPILAR"]}',array['soporte transversal','vitaminas','detox'],'CLINICAL_REVIEW_REQUIRED','ZV_COMMERCIAL_ARCH_2026','PDF pp.14-20; 22-23','APPROVED',now()),
('CROSS_DOMAIN_EVALUATION','APPROACH','ZV_SYSTEM','Evaluación clínica transversal','["Consulta","Valoración"]',
 'La evaluación ordena el caso antes de definir un proceso.',
 'Una consulta no se fuerza dentro de un enfoque estético: su función es evaluar, priorizar y derivar al dominio/enfoque correcto.',
 'Soporte transversal para consultas y valoración; no constituye un cuarto dominio.',
 'Diagnóstico e indicación pertenecen al profesional clínico.',
 '{"cross_domain":true,"preprocess":true}',array['consulta','evaluacion','valoracion'],'HIGH','ZV_PATIENT_PROCESS_2026','PDF Proceso Atención; consulta/evaluación','APPROVED',now())
on conflict(code) do update set
  title=excluded.title,aliases=excluded.aliases,public_client=excluded.public_client,
  advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,
  clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,
  keywords=excluded.keywords,risk_level=excluded.risk_level,source_code=excluded.source_code,
  source_locator=excluded.source_locator,status='APPROVED',approved_at=now(),updated_at=now();

-- Six fundational commercial principles.
insert into public.aos_knowledge_nodes_v1
(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('PRINCIPLE_PROCESS_NOT_PROCEDURE','PRINCIPLE','ZV_SYSTEM','Venta por proceso, no por procedimiento','[]',
 'Zi Vital explica cada tratamiento dentro de un proceso con objetivo, orden y seguimiento.',
 'Empieza por qué se busca trabajar y en qué fase; después nombra el tratamiento como herramienta.',
 'Principio inamovible: el procedimiento no es protagonista; el proceso protege personalización, autoridad y margen.',null,
 '{"immutable":true,"anti_patterns":["precio como eje","procedimiento aislado","combo rígido"]}',array['proceso','procedimiento'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.7-8','APPROVED',now()),
('PRINCIPLE_NO_DISCOUNT','PRINCIPLE','ZV_SYSTEM','No-descuento; incremento de valor','[]',
 'Zi Vital no basa la decisión en descuentos; puede ofrecer formas de pago y beneficios vinculados al proceso.',
 'No improvises rebajas. Si cambia el alcance, recalcula el proceso; si no cambia, no negocies el valor.',
 'El incentivo se construye con acompañamiento, toppings clínicos, productos estratégicos, programación o facilidades, no con reducción arbitraria del precio.',null,
 '{"immutable":true,"price_authority":"CATALOG_RUNTIME","discount_language_prohibited":true}',array['descuento','valor','beneficio'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.8; 80-81','APPROVED',now()),
('PRINCIPLE_STRUCTURED_PERSONALIZATION','PRINCIPLE','ZV_SYSTEM','Personalización dentro de estructura','[]',
 'Cada plan puede ser distinto, pero se organiza dentro de una estructura clara.',
 'La estructura es estable; tratamientos, sesiones, orden e intensidad pueden variar por evaluación.',
 'Fórmula rectora: estructura firme + criterio clínico flexible. Evita caos e igualmente evita planes rígidos disfrazados de personalización.',
 'El contenido clínico individual solo puede definirlo el profesional autorizado.',
 '{"immutable":true}',array['personalizacion','estructura'],'MEDIUM','ZV_COMMERCIAL_ARCH_2026','PDF p.9','APPROVED',now()),
('PRINCIPLE_CLINICAL_COHERENCE','PRINCIPLE','ZV_SYSTEM','Coherencia clínica sobre urgencia comercial','[]',
 'Zi Vital prioriza que el proceso tenga sentido antes que forzar una decisión rápida.',
 'No cierres a costa de contradecir el plan médico, sobreprometer o añadir algo sin función clínica.',
 'La coherencia clínica es límite superior del sistema comercial.',
 'Toda decisión médica permanece bajo autoridad clínica.',
 '{"immutable":true}',array['coherencia clinica','urgencia comercial'],'HIGH','ZV_COMMERCIAL_ARCH_2026','PDF p.9; pp.98-99','APPROVED',now()),
('PRINCIPLE_LONG_TERM','PRINCIPLE','ZV_SYSTEM','Acompañamiento a largo plazo','[]',
 'La atención contempla controles, mantenimiento, productos de soporte y planificación futura cuando corresponden.',
 'El cierre de una sesión debe dejar claro el siguiente paso sin presión.',
 'La continuidad es parte del valor y de la retención ética; no equivale a perseguir recompra.',null,
 '{"immutable":true}',array['acompanamiento','continuidad','mantenimiento'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.9-10; 97-100','APPROVED',now()),
('PRINCIPLE_TRANSPARENCY_WITHOUT_FRAGMENTATION','PRINCIPLE','ZV_SYSTEM','Transparencia sin fragmentación','[]',
 'El paciente puede conocer tratamientos y precios, pero la información se ordena dentro del proceso.',
 'Responde detalles si los piden y vuelve al objetivo, función y fase; evita una lista fría que invite a desarmar el plan.',
 'La transparencia no significa convertir el plan en factura técnica; el desglose es secundario a la comprensión del recorrido.',null,
 '{"immutable":true}',array['transparencia','fragmentacion','desglose'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF p.10; pp.63-66','APPROVED',now())
on conflict(code) do update set public_client=excluded.public_client,advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,source_locator=excluded.source_locator,updated_at=now();

-- Commercial dictionary: one governed source of language, not copies inside every service.
insert into public.aos_knowledge_nodes_v1
(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('GLOSSARY_PUBLIC_PROCESS_LANGUAGE','GLOSSARY','ZV_SYSTEM','Lenguaje de proceso hacia paciente','[]',
 'Zi Vital usa un lenguaje simple de proceso, fase, corrección, activación, regeneración, acompañamiento, mantenimiento, control y planificación.',
 'Prioriza función y objetivo. Toxina = herramienta de corrección muscular; AH = soporte estructural; bioestimuladores/exosomas = recursos regenerativos; tratamientos corporales = reducción/modelado/regeneración según caso.',
 'Diccionario externo común para evitar contradicciones entre doctora, enfermería y recepción.',
 'No convertir traducciones comerciales en afirmaciones clínicas absolutas.',
 '{"public_terms":["proceso","fase","corrección","activación","regeneración","acompañamiento","mantenimiento","control","planificación"],"translation_map":{"toxina":"corrección muscular","acido_hialuronico":"soporte estructural","bioestimulador":"bioestimulación/regeneración","radiofrecuencia_facial":"regeneración por capas","enzimas":"reducción localizada","criolipolisis":"reducción controlada","ondas_rusas":"activación muscular","radiofrecuencia_capilar":"activación folicular","exosomas_capilar":"regeneración capilar","producto_capilar":"mantenimiento"}}',
 array['diccionario','lenguaje paciente','traduccion'],'MEDIUM','ZV_COMMERCIAL_ARCH_2026','PDF pp.21-38','APPROVED',now()),
('GLOSSARY_INTERNAL_ONLY','GLOSSARY','ZV_SYSTEM','Lenguaje exclusivamente interno','[]',
 null,
 'Mililitros exactos, marcas, costos unitarios, margen, toppings, packs internos y precio base se usan para operación; frente al paciente se explican solo cuando son necesarios y dentro del marco del proceso.',
 'Esta separación protege coherencia y evita que variables internas se conviertan en el argumento comercial principal.',
 'Detalle clínico de dosis/material requiere autoridad profesional.',
 '{"internal_terms":["ml exactos","marcas específicas","costos unitarios","márgenes","amortiguadores","toppings","packs internos","precios base"]}',
 array['lenguaje interno','margen','toppings','precio base'],'HIGH','ZV_COMMERCIAL_ARCH_2026','PDF pp.28-29','APPROVED',now())
on conflict(code) do update set public_client=excluded.public_client,advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,source_locator=excluded.source_locator,updated_at=now();

-- Core quotation / payment / topping / continuity rules.
insert into public.aos_knowledge_nodes_v1
(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('RULE_MEDICAL_PLAN_TO_COMMERCIAL','COMMERCIAL_RULE','ZV_SYSTEM','Plan médico → arquitectura comercial','[]',
 null,
 'Antes de cotizar identifica dominio, objetivo principal, fases, núcleo/movibles, tiempos y qué puede escalonarse. Si no entiendes el mapa, no cotices todavía.',
 'El plan de la doctora es prescripción clínica estructurada, no cotización. Recepción traduce criterio a escenarios sin modificar la indicación.',
 'El diagnóstico, objetivo clínico y tratamientos corresponden a la doctora.',
 '{"required_plan_fields":["domains","clinical_objective","phases","treatments_by_phase","sessions_intervals","core_vs_reprogrammable","biological_timing"]}',
 array['plan medico','cotizacion','recepcion'],'HIGH','ZV_COMMERCIAL_ARCH_2026','PDF pp.54-62','APPROVED',now()),
('RULE_QUOTE_PROCESS','COMMERCIAL_RULE','ZV_SYSTEM','Cotizar proceso antes que ítems','[]',
 'El valor se presenta dentro del recorrido diseñado; si quieres detalle, puede explicarse sin perder el contexto.',
 'Presenta primero objetivo y proceso, luego valor total y escenarios. Si se solicita desglose, explica función antes del precio unitario.',
 'El precio vigente siempre proviene del catálogo/runtime; los importes del PDF son solo ejemplos.',null,
 '{"price_authority":"aos_catalogo_servicios","example_prices_are_authority":false}',array['cotizar proceso','valor global','desglose'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.63-66','APPROVED',now()),
('RULE_RECALCULATE_PROCESS','COMMERCIAL_RULE','ZV_SYSTEM','Recalcular proceso; no restar piezas','[]',
 'Si decides postergar una parte, el equipo puede explicarte cómo cambia el recorrido y qué queda para después.',
 'Cuando el paciente pide quitar algo, valida, explica impacto y rediseña alcance/tiempos. Nunca hagas una resta automática presentada como descuento.',
 'Regla: si cambia el proceso, se recalcula; si el proceso no cambia, el valor no se negocia.',null,
 '{"rule":"PROCESS_CHANGE_RECALCULATE","anti_pattern":"UNIT_PRICE_SUBTRACTION"}',array['recalcular','quitar tratamiento','reordenar'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.66-75','APPROVED',now()),
('RULE_PAYMENT_SCENARIOS','COMMERCIAL_RULE','ZV_SYSTEM','Pago completo vs progresivo','[]',
 'El proceso puede organizarse completo o progresivamente según el plan y las condiciones vigentes.',
 'Explica ambas opciones sin presión. El completo prioriza fluidez/planificación; el progresivo ordena avance por fases.',
 'No usar el pago progresivo para fragmentar arbitrariamente un plan. Condiciones económicas reales provienen de políticas vigentes.',null,
 '{"scenarios":["COMPLETE","PROGRESSIVE"],"no_pressure":true}',array['pago completo','pago progresivo'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.76-80','APPROVED',now()),
('RULE_TOPPINGS_BENEFITS','COMMERCIAL_RULE','ZV_SYSTEM','Toppings y beneficios con función','[]',
 'Cuando existe un beneficio, debe tener una función clara dentro del acompañamiento.',
 'Un topping solo se ofrece si refuerza resultado, experiencia o continuidad. No lo presentes como regalo improvisado ni como sustituto de descuento.',
 'Beneficios post-compromiso; no usar obsequios sin relación clínica para compensar precio.',
 'Cualquier beneficio clínico debe ser compatible con el plan médico.',
 '{"benefit_not_gift":true,"timing":"POST_COMMITMENT","functions":["RESULT_SUPPORT","EXPERIENCE","CONTINUITY"]}',array['topping','beneficio','regalo'],'MEDIUM','ZV_COMMERCIAL_ARCH_2026','PDF pp.80-81','APPROVED',now()),
('RULE_ETHICAL_UPSELL','COMMERCIAL_RULE','ZV_SYSTEM','Upselling ético y continuidad','[]',
 'Una recomendación adicional debe tener sentido para cuidar el proceso, no solo para aumentar la compra.',
 'Ofrece algo adicional solo si mejora el resultado, reduce riesgo de proceso incompleto o protege la inversión. Respeta comprensión → confianza → contención → compromiso → expansión.',
 'El sistema debe poder justificar por qué se ofrece y por qué todavía no corresponde ofrecer algo.',
 'La coherencia clínica limita cualquier oportunidad comercial.',
 '{"eligibility":["IMPROVES_RESULT","REDUCES_INCOMPLETE_RISK","PROTECTS_INVESTMENT"],"emotional_sequence":["COMPREHENSION","TRUST","CONTAINMENT","COMMITMENT","EXPANSION"]}',array['upselling','cross selling','continuidad'],'HIGH','ZV_COMMERCIAL_ARCH_2026','PDF pp.96-100','APPROVED',now()),
('RULE_PRODUCTS_AS_EXTENSION','COMMERCIAL_RULE','ZV_SYSTEM','Productos como extensión del tratamiento','[]',
 'Los productos se explican por su función de cuidado entre sesiones o mantenimiento, no como retail aislado.',
 'Introduce el producto desde uso, función y momento. No lideres con precio. Debe resolver una necesidad concreta y estar relacionado con el proceso.',
 'Los productos son una pieza de continuidad y recompra consciente; las relaciones deben estar gobernadas por dominio/enfoque.',
 'Suplementos, fármacos o productos con riesgo requieren límites clínicos específicos.',
 '{"default_commercial_phase":"COMMERCIAL_F3_CONTINUITY"}',array['productos','continuidad','domiciliario'],'MEDIUM','ZV_COMMERCIAL_ARCH_2026','PDF pp.97-100','APPROVED',now()),
('POLICY_REFUND_ALIGNMENT','POLICY','ZV_SYSTEM','Política de pagos/devoluciones — alineación requerida','[]',
 null,
 'El documento comercial declara no devoluciones una vez iniciado el proceso; antes de comunicarlo como regla contractual verifica la política/tyc vigente.',
 'No convertir un ejemplo del PDF en política legal si contradice términos vigentes. Requiere alineación con términos y condiciones oficiales.',
 null,
 '{"source_policy":"NO_REFUND_AFTER_START","public_authority":false,"requires_legal_alignment":true}',array['devoluciones','pagos','politica'],'HIGH','ZV_COMMERCIAL_ARCH_2026','PDF pp.90-95','APPROVED',now())
on conflict(code) do update set public_client=excluded.public_client,advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,source_locator=excluded.source_locator,updated_at=now();

-- OWNER_ADMIN metrics and OKRs; thresholds are document-derived targets, not automatically current performance.
insert into public.aos_knowledge_nodes_v1
(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('KPI_EXPERIENCE_TRUST','KPI','ZV_SYSTEM','KPIs — Experiencia & confianza','[]',null,null,
 'Mide claridad del proceso, objeciones repetidas, confianza percibida y tiempo de decisión. Son señales de calidad del relato, no solo de cierre.',null,
 '{"audience":"OWNER_ADMIN","metrics":[{"code":"PROCESS_CLARITY","healthy":">85% yes","alert":"<70% yes"},{"code":"REPEATED_OBJECTIONS","healthy":"<=2 key repeated questions","alert":"same doubts recurring"},{"code":"PERCEIVED_TRUST","healthy":">=4/5","alert":"<=3/5"},{"code":"DECISION_TIME_DAYS","healthy":"<=7","alert":">14"}]}',
 array['kpi','claridad','confianza','decision'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF pp.108-109','APPROVED',now()),
('KPI_COMMERCIAL_COHERENCE','KPI','ZV_SYSTEM','KPIs — Coherencia comercial','[]',null,null,
 'Mide re-cotizaciones, fragmentación, timing de toppings y descuentos encubiertos.',null,
 '{"audience":"OWNER_ADMIN","metrics":[{"code":"REQUOTE_COUNT","healthy":"1-2","alert":">=3"},{"code":"FRAGMENTATION_RATIO","healthy":"<=35%","alert":">50%"},{"code":"TOPPING_POST_COMMITMENT","healthy":">=90%","alert":"<70%"},{"code":"HIDDEN_DISCOUNT","healthy":"0 cases","alert":">=1"}]}',
 array['kpi','recotizacion','fragmentacion','toppings'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF p.109','APPROVED',now()),
('KPI_FINANCIAL_HEALTH','KPI','ZV_SYSTEM','KPIs — Salud financiera','[]',null,null,
 'Mide ticket por proceso, ratio de pago completo, adelanto y margen protegido. El documento da umbrales orientativos que deben validarse contra la operación real.',null,
 '{"audience":"OWNER_ADMIN","metrics":[{"code":"AVG_PROCESS_TICKET","healthy":"stable_or_growing","alert":"sustained_decline"},{"code":"FULL_PAYMENT_RATIO","healthy":">=45%","alert":"<30%"},{"code":"AVG_ADVANCE","healthy":">=50-60%","alert":"<40%"},{"code":"MARGIN_PROTECTED","healthy":"within_target","alert":"progressive_erosion"}]}',
 array['kpi','ticket','pago completo','adelanto','margen'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF p.109','APPROVED',now()),
('KPI_PATIENT_CONTINUITY','KPI','ZV_SYSTEM','KPIs — Continuidad del paciente','[]',null,null,
 'Mide finalización, programación futura, compra de acompañamiento y abandono no justificado.',null,
 '{"audience":"OWNER_ADMIN","metrics":[{"code":"COMPLETION_RATE","healthy":">=75%","alert":"<60%"},{"code":"FUTURE_BOOKING_RATE","healthy":">=65%","alert":"<45%"},{"code":"ACCOMPANIMENT_PRODUCT_RATE","healthy":">=50%","alert":"<30%"},{"code":"UNJUSTIFIED_ABANDONMENT","healthy":"<=10%","alert":">20%"}]}',
 array['kpi','finalizacion','programacion futura','abandono'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF p.110','APPROVED',now()),
('OKR_PREMIUM_COHERENCE','OKR','ZV_SYSTEM','OKR — Coherencia Premium','[]',null,null,
 'Objetivo documental: 0 descuentos encubiertos; 100% de beneficios después del compromiso; <=2 re-cotizaciones promedio.',null,
 '{"audience":"OWNER_ADMIN","target_type":"DOCUMENT_TARGET"}',array['okr','coherencia premium'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF p.110','APPROVED',now()),
('OKR_PATIENT_COMMITMENT','OKR','ZV_SYSTEM','OKR — Compromiso del Paciente','[]',null,null,
 'Objetivo documental: >=75% de procesos completados y >=65% con programación futura.',null,
 '{"audience":"OWNER_ADMIN","target_type":"DOCUMENT_TARGET"}',array['okr','compromiso paciente'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF p.110','APPROVED',now()),
('OKR_COMMERCIAL_HEALTH','OKR','ZV_SYSTEM','OKR — Salud Comercial','[]',null,null,
 'Objetivo documental: >=50% adelanto promedio y ticket promedio estable o creciente, protegiendo margen sin fricción.',null,
 '{"audience":"OWNER_ADMIN","target_type":"DOCUMENT_TARGET"}',array['okr','salud comercial'],'LOW','ZV_COMMERCIAL_ARCH_2026','PDF p.110','APPROVED',now())
on conflict(code) do update set owner_admin=excluded.owner_admin,system_reference=excluded.system_reference,source_locator=excluded.source_locator,updated_at=now();

-- Canonical entity graph: every active service/product gets an explicit mapping. Multi-domain is first-class.
create table if not exists public.aos_knowledge_entity_map_v1 (
  entity_id uuid not null,
  entity_type text not null check (entity_type in ('SERVICE','PRODUCT')),
  entity_name text not null,
  category text,
  domain_codes text[] not null,
  approach_codes text[] not null,
  commercial_phase_codes text[] not null,
  clinical_lifecycle text[] not null,
  zi_function text not null,
  public_positioning text,
  advisor_positioning text,
  mapping_state text not null check (mapping_state in ('MAPPED','MAPPED_MULTI_DOMAIN','MAPPED_NA_EXPLICIT','REVIEW_REQUIRED')),
  mapping_confidence numeric(4,3) not null check (mapping_confidence between 0 and 1),
  composition_state text not null check (composition_state in ('COMPLETE_SOURCE','NOT_APPLICABLE_TECHNOLOGY','NOT_APPLICABLE_OPERATIONAL','REAL_MISSING_REVIEW','CATEGORY_TEMPLATE_REVIEW')),
  source_code text not null references public.aos_knowledge_sources_v1(source_code),
  source_locator text not null,
  mapped_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(entity_type,entity_id),
  check (cardinality(domain_codes)>0),
  check (cardinality(approach_codes)>0),
  check (cardinality(commercial_phase_codes)>0),
  check (cardinality(clinical_lifecycle)>0)
);
revoke all on table public.aos_knowledge_entity_map_v1 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_knowledge_entity_map_v1 to service_role;

with active as (
  select id,nombre,categoria,tipo,composicion
  from public.aos_catalogo_servicios
  where estado='ACTIVO' and tipo in ('SERVICIO','PRODUCTO')
), mapped as (
select a.*,
  case
    when tipo='SERVICIO' and categoria='CAPILAR' then array['CAPILAR']
    when tipo='SERVICIO' and categoria in ('CORPORAL','CRIOLIPÓLISIS','APARATOLOGÍA','GLÚTEOS') then array['CORPORAL']
    when tipo='SERVICIO' and categoria='RF FRACCIONADA' and upper(nombre) like '%BRAZO%' then array['CORPORAL']
    when tipo='SERVICIO' and categoria='TOXINA' and upper(nombre) like '%HIPERHIDROSIS%' then array['CORPORAL']
    when tipo='SERVICIO' and categoria in ('VITAMINAS','DETOX','PEPTONAS','CONSULTA') then array['FACIAL','CORPORAL','CAPILAR']
    when tipo='SERVICIO' then array['FACIAL']
    when tipo='PRODUCTO' and categoria='CAPILAR ZV' then array['CAPILAR']
    when tipo='PRODUCTO' and categoria='CORPORAL ZV' then array['CORPORAL']
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' and upper(nombre) like any(array['%REDUFAST%','%PRUNEX%']) then array['CORPORAL']
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' and upper(nombre) like any(array['%BEAUTY MAKER%']) then array['FACIAL','CAPILAR']
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' and upper(nombre) like any(array['%MAGNESIO%','%NEUROVITAL%','%RESVERATROL%','%ASTAXANTINA%','%ZINC%']) then array['FACIAL','CORPORAL','CAPILAR']
    else array['FACIAL']
  end as domains,
  case
    when tipo='SERVICIO' and categoria='CAPILAR' then array['CAPILAR_ACTIVACION_REGENERACION']
    when tipo='SERVICIO' and categoria='DETOX' then array['CROSS_DOMAIN_SUPPORT','CORPORAL_BODY_RESET']
    when tipo='SERVICIO' and categoria in ('VITAMINAS','PEPTONAS') then array['CROSS_DOMAIN_SUPPORT']
    when tipo='SERVICIO' and categoria='CONSULTA' then array['CROSS_DOMAIN_EVALUATION']
    when tipo='SERVICIO' and categoria in ('CORPORAL','CRIOLIPÓLISIS','APARATOLOGÍA') then array['CORPORAL_SCULPT_BODY']
    when tipo='SERVICIO' and categoria='GLÚTEOS' then array['CORPORAL_SCULPT_BOOTY']
    when tipo='SERVICIO' and categoria='RF FRACCIONADA' and upper(nombre) like '%BRAZO%' then array['CORPORAL_SCULPT_BODY']
    when tipo='SERVICIO' and categoria='RF FRACCIONADA' then array['FACIAL_SKIN_SIGNATURE']
    when tipo='SERVICIO' and categoria='FACIALES' then array['FACIAL_SKIN_SIGNATURE']
    when tipo='SERVICIO' and categoria='PEELINGS' then array['FACIAL_SKIN_SIGNATURE']
    when tipo='SERVICIO' and categoria='MESOTERAPIA' and upper(nombre) like '%PRP%' then array['FACIAL_BIOREGEN_FACE']
    when tipo='SERVICIO' and categoria='MESOTERAPIA' then array['FACIAL_SKIN_SIGNATURE']
    when tipo='SERVICIO' and categoria='EXOSOMAS' then array['FACIAL_BIOREGEN_FACE']
    when tipo='SERVICIO' and categoria='BIOESTIMULADOR' then array['FACIAL_BIOREGEN_FACE']
    when tipo='SERVICIO' and categoria='BIOREVITALIZACIÓN' and upper(nombre) like any(array['%EXO%','%PDRN%']) then array['FACIAL_BIOREGEN_FACE']
    when tipo='SERVICIO' and categoria='BIOREVITALIZACIÓN' then array['FACIAL_SKIN_SIGNATURE']
    when tipo='SERVICIO' and categoria='ACIDO HIALURONICO' and upper(nombre) like any(array['%PROFHILO%','%SUNEKO%']) then array['FACIAL_BIOREGEN_FACE']
    when tipo='SERVICIO' and categoria='ACIDO HIALURONICO' then array['FACIAL_HARMONY_DESIGN']
    when tipo='SERVICIO' and categoria='HIFU' then array['FACIAL_HARMONY_DESIGN']
    when tipo='SERVICIO' and categoria='ENZIMAS' then array['FACIAL_HARMONY_DESIGN']
    when tipo='SERVICIO' and categoria='TOXINA' and upper(nombre) like '%HIPERHIDROSIS%' then array['NOT_APPLICABLE_FUNCTIONAL']
    when tipo='SERVICIO' and categoria='TOXINA' then array['FACIAL_HARMONY_DESIGN']
    when tipo='PRODUCTO' and categoria='CAPILAR ZV' then array['CAPILAR_MANTENIMIENTO_PREVENCION']
    when tipo='PRODUCTO' and categoria='CORPORAL ZV' then array['CORPORAL_SCULPT_BODY']
    when tipo='PRODUCTO' and categoria in ('FACIAL ZV','FACIALES','ISDIN') and upper(nombre) like any(array['%EXOFUSION%']) then array['FACIAL_BIOREGEN_FACE']
    when tipo='PRODUCTO' and categoria='FACIAL ZV' and upper(nombre) like any(array['%LIFTING B%','%PERFECT FORM F%']) then array['FACIAL_HARMONY_DESIGN']
    when tipo='PRODUCTO' and categoria in ('FACIAL ZV','FACIALES','ISDIN') then array['FACIAL_SKIN_SIGNATURE']
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' and upper(nombre) like any(array['%REDUFAST%','%PRUNEX%']) then array['CORPORAL_BODY_RESET','CORPORAL_SCULPT_BODY']
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' and upper(nombre) like '%BEAUTY MAKER%' then array['FACIAL_BIOREGEN_FACE','CAPILAR_MANTENIMIENTO_PREVENCION']
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' and upper(nombre) like any(array['%HELIOCARE%','%POLYPODIUM%']) then array['FACIAL_SKIN_SIGNATURE']
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' then array['CROSS_DOMAIN_SUPPORT']
    else array['NOT_APPLICABLE_FUNCTIONAL']
  end as approaches
from active a
)
insert into public.aos_knowledge_entity_map_v1
(entity_id,entity_type,entity_name,category,domain_codes,approach_codes,commercial_phase_codes,clinical_lifecycle,zi_function,public_positioning,advisor_positioning,mapping_state,mapping_confidence,composition_state,source_code,source_locator)
select id,
  case when tipo='PRODUCTO' then 'PRODUCT' else 'SERVICE' end,
  nombre,categoria,domains,approaches,
  case
    when tipo='PRODUCTO' then array['COMMERCIAL_F3_CONTINUITY']
    when categoria='CONSULTA' then array['PRE_PHASE_EVALUATION']
    when categoria in ('DETOX','VITAMINAS') then array['COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F3_CONTINUITY']
    when categoria='FACIALES' and upper(nombre) like '%HIDROFACIAL%' then array['COMMERCIAL_F1_PREP_ACT','COMMERCIAL_F3_CONTINUITY']
    else array['COMMERCIAL_F2_INTERVENTION']
  end,
  case
    when tipo='PRODUCTO' then array['MAINTAIN']
    when categoria='CONSULTA' then array['PREPARE']
    when categoria in ('DETOX','VITAMINAS') then array['PREPARE','ACTIVATE','MAINTAIN']
    when categoria='FACIALES' and upper(nombre) like '%HIDROFACIAL%' then array['PREPARE','MAINTAIN']
    when categoria in ('BIOESTIMULADOR','BIOREVITALIZACIÓN','EXOSOMAS','MESOTERAPIA','PEELINGS','RF FRACCIONADA','PEPTONAS') then array['REGENERATE']
    else array['ACTIVATE']
  end,
  case
    when tipo='PRODUCTO' and categoria='CAPILAR ZV' then 'MANTENIMIENTO_CAPILAR_DOMICILIARIO'
    when tipo='PRODUCTO' and categoria in ('FACIAL ZV','FACIALES','ISDIN') then 'MANTENIMIENTO_CUTANEO_DOMICILIARIO'
    when tipo='PRODUCTO' and categoria='CORPORAL ZV' then 'MANTENIMIENTO_CORPORAL_DOMICILIARIO'
    when tipo='PRODUCTO' and categoria='NUTRICIONAL' then 'SOPORTE_NUTRICIONAL_Y_CONTINUIDAD'
    when categoria='DETOX' then 'PREPARACION_Y_ACOMPANAMIENTO'
    when categoria='VITAMINAS' then 'SOPORTE_SISTEMICO_GOBERNADO'
    when categoria='CONSULTA' then 'EVALUACION_Y_PRIORIZACION'
    when categoria='CAPILAR' then 'ACTIVACION_Y_REGENERACION_CAPILAR'
    when categoria='ACIDO HIALURONICO' then 'SOPORTE_ESTRUCTURAL_O_BIOREMODELACION'
    when categoria='TOXINA' then 'CORRECCION_MUSCULAR_O_FUNCIONAL'
    when categoria in ('BIOESTIMULADOR','EXOSOMAS') then 'BIOESTIMULACION_Y_REGENERACION'
    when categoria in ('FACIALES','PEELINGS','BIOREVITALIZACIÓN','MESOTERAPIA') then 'CALIDAD_Y_REGENERACION_CUTANEA'
    when categoria in ('CRIOLIPÓLISIS','CORPORAL','APARATOLOGÍA') then 'REDUCCION_MODELADO_Y_SOSTEN_CORPORAL'
    when categoria='GLÚTEOS' then 'FIRMEZA_PROYECCION_Y_CALIDAD_TISULAR'
    when categoria='HIFU' then 'SOPORTE_REDEFINICION_Y_FIRMEZA'
    when categoria='RF FRACCIONADA' then 'REGENERACION_Y_CALIDAD_TISULAR'
    when categoria='ENZIMAS' then 'REDUCCION_LOCALIZADA_Y_CONTORNO'
    when categoria='PEPTONAS' then 'SOPORTE_REGENERATIVO'
    else 'FUNCION_CLINICA_SEGUN_PLAN'
  end,
  case when tipo='PRODUCTO' then 'Extensión de cuidado y continuidad del proceso; su uso se explica por función y momento, no como retail aislado.'
       else 'Herramienta dentro de un proceso Zi Vital; se explica por objetivo, función y fase antes que por técnica aislada.' end,
  case when tipo='PRODUCTO' then 'Relaciona el producto con el dominio/enfoque y con la fase de mantenimiento; evita recomendarlo sin contexto o fuera de sus límites.'
       else 'Ubica primero dominio, enfoque y fase; luego traduce el servicio a función Zi Vital y deriva la decisión clínica cuando corresponda.' end,
  case
    when approaches=array['NOT_APPLICABLE_FUNCTIONAL'] then 'MAPPED_NA_EXPLICIT'
    when cardinality(domains)>1 then 'MAPPED_MULTI_DOMAIN'
    when categoria in ('PEPTONAS') then 'REVIEW_REQUIRED'
    else 'MAPPED'
  end,
  case
    when approaches=array['NOT_APPLICABLE_FUNCTIONAL'] then 0.700
    when categoria='PEPTONAS' then 0.650
    when cardinality(domains)>1 then 0.850
    else 0.950
  end,
  case
    when nullif(btrim(coalesce(composicion,'')),'') is not null and categoria='VITAMINAS' then 'CATEGORY_TEMPLATE_REVIEW'
    when nullif(btrim(coalesce(composicion,'')),'') is not null then 'COMPLETE_SOURCE'
    when tipo='SERVICIO' and categoria in ('HIFU','CRIOLIPÓLISIS','RF FRACCIONADA','APARATOLOGÍA') then 'NOT_APPLICABLE_TECHNOLOGY'
    when tipo='SERVICIO' and categoria='CONSULTA' then 'NOT_APPLICABLE_OPERATIONAL'
    else 'REAL_MISSING_REVIEW'
  end,
  'ZV_COMMERCIAL_ARCH_2026',
  'Derived mapping: Commercial Architecture pp.13-23, Domains source, canonical catalog name/category'
from mapped
on conflict(entity_type,entity_id) do update set
  entity_name=excluded.entity_name,category=excluded.category,domain_codes=excluded.domain_codes,
  approach_codes=excluded.approach_codes,commercial_phase_codes=excluded.commercial_phase_codes,
  clinical_lifecycle=excluded.clinical_lifecycle,zi_function=excluded.zi_function,
  public_positioning=excluded.public_positioning,advisor_positioning=excluded.advisor_positioning,
  mapping_state=excluded.mapping_state,mapping_confidence=excluded.mapping_confidence,
  composition_state=excluded.composition_state,source_code=excluded.source_code,
  source_locator=excluded.source_locator,updated_at=now();

-- Embed catalog into approach nodes through governed relations; no catalog mutation.
delete from public.aos_knowledge_relations_v1
where source_locator like 'WA-4A.1B entity map%';
insert into public.aos_knowledge_relations_v1
(knowledge_code,relation_type,target_type,target_key,target_id,relation_scope,source_locator)
select approach_code,
       case when m.entity_type='PRODUCT' then 'RELATED_PRODUCT' else 'RELATED_SERVICE' end,
       m.entity_type,
       m.entity_name,
       m.entity_id,
       case when m.entity_type='PRODUCT' then 'PUBLIC' else 'REFERENCE' end,
       'WA-4A.1B entity map · ZV Commercial Architecture 2026'
from public.aos_knowledge_entity_map_v1 m
cross join lateral unnest(m.approach_codes) approach_code
join public.aos_knowledge_nodes_v1 n on n.code=approach_code
where approach_code not like 'NOT_APPLICABLE%'
on conflict(knowledge_code,relation_type,target_type,target_key) do update set
  target_id=excluded.target_id, relation_scope=excluded.relation_scope, source_locator=excluded.source_locator;

-- Read-only entity-context RPC for future internal/copilot use. Not wired by this phase.
create or replace function public.aos_wa4a_entity_context_v1(p_entity_id uuid, p_entity_type text)
returns table(
  entity_id uuid, entity_type text, entity_name text, category text,
  domain_codes text[], approach_codes text[], commercial_phase_codes text[],
  clinical_lifecycle text[], zi_function text, mapping_state text,
  mapping_confidence numeric, composition_state text, evidence jsonb
)
language sql stable security definer set search_path=public as $$
  select m.entity_id,m.entity_type,m.entity_name,m.category,m.domain_codes,m.approach_codes,
         m.commercial_phase_codes,m.clinical_lifecycle,m.zi_function,m.mapping_state,
         m.mapping_confidence,m.composition_state,
         jsonb_build_object('source_code',m.source_code,'source_locator',m.source_locator,'mapped_at',m.mapped_at)
  from public.aos_knowledge_entity_map_v1 m
  where m.entity_id=p_entity_id and m.entity_type=upper(p_entity_type)
$$;
revoke all on function public.aos_wa4a_entity_context_v1(uuid,text) from public,anon,authenticated;
grant execute on function public.aos_wa4a_entity_context_v1(uuid,text) to service_role;

commit;
