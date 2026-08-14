-- ASCENDA OS CIA V3 — Phase 15 Tool/Agent Registry seed

create table if not exists public.aos_cia_kronia_proposal_events (
  id bigint generated always as identity primary key,
  proposal_id uuid not null references public.aos_cia_kronia_proposals(id) on delete cascade,
  request_id uuid references public.aos_cia_requests(id),
  event_type text not null check (event_type in ('PROPOSED','REQUEST_LINKED','HUMAN_DECISION_OBSERVED')),
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default clock_timestamp()
);
create index if not exists idx_cia_kronia_prop_events on public.aos_cia_kronia_proposal_events(proposal_id,occurred_at,id);
create index if not exists idx_cia_kronia_prop_events_request on public.aos_cia_kronia_proposal_events(request_id,occurred_at,id) where request_id is not null;
alter table public.aos_cia_kronia_proposal_events enable row level security;
revoke all on table public.aos_cia_kronia_proposal_events from public,anon,authenticated;
drop trigger if exists trg_cia_kronia_proposal_events_immutable on public.aos_cia_kronia_proposal_events;
create trigger trg_cia_kronia_proposal_events_immutable before update or delete on public.aos_cia_kronia_proposal_events for each row execute function public.aos_cia_kronia_immutable_audit_guard_v1();

insert into public.aos_cia_kronia_tool_registry(tool_key,version,display_name,description,operation_class,risk_class,request_type,input_schema,output_schema,active)
values
('intelligence.get',1,'Intelligence Get','Lee una recomendación F14 SHADOW sin PII directa ni autoridad operacional.','READ','LOW',null,'{"type":"object","properties":{"recommendation_id":{"type":"string","format":"uuid"}},"required":["recommendation_id"]}'::jsonb,'{"type":"object"}'::jsonb,true),
('intelligence.explain',1,'Intelligence Explain','Devuelve evidence/explainability/freshness determinísticos de F14.','READ','LOW',null,'{"type":"object","properties":{"recommendation_id":{"type":"string","format":"uuid"}},"required":["recommendation_id"]}'::jsonb,'{"type":"object"}'::jsonb,true),
('policy.release.probe',1,'Release Policy Probe','Consulta F13 Policy Gate para una propuesta RELEASE_ASSIGNMENT; nunca ejecuta.','READ','MEDIUM','RELEASE_ASSIGNMENT','{"type":"object"}'::jsonb,'{"type":"object"}'::jsonb,true),
('policy.auto_assign.probe',1,'Auto Assign Policy Probe','Demuestra que AUTO_ASSIGN permanece bloqueado por F13.','READ','HIGH',null,'{"type":"object"}'::jsonb,'{"type":"object"}'::jsonb,true),
('proposal.release',1,'Release Proposal','Genera una propuesta gobernada de liberación únicamente si existe ownership F9 activo; nunca aprueba ni ejecuta.','PROPOSE','HIGH','RELEASE_ASSIGNMENT','{"type":"object","properties":{"reason":{"type":"string","maxLength":500}}}'::jsonb,'{"type":"object"}'::jsonb,true),
('f16.email.context.preview',1,'F16 Email Context Preview','Prepara contexto comercial no clínico y no ejecutable para la futura integración Email F16.','READ','MEDIUM',null,'{"type":"object"}'::jsonb,'{"type":"object"}'::jsonb,true)
on conflict (tool_key,version) do update set display_name=excluded.display_name,description=excluded.description,operation_class=excluded.operation_class,risk_class=excluded.risk_class,request_type=excluded.request_type,input_schema=excluded.input_schema,output_schema=excluded.output_schema,active=excluded.active,updated_at=clock_timestamp();

insert into public.aos_cia_kronia_agent_registry(agent_key,version,display_name,purpose,agent_class,allowed_tools,execution_mode,active,metadata)
values
('kronia',1,'KronIA','Coordinadora General; interpreta contexto F14 y orquesta herramientas gobernadas sin autoridad de ejecución.','ORCHESTRATOR',array['intelligence.get','intelligence.explain','policy.release.probe','policy.auto_assign.probe','proposal.release','f16.email.context.preview'],'SHADOW',true,'{"legacy_role":"Coordinadora General"}'::jsonb),
('centinela',1,'Dante','Vigilante de Leads; observa oportunidades y explica señales sin mutar ownership.','OBSERVER',array['intelligence.get','intelligence.explain','policy.release.probe'],'SHADOW',true,'{"legacy_role":"Vigilante de Leads"}'::jsonb),
('clasificador',1,'Nico','Clasificador de Leads; interpreta evidencia comercial sin escribir fuentes.','INTERPRETER',array['intelligence.get','intelligence.explain'],'SHADOW',true,'{"legacy_role":"Clasificador de Leads"}'::jsonb),
('analista_mkt',1,'Valentina','Analista de Marketing; consume inteligencia comercial y preview de contexto F16 sin envío.','ANALYST',array['intelligence.get','intelligence.explain','f16.email.context.preview'],'SHADOW',true,'{"legacy_role":"Analista de Marketing"}'::jsonb),
('monitor',1,'León','Monitor de KPIs; observa y explica señales determinísticas.','MONITOR',array['intelligence.get','intelligence.explain'],'SHADOW',true,'{"legacy_role":"Monitor de KPIs"}'::jsonb),
('analista',1,'Sofía','Analista de Datos; interpreta evidencia F14 y puede consultar Policy Gate sin ejecutar.','ANALYST',array['intelligence.get','intelligence.explain','policy.release.probe'],'SHADOW',true,'{"legacy_role":"Analista de Datos"}'::jsonb)
on conflict (agent_key,version) do update set display_name=excluded.display_name,purpose=excluded.purpose,agent_class=excluded.agent_class,allowed_tools=excluded.allowed_tools,execution_mode=excluded.execution_mode,active=excluded.active,metadata=excluded.metadata,updated_at=clock_timestamp();
