# P0 #457 — WA-L9 cross-regression marker

This file intentionally scopes PR #459 into the canonical WA-L9 workflow because the additive bounded certification migration also defines `aos_wa_l9_safety_status_v2()`.

The v2 source itself is statically enforced by `ci/wa-l8/p0_certification_status_v2_contract.js`; the WA-L9 workflow remains responsible for proving the existing shadow authority, privacy, no-dispatch and SAFE-OFF contracts are unchanged.
