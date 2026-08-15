#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / '.github' / 'workflows'
errors = []

hosted_patterns = (
    'ubuntu-latest',
    'windows-latest',
    'macos-latest',
    'macos-13',
    'macos-14',
    'macos-15',
)

# Zero-Cost multi-runner pool. Both labels are repo-level self-hosted capacity;
# ascenda-zero-cost-v2 remains the Linux/DB lane and ascenda-fast is Windows/static.
allowed_runner_labels = ('ascenda-zero-cost-v2', 'ascenda-fast')

workflow_files = sorted(list(WF.glob('*.yml')) + list(WF.glob('*.yaml')))
if not workflow_files:
    errors.append('No workflow files found')

for path in workflow_files:
    text = path.read_text(encoding='utf-8')
    lower = text.lower()
    for token in hosted_patterns:
        if token in lower:
            errors.append(f'{path.relative_to(ROOT)} uses prohibited GitHub-hosted runner: {token}')

    runs = [line.strip() for line in text.splitlines() if line.lstrip().startswith('runs-on:')]
    if not runs:
        errors.append(f'{path.relative_to(ROOT)} has no runs-on declaration')
    for line in runs:
        if 'self-hosted' not in line:
            errors.append(f'{path.relative_to(ROOT)} is not self-hosted: {line}')
            continue
        if not any(label in line for label in allowed_runner_labels):
            errors.append(f'{path.relative_to(ROOT)} has non-canonical Zero-Cost runs-on: {line}')
        if 'ascenda-fast' in line and ('Windows' not in line or 'X64' not in line):
            errors.append(f'{path.relative_to(ROOT)} FAST lane must be Windows X64: {line}')

sync = WF / 'sync-supabase.yml'
if sync.exists():
    sync_text = sync.read_text(encoding='utf-8')
    if re.search(r'^\s*schedule\s*:', sync_text, re.M):
        errors.append('sync-supabase.yml must remain manual; schedule is prohibited under Zero-Cost CI')

standard = ROOT / 'docs' / 'control' / 'ASCENDA_ZERO_COST_VALIDATION_STANDARD.md'
if not standard.exists():
    errors.append('Canonical Zero-Cost validation standard missing')
else:
    s = standard.read_text(encoding='utf-8')
    if 'ZERO-COST VALIDATION STANDARD V2' not in s or 'ascenda-zero-cost-v2' not in s:
        errors.append('Canonical Zero-Cost validation standard is missing its V2 baseline')

if errors:
    print('ASCENDA_ZERO_COST_POLICY=FAIL')
    for e in errors:
        print(f' - {e}')
    sys.exit(1)

print(f'ASCENDA_ZERO_COST_POLICY=PASS workflows={len(workflow_files)} lanes={",".join(allowed_runner_labels)}')
