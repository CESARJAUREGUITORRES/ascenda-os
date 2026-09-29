# P0 Auth Background Isolation · 2026-09-28

## Incident
At 23:20 Lima, mobile login requests returned 504/502 while Railway itself remained healthy. Runtime evidence showed Supabase timeouts from `notification-push-claim` and `agent-cron-scan` immediately before `AUTH_UPSTREAM_TIMEOUT`.

## Root cause
The database recovery switch had previously been disabled to restore user-facing Marketing. That also re-enabled server-side notification polling and reminder cron. Those background calls shared the same Supabase/PostgREST capacity as Auth and were allowed to wait long enough to contend with login.

## Fix contract
1. Auth, Call Center, Agenda, Patients and Sales writes are never classified as background traffic.
2. Every classified background request gets a strict transport budget. If it exceeds the budget, the request is aborted locally and the shared background circuit opens before more background work can pile up.
3. The first pressure failure pauses classified background work for 10 minutes; repeated pressure extends the pause to 30 minutes.
4. `AOS_FOREGROUND_PRIORITY_MODE=true` remains an emergency kill-switch that suppresses all classified background work. Reminder cron is no longer exempt from an active emergency recovery mode.
5. Normal mode can remain enabled for user-facing Marketing/analytics; the automatic background circuit is responsible for yielding capacity when Supabase slows down.

## Production mitigation
Before this code change, production was immediately returned to `AOS_FOREGROUND_PRIORITY_MODE=true` and the reminder window was forced out of range so Auth could recover without cron/push contention.

## Exit gate
After deployment: restore normal mode, verify background requests are either healthy within budget or circuit-broken, then certify repeated Auth V3 login while notifications/reminders are enabled.
