'use strict';
const fs=require('fs');
const path=require('path');
const map={
 '20260814170000_kronia_k1_private_credentials_auth_v3.sql':'20260817170000_kronia_k1_private_credentials_auth_v3.sql',
 '20260814171000_kronia_k1_app_token_control_plane.sql':'20260817170100_kronia_k1_app_token_control_plane.sql',
 '20260814171500_kronia_k1_identity_sync.sql':'20260817170200_kronia_k1_identity_sync.sql',
 '20260814171600_kronia_k1_feed_schema_alignment.sql':'20260817170300_kronia_k1_feed_schema_alignment.sql',
 '20260814171800_kronia_k1_auth_v3_branded_alignment.sql':'20260817170400_kronia_k1_auth_v3_branded_alignment.sql',
 '20260814172000_kronia_k1_team_profile_alignment.sql':'20260817170500_kronia_k1_team_profile_alignment.sql',
 '20260814172100_kronia_k1_authority_session_revocation.sql':'20260817170600_kronia_k1_authority_session_revocation.sql'
};
for(const [oldName,newName] of Object.entries(map)){
  const oldPath=path.join('supabase','migrations',oldName);
  const newPath=path.join('supabase','migrations',newName);
  if(fs.existsSync(oldPath)) fs.renameSync(oldPath,newPath);
  if(!fs.existsSync(newPath)) throw new Error('renumber target missing '+newPath);
}
const replacements=Object.entries(map);
const permanent=[
 'ci/kronia-k1-phase2/runtime_contract.py',
 'ci/kronia-k1-phase2/security_static_contract.py',
 'docs/control/KRONIA_K1_CURRENT_CERTIFICATION_CHECKPOINT_20260815.md'
];
for(const p of permanent){
  if(!fs.existsSync(p)) continue;
  let s=fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n');
  for(const [a,b] of replacements) s=s.split(a).join(b);
  fs.writeFileSync(p,s,'utf8');
}
const oldDoc='docs/control/KRONIA_K1_CURRENT_CERTIFICATION_CHECKPOINT_20260815.md';
const newDoc='docs/control/KRONIA_K1_CURRENT_CERTIFICATION_CHECKPOINT_20260817.md';
if(fs.existsSync(oldDoc)) fs.renameSync(oldDoc,newDoc);
if(fs.existsSync(newDoc)){
  let s=fs.readFileSync(newDoc,'utf8').replace(/2026-08-15/g,'2026-08-17');
  s=s.replace(/K1 -> F5 -> WA4 -> WA3 -> WA2 -> F4 -> Phase2\/core/g,'K1 -> Phase S -> F5 -> WA4 -> WA3 -> WA2 -> F4 -> Phase2/core');
  fs.writeFileSync(newDoc,s,'utf8');
}
const listed=fs.readdirSync(path.join('supabase','migrations'))
  .filter(x=>x.includes('kronia_k1')&&x.endsWith('.sql'))
  .map(x=>'supabase/migrations/'+x)
  .sort();
const expected=Object.values(map).map(x=>'supabase/migrations/'+x).sort();
if(JSON.stringify(listed)!==JSON.stringify(expected)) throw new Error('K1 migration set is not exact after renumber: '+JSON.stringify(listed));
for(const p of expected){
  const version=path.basename(p).slice(0,14);
  if(version<='20260817161248') throw new Error('K1 version not after current production baseline: '+version);
}
console.log('KRONIA_K1_RELEASE_RENUMBER_V4=PASS',expected.join(','));
