#!/usr/bin/env python3
from pathlib import Path


def replace_exact(path, old, new, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 occurrence, found {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_exact(
    'app/server.js',
    "const EMAIL_SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''",
    "const EMAIL_SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''",
    'server env alias',
)
replace_exact(
    'app/email-gateway.js',
    "var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || ''))",
    "var serviceKey = String(config.serviceRoleKey != null ? config.serviceRoleKey : (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''))",
    'gateway env alias',
)
print('CIA_PHASE16_ENV_ALIAS_PATCH=PASS')
