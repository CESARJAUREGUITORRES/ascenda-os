-- Minimal CIA-F17 recipient-control contract used only by isolated WA-7A.4 Zero-Cost tests.
-- Production authority remains the real CIA-F17 migration.

create or replace function public.aos_cia_normalize_contact_key_v1(p_raw text)
returns text
language sql
immutable parallel safe
as $$
select case
  when length(regexp_replace(coalesce(p_raw,''),'\D','','g'))=9 then regexp_replace(coalesce(p_raw,''),'\D','','g')
  when length(regexp_replace(coalesce(p_raw,''),'\D','','g'))=11 and left(regexp_replace(coalesce(p_raw,''),'\D','','g'),2)='51'
    then right(regexp_replace(coalesce(p_raw,''),'\D','','g'),9)
  else null
end;
$$;

create table public.aos_cia_channel_recipient_controls_v1 (
  contact_key text not null,
  channel text not null check (channel in ('WHATSAPP','SMS')),
  consent_status text not null default 'UNKNOWN' check (consent_status in ('UNKNOWN','ALLOWED','DENIED')),
  suppression_status text not null default 'UNKNOWN' check (suppression_status in ('UNKNOWN','CLEAR','SUPPRESSED')),
  source text not null default 'UNSET',
  evidence jsonb not null default '{}'::jsonb,
  updated_by_user_id uuid,
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(contact_key,channel),
  check (public.aos_cia_normalize_contact_key_v1(contact_key)=contact_key)
);
