# CIA Audience Workspace V3 · Product & Runtime Contract

Date: 2026-09-17 (America/Lima)
Status: STAGED FOR CI
Depends on: CC-HOPPER-F1 (PR #611 / merge 68a6f646...)
Production assignment mutation: NONE
Human test: NOT EXECUTED

## Product correction

The prior three-step modal mixed four different responsibilities:
1. defining a segment,
2. inspecting contacts,
3. persisting a reusable audience,
4. assigning work to Call Center.

V3 separates them into four workspaces:

- **Audiencias** — catalog of pre-established dynamic audiences.
- **Distribución** — choose a source audience and decide who/channel executes it.
- **Actividad** — immutable activations/snapshots and assignment outcomes.
- **Explorar** — advanced filter registry for special cases.

The default operator path no longer starts with a filter builder.

## Runtime model

One canonical contact can belong to multiple audiences at the same time.

Examples:
- new lead + no calls → Nunca llamados
- called, no effective contact → Llamados sin contacto efectivo
- future appointment → Con cita futura
- no-show and no new appointment → No-show sin cita futura
- purchase → buyer/customer/value audiences

Audience membership is dynamic. Execution is immutable:
Audience definition → Activation snapshot → Assignment Plan → Assignments/hopper → Advisor work/outcome.

## Performance rule

The full audience source is a rich view and must never be scanned automatically on panel open.

V3 therefore uses:
- cached catalog counts in `aos_audience_preset_runtime_cache_v1`;
- an explicit operator action **Actualizar conteos**;
- one controlled aggregate refresh for the curated catalog;
- explicit bounded preview (25 contacts);
- explicit CSV export;
- independent loading of catalog, advisor bootstrap and saved audiences.

If bootstrap/library fails, the catalog remains usable.

## UX layout

### Audiencias
- left: categories
- center: compact catalog table
- right: detail drawer
- search, cached count, freshness
- preview 25
- CSV
- “Usar en distribución”

This uses horizontal space instead of stacking three processes in one modal.

### Distribución
- source audience summary
- channels: Call Center / Email / WhatsApp
- Call Center safe test with exactly one contact
- mass distribution remains blocked until one-contact PASS

Normal admin copy deliberately excludes engineering terms such as:
- Human Canary
- resolver v2
- readback técnico

### Actividad
Read-only recent activations/plans and assignment counts.

### Explorar
All governed filter dimensions and saved custom audiences.

## Safety

- no automatic send
- no automatic routing enablement
- no background polling
- no count-on-render
- no parallel CRM
- stale saved audience definition is blocked before canary plan creation
- existing reversible V2 canary gateway remains authoritative for the one-contact test
- global routing baseline must be OFF before starting the test
