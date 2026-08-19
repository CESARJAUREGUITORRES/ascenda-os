# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5R Pre-Merge Readback

Functional production state before GitHub merge:

- cleanup semantic migration applied; hash `a6f918f64ac56f587a75ed0aebde0e09`;
- 37108 restored → lead 5664 / MIREYA / LLAMADA_MANUAL_COMERCIAL;
- 37110 restored → lead 5599 / MIREYA / LLAMADA_MANUAL_COMERCIAL;
- inferred historical calls created: 37199, 37200, 37201, 37202;
- six target Agenda rows direct-linked; Agenda total unchanged at 3,126;
- Mireya 2026-08-18: 51/4 → 53/6, exact +2/+2;
- prior calls 36912 and 37062 unchanged;
- Acquisition V2/V3 54/55;
- V3 deterministic hash `3223caf0ec5d1b264c4494775c6f7d58`;
- duplicates 0; post-sale 0;
- Attribution V2 126 / S/45,158.70 unchanged;
- Attribution V3 173 / S/66,644.10 unchanged;
- REV-F5 remains 7,064/15,498 and 3,950 clusters, 0 members/preview/apply;
- idempotency predicates: 0 Mireya inserts / 0 inferred inserts / 0 Agenda links pending;
- frontend `app/**` unchanged; current generic manual flow still emits LLAMADA and therefore retains legacy cleanup behavior until Loop 6.

Result: functional Loop 5 gates PASS; GitHub/Notion final merge/readback pending.
