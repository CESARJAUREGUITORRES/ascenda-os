# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Captured:** 2026-09-16 America/Lima  
**ACTIVE HIGH/CRITICAL LOCK:** `BOOKING-V3.8 — TECHNICAL READY / HUMAN CANARY REQUIRED`  
**OWNER AUTHORIZATION:** `PROCEDE · cerrar Patients 360 + Coordinación + Link Center + WEB monitor; después canary César + asesores`  
**PAUSED HIGH/CRITICAL LANE:** `CONV-L4 #508 — checkpoint preserved; resumes only after BOOKING closeout or explicit owner reprioritization`  
**Production safety:** Conversations autonomy remains `SAFE-OFF`.

## BOOKING-V3.8 technical checkpoint

- Canonical appointment ledger remains `public.aos_agenda_citas`; no second agenda/backend exists.
- Public booking confirmation preserves the canonical Zi Vital information contract and reads logo/colors/name from `aos_configuracion`.
- Owner visually approved the refreshed confirmation email on 2026-09-16: **EMAIL VISUAL PASS**.
- Shared transactional email shell was modernized without removing template-specific content.
- Google Calendar CTA remains present and downstream Google Calendar/Contacts authority is unchanged.

### Patient 360
- Patient search/selection uses canonical IDs and governed Auth V3 service-worker token injection.
- César resolves uniquely by phone to canonical patient `P-1777072868922`; canonical Patient 360 returns `found=true`.
- JACQUELINA MARLENI PADILLA VALDIVIA resolves with HIGH confidence to canonical patient `P-5549`; merged duplicate rows remain `FUSIONADO`, while the canonical record remains `ACTIVO`.
- Canonical Patient 360 for `P-5549` returns the preserved commercial/appointment history (including 98 purchases and historical appointments). The merge did not delete the patient history.
- Human UI re-test remains required for César + P-5549 before final closeout.

### Coordination
- Root cause: 8-second polling rebuilt the chat DOM/input and erased in-progress typing.
- `app/public/asesor-coord.html` now persists a per-chat draft, focus and cursor position across refreshes and clears the draft only after send.
- Production deployment containing this change reached SUCCESS.
- Human test required: type for >8–15 seconds across polling, then send/receive.

### Advisor personal link center
- New governed RPC: `aos_booking_advisor_link_dashboard_v38(p_token)`.
- Identity is derived from the canonical authenticated app session via `aos_cia_verify_app_session_v1`; callers cannot choose another advisor ID.
- Negative auth test returns `UNAUTHORIZED` for an invalid token.
- Production readback: **10 active users / 10 users with an active permanent advisor link / 0 owners with duplicate active links**.
- Clinic shell now loads the governed link-center asset instead of the legacy V3.2 direct-user wrapper.
- UI exposes one permanent `Mi link web` per user, ready to copy, for both new and existing patients.
- Metrics exposed: `Citas web`, `Pendientes`, `Efectivas`, `Conversión`.
- No click metric is shown until a canonical link-open event exists.

### WEB / organic monitoring
- `aos_monitoreo_equipo(current_date)` exposes `citas_web` and `link_personal`.
- Current production readback includes synthetic `WEB` with **3 WEB bookings** and `link_personal=0`.
- Admin Home and Admin Calls now expose a visible `Web` column. The synthetic website row is labeled operationally as `WEB · ORGÁNICO`; advisor personal-link bookings remain on the advisor row.
- Monitoring tables preserve existing `Citas`, `Reactiv.`, and `Agenda dir.` dimensions.

### Railway
- Latest production deployment `72178ce8-201e-4859-9515-9b38b5ac0e16` for commit `1c90968d793858021317618c5d22d68fec02d8b2`: **SUCCESS**.
- Healthcheck `/health` succeeded after normal startup retries.
- Phase-S/F17 runtime came up healthy; branding cache loaded `header=#f0ebe0 sec=#cea14a`.

## Critical canary correction

The latest human booking performed by César before V3.8 was **not** proof of `ADVISOR_LINK` attribution. Production evidence shows that appointment was created as:

`source_channel=WEB · asesor=ORGANICO · id_asesor=NULL · source_link_token=NULL`

This correctly proves the organic website path, not the advisor-personal-link path.

Therefore the next César canary MUST originate from the exact tokenized link copied from the new `Mi link web` modal. Expected production evidence:

`source_channel=ADVISOR_LINK` + César owner ID + non-null `source_link_token`.

## HUMAN CANARY — current gate

Run in this order:

1. **Patients 360:** open César and JACQUELINA MARLENI PADILLA VALDIVIA / `P-5549`; both must render instead of `No encontrado`.
2. **Coordination:** type continuously through at least one 8-second polling cycle; draft must remain, then send/receive.
3. **Link Center:** open top-bar booking control; it must show one `Mi link web`, not New/Old/Permanent choices.
4. **César personal link:** copy the generated tokenized link and create one controlled appointment.
5. Verify in production: exact `ADVISOR_LINK` owner attribution, Agenda row uniqueness, push/in-app, approved Zi Vital email, Google Calendar event/sync, and `Web` monitor increment.
6. After César PASS, every advisor performs one booking from their own permanent link; verify one attributed appointment per tester.
7. Only after representative multi-user human evidence may BOOKING be closed.

## Website/theme integration rule

The future ASCENDA CLINIC WordPress/theme surface is presentation-only: skin, branding, colors, typography and composition. It must consume the same canonical booking authority, availability, professionals, treatments, patient identity, attribution, notifications, email and Google integrations. **No duplicate Agenda, booking database or parallel business logic may be created.**

## Return rule

After BOOKING-V3.8 human canary PASS, update this file. The next owner-prioritized lane is Agenda visual redesign / website-theme integration; preserved formal fallback lane remains `CONV-L4 #508`.
