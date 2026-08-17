# Sentinel F9-C — Secure Telegram Provisioning — Recovery Checkpoint

**Base:** `main@24a36b64ca85a856a5640f306435405c0b5d92ac`  
**Estado:** `EN CURSO / RECOVERY`  
**Objetivo:** crear un camino owner-only para aprovisionar `Sentinel Owner Alerts` sin exponer bot token/chat target en browser storage, GitHub, logs o chat.

## Restricciones

- no secrets in repo;
- no secrets in URL/query/logs;
- browser never receives stored secret values;
- service_role remains server-side only;
- owner/admin + 2FA gate required before mutation;
- integration metadata remains sanitized;
- vault values are write-only from the UI perspective;
- provider preflight returns booleans/status only;
- live canary is explicit and synthetic only;
- F10 remains blocked until F9 final certificate.

## Recovery tasks

1. inspect existing owner/admin + 2FA server gates;
2. inspect integration metadata/secret boundary;
3. design provisioning endpoint/RPC using current runtime chain;
4. add contracts and synthetic fixtures with fake secrets only;
5. Zero-Cost/security gate;
6. production canary only after real owner-originated Telegram credentials are entered through the secure UI.
