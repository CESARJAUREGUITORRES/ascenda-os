# Runtime observation

Live window: 2026-09-29 19:24–19:30 America/Lima.

Observed before this patch:
- Marketing gateway requests included 504s at ~6.3 s and ~15.0 s.
- `aos_marketing_period_summary_v2` reached ~14,997 ms in the live contention window.
- Public booking emitted parallel `/days` requests and repeated catalog/profile lookups.
- Legacy `Ver Leads` still used the direct browser RPC path.

This checkpoint is evidence for the P0 latency changes only; it does not redefine Marketing formulas or booking authority.
