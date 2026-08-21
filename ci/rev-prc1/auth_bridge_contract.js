'use strict';
const fs=require('fs');

function read(p){return fs.readFileSync(p,'utf8');}
function must(hay,needle,label){if(!hay.includes(needle))throw new Error('REV_PRC1_AUTH_BRIDGE_CONTRACT: '+label);}

const bridge=read('app/public/rev-prc1-auth-bridge.js');
const bootstrap=read('app/server-phase-s-f17.js');
const hotfix=read('app/public/f4-production-canary-hotfix.js');

[
  'aos_product_review_admin_v1',
  'aos_product_review_admin_v2',
  'aos_product_review_resolve_v2',
  'aos_product_review_reopen_v1',
  'aos_product_batch_review_v1'
].forEach(function(name){must(bridge,name,'browser allowlist missing '+name);must(bootstrap,name,'server allowlist missing '+name);});

must(bridge,"downstreamFetch('/api/prc1/rpc'",'browser must use same-origin PRC1 endpoint');
must(bridge,"'X-AOS-App-Token':token",'browser must bind Auth V3 token in header');
must(bridge,"delete payload.p_token",'browser must not trust body token');
must(bridge,'tokenCandidates()','browser must try strong token candidates');
must(bootstrap,"pathname==='/api/prc1/rpc'",'server route missing');
must(bootstrap,"payload.p_token=token",'server must overwrite RPC token from verified boundary header');
must(bootstrap,"PRC1_RPC_NOT_ALLOWED",'server must fail closed outside allowlist');
must(bootstrap,"F4_STRONG_SESSION_REQUIRED",'server must require strong app session');
must(hotfix,"/rev-prc1-auth-bridge.js?v=20260821-prc1-auth-v1",'hotfix must load auth bridge');
must(hotfix,"/rev-prc1-product-resolution-center.js?v=20260821-prc1-v3-authbridge",'hotfix must cache-bust PRC1 runtime');
if(hotfix.indexOf('rev-prc1-auth-bridge.js')>hotfix.indexOf('rev-prc1-product-resolution-center.js'))throw new Error('REV_PRC1_AUTH_BRIDGE_CONTRACT: bridge must be declared before PRC1 runtime');

console.log('REV_PRC1_AUTH_BRIDGE_CONTRACT PASS');
