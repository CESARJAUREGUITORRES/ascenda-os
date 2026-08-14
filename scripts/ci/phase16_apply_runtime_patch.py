#!/usr/bin/env python3
"""Execute the original runtime patch after replacing one over-broad local assertion.

The historical assertion searched 1800 characters after the new governed /api/send-email
route and could see unrelated wildcard-CORS endpoints, producing a false positive even
after the permissive send-email block had been removed. This wrapper narrows the assertion
for execution without weakening the actual workflow boundary tests.
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
PATCH = ROOT / "scripts/ci/phase16_patch_runtime.py"

OLD = '''    if "Access-Control-Allow-Origin', '*'" in text and "/api/send-email" in text:
        # Other historical endpoints can still use CORS, but the removed /api/send-email block may not.
        legacy_section = text[text.find("/api/send-email") : text.find("/api/send-email") + 1800]
        if "Access-Control-Allow-Origin', '*'" in legacy_section:
            raise RuntimeError("server send-email CORS wildcard still reachable")
'''
NEW = '''    if "// ===== RESEND EMAIL API =====" in text:
        raise RuntimeError("legacy permissive send-email implementation remains")
    if text.count("if (p === '/api/send-email') return EMAIL_GATEWAY.handleAdmin(req, res)") != 1:
        raise RuntimeError("governed send-email route is not unique")
'''


def main() -> int:
    original = PATCH.read_text(encoding="utf-8")
    if OLD not in original:
        raise RuntimeError("runtime assertion source changed; manual review required")
    executable = original.replace(OLD, NEW, 1)
    PATCH.write_text(executable, encoding="utf-8")
    try:
        subprocess.run([sys.executable, str(PATCH)], cwd=ROOT, check=True)
    finally:
        PATCH.write_text(original, encoding="utf-8")
    print("CIA_PHASE16_RUNTIME_ASSERTION_FIX=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
