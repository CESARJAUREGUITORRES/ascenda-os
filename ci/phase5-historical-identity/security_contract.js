const fs = require('fs');

const MIG = fs.readFileSync('supabase/migrations/20260815220000_f5_historical_patient_identity_foundation_v1.sql','utf8');
const REC = fs.readFileSync('supabase/rollbacks/20260815220000_f5_historical_patient_identity_foundation_v1_recovery.sql','utf8');

const expected = [
  'aos_f5_source_batches_v1',
  'aos_f5_patient_source_rows_v1',
  'aos_f5_identity_clusters_v1',
  'aos_f5_identity_cluster_members_v1',
  'aos_f5_patient_link_preview_v1',
  'aos_f5_audit_v1',
];
function assert(cond,msg){ if(!cond) throw new Error(msg); }
for (const table of expected) {
  assert(MIG.includes(`create table if not exists public.${table}`),`missing ${table}`);
  assert(MIG.includes(`alter table public.${table} enable row level security`),`RLS missing ${table}`);
  assert(MIG.includes(`revoke all on table public.${table} from public, anon, authenticated`),`revoke missing ${table}`);
}
const low = MIG.toLowerCase();
for (const forbidden of [
  'insert into public.aos_pacientes',
  'update public.aos_pacientes',
  'delete from public.aos_pacientes',
  'truncate public.aos_pacientes',
  'drop table public.aos_pacientes',
]) assert(!low.includes(forbidden),`canonical patient mutation forbidden: ${forbidden}`);

assert(!/grant\s+.+\s+to\s+(anon|authenticated)/i.test(MIG),'F5 foundation must not grant browser access');
assert(MIG.includes('raw_payload jsonb not null'),'raw evidence must be preserved');
assert(MIG.includes('source_sha256 text not null unique'),'file-level idempotency hash missing');
assert(MIG.includes('unique(batch_id, source_row_num)'),'row-level idempotency missing');
assert(MIG.includes('requires_human boolean not null default true'),'human review default missing');

const recLow = REC.toLowerCase();
assert(!recLow.includes('drop table'),'recovery must preserve staged evidence');
assert(!/\bgrant\s/i.test(REC),'recovery must never widen access');
for (const table of expected) assert(REC.includes(`revoke all on table public.${table} from public, anon, authenticated`),`recovery revoke missing ${table}`);
console.log('F5 historical identity security contract: PASS');
