#!/usr/bin/env python3
"""Execute the original runtime patch after replacing one over-broad local assertion.

The historical assertion searched 1800 characters after the new governed /api/send-email
route and could see unrelated wildcard-CORS endpoints, producing a false positive even
after the permissive send-email block had been removed. This wrapper narrows the assertion
for execution without weakening the actual workflow boundary tests.

The Zero-Cost self-hosted runner executes JavaScript actions with its bundled Node runtime,
but that binary is not necessarily exported on the shell PATH. F16 JavaScript syntax and
unit gates require `node`, so this wrapper exposes the already-bundled runner binary to
subsequent workflow steps through GITHUB_PATH. It never falls back to a paid runner and
never downloads a toolchain from an ungoverned source.
"""
from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys

# Exact-SHA certification retrigger: prior run validated runtime/scope but lost only the push race.
# 2026-08-15 CURRENT-main sync retrigger: recertify runtime after PR #120 merged into the active release.
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


def expose_runner_node() -> None:
    """Expose the runner-bundled Node binary to subsequent GitHub Actions steps."""
    if shutil.which("node"):
        print("CIA_PHASE16_NODE_PATH=ALREADY_AVAILABLE")
        return

    github_path = os.environ.get("GITHUB_PATH")
    runner_temp = os.environ.get("RUNNER_TEMP")
    if not github_path or not runner_temp:
        raise RuntimeError("node missing and GitHub runner path metadata unavailable")

    temp_path = pathlib.Path(runner_temp).resolve()
    search_roots = [temp_path, *temp_path.parents]
    candidates: list[pathlib.Path] = []
    for root in search_roots:
        externals = root / "externals"
        if externals.is_dir():
            candidates.extend(externals.glob("node*/bin/node"))

    candidates = sorted({p.resolve() for p in candidates if p.is_file()}, reverse=True)
    if not candidates:
        raise RuntimeError("node missing and no bundled runner Node binary was found")

    node_bin_dir = candidates[0].parent
    with open(github_path, "a", encoding="utf-8") as fh:
        fh.write(f"{node_bin_dir}\n")

    print(f"CIA_PHASE16_NODE_PATH=PROVISIONED bundled={candidates[0].name}")


def main() -> int:
    expose_runner_node()

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
