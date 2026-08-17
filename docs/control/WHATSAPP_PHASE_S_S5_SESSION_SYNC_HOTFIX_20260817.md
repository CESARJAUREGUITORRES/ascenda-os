# PHASE S — S5 Native Session Sync Hotfix — 2026-08-17

## Symptom

ASCENDA shell shows WA conversations through automatic recovery, but the native WA-3 composer and Routing & Handoff controls do not mount.

Observed UI:

- `recuperación de inbox` in conversation header;
- `WA-3 recuperado automáticamente` in right panel;
- composer remains `Recuperando sesión operativa WA-3...`.

## Root cause

The embedded `admin-whatsapp-wa3.html` performs one native `boot()` attempt. If the iframe does not yet have the strong ASCENDA 2FA app token in its own session context, the native boot aborts and does not retry. The parent shell later succeeds because its own `reqJson()` uses the parent app token, but the read-only recovery renderer does not reconstruct the native WA-3 in-memory state (`S.boot`), so it cannot safely enable the native composer.

## Fix invariant

Do not force-enable the button.

Instead:

1. synchronize the strong app token from the ASCENDA parent shell into the same-origin WA iframe session;
2. allow one controlled native iframe reload after synchronization;
3. on the second load, let original WA-3 `boot() -> refreshInbox()` own the UI;
4. if native boot still fails, keep existing recovery as read-only safety net;
5. never bypass `aos_wa3_human_send_authorize_v1`, ownership, active assignment, human-send kill switch, canary allowlist or idempotency.

## Exit gate

PASS only if `zi vital` loads without `recuperación de inbox`, right panel renders native control/ownership, `VENTAS_GENERAL` is visible, and composer appears because native `canCompose()` evaluates true from server-authorized state.