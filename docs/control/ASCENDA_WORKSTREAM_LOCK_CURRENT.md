# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / WHATSAPP REVENUE HUB V2  
**Captured:** 2026-08-24 America/Lima  
**Baseline before WA-3.5 closeout:** `main@6292852fad190f1489836fc34644a2161aa575a2`  
**Closeout PR:** `#372`  
**ACTIVE LOCK:** `WA-3.5 — REVENUE INBOX UX CLOSEOUT`  
**NEXT LOCK AFTER MERGE:** `WA-7A — META ATTRIBUTION INGRESS`

## Owner directive

Finish WA-3.5 completely before moving the mutable lane to WA-7A. At most one HIGH/CRITICAL mutable workstream may operate at a time.

## Preserved portfolio state

- REV-F5 = PRODUCTION CERTIFIED 100%.
- REV-F6 = PRODUCTION CERTIFIED 100%.
- REV-F7 = paused while WA owns the mutable lane.
- Notifications S13–S15.5 = CLOSED / regression-only.
- MKT Integrity Loop 6 V2.3 = PAUSED / RECOVERABLE.
- CIA, Sentinel, KronIA and unrelated product/data work remain read-only/regression-only unless WA proves a strict dependency.

## WA-3 / closeout baseline

The certified WA foundation preserves:

- signed Meta gateway + replay/idempotency controls;
- canonical conversation projection;
- strong Auth V3/2FA;
- explicit `whatsapp-agent` authorization;
- boxes/members/`max_active`;
- AVAILABLE/AWAY/OFFLINE readiness;
- explicit `HUMAN_REQUESTED` queue;
- queue privacy;
- claim/reassign/release;
- supervisor/manual intervention;
- concurrent single-owner claim;
- exact-owner send + 24h window;
- ownership-loss recovery;
- alerts/notifications regressions;
- Supabase 402 fail-closed retry containment;
- `auto_routing=false`, `ai_send=false`, `copilot=false`, `auto_reply=false`.

## WA-3.5 closeout scope

### P0 — CLOSED in product scope

Revenue Inbox filters, campaign selector, richer cards and shared canonical snapshot with no duplicate polling.

### P1A — CLOSED in product scope

Populate-only quick replies, scoped/expiring drafts, keyboard shortcuts and responsive baseline.

### P2 — CLOSED in product scope

- DETAILS uses native WA-3 authority;
- CUSTOMER 360 reuses REV-F6 on demand with existing patient permissions and narrow commercial projection;
- CAMPAIGN exposes only current provenance and hands expansion to WA-7A;
- ACTIVITY uses canonical timestamps;
- COPILOT remains SAFE-OFF;
- P2 is event-driven with zero timers/polling/MutationObserver.

Internal notes are a governance exclusion until a canonical write contract exists; they must not be implemented as browser-only truth.

## Production hold

Supabase production remains HTTP 402. Therefore:

- no production auth bypass;
- no Cloud write retries merely to exercise WA;
- historical counts are not fresh readback;
- `WA-3.5 LIVE / PRODUCTION CERTIFIED 100%` remains false;
- code/CI/Zero-Cost closeout may complete independently.

LIVE recovery gate:

`402 → 200 → Railway exact health → Auth/2FA → provider health → signed inbound → allowlisted outbound → terminal delivery → CESAR↔MIREYA handoff/claim/send/reassign/isolation/readback → notifications → WA-3.5 visual smoke → egress observation`.

## Lock transition rule

The mutable lock moves to `WA-7A — META ATTRIBUTION INGRESS` only after:

1. PR #372 final exact-head `ASCENDA WA-3.5 Closeout` = SUCCESS;
2. `main` anti-drift readback passes;
3. merge uses exact `expected_head_sha`;
4. Railway status for the merge is checked;
5. GitHub CURRENT + certificate are reconciled;
6. Notion is updated last.

WA-7A may then mutate only attribution-ingress scope. It must not simultaneously open WA-4/WA-5/WA-6 product mutations.

## Safety invariants

- one mutable HIGH/CRITICAL lane;
- no secrets in Git/Notion/chat/frontend;
- no autonomous diagnosis;
- no AI auto-reply before future controlled-autonomy gates;
- no attribution from phone alone;
- no parallel CRM/Agenda/sales/email truth;
- fail-closed recovery;
- exact-head → merge → reconciliation → next lock.
