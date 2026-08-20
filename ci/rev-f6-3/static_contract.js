const fs = require('fs');
const migration = fs.readFileSync('supabase/migrations/20260820172500_rev_f6_3_identity_confidence_metric_trust_v1.sql','utf8');
const rollback = fs.readFileSync('supabase/rollbacks/20260820172500_rev_f6_3_identity_confidence_metric_trust_v1_recovery.sql','utf8');

const required = [
  'aos_rev_identity_confidence_current_v1',
  'aos_rev_identity_confidence_by_patient_v1',
  'aos_rev_identity_confidence_summary_v1',
  'aos_rev_metric_trust_envelope_v1',
  'aos_rev_metric_trust_baseline_v1',
  'aos_rev_f6_3_contract_v1',
  'REV-F6.3_IDENTITY_CONFIDENCE_V1',
  'REV-F6.3_METRIC_TRUST_V1',
  'NO_CERTIFIED_SOURCE_NE_ZERO',
  'SOURCE_AVAILABILITY',
  'FRESHNESS',
  'COVERAGE',
  'CONFIDENCE',
  'sample_size',
  'phone_nearness_authorizes_identity',
  "set search_path=''",
  'aos_patient_commercial_360_v2_f6_2_base'
];
for (const token of required) {
  if (!migration.includes(token)) throw new Error(`missing contract token: ${token}`);
}
if (/statement_timeout/i.test(migration)) throw new Error('F6.3 must not solve performance by increasing statement_timeout');
if (/\blevenshtein\s*\(|\bsimilarity\s*\(|\bword_similarity\s*\(|\bstrict_word_similarity\s*\(/i.test(migration)) {
  throw new Error('F6.3 must not introduce executable fuzzy identity primitives');
}
if (!migration.includes("'TRANSACTIONAL_SALES_2024','null'::jsonb")) throw new Error('2024 no-source must remain null, not zero');
if (!migration.includes("'TRANSACTIONAL_SALES_2025','null'::jsonb")) throw new Error('2025 no-source must remain null, not zero');
if (!rollback.includes('rename to aos_patient_commercial_360_v2')) throw new Error('recovery must restore F6.2 governed gateway');
if (!rollback.includes('drop function if exists public.aos_rev_f6_3_contract_v1')) throw new Error('recovery must remove F6.3 contract');
console.log('REV-F6.3 FAST static contract PASS');
