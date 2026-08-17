#!/usr/bin/env python3
from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import hashlib
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"
SNAPSHOT = ROOT / "docs" / "control" / "snapshots" / "migration_ledger_prod_20260815_20260817_hashes.txt"
REPORT = ROOT / "docs" / "control" / "MIGRATION_PARITY_AUDIT_20260817.md"
VERSION_RE = re.compile(r"^(\d{14})_(.+)\.sql$")
SCOPE_MIN = "20260815000000"


def md5_bytes(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def read_remote() -> list[tuple[str, str, int, str]]:
    rows: list[tuple[str, str, int, str]] = []
    for raw in SNAPSHOT.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) != 4:
            raise SystemExit(f"invalid snapshot row: {line!r}")
        version, name, statement_count_raw, statement_md5 = parts
        if not (len(version) == 14 and version.isdigit() and name):
            raise SystemExit(f"invalid snapshot identity: {line!r}")
        if not statement_count_raw.isdigit():
            raise SystemExit(f"invalid statement_count: {line!r}")
        if not re.fullmatch(r"[0-9a-f]{32}", statement_md5):
            raise SystemExit(f"invalid statement md5: {line!r}")
        rows.append((version, name, int(statement_count_raw), statement_md5))
    identities = [(version, name) for version, name, _, _ in rows]
    if len(identities) != len(set(identities)):
        raise SystemExit("duplicate production ledger identities in snapshot")
    return rows


def read_local_all() -> list[tuple[str, str, str, str]]:
    rows: list[tuple[str, str, str, str]] = []
    for path in sorted(MIGRATIONS.glob("*.sql")):
        match = VERSION_RE.match(path.name)
        if not match:
            continue
        version, name = match.groups()
        rows.append((version, name, path.relative_to(ROOT).as_posix(), md5_bytes(path)))
    return rows


