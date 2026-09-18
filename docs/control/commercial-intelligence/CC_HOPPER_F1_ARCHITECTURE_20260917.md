# CC-HOPPER-F1 · Call Center Operating Model

Date: 2026-09-17 (America/Lima)
Status: DESIGN + SAFE STAGING
Production routing mutation: NONE
Human canary: NOT EXECUTED

## Why this workstream exists

The current production Call Center still depends on the legacy selector path `aos_siguiente_lead_v2` while global V3 routing is OFF. That selector scans operational tables at request time using many `NOT EXISTS`, joins and tier branches. Historical pg_stat_statements shows the legacy `aos_siguiente_lead` family as one of the most expensive foreground paths.

The correct architecture is not another parallel queue table. ASCENDA already has the required components:

1. **Canonical Contact / Facts** — one person and their commercial/clinical facts.
2. **Audience** — dynamic definition of who belongs to a segment.
3. **Activation** — immutable use/snapshot of an audience for one channel/purpose.
4. **Assignment Plan** — distribution policy.
5. **Assignment** — the actual advisor work queue / hopper.
6. **Advisor Work** — claim, lease, start, release, complete.
7. **Outcome** — call result, appointment, sale, follow-up, exclusion.

This must become the only new operating model. Legacy V2 remains fallback until human canary and rollout gates pass.

## External patterns reviewed

### VICIdial
VICIdial separates **lead list / campaign / hopper / live agent**. The hopper is not the master database; it is an operational queue with states, priority, campaign, owner and lead identity. ASCENDA should map this pattern to:

- VICIdial List → ASCENDA Audience
- VICIdial Campaign → ASCENDA Activation
- VICIdial Hopper → `aos_cia_assignments`
- VICIdial Live Agent → Advisor Work / lease
- VICIdial Status / recycle → Call Outcome + eligibility rules

Key lesson: **do not scan the whole lead universe every time an advisor asks for the next call**.

### Mautic
Mautic segments are dynamic filter definitions. Contacts automatically enter and leave segments as facts change; campaigns consume segments separately. ASCENDA should do the same: an audience is a rule, not a copied spreadsheet.

Key lesson: **segment membership and execution are separate concepts**.

### Twenty CRM
Twenty treats filtered/sorted/grouped views as the primary user interface, with table views, record side panels, saved views and CSV export.

Key lesson: **the admin starts from a catalog/table of useful views, not from a technical filter builder**.

### listmonk
listmonk separates subscribers from list membership and supports query-driven bulk list operations and export.

Key lesson: **channels consume a governed source of contacts; they do not create a second CRM**.

## Product model

### A. Audiencias
Default landing surface. Pre-established and live:
- Todos los contactos
- Nunca llamados
- Llamados sin contacto efectivo
- Seguimientos pendientes
- Con cita futura
- No-show
- Nunca compraron
- Compradores recientes
- Clientes activos / nuevos / Gold / Diamante
- Email válido / abrió / clic / rebote
- Edad / sexo / distrito / sede
- Interés por servicio/producto
- and future governed combinations

Each audience shows:
- current/last-known count
- freshness
- short business explanation
- preview
- export CSV
- **Usar** action

There is no requirement to manually recreate these audiences.

### B. Distribución
A separate workspace:
- source audience
- channel
- advisor(s)
- quantity/capacity
- priority
- lease / must-start window
- start / pause / close

Call Center materializes work into `aos_cia_assignments`. Email and WhatsApp consume the same audience definition/activation and must not duplicate the contact master.

### C. Actividad
Operational history:
- activation
- audience/version
- channel
- assignment count
- in progress / completed / released / expired
- outcomes
- snapshot export

### D. Explorar
Advanced builder only. Used to create a new governed audience from registry filters. It is not the home page.

## Call Center hot path

Target hot path:

```
advisor asks next
  -> resolve advisor identity
  -> select one eligible ASSIGNED / IN_PROGRESS row
     from aos_cia_assignments
     using advisor/state/deadline/rank index
     FOR UPDATE SKIP LOCKED
  -> lease/start assignment
  -> return contact + context
```

The request must **not**:
- rebuild a segment
- scan all leads
- recalculate all tiers
- call multiple unrelated panels
- create a new audience
- mutate global routing unexpectedly

## Existing assets reused

- `aos_cia_contact_identity_v1`
- audience filter registry + resolver
- audience library/versioning
- activation tables
- `aos_cia_assignment_plans`
- `aos_cia_assignments`
- lease transition functions
- V3 router / V2 fallback
- queue gateway / Auth V3
- advisor panel permissions

No parallel CRM, no Chatwoot, no n8n.

## F1 implementation in this branch

Migration:
`20260918013500_cc_hopper_f1_claim_hotpath.sql`

It adds only a **partial covering index** for the existing assignment claim query:

- advisor
- state
- must-start deadline
- source rank
- assigned time
- id

Included:
- plan
- activation
- contact key
- expiry

This does **not** enable V3, alter routing, create assignments or change user-visible behavior.

## Release sequence

1. F1 architecture + hotpath index CI
2. apply index migration in production
3. verify index + zero routing residue
4. redesign Audience Control Center against this model
5. Human Canary: 1 audience → 1 advisor → 1 assignment
6. prove claim/readback/rollback
7. enable V3 for one advisor only
8. measured multi-advisor rollout
9. only after sustained PASS, retire legacy selector as default
10. keep fail-closed fallback until final deprecation gate

## Hard rules

- Audience != Activation != Assignment != Advisor Work.
- Dynamic audiences are evaluated from canonical facts.
- Call Center consumes assignments, not arbitrary base scans.
- Email/WhatsApp reuse the audience source.
- A contact can belong to many audiences simultaneously.
- Execution uses an immutable activation/snapshot for auditability.
- One contact cannot be actively owned by two advisors in the same activation.
- Every claim is leased, expirable and auditable.
- No mass rollout before one-contact human canary PASS.
- No technical labels such as `Human Canary`, `resolver v2`, or `readback técnico` in normal admin UX.

## Current production boundary

Production remains on the current certified main SHA. PR #610 is draft and must not be merged as-is. This F1 branch is isolated from the Audience UI branch so operational reliability and product design are no longer mixed in the same release.
