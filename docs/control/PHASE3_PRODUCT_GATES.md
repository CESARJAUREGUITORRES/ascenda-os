# Phase 3 Product Canonical — certification gates

- P3-G01 source workbook audited and 394 sale IDs matched to production.
- P3-G02 four integration corrections locked; source descriptions preserved.
- P3-G03 51 canonical identities represented without PII.
- P3-G04 394 facts = 388 PRODUCT + 6 EXCLUDED.
- P3-G05 physical quantity = 418 and promo/pack rows = 43.
- P3-G06 alias layer has no owner alias→canonical conflict.
- P3-G07 unknown descriptions fail closed to REVIEW_REQUIRED.
- P3-G08 split payments do not double-count physical units.
- P3-G09 RLS/ACL and browser-write denial pass.
- P3-G10 Zero-Cost CI V2 exact SHA green.
- P3-G11 production preflight and additive canary pass.
- P3-G12 post-deploy smoke confirms future imports resolve without rewriting raw description.

Do not label Phase 3 `PRODUCTION CERTIFIED` until P3-G01..P3-G12 are all closed.
