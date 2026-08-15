-- ASCENDA OS CIA V3 — F16 temporary live provider canary evidence.
-- Synthetic Resend simulator only. No patient/customer address may be written here.

begin;

create table if not exists public.aos_cia_email_canary_evidence_temp (
  provider_message_id text primary key,
  provider_event_id text unique,
  event_type text,
  svix_timestamp text,
  svix_signature text,
  raw_body text,
  replay_count integer not null default 0 check (replay_count >= 0),
  provider_accepted_at timestamptz not null default now(),
  webhook_seen_at timestamptz,
  replay_seen_at timestamptz,
  created_at timestamptz not null default now(),
  check (provider_message_id <> ''),
  check (raw_body is null or octet_length(raw_body) <= 20000),
  check (svix_signature is null or octet_length(svix_signature) <= 2000)
);

alter table public.aos_cia_email_canary_evidence_temp enable row level security;
revoke all on table public.aos_cia_email_canary_evidence_temp from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_cia_email_canary_evidence_temp to service_role;

comment on table public.aos_cia_email_canary_evidence_temp is 'F16 temporary zero-PII live Resend simulator evidence used only to prove signed webhook and replay handling before release certification.';

commit;
