'use strict';
const fs=require('fs'); const path=require('path');
const ROOT=path.resolve(__dirname,'../..');
const MIG='supabase/migrations/20260820215500_rev_f6_6_sentinel_integrity_handoff_v1.sql';
const RB='supabase/rollbacks/20260820215500_rev_f6_6_sentinel_integrity_handoff_v1_recovery.sql';
const REG='docs/control/SENTINEL_SIGNAL_CONTRACTS_REV_F6_6_V1.json';
const CANON='docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md';
const TEST='ci/rev-f6-6/tests/001_sentinel_integrity_handoff.sql';
const FIX='ci/rev-f6-6/fixture.sql';
const WF='.github/workflows/rev-f6-6-sentinel-integrity-handoff.yml';
function read(p){const x=path.join(ROOT,p); if(!fs.existsSync(x)) throw new Error(`MISSING:${p}`); return fs.readFileSync(x,'utf8');}
function ok(v,m){if(!v) throw new Error(m);}
const mig=read(MIG),rb=read(RB),reg=JSON.parse(read(REG)),canon=read(CANON),test=read(TEST),fix=read(FIX),wf=read(WF);
const ids=['SEN-DQ-F5-001','SEN-DQ-F5-002','SEN-DQ-F5-003','SEN-DQ-F5-004','SEN-DQ-F5-005','SEN-DQ-REV-001','SEN-DQ-REV-002','SEN-DQ-F6-001','SEN-DQ-F6-002','SEN-DQ-360-001'];
ok(reg.schema_version==='sentinel-signal-contracts/rev-f6-6/v1','REGISTRY_VERSION');
ok(reg.extension_of==='docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json','REGISTRY_EXTENSION');
ok(reg.observation_only===true&&reg.auto_repair===false&&reg.auto_incident_ingest===false,'OBSERVATION_BOUNDARY');
ok(reg.zero_pii===true&&reg.missing_telemetry_state==='UNKNOWN','ZERO_PII_UNKNOWN');
ok(JSON.stringify(reg.states)===JSON.stringify(['OK','DEGRADED','REVIEW_REQUIRED','BROKEN','UNKNOWN']),'STATE_SET');
ok(reg.signals.length===10&&new Set(reg.signals.map(x=>x.signal_id)).size===10,'SIGNAL_COUNT');
for(const id of ids){ok(reg.signals.some(x=>x.signal_id===id),`REG:${id}`);ok(mig.includes(`'${id}'`),`MIG:${id}`);ok(canon.includes(id),`CANON:${id}`);}
for(const t of ['aos_rev_f6_6_integrity_baseline_v1','aos_sentinel_rev_f6_6_signal_envelope_v1','aos_sentinel_rev_f6_6_evaluate_v1','aos_sentinel_rev_f6_6_snapshot_v1','aos_sentinel_rev_f6_6_integrity_health_v1','aos_sentinel_rev_f6_6_incident_candidates_v1','aos_rev_f6_6_contract_v1',"'auto_ingest',false","'observation_only',true","'auto_repair',false","'state_digest'",'source_newer_than_cache','coverage_material_drop_pp']) ok(mig.includes(t),`MIG_TOKEN:${t}`);
ok(!mig.includes('pg_catalog.coalesce'),'POSTGRES_SPECIAL_EXPRESSION_COALESCE_MUST_NOT_BE_SCHEMA_QUALIFIED');
ok(!mig.includes('pg_catalog.greatest'),'POSTGRES_SPECIAL_EXPRESSION_GREATEST_MUST_NOT_BE_SCHEMA_QUALIFIED');
for(const t of ['aos_pacientes','aos_ventas','aos_product_sale_fact_v1','aos_cartera_reconciliacion','aos_f5_patient_source_rows_v1','aos_f5_identity_cluster_members_v1','aos_f5_canonical_classification_v1']){const re=new RegExp(`\\b(insert\\s+into|update|delete\\s+from)\\s+public\\.${t}\\b`,'i');ok(!re.test(mig),`BUSINESS_DML:${t}`);}
ok(!/\btruncate\b/i.test(mig),'TRUNCATE');
for(const fn of ['aos_rev_f6_6_contract_v1','aos_sentinel_rev_f6_6_incident_candidates_v1','aos_sentinel_rev_f6_6_integrity_health_v1','aos_sentinel_rev_f6_6_snapshot_v1','aos_sentinel_rev_f6_6_evaluate_v1','aos_sentinel_rev_f6_6_signal_envelope_v1','aos_rev_f6_6_integrity_baseline_v1']) ok(rb.includes(`drop function if exists public.${fn}`),`ROLLBACK:${fn}`);
for(const letter of 'ABCDEFGHIJKLMNOPQRSTUVWX') ok(test.includes(`${letter}.`)||test.includes(`${letter}:`),`TEST_${letter}`);
ok(test.includes('F8_REPLAY_DEDUP')&&test.includes('V_PII_KEY')&&test.includes('S_MISSING_TELEMETRY'),'TEST_GUARDS');
ok(fix.includes('synthetic-only'),'FIXTURE');
for(const t of ['self-hosted','ascenda-fast','ascenda-zero-cost-v2','node ci/rev-f6-6/static_contract.js','001_sentinel_integrity_handoff.sql','20260820215500_rev_f6_6_sentinel_integrity_handoff_v1.sql']) ok(wf.includes(t),`WF:${t}`);
for(const bad of ['ubuntu-latest','windows-latest','macos-latest']) ok(!wf.includes(bad),`HOSTED:${bad}`);
const suspicious=[/\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,/\bsb_secret_[A-Za-z0-9_-]{20,}\b/,/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,/\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b/];
for(const p of [MIG,RB,REG,TEST,FIX,WF]) for(const re of suspicious) ok(!re.test(read(p)),`SECRET:${p}`);
console.log(JSON.stringify({ok:true,certificate:'REV_F6_6_STATIC_CONTRACT_PASS',signals:10,observation_only:true,auto_repair:false,auto_incident_ingest:false,zero_pii:true},null,2));
