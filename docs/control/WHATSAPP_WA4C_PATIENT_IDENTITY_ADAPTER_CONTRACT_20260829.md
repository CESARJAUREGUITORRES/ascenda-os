# WA-4C — Patient Identity Adapter Contract

**Date:** 2026-08-29 America/Lima  
**Parent:** `WA-4C — Conversational Sales & Patient Identity Hardening`  
**Status:** `DESIGN CONTRACT / REQUIRED BEFORE LIVE CERTIFICATION`

## Existing canonical search behavior verified in PROD schema

`aos_patient_search_v2(p_token,p_query,p_limit)` already:

- normalizes `PHONE`, `DOCUMENT` and `EMAIL` through `aos_rev_normalize_patient_identifier_v2`;
- checks `aos_rev_patient_identity_alias_v2` for canonical alias hits;
- reports `IDENTITY_CONFLICT` when an exact normalized alias has more than one candidate;
- can also search active `aos_pacientes` by full-name text, phone digits, document digits or exact email;
- returns canonical patient id, first/last names, phone, DNI, site/state and identity confidence metadata;
- requires an authorized `advisor-patients` or `admin-patients` app actor.

## WhatsApp adapter rule

The raw RPC response is **not** an acceptable direct LLM/customer payload because it contains identifiers that the Sales Copilot does not need, including full DNI.

Create a least-privilege projection for WhatsApp. The Copilot-facing identity context should expose only what is necessary, for example:

```json
{
  "lookup_status": "NORMAL",
  "customer_type": "EXISTING",
  "identity_state": "CHANNEL_RESOLVED",
  "canonical_patient_id": "...",
  "first_name": "...",
  "site": "...",
  "confidence_band": "HIGH"
}
```

Do not pass raw full DNI, full email, notes, clinical history, documents or unrelated patient fields to the LLM.

## Binding policy

### Passive channel resolution

Use signed WhatsApp sender identifiers/normalized phone against canonical identity aliases first.

- exactly one strong candidate → `CHANNEL_RESOLVED`;
- no candidate → `UNRESOLVED`;
- more than one canonical candidate / conflict → `CONFLICT` and no auto-binding.

### Name claims

A message such as `soy <nombre y apellido>` may be used as a search hint, never as sufficient binding evidence.

If name search returns one row but there is no stronger verified channel/document/email evidence, treat the result as a candidate, not as verified identity.

### `Soy paciente` flow

When unresolved and customer selects `Soy paciente`:

1. request the minimum verification factor required by policy;
2. document number may be accepted as a verification input because the canonical search already normalizes DOCUMENT;
3. never echo the complete document number back to the customer;
4. redact/hash sensitive identifier values in logs/audit where practical;
5. if unique canonical alias resolves, promote identity state according to the verification matrix;
6. if conflict, stop binding and route governed/manual resolution;
7. if no result, do not block service — continue as unresolved/new flow and request only booking-required data.

### `Es mi primera vez` flow

Mark commercial customer type `NEW`/`NEW_LEAD`. Do not create a canonical patient merely because a button was clicked. Patient/prospect creation belongs to the governed booking/customer creation path.

## Disclosure matrix

### No verified identity required

- public treatment/service information;
- current governed public price;
- public locations;
- public hours;
- general payment information;
- approved commercial media.

### Channel-resolved / low-risk personalization

May use first name and existing profile internally where authorized, but must not expose sensitive patient-specific facts merely from a phone match.

### Stronger verification required

- upcoming appointment date/time/details;
- customer-specific appointment changes where disclosure itself is sensitive;
- patient-specific financial/transaction data;
- any information that reveals treatment history or health-service history.

### Human/clinical authority

- clinical history;
- diagnoses;
- contraindication/candidacy decisions;
- notes/PHI;
- adverse-event interpretation.

## Agenda linkage

Existing `aos_agenda_citas` fields support `numero`, `dni`, `correo`, names, treatment, site, date/time and state. Existing `aos_rev_customer_agenda_identity_v1` links appointments to `canonical_patient_id` with candidate count and identity status.

WhatsApp should therefore query a governed appointment read model keyed by canonical patient identity instead of scanning agenda by free-form name.

## Legacy booking boundary

`aos_agendar_publica(...)` currently:

- accepts name + surname + phone;
- treats DNI and email as optional defaults;
- normalizes phone;
- looks up `aos_pacientes` by `numero_limpio LIMIT 1`;
- creates a `PROSPECTO` when none is found;
- inserts the appointment.

This function remains useful evidence for the minimum data needed to book, but its phone-only patient lookup must **not** become the final WhatsApp identity contract. WA-4C/WA-6 should introduce a governed adapter that resolves canonical identity first and prevents silent misbinding/duplicate creation.

## Fail-closed rules

- never bind by name alone;
- never choose the first row from an identity conflict;
- never send full DNI to the LLM;
- never disclose another person's appointment/data;
- never create patient truth inside the conversation state;
- never make booking unavailable solely because an optional email is missing unless a later governed booking rule explicitly requires it.
