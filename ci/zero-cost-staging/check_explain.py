#!/usr/bin/env python3
"""Fail CI when the isolated Sales Intelligence plan exceeds conservative limits."""
from __future__ import annotations

import json
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: check_explain.py PLAN_JSON")

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
root = payload[0]
execution_ms = float(root.get("Execution Time", 0.0))


def sum_buffers(node):
    total = int(node.get("Shared Hit Blocks", 0) or 0) + int(node.get("Shared Read Blocks", 0) or 0)
    for child in node.get("Plans", []) or []:
        total += sum_buffers(child)
    return total

buffers = sum_buffers(root.get("Plan", {}))
max_ms = 250.0
max_buffers = 1500

print(f"Sales Intelligence performance: execution={execution_ms:.3f}ms buffers={buffers}")
print(f"Gate limits: execution<={max_ms:.0f}ms buffers<={max_buffers}")

if execution_ms > max_ms:
    raise SystemExit(f"performance gate failed: {execution_ms:.3f}ms > {max_ms:.0f}ms")
if buffers > max_buffers:
    raise SystemExit(f"buffer gate failed: {buffers} > {max_buffers}")
