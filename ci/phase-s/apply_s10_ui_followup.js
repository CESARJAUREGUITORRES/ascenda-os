'use strict';
const fs=require('fs');
const p='app/public/wa-native-panel.js';
let s=fs.readFileSync(p,'utf8');
function one(a,b){const i=s.indexOf(a);if(i<0)throw new Error('needle missing: '+a.slice(0,120));if(s.indexOf(a,i+a.length)>=0)throw new Error('needle duplicate');s=s.slice(0,i)+b+s.slice(i+a.length);}
one("var c=canSend(),sig=[S.selected&&S.selected.id,S.selected&&S.selected.owner_user_id,S.selected&&S.selected.state,S.boot&&S.boot.actor&&S.boot.actor.id,S.boot&&S.boot.control&&S.boot.control.human_send_enabled].join('|');","var c=canSend(),li=Date.parse(String(S.selected&&S.selected.last_inbound_at||'')),windowState=(Number.isFinite(li)&&Date.now()-li<86400000)?'OPEN':'CLOSED',sig=[S.selected&&S.selected.id,S.selected&&S.selected.owner_user_id,S.selected&&S.selected.state,S.selected&&S.selected.last_inbound_at,windowState,S.boot&&S.boot.actor&&S.boot.actor.id,S.boot&&S.boot.control&&S.boot.control.human_send_enabled].join('|');");
one(".catch(function(e){toast('Envío bloqueado: '+e.message,true);}).finally(function(){renderComposer(true);});",".catch(function(e){var detail=e&&e.data&&e.data.provider_details?(' · '+String(e.data.provider_details).slice(0,220)):'';toast('Envío bloqueado: '+e.message+detail,true);}).finally(function(){renderComposer(true);});");
fs.writeFileSync(p,s);
console.log('S10_UI_FOLLOWUP_APPLIED');
