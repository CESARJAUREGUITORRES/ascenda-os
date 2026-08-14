#!/usr/bin/env python3
"""Static safety gate for Sales Intelligence Phase A migrations."""
from __future__ import annotations

import re
import sys
from pathlib import Path

if len(sys.argv) < 2:
    raise SystemExit("usage: check_migration_contract.py MIGRATION...")

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    sql = path.read_text(encoding="utf-8")
    normalized = re.sub(r"--.*?$", "", sql, flags=re.MULTILINE)
    upper = normalized.upper()

    required = ["SECURITY INVOKER", "STABLE", "AOS_SALES_INTELLIGENCE_SUMMARY"]
    for token in required:
        if token not in upper:
            raise SystemExit(f"{path}: missing required contract token {token}")

    forbidden = [
        r"\bINSERT\s+INTO\s+PUBLIC\.AOS_VENTAS\b",
        r"\bUPDATE\s+PUBLIC\.AOS_VENTAS\b",
        r"\bDELETE\s+FROM\s+PUBLIC\.AOS_VENTAS\b",
        r"\bTRUNCATE\s+(TABLE\s+)?PUBLIC\.AOS_VENTAS\b",
        r"\bALTER\s+TABLE\s+PUBLIC\.AOS_VENTAS\b",
        r"\bDROP\s+TABLE\s+PUBLIC\.AOS_VENTAS\b",
    ]
    for pattern in forbidden:
        if re.search(pattern, upper):
            raise SystemExit(f"{path}: read-only contract violated by {pattern}")

    print(f"Read-only migration contract PASS: {path}")

final_sql = Path(sys.argv[-1]).read_text(encoding="utf-8")
if "v.*" in final_sql or "V.*" in final_sql:
    raise SystemExit("final optimized migration must not select v.*")
print("Narrow-column optimization contract PASS")
