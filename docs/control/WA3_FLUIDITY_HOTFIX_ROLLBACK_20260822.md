# WA-3 Fluidity Hotfix Rollback

Rollback is UI-only:
1. restore previous `wa-multiagent-v2-panel.js`;
2. restore previous `MULTI_SRC` cache key in `wa-shell-integration.js`;
3. restore previous `ui_contract_v2.js` assertions.

No database rollback is required because this hotfix introduces no DDL/DML or routing contract change.
