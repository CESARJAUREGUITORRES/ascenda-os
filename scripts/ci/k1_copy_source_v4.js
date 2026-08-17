'use strict';
const fs=require('fs');
const path=require('path');
const cp=require('child_process');
const source=process.argv[2];
if(!/^[0-9a-f]{40}$/i.test(String(source||'')))throw new Error('exact source SHA required');
const files=[
  'app/server-k1.js',
  'app/k1_phase2_materialize.py',
  'app/public/k1-browser-security.js',
  'chrome-extension/k1-extension-auth.js',
  'chrome-extension/manifest.json',
  'chrome-extension/content-script.js',
  'chrome-extension/kronia-core.js',
  'chrome-extension/popup.html',
  'chrome-extension/popup.js',
  'ci/kronia-k1-phase2/001_k1_phase2_certificate.sql',
  'ci/kronia-k1-phase2/002_k1_safe_recovery.sql',
  'ci/kronia-k1-phase2/fixture_pre_k1.sql',
  'ci/kronia-k1-phase2/runtime_contract.py',
  'ci/kronia-k1-phase2/test_proxy_security.js',
  'docs/control/KRONIA_K1_CURRENT_CERTIFICATION_CHECKPOINT_20260815.md',
  'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql',
  'supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql',
  'supabase/migrations/20260814171500_kronia_k1_identity_sync.sql',
  'supabase/migrations/20260814171600_kronia_k1_feed_schema_alignment.sql',
  'supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql',
  'supabase/migrations/20260814172000_kronia_k1_team_profile_alignment.sql',
  'supabase/migrations/20260814172100_kronia_k1_authority_session_revocation.sql',
  'supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql'
];
for(const p of files){
  fs.mkdirSync(path.dirname(p),{recursive:true});
  const data=cp.execFileSync('git',['show',`${source}:${p}`]);
  fs.writeFileSync(p,data);
}
console.log('KRONIA_K1_V4_EXACT_SOURCE_COPY=PASS',source,files.length);
