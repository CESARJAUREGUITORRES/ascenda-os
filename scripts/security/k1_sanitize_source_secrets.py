from pathlib import Path
import re
import sys

p = Path('app/server.js')
s = p.read_text(encoding='utf-8')

# Never print matched values. Only report deterministic replacement counts.
verify_pattern = re.compile(r"const\s+VERIFY_TOKEN\s*=\s*'[^']*'")
resend_pattern = re.compile(r"process\.env\.RESEND_API_KEY\s*\|\|\s*'[^']+'")

s, verify_count = verify_pattern.subn(
    "const VERIFY_TOKEN = process.env.META_VERIFY_TOKEN || '__DISABLED__'",
    s,
    count=1,
)
s, resend_count = resend_pattern.subn("process.env.RESEND_API_KEY || ''", s)

if verify_count != 1:
    raise SystemExit(f'K1 sanitizer: expected exactly 1 VERIFY_TOKEN fallback, got {verify_count}')
if resend_count < 1:
    raise SystemExit(f'K1 sanitizer: expected at least 1 Resend hardcoded fallback, got {resend_count}')
if verify_pattern.search(s):
    raise SystemExit('K1 sanitizer: VERIFY_TOKEN hardcoded fallback survived')
if resend_pattern.search(s):
    raise SystemExit('K1 sanitizer: Resend hardcoded fallback survived')

p.write_text(s, encoding='utf-8')
print(f'K1_SOURCE_SECRET_SANITIZE=PASS verify={verify_count} resend={resend_count}')
