'use strict';
const fs=require('fs');
const assert=require('assert');
const shell=fs.readFileSync('app/public/wa-shell-integration.js','utf8');
const panel=fs.readFileSync('app/public/wa-multiagent-final-panel.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260822224500_wa3_presence_handoff_final_v3.sql','utf8');

assert(shell.includes("MULTI_SRC='/wa-multiagent-final-panel.js?v=20260822-wa3-final-p01'"));
assert(shell.includes('startGlobalPresence()'));
assert(shell.includes("presenceBeat('HEARTBEAT')"));
assert(shell.includes('15000'));
assert(shell.includes("presenceBeat('OFFLINE',true)"));
assert(shell.includes("X-AOS-App-Token"));
assert(!shell.includes("if(!document.hidden)presenceBeat('HEARTBEAT')"));

for(const token of ['Supervisor WA','Requieren humano','No leídos','Humano','Bot','ESPERANDO ASESOR','ASESOR · ','ADMIN · ','Tomar','HUMAN_REQUESTED','wa3f-owner','Meta aceptó el mensaje']) assert(panel.includes(token),token);
assert(!panel.includes('data-pres='));
assert(!panel.includes('Disponible</button>'));
assert(!panel.includes('Ausente</button>'));
assert(!panel.includes('Offline</button>'));
assert(panel.includes("if(X.actor.is_admin===true)"));
assert(panel.includes("if(total>0)"));
assert(panel.includes("row.state==='HUMAN_REQUESTED'"));
assert(panel.includes("/^24H\\s/i"));
assert(panel.includes("boxNames.has(t)"));
assert(panel.includes("d.error==='WA3_NOT_OWNER'"));

for(const token of ['aos_wa3_effective_presence_v2','ASCENDA_GLOBAL','HUMAN_HANDOFF_ONLY','HUMAN_REQUESTED','conversation.handoff_requested','NO_HUMAN_HANDOFF_WORK']) assert(migration.includes(token),token);
assert(migration.includes("c.state='HUMAN_REQUESTED'"));
assert(migration.includes("c.handoff_requested_at is not null"));
assert(migration.includes("v_normalized in ('LOGEADO','ACTIVO','DISPONIBLE','ONLINE','TRABAJO')"));
assert(migration.includes("v_effective:='AWAY'"));
assert(migration.includes("now()-interval '60 seconds'"));
assert(!migration.includes('auto_routing_enabled=true'));
assert(!migration.includes('ai_send_enabled=true'));

console.log('WA-3 FINAL presence/handoff UI contract: PASS');
