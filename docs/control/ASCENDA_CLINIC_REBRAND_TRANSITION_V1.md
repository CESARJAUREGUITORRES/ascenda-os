# ASCENDA CLINIC — REBRAND & SAAS TRANSITION V1

**Decision date:** 2026-09-15  
**Source product:** ASCENDA OS  
**Commercial target:** ASCENDA CLINIC  
**Technical compatibility codename:** `ascenda-os` until an explicit rename gate

## Canonical decision

ASCENDA CLINIC is now the approved visible/commercial product identity for the current ASCENDA OS clinical product line.

This does **not** authorize a technical rename of the production stack.

Preserve until a separate migration gate:
- repository `CESARJAUREGUITORRES/ascenda-os`;
- Railway project/service identifiers;
- Supabase project identifiers;
- existing callback URLs, secrets, CI namespaces, DB object names and operational references.

Brand/UI rename and infrastructure rename are separate workstreams.

## Product lineage

`ASCENDA OS -> ASCENDA CLINIC -> ASCENDA NURSE`

ASCENDA OS remains the current source/oracle and production baseline until Freeze Source + certified release. ASCENDA CLINIC is the commercial SaaS packaging of that clinical baseline.

## ASCENDA SOFTY boundary

ASCENDA SOFTY is the shared Workbench / SaaSization / Commercial Plane.

ASCENDA CLINIC remains an independent runtime and domain product.

SOFTY may own:
- storefront and pricing presentation;
- plans / subscriptions / entitlement lifecycle;
- provisioning orchestration;
- SaaS CRM and customer lifecycle;
- product registry and operational integrations.

SOFTY must not become a hard runtime dependency for clinical operations. A SOFTY outage must not stop ASCENDA CLINIC.

Preferred integration:
`SOFTY -> provisioning API + signed webhooks + entitlement contract -> CLINIC`

Avoid direct SOFTY writes into CLINIC business tables.

## Rebrand execution layers

### CLINIC-BRAND-L0 — Identity + Login V4
Allowed:
- visible product name;
- login/PWA branding;
- design system, iconography and copy;
- metadata / application-name;
- mobile and desktop visual polish;
- OTP segmented visual treatment over the existing semantic OTP input.

Not allowed:
- changing Auth V3 semantics;
- changing 2FA challenge/expiry;
- changing app token/session authority;
- renaming repo/runtime/infrastructure;
- changing production DB identifiers merely for branding.

### Compatibility gate
Every branding release must regression-test:
- login + 2FA;
- Gmail/background return;
- PWA install/update;
- Team/RBAC;
- Call Center;
- Agenda/Calendar;
- Notifications;
- WhatsApp;
- existing admin/advisor navigation.

### SaaS hardening
Target architecture:
`Web/PWA -> /api/v1/* -> server-side authz + tenant policy -> domain/Supabase`

Priorities:
- RBAC + tenant + site/action authorization;
- audit log;
- rate limits;
- idempotency;
- RLS and server-side authorization;
- reduced privileged browser writes;
- explicit API scopes for future external integrations;
- no false-success UI.

### SOFTY commercialization gate
Only after product stability:
- register CLINIC in SOFTY Product Registry;
- define plans and entitlements;
- provisioning contract;
- billing/lifecycle integration;
- customer-organization onboarding.

### Technical rename gate
Repo/Railway/Supabase/domain rename is a separate future migration and requires:
- exact inventory of references;
- callback/domain migration plan;
- CI and secrets migration;
- rollback;
- staging proof;
- human canary;
- explicit owner authorization.

## Current validated production evidence

As of 2026-09-15:
- Auth V3 / 2FA working;
- mobile PWA access working;
- Ruvila email update/login validated;
- Call Mobile V1 validated;
- persisted call sessions record `duracion_seg`, `session_id`, `desde_dispositivo` and `tipo_gestion`;
- production continues on technical identifiers under `ascenda-os`.

## Permanent rule

**Brand rename != technical rename.**

Any agent or workstream implementing ASCENDA CLINIC branding must preserve production-compatible technical identifiers until the dedicated technical rename gate is explicitly opened.
