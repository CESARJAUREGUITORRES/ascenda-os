# Marketing Read Latency P0 · 2026-09-29

## Trigger
Live admin canary showed Marketing eventually reconciling correctly but with visible blank/loading intervals. Railway/Supabase runtime showed a long `aos_marketing_period_summary_v2` request (~15 s) plus concurrent public booking `/days` fan-out. The legacy `Ver Leads` modal still read `aos_marketing_leads_detalle` directly through the browser path and could inherit the anon statement timeout.

## Changes
- Marketing gateway keeps cache/single-flight but replaces one global read tail with a bounded FIFO lane of **2 concurrent reads**. This prevents a slow summary from blocking every other Marketing surface while still limiting database pressure.
- `aos_marketing_leads_detalle` joins the authenticated Marketing gateway allowlist and browser read shaping.
- Initial operational Marketing hydration starts immediately so KPI, funnel, campaigns, ads and sales do not wait for the deep period-summary chain.
- Visible annual history becomes a priority read; deeper LTV/value-map work remains viewport/quiescence governed.
- Booking connector v1.0.2 coalesces and TTL-caches catalog, professional profiles and monthly available-day reads. Real-time `/availability` and `/book` stay uncached. Successful bookings invalidate day caches.

## Preserved invariants
- No Marketing formulas changed.
- No clinical, lead, booking or sales data is rewritten.
- No new polling/timers are added.
- `aos_agenda_citas` remains booking authority.
- Slot availability and booking writes remain live reads/writes.
- Marketing reads still require same-origin admin session through `/api/marketing/rpc`.

## Canary targets
1. Marketing top KPI/operational blocks become usable before deeper analytics finish.
2. `Ver Leads` loads through the governed server boundary instead of browser anon.
3. `Citas Web` does not sit behind unrelated long Marketing reads.
4. Repeated landing `/days` requests collapse to cache/single-flight and stop multiplying catalog/profile reads.
5. No new 57014/504 burst attributable to normal Marketing + landing usage.
