#!/usr/bin/env python3
from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"
SNAPSHOT = ROOT / "docs" / "control" / "snapshots" / "migration_ledger_prod_20260815_20260817_hashes.txt"
REPORT = ROOT / "docs" / "control" / "MIGRATION_PARITY_AUDIT_CURRENT.md"
SUMMARY = ROOT / "docs" / "control" / "snapshots" / "migration_parity_current_summary.json"
VERSION_RE = re.compile(r"^(\d{14})_(.+)\.sql$")
SCOPE_MIN = "20260815000000"


def md5_file(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def remote_rows():
    rows=[]
    for raw in SNAPSHOT.read_text(encoding="utf-8").splitlines():
        line=raw.strip()
        if not line or line.startswith("#"):
            continue
        version,name,count,digest=line.split("|")
        rows.append((version,name,int(count),digest))
    return rows


def local_rows():
    rows=[]
    for path in sorted(MIGRATIONS.glob("*.sql")):
        m=VERSION_RE.match(path.name)
        if m:
            version,name=m.groups()
            rows.append((version,name,path.relative_to(ROOT).as_posix(),md5_file(path)))
    return rows


def main():
    remote=remote_rows()
    local=local_rows()
    by_version=defaultdict(list)
    by_name=defaultdict(list)
    by_hash=defaultdict(list)
    for version,name,path,digest in local:
        by_version[version].append((name,path,digest))
        by_name[name].append((version,path,digest))
        by_hash[digest].append((version,name,path))

    duplicate_versions={k:v for k,v in by_version.items() if len(v)>1}
    exact=[]
    version_content_mismatch=[]
    exact_version_drift=[]
    exact_name_version_drift=[]
    name_content_mismatch=[]
    version_name_conflict=[]
    ambiguous=[]
    unsupported=[]
    remote_only=[]
    used=set()

    for rv,rn,count,rh in remote:
        if count != 1:
            unsupported.append((rv,rn,count)); continue
        identity=[x for x in by_version.get(rv,[]) if x[0]==rn]
        if len(identity)==1:
            _,path,lh=identity[0]; used.add(path)
            if lh==rh: exact.append((rv,rn,path,rh))
            else: version_content_mismatch.append((rv,rn,path,rh,lh))
            continue
        if len(identity)>1:
            ambiguous.append((rv,rn,"exact-identity",len(identity))); continue
        if by_version.get(rv):
            for ln,path,lh in by_version[rv]:
                version_name_conflict.append((rv,rn,ln,path,lh))
        same_name=by_name.get(rn,[])
        same_hash=[x for x in same_name if x[2]==rh]
        if len(same_hash)==1:
            lv,path,_=same_hash[0]; used.add(path)
            exact_version_drift.append((rn,rv,lv,path,rh)); continue
        if len(same_hash)>1:
            ambiguous.append((rv,rn,"same-name-hash",len(same_hash))); continue
        if same_name:
            for lv,path,lh in same_name:
                name_content_mismatch.append((rn,rv,lv,path,rh,lh))
            continue
        any_hash=by_hash.get(rh,[])
        if len(any_hash)==1:
            lv,ln,path=any_hash[0]; used.add(path)
            exact_name_version_drift.append((rn,rv,ln,lv,path,rh)); continue
        if len(any_hash)>1:
            ambiguous.append((rv,rn,"any-hash",len(any_hash))); continue
        remote_only.append((rv,rn,rh))

    remote_versions={x[0] for x in remote}
    remote_names={x[1] for x in remote}
    local_only=[]
    for version,name,path,digest in local:
        if version < SCOPE_MIN or path in used:
            continue
        if version in remote_versions and name in remote_names:
            continue
        local_only.append((version,name,path,digest))

    summary={
        "remote_rows":len(remote),
        "local_rows_all":len(local),
        "exact_content":len(exact),
        "content_exact_version_drift":len(exact_version_drift),
        "content_exact_name_and_version_drift":len(exact_name_version_drift),
        "exact_version_content_mismatch":len(version_content_mismatch),
        "name_match_content_mismatch":len(name_content_mismatch),
        "version_name_conflict":len(version_name_conflict),
        "ambiguous_content_match":len(ambiguous),
        "unsupported_statement_count":len(unsupported),
        "remote_only":len(remote_only),
        "local_only":len(local_only),
        "duplicate_local_version":len(duplicate_versions),
    }
    SUMMARY.parent.mkdir(parents=True,exist_ok=True)
    SUMMARY.write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n",encoding="utf-8")

    lines=[
        "# ASCENDA OS — Migration History Parity Audit CURRENT",
        "",
        f"**CURRENT source tree:** generated from `{MIGRATIONS.relative_to(ROOT)}` on the audit branch based on `main@f68b5c0efe3765af8ea8abd0760af29cd13928df`.",
        "**Production evidence:** read-only frozen `supabase_migrations.schema_migrations` versions >= `20260815000000`.",
        "",
        "## Summary",
        "",
    ]
    for k,v in summary.items():
        lines.append(f"- `{k}`: **{v}**")

    def table(title, headers, rows):
        lines.extend(["",f"## {title}","","|"+"|".join(headers)+"|","|"+"|".join(["---"]*len(headers))+"|"])
        if not rows:
            lines.append("|"+"|".join(["—"]*len(headers))+"|")
        else:
            for row in rows:
                lines.append("|"+"|".join(f"`{x}`" for x in row)+"|")

    table("CONTENT_EXACT_VERSION_DRIFT",["name","prod_version","local_version","path","md5"],exact_version_drift)
    table("EXACT_VERSION_CONTENT_MISMATCH",["version","name","path","prod_md5","local_md5"],version_content_mismatch)
    table("NAME_MATCH_CONTENT_MISMATCH",["name","prod_version","local_version","path","prod_md5","local_md5"],name_content_mismatch)
    table("CONTENT_EXACT_NAME_AND_VERSION_DRIFT",["prod_name","prod_version","local_name","local_version","path","md5"],exact_name_version_drift)
    table("VERSION_NAME_CONFLICT",["version","prod_name","local_name","path","local_md5"],version_name_conflict)
    table("REMOTE_ONLY",["prod_version","prod_name","prod_md5"],remote_only)
    table("LOCAL_ONLY",["local_version","local_name","path","local_md5"],local_only)
    table("AMBIGUOUS_CONTENT_MATCH",["prod_version","name","class","count"],ambiguous)
    table("DUPLICATE_LOCAL_VERSION",["version","entries"],[(v,"; ".join(f"{n}:{p}" for n,p,_ in entries)) for v,entries in sorted(duplicate_versions.items())])
    lines.extend(["","## Gate","","Automatic repair is permitted only for `CONTENT_EXACT_VERSION_DRIFT` after owner/current checks. Content mismatches, remote-only rows, transient F5 transport rows and ambiguous matches remain fail-closed.",""])
    REPORT.parent.mkdir(parents=True,exist_ok=True)
    REPORT.write_text("\n".join(lines),encoding="utf-8")
    print("MIGRATION_PARITY_CURRENT="+json.dumps(summary,sort_keys=True))

if __name__=="__main__":
    main()
