#!/usr/bin/env python3
from pathlib import Path


def ensure_alias(path, old, new, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 1 and new_count == 0:
        p.write_text(text.replace(old, new, 1), encoding='utf-8')
        print(f'{label}=APPLIED')
        return
    if old_count == 0 and new_count == 1:
        print(f'{label}=ALREADY_MATERIALIZED')
        return
    raise SystemExit(f'{label}: invalid state old={old_count} new={new_count}')


ensure_alias(
    'app/server.js',
    "const EMAIL_SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''",
    "const EMAIL_SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''",
    'CIA_PHASE16_SERVER_ENV_ALIAS',
)
ensure_alias(
    'app/email-gateway.js',
    "var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || ''))",
    "var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''))",
    'CIA_PHASE16_GATEWAY_ENV_ALIAS',
)
print('CIA_PHASE16_ENV_ALIAS_PATCH=PASS')
