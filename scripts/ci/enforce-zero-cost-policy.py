#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / '.github' / 'workflows'
errors = []

HOSTED_PATTERNS = (
    'ubuntu-latest',
    'windows-latest',
    'macos-latest',
    'macos-13',
    'macos-14',
    'macos-15',
)
CANONICAL_RUNNER_SETS = (
    ('self-hosted', 'linux', 'x64', 'ascenda-zero-cost-v2'),
    ('self-hosted', 'windows', 'x64', 'ascenda-fast'),
)


def runs_on_values(text: str) -> list[str]:
    """Return only YAML runs-on declarations, including simple block-list forms."""
    lines = text.splitlines()
    values: list[str] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        match = re.match(r'^(\s*)runs-on\s*:\s*(.*)$', raw, re.I)
        if not match:
            i += 1
            continue

        indent = len(match.group(1).replace('\t', '    '))
        tail = match.group(2).strip()
        if tail:
            values.append(tail)
            i += 1
            continue

        block: list[str] = []
        i += 1
        while i < len(lines):
            child = lines[i]
            stripped = child.strip()
            if not stripped or stripped.startswith('#'):
                i += 1
                continue
            child_indent = len(child) - len(child.lstrip(' \t'))
            if child_indent <= indent:
                break
            block.append(stripped)
            i += 1
        values.append(' '.join(block))
    return values


workflow_files = sorted(list(WF.glob('*.yml')) + list(WF.glob('*.yaml')))
if not workflow_files:
    errors.append('No workflow files found')

for path in workflow_files:
    text = path.read_text(encoding='utf-8')
    runs = runs_on_values(text)
    if not runs:
        errors.append(f'{path.relative_to(ROOT)} has no runs-on declaration')
        continue

    for declaration in runs:
        lower = declaration.lower()
        for token in HOSTED_PATTERNS:
            if token in lower:
                errors.append(f'{path.relative_to(ROOT)} uses prohibited GitHub-hosted runner: {token}')
        if not any(all(label in lower for label in labels) for labels in CANONICAL_RUNNER_SETS):
            expected = ' OR '.join(','.join(labels) for labels in CANONICAL_RUNNER_SETS)
            errors.append(
                f'{path.relative_to(ROOT)} has non-canonical runs-on: {declaration} '
                f'(expected {expected})'
            )

sync = WF / 'sync-supabase.yml'
if sync.exists():
    sync_text = sync.read_text(encoding='utf-8')
    if re.search(r'^\s*schedule\s*:', sync_text, re.M):
        errors.append('sync-supabase.yml must remain manual; schedule is prohibited under Zero-Cost CI V2')

standard = ROOT / 'docs' / 'control' / 'ASCENDA_ZERO_COST_VALIDATION_STANDARD.md'
if not standard.exists():
    errors.append('Canonical Zero-Cost validation standard missing')
else:
    s = standard.read_text(encoding='utf-8')
    if 'ZERO-COST VALIDATION STANDARD V2' not in s or 'ascenda-zero-cost-v2' not in s:
        errors.append('Canonical standard is not Zero-Cost CI V2')

if errors:
    print('ASCENDA_ZERO_COST_POLICY=FAIL')
    for e in errors:
        print(f' - {e}')
    sys.exit(1)

print(f'ASCENDA_ZERO_COST_POLICY=PASS workflows={len(workflow_files)}')
