# MKT-INTEGRITY-HOTFIX-V3 — LOOP 5 Final PASS Readback

**Entry blocked main:** `19c326a7f3193ec88dc3ec7755aa29391b091dfd`  
**Functional merge:** PR #296 → `bec9da0d8f114e41632a99cf7732e3949237f760`  
**Result:** `LOOP 5 = PASS`  
**Loop 6:** NOT STARTED

Post-merge production readback confirms:

- 37108 → lead 5664 / MIREYA / `LLAMADA_MANUAL_COMERCIAL`.
- 37110 → lead 5599 / MIREYA / `LLAMADA_MANUAL_COMERCIAL`.
- historical inferred calls 37199, 37200, 37201, 37202 remain present and explicitly marked `INFERIDA_HISTORICA`.
- all six target Agenda rows have direct lead + call links.
- Agenda total remains 3,126.
- Mireya on business date 2026-08-18 = 53 calls / 6 CITA CONFIRMADA; certified delta from immediate pre-apply baseline = +2 / +2.
- prior failed calls 36912 and 37062 remain intact.
- Acquisition V2 = 54.
- Acquisition V3 = 55.
- V3 deterministic hash = `3223caf0ec5d1b264c4494775c6f7d58`.
- duplicate acquisitions = 0.
- post-sale lead attribution = 0.
- Attribution V2 = 126 ops / S/45,158.70.
- Attribution V3 = 173 ops / S/66,644.10.
- REV-F5 = 7,064 / 15,498; 3,950 clusters; 0 members/preview/apply.
- cleanup function hash = `a6f918f64ac56f587a75ed0aebde0e09`.
- no frontend `app/**` cutover or Loop-6 implementation occurred.

The historical inferred-call rule is now explicit: only a prior Marketing lead + no call through first conversion + no prior conversion before the lead qualifies. Proxy date/time are visibly marked and do not masquerade as observed timestamps.

**LOOP 5 = PASS.**

**LOOP 6 = NOT STARTED.**
