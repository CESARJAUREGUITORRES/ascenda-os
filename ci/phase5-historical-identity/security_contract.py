from pathlib import Path
import re

MIG = Path('supabase/migrations/20260815220000_f5_historical_patient_identity_foundation_v1.sql').read_text(encoding='utf-8')
REC = Path('supabase/rollbacks/20260815220000_f5_historical_patient_identity_foundation_v1_recovery.sql').read_text(encoding='utf-8')

expected = [
    'aos_f5_source_batches_v1',
    'aos_f5_patient_source_rows_v1',
    'aos_f5_identity_clusters_v1',
    'aos_f5_identity_cluster_members_v1',
    'aos_f5_patient_link_preview_v1',
    'aos_f5_audit_v1',
]
for table in expected:
    assert f'create table if not exists public.{table}' in MIG, f'missing {table}'
    assert f'alter table public.{table} enable row level security' in MIG, f'RLS missing {table}'
    assert f'revoke all on table public.{table} from public, anon, authenticated' in MIG, f'revoke missing {table}'

low = MIG.lower()
for forbidden in [
    'insert into public.aos_pacientes',
    'update public.aos_pacientes',
    'delete from public.aos_pacientes',
    'truncate public.aos_pacientes',
    'drop table public.aos_pacientes',
]:
    assert forbidden not in low, f'canonical patient mutation forbidden in foundation: {forbidden}'

assert not re.search(r'grant\s+.+\s+to\s+(anon|authenticated)', MIG, re.I), 'F5 foundation must not grant browser access'
assert 'raw_payload jsonb not null' in MIG, 'raw evidence must be preserved'
assert 'source_sha256 text not null unique' in MIG, 'file-level idempotency hash missing'
assert 'unique(batch_id, source_row_num)' in MIG, 'row-level idempotency missing'
assert 'requires_human boolean not null default true' in MIG, 'human review default missing'

rec_low = REC.lower()
assert 'drop table' not in rec_low, 'recovery must preserve staged evidence'
assert 'grant ' not in rec_low, 'recovery must never widen access'
for table in expected:
    assert f'revoke all on table public.{table} from public, anon, authenticated' in REC, f'recovery revoke missing {table}'

print('F5 historical identity security contract: PASS')
