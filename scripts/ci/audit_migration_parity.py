#!/usr/bin/env python3
from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"
SNAPSHOT = ROOT / "docs" / "control" / "snapshots" / "migration_ledger_prod_20260815_20260817.txt"
REPORT = ROOT / "docs" / "control" / "MIGRATION_PARITY_AUDIT_20260817.md"
VERSION_RE = re.compile(r"^(\d{14})_(.+)\.sql$")
SCOPE_MIN = "20260815000000"


def read_remote() -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for raw in SNAPSHOT.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        version, name = line.split("|", 1)
        if not (len(version) == 14 and version.isdigit() and name):
            raise SystemExit(f"invalid snapshot row: {line!r}")
        rows.append((version, name))
    if len(rows) != len(set(rows)):
        raise SystemExit("duplicate production ledger rows in snapshot")
    return rows


def read_local() -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    for path in sorted(MIGRATIONS.glob("*.sql")):
        match = VERSION_RE.match(path.name)
        if not match:
            continue
        version, name = match.groups()
        if version >= SCOPE_MIN:
            rows.append((version, name, path.as_posix().split("/supabase/", 1)[-1]))
    return rows


def main() -> int:
    remote = read_remote()
    local = read_local()

    local_by_version: dict[str, tuple[str, str]] = {}
    local_by_name: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for version, name, path in local:
        if version in local_by_version:
            raise SystemExit(f"duplicate local migration version {version}")
        local_by_version[version] = (name, path)
        local_by_name[name].append((version, path))

    remote_by_version = {version: name for version, name in remote}
    remote_by_name: dict[str, list[str]] = defaultdict(list)
    for version, name in remote:
        remote_by_name[name].append(version)

    exact: list[tuple[str, str, str]] = []
    same_name_diff: list[tuple[str, str, str, str]] = []
    version_name_conflict: list[tuple[str, str, str, str]] = []
    remote_only: list[tuple[str, str]] = []

    for version, name in remote:
        local_exact = local_by_version.get(version)
        if local_exact:
            local_name, path = local_exact
            if local_name == name:
                exact.append((version, name, path))
            else:
                version_name_conflict.append((version, name, local_name, path))
            continue
        matches = local_by_name.get(name, [])
        if len(matches) == 1:
            local_version, path = matches[0]
            same_name_diff.append((name, version, local_version, path))
        else:
            remote_only.append((version, name))

    local_only: list[tuple[str, str, str]] = []
    for version, name, path in local:
        if version in remote_by_version:
            continue
        if name in remote_by_name:
            # Already represented as SAME_NAME_DIFFERENT_VERSION.
            continue
        local_only.append((version, name, path))

    lines = [
        "# ASCENDA OS — Migration History Parity Audit",
        "",
        "**Mode:** read-only / offline comparison against frozen production ledger snapshot  ",
        "**Scope:** versions `>= 20260815000000`  ",
        f"**Remote rows:** {len(remote)}  ",
        f"**Local rows in scope:** {len(local)}  ",
        "",
        "## Summary",
        "",
        f"- EXACT: **{len(exact)}**",
        f"- SAME_NAME_DIFFERENT_VERSION: **{len(same_name_diff)}**",
        f"- VERSION_NAME_CONFLICT: **{len(version_name_conflict)}**",
        f"- REMOTE_ONLY: **{len(remote_only)}**",
        f"- LOCAL_ONLY: **{len(local_only)}**",
        "",
        "`SAME_NAME_DIFFERENT_VERSION` is a candidate for filename/history reconciliation only after content identity is proven. `REMOTE_ONLY` may be active concurrent work and must never be blindly deleted or replayed.",
        "",
        "## SAME_NAME_DIFFERENT_VERSION",
        "",
        "| Migration | Production version | Repository version | Local path |",
        "|---|---:|---:|---|",
    ]
    for name, remote_version, local_version, path in same_name_diff:
        lines.append(f"| `{name}` | `{remote_version}` | `{local_version}` | `{path}` |")
    if not same_name_diff:
        lines.append("| — | — | — | — |")

    lines += [
        "",
        "## VERSION_NAME_CONFLICT",
        "",
        "| Version | Production name | Local name | Local path |",
        "|---:|---|---|---|",
    ]
    for version, remote_name, local_name, path in version_name_conflict:
        lines.append(f"| `{version}` | `{remote_name}` | `{local_name}` | `{path}` |")
    if not version_name_conflict:
        lines.append("| — | — | — | — |")

    lines += [
        "",
        "## REMOTE_ONLY",
        "",
        "| Production version | Production name |",
        "|---:|---|",
    ]
    for version, name in remote_only:
        lines.append(f"| `{version}` | `{name}` |")
    if not remote_only:
        lines.append("| — | — |")

    lines += [
        "",
        "## LOCAL_ONLY",
        "",
        "| Repository version | Repository name | Local path |",
        "|---:|---|---|",
    ]
    for version, name, path in local_only:
        lines.append(f"| `{version}` | `{name}` | `{path}` |")
    if not local_only:
        lines.append("| — | — | — |")

    lines += [
        "",
        "## Gate",
        "",
        "This audit intentionally does **not** mutate production or Supabase migration history.",
        "",
        "PASS for analysis means the report was generated deterministically. Release parity is not PASS until every non-EXACT row is classified and resolved by its owning workstream, followed by a green Supabase Preview on exact CURRENT head.",
        "",
    ]

    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"PARITY_AUDIT_GENERATED remote={len(remote)} local={len(local)} exact={len(exact)} same_name_diff={len(same_name_diff)} version_name_conflict={len(version_name_conflict)} remote_only={len(remote_only)} local_only={len(local_only)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
