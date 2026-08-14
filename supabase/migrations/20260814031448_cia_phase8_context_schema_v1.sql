-- ASCENDA CIA Phase 8 — Channel Context & Availability schema.
-- Additive only. Does not touch operational write paths.

create table if not exists public.aos_cia_context_policies (
  policy_key text not null,
  version integer not null,
  channel text not null,
  name text not null,
  status text not null default 'ACTIVE',
  is_default boolean not null default false,
  rules jsonb not null default '{}'::jsonb,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  primary key(policy_key,version),
  constraint aos_cia_context_policies_key_chk check (policy_key ~ '^[A-Z0-9_]{3,80}$'),
  constraint aos_cia_context_policies_channel_chk check (channel in ('CALL','EMAIL','SMS','WHATSAPP','ANALYSIS','AUTOMATION','OTHER')),
  constraint aos_cia_context_policies_status_chk check (status in ('ACTIVE','RETIRED')),
  constraint aos_cia_context_policies_rules_chk check (jsonb_typeof(rules)='object'),
  constraint aos_cia_context_policies_effective_chk check (effective_to is null or effective_to>effective_from)
);

create unique index if not exists ux_aos_cia_context_default_channel
  on public.aos_cia_context_policies(channel)
  where status='ACTIVE' and is_default;

create table if not exists public.aos_audiencia_activacion_context (
  activation_id uuid primary key references public.aos_audiencia_activaciones(id) on delete restrict,
  policy_key text not null,
  policy_version integer not null,
  bound_by_user_id uuid not null references public.aos_usuarios(id) on delete restrict,
  bound_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint aos_audiencia_activacion_context_policy_fk foreign key(policy_key,policy_version)
    references public.aos_cia_context_policies(policy_key,version) on delete restrict,
  constraint aos_audiencia_activacion_context_metadata_chk check (jsonb_typeof(metadata)='object' and pg_column_size(metadata)<=16384)
);

alter table public.aos_cia_context_policies enable row level security;
alter table public.aos_audiencia_activacion_context enable row level security;

insert into public.aos_cia_context_policies(policy_key,version,channel,name,is_default,rules)
values
('CALL_GENERAL',1,'CALL','Llamadas generales',true,
 '{"require_phone":true,"exclude_lifecycle":["DISQUALIFIED_PROSPECT"],"exclude_latest_call_status":["PROVINCIA","PROVINCIAS"],"block_called_today":true,"block_future_appointment":true,"block_legacy_in_progress":true,"availability_support":"FULL"}'::jsonb),
('CALL_PROVINCE',1,'CALL','Llamadas provincia',false,
 '{"require_phone":true,"require_latest_call_status":["PROVINCIA","PROVINCIAS"],"block_called_today":true,"block_future_appointment":true,"block_legacy_in_progress":true,"availability_support":"FULL"}'::jsonb),
('EMAIL_GENERAL',1,'EMAIL','Email general',true,
 '{"require_email":true,"require_email_identity_confidence":["MEDIUM"],"block_email_sent_today":true,"availability_support":"FULL"}'::jsonb),
('SMS_GENERAL',1,'SMS','SMS general',true,
 '{"require_phone":true,"availability_support":"UNKNOWN_HISTORY"}'::jsonb),
('WHATSAPP_GENERAL',1,'WHATSAPP','WhatsApp general',true,
 '{"require_phone":true,"availability_support":"UNKNOWN_HISTORY"}'::jsonb),
('ANALYSIS_GENERAL',1,'ANALYSIS','Análisis',true,
 '{"availability_support":"NON_CONTACT"}'::jsonb),
('AUTOMATION_GENERAL',1,'AUTOMATION','Automatización',true,
 '{"availability_support":"NON_CONTACT"}'::jsonb),
('OTHER_GENERAL',1,'OTHER','Otro contexto',true,
 '{"availability_support":"NON_CONTACT"}'::jsonb)
on conflict(policy_key,version) do nothing;
