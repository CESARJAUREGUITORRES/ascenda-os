const fs = require('fs');
const p='supabase/migrations/20260815233000_f5_historical_patient_identity_private_ingest_v1.sql';
const s=fs.readFileSync(p,'utf8');
const low=s.toLowerCase();
function ok(c,m){if(!c) throw new Error(m)}
ok(s.includes('aos_f5_ingest_source_rows_v1'),'private ingest function missing');
ok(/security definer/i.test(s),'ingest must be security definer');
ok(/set search_path = public, pg_temp/i.test(s),'safe search_path missing');
ok(s.includes('SOURCE_ROW_HASH_CONFLICT'),'hash conflict must fail closed');
ok(s.includes('on conflict(batch_id,source_row_num) do nothing'),'row idempotency missing');
ok(s.includes("v_requested > 500"),'bounded chunk size missing');
ok(/revoke all on function public\.aos_f5_ingest_source_rows_v1\(text,jsonb\) from public, anon, authenticated/i.test(s),'browser execute must be revoked');
ok(/grant execute on function public\.aos_f5_ingest_source_rows_v1\(text,jsonb\) to service_role/i.test(s),'service-side execution missing');
for(const forbidden of ['insert into public.aos_pacientes','update public.aos_pacientes','delete from public.aos_pacientes','truncate public.aos_pacientes']) ok(!low.includes(forbidden),`canonical patient mutation forbidden: ${forbidden}`);
ok(s.includes('raw_payload'),'raw evidence must remain part of ingest');
ok(s.includes('F5_PRIVATE_INGEST_V1'),'security audit marker missing');
console.log('F5 private ingest contract: PASS');
