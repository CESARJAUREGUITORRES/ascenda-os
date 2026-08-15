# F4 Auth transport same-origin hotfix — 2026-08-15

Production diagnostics proved Auth V3 sessions, grants, aos_cartera_gateway and aos_sales_intelligence_gateway are healthy. Both RPCs succeeded under role anon with transactional synthetic strong tokens and rollback. The production failure boundary is browser/direct-PostgREST token transport.

Fix: read-only same-origin routes /api/f4/cartera-read and /api/f4/sales-intelligence-read in server-f4; browser sends X-AOS-App-Token; server forwards p_token with anon transport; existing RPC remains authorization authority. Panels recover the app token from aos-phase2-auth cache if sessionStorage is absent. No service-role exposure, no sale/payment/patient/debt write, and no legacy cutover.