def main() -> int:
    remote = read_remote()
    local_all = read_local_all()
    local_scope = [row for row in local_all if row[0] >= SCOPE_MIN]

    local_by_version: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    local_by_name: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    local_by_hash: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    for version, name, path, digest in local_all:
        local_by_version[version].append((name, path, digest))
        local_by_name[name].append((version, path, digest))
        local_by_hash[digest].append((version, name, path))

    duplicate_local_versions = {
        version: entries for version, entries in local_by_version.items() if len(entries) > 1
    }

    remote_versions = {version for version, _, _, _ in remote}
    remote_names = {name for _, name, _, _ in remote}
    used_paths: set[str] = set()

    exact_content: list[tuple[str, str, str]] = []
    exact_version_content_mismatch: list[tuple[str, str, str, str, str]] = []
    content_exact_version_drift: list[tuple[str, str, str, str, str]] = []
    content_exact_name_version_drift: list[tuple[str, str, str, str, str]] = []
    version_name_conflict: list[tuple[str, str, str, str, str]] = []
    name_match_content_mismatch: list[tuple[str, str, str, str, str]] = []
    ambiguous_content_match: list[tuple[str, str, int]] = []
    unsupported_statement_count: list[tuple[str, str, int]] = []
    remote_only: list[tuple[str, str]] = []

    for version, name, statement_count, remote_md5 in remote:
        if statement_count != 1:
            unsupported_statement_count.append((version, name, statement_count))
            continue

        exact_version_entries = local_by_version.get(version, [])
        exact_identity_entries = [
            (local_name, path, digest)
            for local_name, path, digest in exact_version_entries
            if local_name == name
        ]
        if exact_identity_entries:
            if len(exact_identity_entries) == 1:
                _, path, local_md5 = exact_identity_entries[0]
                used_paths.add(path)
                if local_md5 == remote_md5:
                    exact_content.append((version, name, path))
                else:
                    exact_version_content_mismatch.append((version, name, path, remote_md5, local_md5))
            else:
                ambiguous_content_match.append((version, name, len(exact_identity_entries)))
            continue

        if exact_version_entries:
            for local_name, path, digest in exact_version_entries:
                version_name_conflict.append((version, name, local_name, path, digest))

        same_name_entries = local_by_name.get(name, [])
        same_name_content = [entry for entry in same_name_entries if entry[2] == remote_md5]
        if len(same_name_content) == 1:
            local_version, path, _ = same_name_content[0]
            used_paths.add(path)
            content_exact_version_drift.append((name, version, local_version, path, remote_md5))
            continue
        if len(same_name_content) > 1:
            ambiguous_content_match.append((version, name, len(same_name_content)))
            continue
        if same_name_entries:
            # Record every same-name candidate because a materializer may have changed content.
            for local_version, path, local_md5 in same_name_entries:
                name_match_content_mismatch.append((name, version, local_version, path, local_md5))
            continue

        any_content = local_by_hash.get(remote_md5, [])
        if len(any_content) == 1:
            local_version, local_name, path = any_content[0]
            used_paths.add(path)
            content_exact_name_version_drift.append((name, version, local_name, local_version, path))
            continue
        if len(any_content) > 1:
            ambiguous_content_match.append((version, name, len(any_content)))
            continue

        remote_only.append((version, name))

    local_only: list[tuple[str, str, str, str]] = []
    for version, name, path, digest in local_scope:
        if path in used_paths:
            continue
        if version in remote_versions and name in remote_names:
            continue
        local_only.append((version, name, path, digest))

    lines = [
        "# ASCENDA OS — Migration History Parity Audit",
        "",
        "**Mode:** read-only / offline content comparison against frozen production ledger hashes  ",
        "**Remote scope:** versions `>= 20260815000000`  ",
        f"**Remote rows:** {len(remote)}  ",
        f"**Local rows scanned (all history):** {len(local_all)}  ",
        f"**Local rows in recent scope:** {len(local_scope)}  ",
        "",
        "## Summary",
        "",
        f"- EXACT_CONTENT: **{len(exact_content)}**",
        f"- CONTENT_EXACT_VERSION_DRIFT: **{len(content_exact_version_drift)}**",
        f"- CONTENT_EXACT_NAME_AND_VERSION_DRIFT: **{len(content_exact_name_version_drift)}**",
        f"- EXACT_VERSION_CONTENT_MISMATCH: **{len(exact_version_content_mismatch)}**",
        f"- NAME_MATCH_CONTENT_MISMATCH: **{len(name_match_content_mismatch)}**",
        f"- VERSION_NAME_CONFLICT: **{len(version_name_conflict)}**",
        f"- AMBIGUOUS_CONTENT_MATCH: **{len(ambiguous_content_match)}**",
        f"- UNSUPPORTED_STATEMENT_COUNT: **{len(unsupported_statement_count)}**",
        f"- REMOTE_ONLY: **{len(remote_only)}**",
        f"- LOCAL_ONLY: **{len(local_only)}**",
        f"- DUPLICATE_LOCAL_VERSION: **{len(duplicate_local_versions)}**",
        "",
        "Only `CONTENT_EXACT_VERSION_DRIFT` is an automatic candidate for filename/version reconciliation after owner/drift checks. `CONTENT_EXACT_NAME_AND_VERSION_DRIFT` proves identical SQL but also a name change, so it remains manual. Any content mismatch or ambiguity is blocked from automatic repair.",
        "",
        "## CONTENT_EXACT_VERSION_DRIFT",
        "",
        "| Migration | Production version | Repository version | Local path | Statement MD5 |",
        "|---|---:|---:|---|---|",
    ]
    for name, remote_version, local_version, path, digest in content_exact_version_drift:
        lines.append(f"| `{name}` | `{remote_version}` | `{local_version}` | `{path}` | `{digest}` |")
    if not content_exact_version_drift:
        lines.append("| — | — | — | — | — |")

    lines += [
        "",
        "## CONTENT_EXACT_NAME_AND_VERSION_DRIFT",
        "",
        "| Production migration | Production version | Repository migration | Repository version | Local path |",
        "|---|---:|---|---:|---|",
    ]
    for remote_name, remote_version, local_name, local_version, path in content_exact_name_version_drift:
        lines.append(f"| `{remote_name}` | `{remote_version}` | `{local_name}` | `{local_version}` | `{path}` |")
    if not content_exact_name_version_drift:
        lines.append("| — | — | — | — | — |")

    lines += [
        "",
        "## EXACT_VERSION_CONTENT_MISMATCH",
        "",
        "| Version | Migration | Local path | Production MD5 | Local MD5 |",
        "|---:|---|---|---|---|",
    ]
    for version, name, path, remote_md5, local_md5 in exact_version_content_mismatch:
        lines.append(f"| `{version}` | `{name}` | `{path}` | `{remote_md5}` | `{local_md5}` |")
    if not exact_version_content_mismatch:
        lines.append("| — | — | — | — | — |")

    lines += [
        "",
        "## NAME_MATCH_CONTENT_MISMATCH",
        "",
        "| Migration | Production version | Repository version | Local path | Local MD5 |",
        "|---|---:|---:|---|---|",
    ]
    for name, remote_version, local_version, path, local_md5 in name_match_content_mismatch:
        lines.append(f"| `{name}` | `{remote_version}` | `{local_version}` | `{path}` | `{local_md5}` |")
    if not name_match_content_mismatch:
        lines.append("| — | — | — | — | — |")

    lines += [
        "",
        "## VERSION_NAME_CONFLICT",
        "",
        "| Version | Production name | Local name | Local path | Local MD5 |",
        "|---:|---|---|---|---|",
    ]
    for version, remote_name, local_name, path, local_md5 in version_name_conflict:
        lines.append(f"| `{version}` | `{remote_name}` | `{local_name}` | `{path}` | `{local_md5}` |")
    if not version_name_conflict:
        lines.append("| — | — | — | — | — |")

    lines += [
        "",
        "## AMBIGUOUS_CONTENT_MATCH",
        "",
        "| Production version | Migration | Matching local candidates |",
        "|---:|---|---:|",
    ]
    for version, name, count in ambiguous_content_match:
        lines.append(f"| `{version}` | `{name}` | `{count}` |")
    if not ambiguous_content_match:
        lines.append("| — | — | — |")

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
        "| Repository version | Repository name | Local path | Local MD5 |",
        "|---:|---|---|---|",
    ]
    for version, name, path, digest in local_only:
        lines.append(f"| `{version}` | `{name}` | `{path}` | `{digest}` |")
    if not local_only:
        lines.append("| — | — | — | — |")

    lines += [
        "",
        "## DUPLICATE_LOCAL_VERSION",
        "",
        "| Version | Local entries |",
        "|---:|---|",
    ]
    for version, entries in sorted(duplicate_local_versions.items()):
        detail = "; ".join(f"`{name}` → `{path}`" for name, path, _ in entries)
        lines.append(f"| `{version}` | {detail} |")
    if not duplicate_local_versions:
        lines.append("| — | — |")

    lines += [
        "",
        "## UNSUPPORTED_STATEMENT_COUNT",
        "",
        "| Production version | Migration | Statement count |",
        "|---:|---|---:|",
    ]
    for version, name, count in unsupported_statement_count:
        lines.append(f"| `{version}` | `{name}` | `{count}` |")
    if not unsupported_statement_count:
        lines.append("| — | — | — |")

    lines += [
        "",
        "## Gate",
        "",
        "This audit intentionally does **not** mutate production or Supabase migration history.",
        "",
        "Analysis PASS means the report was generated deterministically from a read-only production statement-hash snapshot. Release parity remains blocked until every non-exact row is resolved by its owning workstream and Supabase Preview is green on exact CURRENT head.",
        "",
    ]

    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(
        "PARITY_AUDIT_GENERATED "
        f"remote={len(remote)} local_all={len(local_all)} local_scope={len(local_scope)} "
        f"exact_content={len(exact_content)} content_exact_version_drift={len(content_exact_version_drift)} "
        f"content_exact_name_version_drift={len(content_exact_name_version_drift)} "
        f"exact_version_content_mismatch={len(exact_version_content_mismatch)} "
        f"remote_only={len(remote_only)} local_only={len(local_only)} "
        f"duplicate_local_version={len(duplicate_local_versions)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
