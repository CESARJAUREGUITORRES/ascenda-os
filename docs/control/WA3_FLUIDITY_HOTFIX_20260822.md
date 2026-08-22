# WA-3 Fluidity Hotfix — 2026-08-22

## Physical canary evidence
- CESAR admin reassigned `zi vital` to MIREYA.
- MIREYA had PASSWORD_2FA, `whatsapp-agent`, active VENTAS_GENERAL membership and AVAILABLE presence.
- Ownership moved to MIREYA; CESAR became non-owner and human send was blocked for CESAR.
- MIREYA sent `mireya 2`; Meta accepted it and the message reached `delivered`.
- Release to queue removed the conversation from MIREYA as expected.

## Defects discovered
1. A post-release `WA3_NOT_OWNER` 403 from the timeline was misclassified by the native panel as a lost 2FA session, replacing the Hub with a false `Sesión 2FA requerida` screen.
2. Advisor presence changes could take up to 30 seconds to appear in the admin team view.
3. Admin assignment UI did not explain that AWAY/OFFLINE advisors are intentionally unavailable for new ownership.
4. Human owner was not prominent enough in the conversation list/header.
5. Successful Meta sends displayed provider acceptance IDs as advisor-facing green toast noise.

## Hotfix contract
- Preserve `WA3_NOT_OWNER` as a security denial, but treat it as ownership revocation in the client: remount inbox without showing an authentication failure.
- Refresh multiagent/team state every 5 seconds; AVAILABLE heartbeat every 20 seconds.
- Mark unavailable owner options as AUSENTE/OFFLINE and disable them for new assignments.
- Add `ADMIN · <name>`, `ASESOR · <name>`, `BOT`, or `SIN ASIGNAR` badges.
- Suppress only the successful `Meta aceptó el mensaje ...` toast; error toasts remain visible.
- No routing, Meta, AI, RLS, message-store or notification contract changes.
