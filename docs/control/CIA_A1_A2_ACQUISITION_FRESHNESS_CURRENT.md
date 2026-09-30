# CIA A1 + A2 — Acquisition Facts + Event-driven Freshness

Captured: 2026-09-29/30 America/Lima
Repo: `CESARJAUREGUITORRES/ascenda-os`
Workstream: `cia-a1-a2-acquisition-freshness-v1`
Scope: Audience data plane only. No mass Call Center distribution, Email send or WhatsApp send is enabled by this checkpoint.

## Goal

Make the shared CIA/Audiences contact model understand direct landing acquisition and keep its fast runtime cache current when commercial facts change.

Target lineage:

`landing -> platform -> campaign -> ad -> UTM -> appointment -> call/contact -> attendance -> sale/revenue -> audience`

The canonical commercial identity remains `contact_key`; no duplicate CRM/contact database is introduced.

## A1 — Acquisition / Landing Facts

Source authority: `aos_landing_booking_attribution`.

Added read model: `aos_cia_acquisition_facts_v1`, one row per canonical `contact_key`, including:

- web booking count;
- first/last web booking timestamps;
- acquisition channel and platform;
- landing code/name/url;
- campaign code/name;
- ad code/name;
- treatment/advisor context;
- UTM source/medium/campaign/content/term;
- referrer and client event id.

The runtime cache now carries the same acquisition dimensions and `aos_cia_audience_source_v1` appends them without replacing existing lead/call/appointment/sale/email/segment facts.

Sixteen governed `ACQUISITION` filter dimensions were added to `aos_audience_filter_registry` and routed through `aos_cia_audience_leaf_keys_v3` using the fast acquisition adapter.

Initial presets:

- `WEB_BOOKINGS`;
- `WEB_BOOKINGS_FUTURE`;
- `WEB_BOOKINGS_NO_PURCHASE`.

## A2 — Event-driven freshness

Prior condition: the rich canonical source had 13,752 contacts while the fast audience runtime cache had 13,398, because the cache depended on explicit manual refresh.

A2 adds incremental refreshes keyed by `contact_key` for:

- landing attribution;
- patient/profile changes;
- appointments;
- calls;
- sales;
- leads.

Each affected source has a row trigger that updates only the touched contact in `aos_cia_contact_runtime_cache_v1`, plus a statement trigger that recomputes preset counts once per SQL statement. This avoids polling and avoids rebuilding the rich 13k-contact source per user action.

Freshness state is tracked in `aos_cia_runtime_freshness_v1`; preset recount uses an advisory lock and `aos_cia_catalog_recount_if_dirty_v1` for single-flight/coalesced behavior.

`aos_cia_control_center_app_v7` is provided as an additive authenticated metadata wrapper for a future UI cutover. Product correctness does not depend on V7 because source statement triggers already update counts automatically.

## Production validation evidence

### Baseline reconciliation

- `aos_cia_audience_source_v1`: **13,752** contacts.
- `aos_cia_audience_source_v1_1`: **13,752** contacts.
- `aos_cia_contact_runtime_cache_v1`: reconciled from **13,398** to **13,752** contacts.
- active acquisition filter dimensions: **16**.
- active presets: **50** (47 existing + 3 web acquisition presets).

A one-time full historical reconciliation used the existing governed runtime refresh. It processed 13,752 rows in **7,410 ms**. This full operation is maintenance-only; normal A2 events do not run it.

### Incremental performance

Combined per-contact refresh of acquisition + profile + appointment + call + sale on an existing contact:

- PostgreSQL execution time: **31.66 ms** total.

Fast preset recount over the reconciled 13,752-contact cache:

- **25 ms**.

### Synthetic landing canary

A synthetic registry + attribution was inserted inside an explicit transaction and rolled back. Assertions proved:

1. `aos_cia_acquisition_facts_v1` observed one web booking;
2. runtime cache received platform, landing, campaign and ad lineage;
3. `aos_cia_audience_leaf_keys_v3` matched the contact through an acquisition filter;
4. freshness was marked dirty;
5. governed recount refreshed the `WEB_BOOKINGS` preset;
6. transaction rollback left **0** synthetic attribution rows and **0** synthetic registry rows.

Result: `PASS_A1_A2_SYNTHETIC_ROLLBACK`.

A second rollback canary verified statement-level automatic recount. After the attribution INSERT, `catalog_dirty=false` and the web preset count was already updated before any manual refresh.

Result: `PASS_A2_STATEMENT_RECOUNT_ROLLBACK`.

### Defects caught during validation

Two defects were found before closure and fixed in production:

1. first A1 view composition accidentally introduced `v1 -> v1_1 -> v1` recursion. The source was rebuilt directly from commercial/profile/segment/purchase-detail authorities, eliminating the cycle; both audience source versions again return 13,752 contacts.
2. first A2 recount exceeded PostgreSQL `jsonb_build_object` argument limits after adding three web presets. The count object was split into safe JSONB blocks; recount now completes successfully in ~25 ms.

These fixes are incorporated in the repository migrations, so a clean replay does not pass through either broken intermediate state.

## Safety / no-regression readback

Distribution release state remains unchanged:

- CALL: `HUMAN_CANARY_REQUIRED`, `execution_enabled=false`, `max_source_limit=1`, `max_advisors=1`;
- EMAIL: `HUMAN_CANARY_REQUIRED`, `execution_enabled=false`;
- WHATSAPP: `HUMAN_CANARY_REQUIRED`, `execution_enabled=false`.

Assignment state after A1+A2:

- assignment runs: **0**;
- open assignments: **0**;
- open plans: **0**.

A1+A2 therefore changes the audience data plane only; it does not release distribution execution.

## Current expected behavior

When future landing booking lineage is written to `aos_landing_booking_attribution`, CIA will immediately:

1. resolve the same canonical contact key;
2. project acquisition/UTM lineage into the contact runtime cache;
3. combine it with existing appointment/call/sale/profile facts;
4. refresh the affected audience counts without operator polling;
5. make acquisition dimensions available to the governed audience resolver.

No real landing booking was invented for this checkpoint. The real `WEB_BOOKINGS` presets remain at zero until the first production landing attribution arrives.

## Next phase — intentionally out of scope

A3 should expose the `ACQUISITION` dimensions as first-class product UX in Explore/Audience Builder (landing, platform, campaign, ad and UTM filters). A4 remains the controlled Call Center distribution release after a one-contact human canary. A5 is the shared Audience -> Email handoff. None is activated by A1+A2.
