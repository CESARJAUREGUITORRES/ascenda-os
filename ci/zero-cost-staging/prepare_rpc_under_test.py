#!/usr/bin/env python3
"""Compile the final Sales Intelligence RPC into the isolated zcs schema for CI."""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: prepare_rpc_under_test.py INPUT_MIGRATION OUTPUT_SQL")

src = Path(sys.argv[1]).read_text(encoding="utf-8")

required = [
    "public.aos_sales_intelligence_summary",
    "public.aos_ventas",
    "public.aos_metas_ventas",
    "SECURITY INVOKER",
]
for token in required:
    if token not in src:
        raise SystemExit(f"required contract token missing: {token}")

out = src
out = out.replace("public.aos_sales_intelligence_summary", "zcs.aos_sales_intelligence_summary")
out = out.replace("public.aos_ventas", "zcs.aos_ventas")
out = out.replace("public.aos_metas_ventas", "zcs.aos_metas_ventas")
out = out.replace("SET search_path = public, pg_temp", "SET search_path = zcs, public, pg_temp")

Path(sys.argv[2]).write_text(out, encoding="utf-8")
print(f"Prepared isolated RPC test artifact: {sys.argv[2]}")
