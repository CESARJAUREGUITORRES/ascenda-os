'use strict';
const fs=require('fs');
const p='app/server-phase-s.js';
let s=fs.readFileSync(p,'utf8');
function repN(a,b,n){const parts=s.split(a);const count=parts.length-1;if(count!==n)throw new Error('expected '+n+' occurrences, found '+count+': '+a);s=parts.join(b);}
repN('/wa-native-panel.js?v=20260817-wa-native-s8-p01','/wa-native-panel.js?v=20260817-wa-native-s10-p01',2);
repN('/wa-shell-integration.js?v=20260817-wa-shell-s8-p01','/wa-shell-integration.js?v=20260817-wa-shell-s10-p01',2);
fs.writeFileSync(p,s);
console.log('S10_CACHE_BUMP_APPLIED');
