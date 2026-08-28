-- ASCENDA OS — WA-4A.1 Zi Vital Governed Knowledge V1
-- TEST-first / PROD-ready. Do not apply to production while WA-4A PROD migration remains unapplied.
-- Source material: two user-provided Zi Vital PDFs, transformed into audience-separated governed knowledge.
begin;

do $$
begin
  if to_regprocedure('public.aos_wa4a_norm_v1(text)') is null then
    raise exception 'WA4A1_REQUIRES_WA4A_KNOWLEDGE_FABRIC';
  end if;
  if to_regclass('public.aos_catalogo_servicios') is null then
    raise exception 'WA4A1_SOURCE_REQUIRED:aos_catalogo_servicios';
  end if;
end
$$;

create table if not exists public.aos_zi_knowledge_sources_v1 (
  source_key text primary key,
  title text not null,
  source_type text not null check (source_type in ('USER_PDF','GOVERNED_INTERNAL_DOC')),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  page_count integer not null check (page_count > 0),
  description text,
  approval_state text not null default 'APPROVED' check (approval_state in ('DRAFT','APPROVED','RETIRED')),
  source_version text not null default '2026-08-27',
  ingested_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_zi_knowledge_entities_v1 (
  entity_key text primary key,
  entity_type text not null check (entity_type in ('SYSTEM','PRINCIPLE','CROSS_LAYER','DOMAIN','APPROACH','PROCESS','ROLE','CARE_PHASE','CARE_SUBPHASE')),
  canonical_name text not null,
  aliases text[] not null default '{}',
  parent_entity_key text references public.aos_zi_knowledge_entities_v1(entity_key) on update cascade on delete restrict,
  source_key text not null references public.aos_zi_knowledge_sources_v1(source_key) on update cascade on delete restrict,
  page_start integer not null check (page_start > 0),
  page_end integer not null check (page_end >= page_start),
  canonical_summary text not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','REVIEW','RETIRED')),
  version text not null default 'ZI_KNOWLEDGE_V1_20260827',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aos_zi_knowledge_blocks_v1 (
  block_key text primary key,
  entity_key text not null references public.aos_zi_knowledge_entities_v1(entity_key) on update cascade on delete cascade,
  audience text not null check (audience in ('PUBLIC_CLIENT','ADVISOR_INTERNAL','OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE')),
  block_type text not null,
  content text not null check (length(trim(content)) > 0),
  payload jsonb not null default '{}'::jsonb,
  risk_level text not null default 'LOW' check (risk_level in ('LOW','MEDIUM','HIGH')),
  answerable boolean not null default true,
  requires_human boolean not null default false,
  source_key text not null references public.aos_zi_knowledge_sources_v1(source_key) on update cascade on delete restrict,
  page_start integer not null check (page_start > 0),
  page_end integer not null check (page_end >= page_start),
  status text not null default 'APPROVED' check (status in ('DRAFT','APPROVED','RETIRED')),
  version text not null default 'ZI_KNOWLEDGE_V1_20260827',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aos_zi_knowledge_blocks_audience_idx
  on public.aos_zi_knowledge_blocks_v1(audience,status,entity_key);

create table if not exists public.aos_zi_knowledge_catalog_rules_v1 (
  rule_key text primary key,
  entity_key text not null references public.aos_zi_knowledge_entities_v1(entity_key) on update cascade on delete cascade,
  catalog_type text not null check (catalog_type in ('SERVICIO','PRODUCTO')),
  relation_kind text not null check (relation_kind in ('TREATMENT_KEY','RELATED_PRODUCT')),
  match_kind text not null check (match_kind in ('EXACT','PREFIX','CONTAINS','CATEGORY')),
  match_value text not null,
  source_label text not null,
  visibility text[] not null default array['PUBLIC_CLIENT','ADVISOR_INTERNAL','OWNER_ADMIN','SYSTEM_REFERENCE']::text[],
  source_key text not null references public.aos_zi_knowledge_sources_v1(source_key) on update cascade on delete restrict,
  page_start integer not null check (page_start > 0),
  page_end integer not null check (page_end >= page_start),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','REVIEW','RETIRED')),
  version text not null default 'ZI_KNOWLEDGE_V1_20260827',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace view public.aos_zi_knowledge_catalog_links_v1
with (security_invoker=true)
as
select
  r.rule_key,
  r.entity_key,
  r.catalog_type,
  r.relation_kind,
  r.source_label,
  r.match_kind,
  r.match_value,
  r.visibility,
  s.id::text as catalog_id,
  s.nombre as catalog_name,
  s.categoria as catalog_category,
  s.estado as catalog_state,
  case when s.id is null then 'UNRESOLVED_SOURCE_LABEL' else 'RESOLVED_CANONICAL' end::text as resolution_state,
  jsonb_build_object(
    'source_key',r.source_key,'pages',jsonb_build_array(r.page_start,r.page_end),
    'rule_key',r.rule_key,'catalog_relation','public.aos_catalogo_servicios'
  ) as evidence_ref
from public.aos_zi_knowledge_catalog_rules_v1 r
left join public.aos_catalogo_servicios s
  on upper(coalesce(s.tipo,''))=r.catalog_type
 and coalesce(s.estado,'ACTIVO')='ACTIVO'
 and (
   (r.match_kind='EXACT' and public.aos_wa4a_norm_v1(s.nombre)=public.aos_wa4a_norm_v1(r.match_value))
   or (r.match_kind='PREFIX' and public.aos_wa4a_norm_v1(s.nombre) like public.aos_wa4a_norm_v1(r.match_value)||'%')
   or (r.match_kind='CONTAINS' and public.aos_wa4a_norm_v1(s.nombre) like '%'||public.aos_wa4a_norm_v1(r.match_value)||'%')
   or (r.match_kind='CATEGORY' and public.aos_wa4a_norm_v1(s.categoria)=public.aos_wa4a_norm_v1(r.match_value))
 )
where r.status='ACTIVE';

create or replace view public.aos_wa4a1_zi_knowledge_items_v1
with (security_invoker=true)
as
select
  'zi:'||b.block_key as knowledge_id,
  'ZI_VITAL'::text as domain,
  e.entity_type as subject_type,
  e.entity_key as subject_id,
  public.aos_wa4a_norm_v1(e.canonical_name) as subject_key,
  e.canonical_name as title,
  concat_ws(' ',e.canonical_name,array_to_string(e.aliases,' '),e.canonical_summary,b.content,b.payload::text,
    coalesce((select string_agg(concat_ws(' ',l.source_label,l.catalog_name),' ')
              from public.aos_zi_knowledge_catalog_links_v1 l
              where l.entity_key=e.entity_key and b.audience=any(l.visibility)),'')
  ) as search_text,
  jsonb_build_object(
    'entity_key',e.entity_key,
    'entity_type',e.entity_type,
    'canonical_name',e.canonical_name,
    'aliases',to_jsonb(e.aliases),
    'parent_entity_key',e.parent_entity_key,
    'audience',b.audience,
    'block_type',b.block_type,
    'content',b.content,
    'payload',b.payload,
    'risk_level',b.risk_level,
    'answerable',b.answerable,
    'requires_human',b.requires_human,
    'related_catalog',coalesce((
      select jsonb_agg(jsonb_build_object(
        'relation_kind',l.relation_kind,'source_label',l.source_label,
        'catalog_id',l.catalog_id,'catalog_name',l.catalog_name,
        'catalog_type',l.catalog_type,'resolution_state',l.resolution_state
      ) order by l.relation_kind,l.source_label,l.catalog_name)
      from public.aos_zi_knowledge_catalog_links_v1 l
      where l.entity_key=e.entity_key and b.audience=any(l.visibility)
    ),'[]'::jsonb)
  ) as facts,
  15::smallint as authority_tier,
  'public.aos_zi_knowledge_blocks_v1'::text as source_relation,
  b.block_key as source_pk,
  b.updated_at as source_updated_at,
  null::timestamptz as valid_from,
  null::timestamptz as valid_to,
  'FRESH'::text as freshness_state,
  'CLEAR'::text as conflict_state,
  case
    when b.status<>'APPROVED' or e.status<>'ACTIVE' then 'BLOCKED_INACTIVE'
    when b.audience='PUBLIC_CLIENT' and (b.risk_level='HIGH' or b.answerable=false or b.requires_human=true) then 'BLOCKED_PUBLIC_SAFETY'
    else 'READY'
  end::text as retrieval_state,
  jsonb_build_object(
    'relation','public.aos_zi_knowledge_blocks_v1',
    'pk',b.block_key,
    'version',b.version,
    'source_key',b.source_key,
    'pages',jsonb_build_array(b.page_start,b.page_end),
    'sha256',src.sha256
  ) as evidence_ref
from public.aos_zi_knowledge_blocks_v1 b
join public.aos_zi_knowledge_entities_v1 e on e.entity_key=b.entity_key
join public.aos_zi_knowledge_sources_v1 src on src.source_key=b.source_key
where src.approval_state='APPROVED';

create or replace function public.aos_wa4a1_zi_knowledge_search_v1(
  p_query text,
  p_audience text,
  p_limit integer default 12
)
returns table (
  knowledge_id text,
  domain text,
  subject_type text,
  subject_id text,
  subject_key text,
  title text,
  facts jsonb,
  authority_tier smallint,
  source_relation text,
  source_pk text,
  source_updated_at timestamptz,
  valid_from timestamptz,
  valid_to timestamptz,
  freshness_state text,
  conflict_state text,
  retrieval_state text,
  evidence_ref jsonb,
  rank_score integer
)
language sql
stable
security definer
set search_path=''
as $$
  with q as (
    select public.aos_wa4a_norm_v1(coalesce(p_query,'')) as nq,
           upper(coalesce(p_audience,'')) as audience,
           greatest(1,least(coalesce(p_limit,12),24)) as lim
  ),
  eligible as (
    select i.*,
      (
        case
          when public.aos_wa4a_norm_v1(i.title)=q.nq and q.nq<>'' then 100
          when public.aos_wa4a_norm_v1(i.title) like '%'||q.nq||'%' and q.nq<>'' then 70
          when public.aos_wa4a_norm_v1(i.search_text) like '%'||q.nq||'%' and q.nq<>'' then 50
          when q.nq='' then 10
          else 0
        end
        + coalesce((
            select count(*)::integer * 10
            from regexp_split_to_table(q.nq,'\s+') tok
            where length(tok)>=3
              and public.aos_wa4a_norm_v1(i.search_text) like '%'||tok||'%'
          ),0)
      )::integer as rank_score
    from public.aos_wa4a1_zi_knowledge_items_v1 i
    cross join q
    where (i.facts->>'audience')=q.audience
      and i.retrieval_state='READY'
      and q.audience in ('PUBLIC_CLIENT','ADVISOR_INTERNAL','OWNER_ADMIN','CLINICAL_RESTRICTED','SYSTEM_REFERENCE')
  )
  select knowledge_id,domain,subject_type,subject_id,subject_key,title,facts,authority_tier,
         source_relation,source_pk,source_updated_at,valid_from,valid_to,freshness_state,
         conflict_state,retrieval_state,evidence_ref,rank_score
  from eligible,q
  where rank_score>0
  order by rank_score desc, authority_tier asc, title asc, knowledge_id asc
  limit (select lim from q);
$$;

revoke all on table public.aos_zi_knowledge_sources_v1 from public,anon,authenticated;
revoke all on table public.aos_zi_knowledge_entities_v1 from public,anon,authenticated;
revoke all on table public.aos_zi_knowledge_blocks_v1 from public,anon,authenticated;
revoke all on table public.aos_zi_knowledge_catalog_rules_v1 from public,anon,authenticated;
revoke all on table public.aos_zi_knowledge_catalog_links_v1 from public,anon,authenticated;
revoke all on table public.aos_wa4a1_zi_knowledge_items_v1 from public,anon,authenticated;
revoke all on function public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer) from public,anon,authenticated;

grant select on table public.aos_zi_knowledge_sources_v1 to service_role;
grant select on table public.aos_zi_knowledge_entities_v1 to service_role;
grant select on table public.aos_zi_knowledge_blocks_v1 to service_role;
grant select on table public.aos_zi_knowledge_catalog_rules_v1 to service_role;
grant select on table public.aos_zi_knowledge_catalog_links_v1 to service_role;
grant select on table public.aos_wa4a1_zi_knowledge_items_v1 to service_role;
grant execute on function public.aos_wa4a1_zi_knowledge_search_v1(text,text,integer) to service_role;

insert into public.aos_zi_knowledge_sources_v1(source_key,title,source_type,sha256,page_count,description,approval_state,source_version)
values ('ZI_DOMAINS_20260827','EL SISTEMA DE DOMINIOS ZI VITAL','USER_PDF','cbb2a3cf2ff0458203004d41522595d5322c30dc1d084eb4e9c4f591b81ad901',14,'Documento base aportado por dirección sobre principio madre, dominios, enfoques, tratamientos/productos relacionados, beneficios, perfiles, sesgos, procesos y tabla maestra.','APPROVED','2026-08-27')
on conflict (source_key) do update set title=excluded.title,sha256=excluded.sha256,page_count=excluded.page_count,description=excluded.description,approval_state=excluded.approval_state,updated_at=now();

insert into public.aos_zi_knowledge_sources_v1(source_key,title,source_type,sha256,page_count,description,approval_state,source_version)
values ('ZI_ATTENTION_20260827','PROCESO ATENCIÓN ZI VITAL','USER_PDF','ac9a61cfd19368a308f78e900b37108c24021ee419fe578cc7635f1000af3254',8,'Documento base de entrenamiento interno sobre roles, fases de atención, triaje, consulta, cotización, consentimientos, procedimiento, seguimiento y lectura estratégica.','APPROVED','2026-08-27')
on conflict (source_key) do update set title=excluded.title,sha256=excluded.sha256,page_count=excluded.page_count,description=excluded.description,approval_state=excluded.approval_state,updated_at=now();

insert into public.aos_zi_knowledge_entities_v1(entity_key,entity_type,canonical_name,aliases,parent_entity_key,source_key,page_start,page_end,canonical_summary,status,version) values
('ZI_SYSTEM','SYSTEM','Sistema Zi Vital','{}'::text[],null,'ZI_DOMAINS_20260827',1,14,'Arquitectura de cuidado estético consciente organizada por dominios y enfoques, con visión integral y de largo plazo.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('ZI_SEQUENCE','PRINCIPLE','Preparar · Activar · Regenerar · Mantener','{}'::text[],'ZI_SYSTEM','ZI_DOMAINS_20260827',1,14,'Secuencia transversal que sostiene la arquitectura Zi Vital.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('ZI_LAYER_DETOX','CROSS_LAYER','Detox','{}'::text[],'ZI_SYSTEM','ZI_DOMAINS_20260827',1,14,'Capa transversal descrita en el documento como preparación y soporte de los dominios.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('ZI_LAYER_VITAMINS','CROSS_LAYER','Vitaminas','{}'::text[],'ZI_SYSTEM','ZI_DOMAINS_20260827',1,14,'Capa transversal de soporte descrita como parte estructural del sistema.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('DOMAIN_FACIAL','DOMAIN','Dominio Facial',array['Facial']::text[],'ZI_SYSTEM','ZI_DOMAINS_20260827',2,5,'Imagen, presencia y armonía consciente; integra calidad cutánea, equilibrio estructural y regeneración.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('DOMAIN_CORPORAL','DOMAIN','Dominio Corporal',array['Corporal']::text[],'ZI_SYSTEM','ZI_DOMAINS_20260827',6,9,'Forma, contorno y reconfiguración consciente con preparación sistémica y trabajo del tejido.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('DOMAIN_CAPILAR','DOMAIN','Dominio Capilar',array['Capilar']::text[],'ZI_SYSTEM','ZI_DOMAINS_20260827',9,12,'Densidad, vitalidad y permanencia consciente con procesos prolongados, soporte sistémico y mantenimiento.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_SKIN_SIGNATURE','APPROACH','Skin Signature','{}'::text[],'DOMAIN_FACIAL','ZI_DOMAINS_20260827',2,3,'Enfoque facial orientado a calidad cutánea, salud, hidratación, densidad y luminosidad sin alterar estructuras.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_HARMONY_DESIGN','APPROACH','Harmony Design','{}'::text[],'DOMAIN_FACIAL','ZI_DOMAINS_20260827',3,4,'Enfoque facial de equilibrio estructural, expresión y soporte con criterio médico y moderación.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_BIOREGEN_FACE','APPROACH','BioRegen Face','{}'::text[],'DOMAIN_FACIAL','ZI_DOMAINS_20260827',5,5,'Enfoque facial de regeneración, longevidad y sostén biológico con resultados progresivos y naturales.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_BODY_RESET','APPROACH','Body Reset','{}'::text[],'DOMAIN_CORPORAL','ZI_DOMAINS_20260827',6,7,'Enfoque corporal de limpieza, descarga y preparación metabólica previo a reducción o remodelación.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_SCULPT_BODY','APPROACH','Sculpt Body',array['Contour Sculpt']::text[],'DOMAIN_CORPORAL','ZI_DOMAINS_20260827',7,8,'Enfoque corporal de reducción, definición y contorno inteligente tras la preparación del cuerpo.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_SCULPT_BOOTY','APPROACH','Sculpt Booty',array['Volume & Firm']::text[],'DOMAIN_CORPORAL','ZI_DOMAINS_20260827',8,9,'Enfoque corporal de proyección, firmeza y calidad de tejido, especialmente glúteos, flacidez y estrías.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_HAIR_REVIVAL','APPROACH','Activación & Regeneración',array['Hair Revival']::text[],'DOMAIN_CAPILAR','ZI_DOMAINS_20260827',10,11,'Enfoque capilar de intervención activa para caída, adelgazamiento o pérdida de densidad.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('APP_HAIR_GUARD','APPROACH','Mantenimiento & Prevención',array['Hair Guard']::text[],'DOMAIN_CAPILAR','ZI_DOMAINS_20260827',11,12,'Enfoque capilar de prevención, refuerzo y protección de resultados a largo plazo.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_PROCESS','PROCESS','Proceso de Atención Zi Vital','{}'::text[],'ZI_SYSTEM','ZI_ATTENTION_20260827',1,8,'Recorrido consciente y lineal que integra funciones clínicas, emocionales, comerciales y legales.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('ROLE_RECEPCION','ROLE','Recepcionista',array['Recepción']::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',1,8,'Rol de orden, apertura, contención inicial, aterrizaje del plan y cierre.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('ROLE_ENFERMERIA','ROLE','Enfermería','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',1,8,'Rol de triaje, educación, preparación, ejecución y acompañamiento.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('ROLE_DOCTORA','ROLE','Doctora','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',1,8,'Rol de diagnóstico, criterio clínico, diseño del plan y validación médica.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F1','CARE_PHASE','Recepción y apertura formal del caso','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',1,2,'Orden, profesionalismo y seguridad desde el primer minuto.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F2','CARE_PHASE','Triaje consciente','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',2,3,'Escucha estructurada y evaluación inicial para preparar una consulta eficiente y humana.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F3','CARE_PHASE','Explicación previa del proceso y enfoques','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',4,4,'Reduce ansiedad y ordena expectativas antes de la consulta médica.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F4','CARE_PHASE','Consulta médica personalizada','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',4,5,'Evaluación clínica, escucha, explicación clara y diseño del plan.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F5','CARE_PHASE','Aterrizaje del plan, cotización y decisión','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',5,5,'Traduce el plan médico a una decisión clara, sostenible y sin presión.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F6','CARE_PHASE','Consentimientos, preparación y procedimiento','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',5,7,'Seguridad legal, contención emocional y ejecución clínica.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F7','CARE_PHASE','Cierre, seguimiento y despedida','{}'::text[],'CARE_PROCESS','ZI_ATTENTION_20260827',7,7,'Continuidad, programación de siguientes sesiones y despedida cuidada.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F6_1','CARE_SUBPHASE','Firma de documentos y consentimiento informado','{}'::text[],'CARE_F6','ZI_ATTENTION_20260827',5,6,'Explicación, firma, huella y archivo de consentimientos por tratamiento.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F6_2','CARE_SUBPHASE','Preparación del paciente','{}'::text[],'CARE_F6','ZI_ATTENTION_20260827',6,6,'Acompañamiento a cabina, preparación física y contención emocional.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F6_3','CARE_SUBPHASE','Ejecución del procedimiento','{}'::text[],'CARE_F6','ZI_ATTENTION_20260827',6,6,'Ejecución clínica, educación durante el procedimiento y upselling consciente no forzado.','ACTIVE','ZI_KNOWLEDGE_V1_20260827'),
('CARE_F6_4','CARE_SUBPHASE','Registro fotográfico clínico','{}'::text[],'CARE_F6','ZI_ATTENTION_20260827',6,6,'Registro de fotografías y reacciones como evidencia del proceso.','ACTIVE','ZI_KNOWLEDGE_V1_20260827')
on conflict (entity_key) do update set entity_type=excluded.entity_type,canonical_name=excluded.canonical_name,aliases=excluded.aliases,parent_entity_key=excluded.parent_entity_key,source_key=excluded.source_key,page_start=excluded.page_start,page_end=excluded.page_end,canonical_summary=excluded.canonical_summary,status='ACTIVE',version=excluded.version,updated_at=now();

commit;
