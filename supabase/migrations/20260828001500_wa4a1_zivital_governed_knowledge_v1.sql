-- WA-4A.1 — Zi Vital Governed Knowledge V1
-- TEST-first / PROD-ready. Sources: EL SISTEMA DE DOMINIOS ZI VITAL + PROCESO ATENCION ZI VITAL.
-- Explicit audience separation prevents internal/clinical knowledge leaking into client answers.
begin;

create table if not exists public.aos_knowledge_sources_v1 (
  source_code text primary key,
  title text not null,
  source_kind text not null check (source_kind in ('INTERNAL_PDF','GOVERNED_DOCUMENT')),
  file_name text not null,
  authority_state text not null default 'AUTHORITATIVE_INTERNAL',
  version text not null,
  source_scope text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_knowledge_nodes_v1 (
  code text primary key,
  node_type text not null check (node_type in ('SYSTEM','DOMAIN','APPROACH','PATIENT_JOURNEY','PHASE','ROLE')),
  parent_code text references public.aos_knowledge_nodes_v1(code),
  title text not null,
  aliases jsonb not null default '[]'::jsonb check (jsonb_typeof(aliases)='array'),
  public_client text,
  advisor_internal text,
  owner_admin text,
  clinical_restricted text,
  system_reference jsonb not null default '{}'::jsonb check (jsonb_typeof(system_reference)='object'),
  keywords text[] not null default '{}'::text[],
  risk_level text not null default 'LOW' check (risk_level in ('LOW','MEDIUM','HIGH','CLINICAL_REVIEW_REQUIRED')),
  source_code text not null references public.aos_knowledge_sources_v1(source_code),
  source_locator text not null,
  status text not null default 'APPROVED' check (status in ('DRAFT','APPROVED','RETIRED')),
  version integer not null default 1 check (version > 0),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (public_client is not null or advisor_internal is not null or owner_admin is not null or clinical_restricted is not null)
);

create table if not exists public.aos_knowledge_relations_v1 (
  id bigint generated always as identity primary key,
  knowledge_code text not null references public.aos_knowledge_nodes_v1(code) on delete cascade,
  relation_type text not null check (relation_type in ('CHILD_OF','RELATED_SERVICE','RELATED_PRODUCT','NEXT_APPROACH','SUPPORTED_BY','RESPONSIBLE_ROLE','ALIAS_OF')),
  target_type text not null check (target_type in ('KNOWLEDGE','SERVICE','PRODUCT','CATEGORY','ROLE')),
  target_key text not null,
  target_id uuid,
  relation_scope text not null default 'REFERENCE' check (relation_scope in ('PUBLIC','INTERNAL','CLINICAL','REFERENCE')),
  source_locator text,
  created_at timestamptz not null default now(),
  unique(knowledge_code,relation_type,target_type,target_key)
);

revoke all on table public.aos_knowledge_sources_v1 from public,anon,authenticated;
revoke all on table public.aos_knowledge_nodes_v1 from public,anon,authenticated;
revoke all on table public.aos_knowledge_relations_v1 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_knowledge_sources_v1 to service_role;
grant select,insert,update,delete on table public.aos_knowledge_nodes_v1 to service_role;
grant select,insert,update,delete on table public.aos_knowledge_relations_v1 to service_role;
grant usage,select on sequence public.aos_knowledge_relations_v1_id_seq to service_role;

insert into public.aos_knowledge_sources_v1(source_code,title,source_kind,file_name,authority_state,version,source_scope,notes)
values
('ZV_DOMAINS_2026','El Sistema de Dominios Zi Vital','INTERNAL_PDF','EL_SISTEMA_DE_DOMINIOS_ZI_VITAL.pdf','AUTHORITATIVE_INTERNAL','2026-08-27','Zi Vital philosophy, domains, approaches, related treatments/products, profiles and process logic','Source language is preserved conceptually; clinical claims remain governed by risk level.'),
('ZV_PATIENT_PROCESS_2026','Proceso Atención Zi Vital','INTERNAL_PDF','PROCESO_ATENCIN_ZI_VITAL.pdf','AUTHORITATIVE_INTERNAL','2026-08-27','Patient journey, roles, triage, consultation, quotation, consent, procedure and follow-up','Operational details are internal unless an explicit public summary is provided.')
on conflict(source_code) do update set title=excluded.title,version=excluded.version,source_scope=excluded.source_scope,notes=excluded.notes,updated_at=now();

-- SYSTEM / DOMAINS
insert into public.aos_knowledge_nodes_v1(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('ZV_SYSTEM','SYSTEM',null,'Sistema Zi Vital','["Arquitectura de Dominios y Enfoques"]',
 'Zi Vital organiza el cuidado por dominios y enfoques, buscando procesos coherentes en lugar de tratamientos aislados.',
 'Explica primero el proceso y la lógica del plan; evita presentar cada tratamiento como una solución aislada.',
 'Es la arquitectura madre para ordenar catálogo, experiencia, comunicación y futuras decisiones de producto/servicio.',
 null,
 '{"sequence":["PREPARAR","ACTIVAR","REGENERAR","MANTENER"],"domains":["FACIAL","CORPORAL","CAPILAR"],"cross_cutting":["DETOX","VITAMINAS"]}',
 array['zi vital','dominios','enfoques','preparar','activar','regenerar','mantener'],'LOW','ZV_DOMAINS_2026','PDF p.1-2; principle mother and domain/approach definitions','APPROVED',now()),
('DOMAIN_FACIAL','DOMAIN','ZV_SYSTEM','Dominio Facial','["Facial"]',
 'El Dominio Facial reúne los procesos relacionados con piel, expresión, presencia y armonía del rostro.',
 'Antes de recomendar, identifica si la conversación trata calidad de piel, armonía estructural o regeneración.',
 'Agrupa Skin Signature, Harmony Design y BioRegen Face; debe ser la capa superior de clasificación de servicios faciales.',
 'La definición del enfoque clínico final corresponde a evaluación profesional; el dominio no equivale a diagnóstico.',
 '{"approaches":["FACIAL_SKIN_SIGNATURE","FACIAL_HARMONY_DESIGN","FACIAL_BIOREGEN_FACE"]}',
 array['facial','rostro','piel','armonia','regeneracion'],'MEDIUM','ZV_DOMAINS_2026','PDF p.2-5; Dominio I Facial','APPROVED',now()),
('DOMAIN_CORPORAL','DOMAIN','ZV_SYSTEM','Dominio Corporal','["Corporal"]',
 'El Dominio Corporal organiza los procesos de preparación, contorno, reducción, firmeza y calidad del tejido corporal.',
 'Distingue preparación corporal, reducción/definición y proyección/firmeza; no vendas todos los procesos como reductores.',
 'Agrupa Body Reset, Sculpt Body y Sculpt Booty y permite ordenar el journey corporal por etapas.',
 'Las afirmaciones metabólicas, inflamatorias o de depuración del documento requieren validación clínica antes de comunicarse como hechos médicos.',
 '{"approaches":["CORPORAL_BODY_RESET","CORPORAL_SCULPT_BODY","CORPORAL_SCULPT_BOOTY"]}',
 array['corporal','cuerpo','reduccion','contorno','firmeza'],'CLINICAL_REVIEW_REQUIRED','ZV_DOMAINS_2026','PDF p.6-9; Dominio II Corporal','APPROVED',now()),
('DOMAIN_CAPILAR','DOMAIN','ZV_SYSTEM','Dominio Capilar','["Capilar"]',
 'El Dominio Capilar organiza el cuidado del cabello en activación/regeneración y mantenimiento/prevención.',
 'En conversaciones capilares distingue caída activa de mantenimiento; explica que el plan concreto depende de evaluación.',
 'Debe conectar servicios capilares, productos domiciliarios y continuidad; es un dominio de largo plazo.',
 'Los protocolos con minoxidil, dutasteride, PRP, exosomas o PDRN son conocimiento clínico restringido y no deben convertirse en prescripción autónoma.',
 '{"approaches":["CAPILAR_ACTIVACION_REGENERACION","CAPILAR_MANTENIMIENTO_PREVENCION"]}',
 array['capilar','cabello','caida','densidad','mantenimiento'],'CLINICAL_REVIEW_REQUIRED','ZV_DOMAINS_2026','PDF p.9-12; Dominio III Capilar','APPROVED',now())
on conflict(code) do update set public_client=excluded.public_client,advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,keywords=excluded.keywords,risk_level=excluded.risk_level,source_locator=excluded.source_locator,status='APPROVED',approved_at=now(),updated_at=now();

-- APPROACHES
insert into public.aos_knowledge_nodes_v1(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('FACIAL_SKIN_SIGNATURE','APPROACH','DOMAIN_FACIAL','Skin Signature','["Calidad Cutánea · Salud · Glow Consciente"]',
 'Skin Signature es el enfoque facial centrado en calidad de piel: hidratación, estabilidad, luminosidad y cuidado de la barrera cutánea.',
 'Úsalo para explicar procesos de calidad cutánea y mantenimiento. El documento lo relaciona con hidrofacial, peelings, Pink Glow, Dermapen y radiofrecuencia fraccionada.',
 'Es la entrada de calidad cutánea del Dominio Facial y una base para preparar o sostener otros procesos faciales.',
 'No asumir que un paciente pertenece a este enfoque solo por síntomas; si ya existe indicación médica, puede explicarse la relación.',
 '{"treatments":["Hidrofacial avanzado","Peelings médicos","Pink Glow","Dermapen con activos","Radiofrecuencia fraccionada"],"products":["Sensiclean","UltraGlow","Hydrashield","Regushield","Sensishield","SkinRegeneration","Beauty Maker","Astaxantina","Power 10 Soak Up Helper","Power 10 Firefighter","Power 10 Pore Lupin","Power 10 Cera Guard","Ultra Eyes","Serum Acne Control"]}',
 array['skin signature','calidad de piel','glow','hidrofacial','pink glow','dermapen'],'MEDIUM','ZV_DOMAINS_2026','PDF p.2-3; Enfoque Facial 1','APPROVED',now()),
('FACIAL_HARMONY_DESIGN','APPROACH','DOMAIN_FACIAL','Harmony Design','["Equilibrio Estructural · Expresión · Soporte"]',
 'Harmony Design es el enfoque facial orientado a equilibrio estructural y expresión, buscando cambios moderados y naturales.',
 'Relaciona este enfoque con ácido hialurónico, perfilamiento, labios, toxina, HIFU facial y enzimas faciales según evaluación.',
 'Es la capa de diseño estructural del Dominio Facial; su narrativa diferencial es criterio y moderación, no volumen excesivo.',
 'La selección de puntos, materiales y procedimiento es médica; el bot/asesor no debe prescribir ni diseñar el plan.',
 '{"treatments":["Ácido hialurónico","Perfilamiento facial y nasal","Labios","Toxina botulínica","HIFU facial","Enzimas faciales"],"products":["Lifting B","Hydrashield","Regushield","Sensishield","Perfect Form F","Redu Fast","Zinc Premium","Lip Balm","Beauty Maker","Astaxantina","Neuro Vital"]}',
 array['harmony design','armonia facial','perfilamiento','labios','toxina','hifu'],'HIGH','ZV_DOMAINS_2026','PDF p.3-4; Enfoque Facial 2','APPROVED',now()),
('FACIAL_BIOREGEN_FACE','APPROACH','DOMAIN_FACIAL','BioRegen Face','["Regeneración · Longevidad · Sostén Biológico"]',
 'BioRegen Face es el enfoque facial de regeneración progresiva y sostén biológico, priorizando resultados naturales y de largo plazo.',
 'El documento lo relaciona con bioestimuladores, exosomas, PDRN/polinucleótidos, PRP e hidrataciones profundas.',
 'Es la propuesta regenerativa profunda del Dominio Facial y un eje de diferenciación frente a una estética centrada solo en relleno.',
 'Bioestimuladores, PDRN, exosomas y PRP requieren criterio clínico. Evitar promesas de regeneración garantizada.',
 '{"treatments":["Bioestimuladores de colágeno","Exosomas","Polinucleótidos / PDRN","PRP","Hidrataciones profundas con AH"],"products":["Beauty Maker","Neuro Vital","Astaxantina","Hydrashield","Regushield","Sensishield","SkinRegeneration","UltraGlow"]}',
 array['bioregen face','regeneracion','bioestimulador','exosomas','pdrn','prp'],'CLINICAL_REVIEW_REQUIRED','ZV_DOMAINS_2026','PDF p.5-6; Enfoque Facial 3','APPROVED',now()),
('CORPORAL_BODY_RESET','APPROACH','DOMAIN_CORPORAL','Body Reset','["Limpieza · Descarga · Preparación Metabólica"]',
 'Body Reset es el enfoque de preparación corporal de Zi Vital antes de procesos de reducción o remodelación.',
 'Preséntalo como fase de preparación y acompañamiento; el documento lo relaciona con detox iónico, vitaminas, drenaje y ondas rusas.',
 'Funciona como punto de entrada del Dominio Corporal dentro de la secuencia propuesta por el documento.',
 'El PDF usa lenguaje de “depurar”, “toxinas” e inflamación. Esas afirmaciones no deben comunicarse como hechos médicos sin revisión clínica; Detox iónico no debe presentarse como extracción demostrada de toxinas.',
 '{"treatments":["Detox iónico","Vitaminas endovenosas","Drenaje linfático manual","Ondas rusas"],"products":["Redu Fast","Astaxantina","Perfect Form B","Prunex"]}',
 array['body reset','detox','preparacion corporal','drenaje','ondas rusas'],'CLINICAL_REVIEW_REQUIRED','ZV_DOMAINS_2026','PDF p.6-7; Enfoque Corporal 1','APPROVED',now()),
('CORPORAL_SCULPT_BODY','APPROACH','DOMAIN_CORPORAL','Sculpt Body','["Contour Sculpt","Reducción · Definición · Contorno Inteligente"]',
 'Sculpt Body es el enfoque corporal para reducción localizada y definición de contorno dentro de un plan progresivo.',
 'El documento lo relaciona con criolipólisis, enzimas, HIFU corporal, radiofrecuencia, vitaminas, detox de apoyo y drenajes.',
 'Es la capa de reducción/definición del Dominio Corporal y sucede conceptualmente después de la preparación.',
 'La indicación y expectativas de reducción dependen de evaluación. No prometer medidas, velocidad ni ausencia de rebote.',
 '{"treatments":["Criolipólisis","Enzimas recombinantes","HIFU corporal","Radiofrecuencia corporal","Vitaminas","Detox","Drenaje linfático","Ondas rusas"],"products":["Beauty Maker","Neuro Vital","Redu Fast","Astaxantina","Perfect Form B","Prunex"]}',
 array['sculpt body','contour sculpt','reduccion','criolipolisis','hifu corporal','enzimas'],'HIGH','ZV_DOMAINS_2026','PDF p.7-8; Enfoque Corporal 2','APPROVED',now()),
('CORPORAL_SCULPT_BOOTY','APPROACH','DOMAIN_CORPORAL','Sculpt Booty','["Volume & Firm","Proyección · Firmeza · Calidad de Tejido"]',
 'Sculpt Booty es el enfoque corporal de proyección, firmeza y calidad del tejido, especialmente asociado a glúteos y zonas con flacidez o estrías.',
 'El documento lo relaciona con ácido hialurónico corporal, bioestimuladores, enzimas para estrías, peptonas y radiofrecuencia.',
 'Es la capa de proyección/firmeza del Dominio Corporal y debe diferenciarse de un enfoque puramente reductor.',
 'Volumen, material e indicación son decisiones clínicas. Evitar promesas de forma o volumen garantizado.',
 '{"treatments":["Ácido hialurónico corporal","Bioestimuladores corporales","Enzimas para estrías","Peptonas","Radiofrecuencia corporal"],"products":["Beauty Maker","Neuro Vital","Astaxantina"]}',
 array['sculpt booty','volume firm','gluteos','firmeza','bioestimuladores','peptonas'],'HIGH','ZV_DOMAINS_2026','PDF p.8-9; Enfoque Corporal 3','APPROVED',now()),
('CAPILAR_ACTIVACION_REGENERACION','APPROACH','DOMAIN_CAPILAR','Activación & Regeneración','["Hair Revival","Activación · Regeneración · Reinicio Folicular"]',
 'Es el enfoque capilar para pacientes cuyo plan busca trabajar caída activa, adelgazamiento o pérdida de densidad. La elección del protocolo corresponde a evaluación médica.',
 'Explícalo como proceso estructurado y de constancia. El documento lo relaciona con RF capilar, mesoterapia, PRP, exosomas, PDRN y productos domiciliarios.',
 'Es la etapa activa del Dominio Capilar y debe conectarse con productos de continuidad y controles.',
 'El documento enumera minoxidil, dutasteride, PRP, exosomas y PDRN. Son elementos clínicos restringidos; no prescribir ni recomendar dosis desde IA.',
 '{"treatments":["Radiofrecuencia capilar","Mesoterapia capilar","PRP capilar","Exosomas capilares","PDRN / polinucleótidos"],"products":["Minoxidil tópico","Shampoo anticaída","Cápsulas de soporte capilar","Beauty Maker","Neuro Vital"]}',
 array['hair revival','activacion capilar','regeneracion capilar','caida','mesoterapia','prp capilar'],'CLINICAL_REVIEW_REQUIRED','ZV_DOMAINS_2026','PDF p.10-11; Enfoque Capilar 1','APPROVED',now()),
('CAPILAR_MANTENIMIENTO_PREVENCION','APPROACH','DOMAIN_CAPILAR','Mantenimiento & Prevención','["Hair Guard","Mantenimiento · Prevención · Protección a Largo Plazo"]',
 'Es el enfoque capilar para proteger resultados y sostener una rutina de mantenimiento o prevención a largo plazo.',
 'Úsalo cuando el paciente ya pasó por una fase activa o cuando el plan médico es preventivo; refuerza seguimiento y constancia.',
 'Es la etapa de continuidad del Dominio Capilar; productos domiciliarios y controles toman un papel central.',
 'Los ajustes de protocolo por hormonas, estrés o medicación corresponden a evaluación clínica, no a decisión autónoma de IA.',
 '{"treatments":["RF capilar de mantenimiento","Mesoterapia de refuerzo","Controles médicos"],"products":["Shampoo preventivo","Spray fortalecedor","Cápsulas de mantenimiento","Beauty Maker","Vitaminas de soporte"]}',
 array['hair guard','mantenimiento capilar','prevencion capilar','control capilar'],'HIGH','ZV_DOMAINS_2026','PDF p.11-12; Enfoque Capilar 2','APPROVED',now())
on conflict(code) do update set title=excluded.title,aliases=excluded.aliases,public_client=excluded.public_client,advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,keywords=excluded.keywords,risk_level=excluded.risk_level,source_locator=excluded.source_locator,status='APPROVED',approved_at=now(),updated_at=now();

-- PATIENT JOURNEY + ROLES
insert into public.aos_knowledge_nodes_v1(code,node_type,parent_code,title,aliases,public_client,advisor_internal,owner_admin,clinical_restricted,system_reference,keywords,risk_level,source_code,source_locator,status,approved_at)
values
('ZV_PATIENT_JOURNEY','PATIENT_JOURNEY','ZV_SYSTEM','Proceso de Atención Zi Vital','["Patient Journey Zi Vital"]',
 'La atención Zi Vital busca comprender primero el caso, explicar el proceso, realizar la evaluación médica y acompañar los siguientes pasos sin presión.',
 'Identifica en qué fase está la persona antes de responder o intentar cerrar: recepción, triaje, preconsulta, consulta, plan, procedimiento o seguimiento.',
 'El journey distribuye funciones clínicas, emocionales, comerciales y legales; debe gobernar automatizaciones y playbooks.',
 'La IA puede explicar el proceso, pero no sustituye triaje, diagnóstico, consentimiento ni ejecución clínica.',
 '{"phases":["PHASE_1_RECEPCION","PHASE_2_TRIAJE","PHASE_3_PRECONSULTA","PHASE_4_CONSULTA_MEDICA","PHASE_5_PLAN_COTIZACION","PHASE_6_CONSENTIMIENTO_PROCEDIMIENTO","PHASE_7_CIERRE_SEGUIMIENTO"]}',
 array['proceso de atencion','patient journey','recepcion','triaje','consulta','seguimiento'],'MEDIUM','ZV_PATIENT_PROCESS_2026','PDF p.1-8; complete patient process','APPROVED',now()),
('ROLE_RECEPCIONISTA','ROLE','ZV_PATIENT_JOURNEY','Recepcionista','["Recepción"]',null,
 'Responsable de orden, apertura, contención inicial, aterrizaje del plan y cierre según el documento.',
 'Rol operativo de apertura/cierre y puente comercial; no debe invadir criterio clínico.',null,
 '{"responsibilities":["apertura","filiacion","coordinacion","cotizacion","cierre"]}',array['recepcionista','recepcion'],'LOW','ZV_PATIENT_PROCESS_2026','PDF p.1; roles','APPROVED',now()),
('ROLE_ENFERMERIA','ROLE','ZV_PATIENT_JOURNEY','Enfermería','["Enfermera"]',null,
 'Responsable de triaje, educación, preparación, acompañamiento y ejecución dentro de su competencia.',
 'Rol de escucha estructurada y preparación; no debe convertir el triaje en venta.',
 'Signos vitales, condiciones médicas y preparación clínica son información restringida y deben manejarse con privacidad.',
 '{"responsibilities":["triaje","educacion","preparacion","acompanamiento"]}',array['enfermeria','triaje'],'HIGH','ZV_PATIENT_PROCESS_2026','PDF p.1-3; roles and triage','APPROVED',now()),
('ROLE_DOCTORA','ROLE','ZV_PATIENT_JOURNEY','Doctora','["Médica","Doctora Zi Vital"]',
 'La doctora realiza la evaluación clínica y define el plan de trabajo según cada caso.',
 'La recomendación clínica y la definición del plan pertenecen a la doctora; el asesor explica y acompaña, no diagnostica.',
 'Es la autoridad de diagnóstico, criterio clínico, diseño del plan y validación médica.',
 'Diagnóstico, indicación, prescripción y validación médica son funciones no delegables al bot.',
 '{"responsibilities":["diagnostico","criterio clinico","plan","validacion medica"]}',array['doctora','medica','consulta medica'],'CLINICAL_REVIEW_REQUIRED','ZV_PATIENT_PROCESS_2026','PDF p.1 and p.4-5; roles and consultation','APPROVED',now()),
('PHASE_1_RECEPCION','PHASE','ZV_PATIENT_JOURNEY','Fase 1 — Recepción y apertura formal','[]',
 'La primera etapa ordena el ingreso y abre formalmente el caso antes de continuar.',
 'Recepción solicita filiación e identificación y completa la apertura del caso según protocolo.',
 'Construye confianza y seriedad; el documento exige completar esta fase antes de continuar.',
 'Datos personales, médicos, DNI e historia clínica son información privada; nunca exponerlos en conocimiento público.',
 '{"responsible_role":"ROLE_RECEPCIONISTA","builds":"confianza + seriedad"}',array['fase 1','recepcion','apertura'],'HIGH','ZV_PATIENT_PROCESS_2026','PDF p.1-2; Fase 1','APPROVED',now()),
('PHASE_2_TRIAJE','PHASE','ZV_PATIENT_JOURNEY','Fase 2 — Triaje consciente','[]',
 'El triaje busca comprender el contexto del paciente antes de la consulta médica.',
 'Se realiza como conversación estructurada, no como venta. Incluye motivación, experiencia previa, expectativas, temores, antecedentes relevantes y contexto de inversión.',
 'Reduce venta apresurada y mejora la calidad de la consulta al llevar contexto estructurado a la doctora.',
 'Condiciones médicas, alergias, tratamientos actuales, signos vitales y demás datos de salud son restringidos; la IA no debe almacenarlos o exponerlos fuera del flujo autorizado.',
 '{"responsible_role":"ROLE_ENFERMERIA","builds":"vinculo + comprension","triage_questions":10}',array['fase 2','triaje','preguntas triaje'],'CLINICAL_REVIEW_REQUIRED','ZV_PATIENT_PROCESS_2026','PDF p.2-3; Fase 2 and 10 mandatory questions','APPROVED',now()),
('PHASE_3_PRECONSULTA','PHASE','ZV_PATIENT_JOURNEY','Fase 3 — Explicación previa del proceso y enfoques','["Pre-consulta"]',
 'Antes de la consulta se explica que Zi Vital trabaja por enfoques y planes, que la doctora recomienda y que el paciente decide cómo avanzar.',
 'Usa esta fase para reducir ansiedad y evitar la sensación de venta forzada. No prometas que todo se realizará el mismo día.',
 'Prepara mentalmente al paciente y aumenta comprensión del modelo de dominios/enfoques antes de la consulta.',null,
 '{"builds":"relajacion mental","avoids":"miedo a venta"}',array['fase 3','preconsulta','explicacion de enfoques'],'LOW','ZV_PATIENT_PROCESS_2026','PDF p.4; Fase 3','APPROVED',now()),
('PHASE_4_CONSULTA_MEDICA','PHASE','ZV_PATIENT_JOURNEY','Fase 4 — Consulta médica personalizada','[]',
 'En consulta, la doctora evalúa el caso y diseña un plan con enfoque, fases, tiempos y prioridades.',
 'El asesor puede explicar un plan ya indicado, pero no debe anticipar cuál será la indicación médica.',
 'Es el punto de autoridad clínica del journey; separa recomendación médica de cierre comercial.',
 'Diagnóstico, evaluación de piel/cuerpo/cuero cabelludo e indicación pertenecen a la doctora.',
 '{"responsible_role":"ROLE_DOCTORA","builds":"autoridad real"}',array['fase 4','consulta medica','plan medico'],'CLINICAL_REVIEW_REQUIRED','ZV_PATIENT_PROCESS_2026','PDF p.4-5; Fase 4','APPROVED',now()),
('PHASE_5_PLAN_COTIZACION','PHASE','ZV_PATIENT_JOURNEY','Fase 5 — Aterrizaje del plan, cotización y decisión','[]',
 'Después de la recomendación médica se explica el plan, sus etapas, valor y opciones, sin presionar la decisión.',
 'Traduce el plan médico a pasos comprensibles y opciones de pago. Explica proceso antes que solo costo.',
 'Construye valor percibido y reduce choque por precio; la venta debe mantenerse separada de la autoridad médica.',null,
 '{"responsible_role":"ROLE_RECEPCIONISTA","builds":"valor percibido","principle":"acompanar, no presionar"}',array['fase 5','cotizacion','plan','precio'],'LOW','ZV_PATIENT_PROCESS_2026','PDF p.5; Fase 5','APPROVED',now()),
('PHASE_6_CONSENTIMIENTO_PROCEDIMIENTO','PHASE','ZV_PATIENT_JOURNEY','Fase 6 — Consentimientos, preparación y procedimiento','[]',
 'Antes del procedimiento se completan los consentimientos, se prepara al paciente y se explica qué puede esperar durante la atención.',
 'El documento permite educación y upselling consciente durante el procedimiento, pero lo define como información complementaria, no presión de cierre.',
 'Concentra seguridad legal, preparación, ejecución, educación y registro fotográfico clínico.',
 'Consentimientos, preparación clínica, ejecución y fotografías son flujos sensibles. La IA no debe sustituir consentimiento informado ni instrucciones profesionales.',
 '{"steps":["consentimiento","preparacion","procedimiento","educacion","registro fotografico"],"principle":"sembrar, no cerrar"}',array['fase 6','consentimiento','procedimiento','preparacion'],'CLINICAL_REVIEW_REQUIRED','ZV_PATIENT_PROCESS_2026','PDF p.5-7; Fase 6','APPROVED',now()),
('PHASE_7_CIERRE_SEGUIMIENTO','PHASE','ZV_PATIENT_JOURNEY','Fase 7 — Cierre, seguimiento y despedida','[]',
 'El cierre busca dejar claro el siguiente paso y mantener continuidad del proceso.',
 'Programa próximas sesiones cuando corresponda, explica productos complementarios y cierra con claridad y acompañamiento.',
 'Convierte una atención puntual en continuidad organizada sin forzar ventas.',null,
 '{"builds":"continuidad","actions":["siguientes sesiones","productos complementarios","cierre"]}',array['fase 7','seguimiento','cierre','continuidad'],'LOW','ZV_PATIENT_PROCESS_2026','PDF p.7-8; Fase 7 and strategic table','APPROVED',now())
on conflict(code) do update set title=excluded.title,aliases=excluded.aliases,public_client=excluded.public_client,advisor_internal=excluded.advisor_internal,owner_admin=excluded.owner_admin,clinical_restricted=excluded.clinical_restricted,system_reference=excluded.system_reference,keywords=excluded.keywords,risk_level=excluded.risk_level,source_locator=excluded.source_locator,status='APPROVED',approved_at=now(),updated_at=now();

-- Structural knowledge relations.
insert into public.aos_knowledge_relations_v1(knowledge_code,relation_type,target_type,target_key,relation_scope,source_locator)
values
('DOMAIN_FACIAL','CHILD_OF','KNOWLEDGE','ZV_SYSTEM','PUBLIC','Domains PDF p.1-2'),
('FACIAL_SKIN_SIGNATURE','CHILD_OF','KNOWLEDGE','DOMAIN_FACIAL','PUBLIC','Domains PDF p.2-3'),
('FACIAL_HARMONY_DESIGN','CHILD_OF','KNOWLEDGE','DOMAIN_FACIAL','PUBLIC','Domains PDF p.3-4'),
('FACIAL_BIOREGEN_FACE','CHILD_OF','KNOWLEDGE','DOMAIN_FACIAL','PUBLIC','Domains PDF p.5'),
('DOMAIN_CORPORAL','CHILD_OF','KNOWLEDGE','ZV_SYSTEM','PUBLIC','Domains PDF p.6'),
('CORPORAL_BODY_RESET','CHILD_OF','KNOWLEDGE','DOMAIN_CORPORAL','PUBLIC','Domains PDF p.6-7'),
('CORPORAL_SCULPT_BODY','CHILD_OF','KNOWLEDGE','DOMAIN_CORPORAL','PUBLIC','Domains PDF p.7-8'),
('CORPORAL_SCULPT_BOOTY','CHILD_OF','KNOWLEDGE','DOMAIN_CORPORAL','PUBLIC','Domains PDF p.8-9'),
('DOMAIN_CAPILAR','CHILD_OF','KNOWLEDGE','ZV_SYSTEM','PUBLIC','Domains PDF p.9'),
('CAPILAR_ACTIVACION_REGENERACION','CHILD_OF','KNOWLEDGE','DOMAIN_CAPILAR','PUBLIC','Domains PDF p.10-11'),
('CAPILAR_MANTENIMIENTO_PREVENCION','CHILD_OF','KNOWLEDGE','DOMAIN_CAPILAR','PUBLIC','Domains PDF p.11-12'),
('CAPILAR_ACTIVACION_REGENERACION','NEXT_APPROACH','KNOWLEDGE','CAPILAR_MANTENIMIENTO_PREVENCION','REFERENCE','Domains PDF p.10-12'),
('ZV_PATIENT_JOURNEY','CHILD_OF','KNOWLEDGE','ZV_SYSTEM','PUBLIC','Process PDF p.1'),
('PHASE_1_RECEPCION','RESPONSIBLE_ROLE','ROLE','ROLE_RECEPCIONISTA','INTERNAL','Process PDF p.1-2'),
('PHASE_2_TRIAJE','RESPONSIBLE_ROLE','ROLE','ROLE_ENFERMERIA','INTERNAL','Process PDF p.2-3'),
('PHASE_4_CONSULTA_MEDICA','RESPONSIBLE_ROLE','ROLE','ROLE_DOCTORA','INTERNAL','Process PDF p.4-5'),
('PHASE_5_PLAN_COTIZACION','RESPONSIBLE_ROLE','ROLE','ROLE_RECEPCIONISTA','INTERNAL','Process PDF p.5')
on conflict do nothing;

-- Resolve a safe subset of exact catalog links already present in the canonical catalog.
insert into public.aos_knowledge_relations_v1(knowledge_code,relation_type,target_type,target_key,target_id,relation_scope,source_locator)
select 'FACIAL_SKIN_SIGNATURE','RELATED_SERVICE','SERVICE',s.nombre,s.id,'REFERENCE','Domains PDF p.2-3'
from public.aos_catalogo_servicios s where s.estado='ACTIVO' and s.tipo='SERVICIO' and s.nombre in ('PINK GLOW 1ML','HIDROFACIAL PREMIUM','HIDROFACIAL ROSTRO','RF FRACCIONADA ROSTRO/CUELLO x1','DERMAPEN VIT FACIAL x1')
on conflict do nothing;
insert into public.aos_knowledge_relations_v1(knowledge_code,relation_type,target_type,target_key,target_id,relation_scope,source_locator)
select 'CAPILAR_ACTIVACION_REGENERACION','RELATED_SERVICE','SERVICE',s.nombre,s.id,'CLINICAL','Domains PDF p.10-11'
from public.aos_catalogo_servicios s where s.estado='ACTIVO' and s.tipo='SERVICIO' and s.nombre in ('MESO CAPILAR MINOXIDIL','DUTASTERIDE CAPILAR x1','PRP CAPILAR x1','EXOSOMAS EXOSIGNAL HAIR x1','RF FRACCIONADA CAPILAR x1')
on conflict do nothing;
insert into public.aos_knowledge_relations_v1(knowledge_code,relation_type,target_type,target_key,target_id,relation_scope,source_locator)
select 'CORPORAL_BODY_RESET','RELATED_SERVICE','SERVICE',s.nombre,s.id,'REFERENCE','Domains PDF p.6-7'
from public.aos_catalogo_servicios s where s.estado='ACTIVO' and s.tipo='SERVICIO' and s.nombre in ('DETOX IÓNICO')
on conflict do nothing;
insert into public.aos_knowledge_relations_v1(knowledge_code,relation_type,target_type,target_key,target_id,relation_scope,source_locator)
select 'CORPORAL_SCULPT_BODY','RELATED_SERVICE','SERVICE',s.nombre,s.id,'REFERENCE','Domains PDF p.7-8'
from public.aos_catalogo_servicios s where s.estado='ACTIVO' and s.tipo='SERVICIO' and s.nombre in ('CRIOLIPÓLISIS 1 ZONA','HIFU CORP ABDOMEN ALTO','ENZIMAS CORP ABDOMEN/GLÚTEOS x1')
on conflict do nothing;

-- Audience-safe projection: only one audience text is exposed per call.
create or replace function public.aos_wa4a_knowledge_search_v2(
  p_query text,
  p_audience text default 'PUBLIC_CLIENT',
  p_limit integer default 12,
  p_domains text[] default null
)
returns table(
  knowledge_id text,
  domain text,
  subject_type text,
  subject_id text,
  title text,
  facts jsonb,
  authority_tier smallint,
  source_relation text,
  source_pk text,
  source_updated_at timestamptz,
  freshness_state text,
  conflict_state text,
  retrieval_state text,
  evidence_ref jsonb,
  score integer
)
language sql
stable
security definer
set search_path='public'
as $$
with params as (
  select trim(coalesce(p_query,'')) q,
         upper(coalesce(p_audience,'PUBLIC_CLIENT')) audience,
         greatest(1,least(coalesce(p_limit,12),24)) lim
),
base as (
  select b.* from params p
  cross join lateral public.aos_wa4a_knowledge_search_v1(p.q,p.lim,p_domains) b
  where p_domains is null or b.domain=any(p_domains)
),
clinic as (
  select
    'clinic:'||n.code as knowledge_id,
    'CLINIC_KNOWLEDGE'::text as domain,
    n.node_type::text as subject_type,
    n.code::text as subject_id,
    n.title::text,
    jsonb_strip_nulls(jsonb_build_object(
      'code',n.code,
      'node_type',n.node_type,
      'parent_code',n.parent_code,
      'title',n.title,
      'aliases',n.aliases,
      'answer',case p.audience
        when 'PUBLIC_CLIENT' then n.public_client
        when 'ADVISOR_INTERNAL' then n.advisor_internal
        when 'OWNER_ADMIN' then n.owner_admin
        when 'CLINICAL_RESTRICTED' then n.clinical_restricted
        when 'SYSTEM_REFERENCE' then coalesce(n.owner_admin,n.advisor_internal,n.public_client)
        else null end,
      'public_summary',case when p.audience in ('ADVISOR_INTERNAL','OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE') then n.public_client else null end,
      'system_reference',case when p.audience in ('OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE') then n.system_reference else null end,
      'risk_level',n.risk_level,
      'audience',p.audience
    )) as facts,
    15::smallint as authority_tier,
    'public.aos_knowledge_nodes_v1'::text as source_relation,
    n.code::text as source_pk,
    n.updated_at as source_updated_at,
    'GOVERNED'::text as freshness_state,
    'CLEAR'::text as conflict_state,
    case
      when n.status<>'APPROVED' then 'BLOCKED_UNAPPROVED'
      when (case p.audience when 'PUBLIC_CLIENT' then n.public_client when 'ADVISOR_INTERNAL' then n.advisor_internal when 'OWNER_ADMIN' then n.owner_admin when 'CLINICAL_RESTRICTED' then n.clinical_restricted when 'SYSTEM_REFERENCE' then coalesce(n.owner_admin,n.advisor_internal,n.public_client) else null end) is null then 'BLOCKED_AUDIENCE'
      else 'READY'
    end::text as retrieval_state,
    jsonb_build_object('relation','public.aos_knowledge_nodes_v1','pk',n.code,'version',n.version::text,'source_code',n.source_code,'source_locator',n.source_locator,'audience',p.audience) as evidence_ref,
    (case
      when public.aos_wa4a_norm_v1(n.title)=public.aos_wa4a_norm_v1(p.q) then 140
      when public.aos_wa4a_norm_v1(n.title) like '%'||public.aos_wa4a_norm_v1(p.q)||'%' then 110
      when public.aos_wa4a_norm_v1(n.aliases::text) like '%'||public.aos_wa4a_norm_v1(p.q)||'%' then 90
      when public.aos_wa4a_norm_v1(array_to_string(n.keywords,' ')) like '%'||public.aos_wa4a_norm_v1(p.q)||'%' then 80
      when public.aos_wa4a_norm_v1(concat_ws(' ',n.public_client,n.advisor_internal,n.owner_admin,n.clinical_restricted)) like '%'||public.aos_wa4a_norm_v1(p.q)||'%' then 60
      else 10 end)::integer as score
  from public.aos_knowledge_nodes_v1 n cross join params p
  where n.status='APPROVED'
    and (p_domains is null or 'CLINIC_KNOWLEDGE'=any(p_domains))
    and (p.q='' or public.aos_wa4a_norm_v1(concat_ws(' ',n.title,n.aliases::text,array_to_string(n.keywords,' '),n.public_client,n.advisor_internal,n.owner_admin,n.clinical_restricted)) like '%'||public.aos_wa4a_norm_v1(p.q)||'%')
),
all_rows as (
  select * from base
  union all
  select * from clinic where retrieval_state='READY'
)
select * from all_rows order by score desc,authority_tier asc,title limit (select lim from params);
$$;

revoke all on function public.aos_wa4a_knowledge_search_v2(text,text,integer,text[]) from public,anon,authenticated;
grant execute on function public.aos_wa4a_knowledge_search_v2(text,text,integer,text[]) to service_role;

commit;
