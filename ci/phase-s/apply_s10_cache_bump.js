'use strict';
const fs=require('fs');
const p='app/server-phase-s.js';
let s=fs.readFileSync(p,'utf8');
function rep(a,b){const i=s.indexOf(a);if(i<0)throw new Error('needle missing: '+a);if(s.indexOf(a,i+a.length)>=0)throw new Error('needle duplicate: '+a);s=s.slice(0,i)+b+s.slice(i+a.length);}
rep('/wa-native-panel.js?v=20260817-wa-native-s8-p01','/wa-native-panel.js?v=20260817-wa-native-s10-p01');
rep('/wa-shell-integration.js?v=20260817-wa-shell-s8-p01','/wa-shell-integration.js?v=20260817-wa-shell-s10-p01');
rep('/wa-native-panel.js?v=20260817-wa-native-s8-p01','/wa-native-panel.js?v=20260817-wa-native-s10-p01');
rep('/wa-shell-integration.js?v=20260817-wa-shell-s8-p01','/wa-shell-integration.js?v=20260817-wa-shell-s10-p01');
fs.writeFileSync(p,s);
console.log('S10_CACHE_BUMP_APPLIED');
