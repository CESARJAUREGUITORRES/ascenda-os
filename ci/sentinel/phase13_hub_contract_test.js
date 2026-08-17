'use strict';
const fs=require('fs');const core=require('../../sentinel/hub/hub-core.cjs');
function ok(v,m){if(!v)throw new Error(m);}
const reg=JSON.parse(fs.readFileSync('docs/control/SENTINEL_SYSTEM_REGISTRY_V1.json','utf8'));
const topo=JSON.parse(fs.readFileSync('app/public/sentinel-topology.v1.json','utf8'));
core.validateTopology(topo);
ok(reg.registry_id===topo.source_registry_id,'F2 registry lineage mismatch');
ok(reg.rules.default_observability_state==='UNKNOWN'&&topo.default_state==='UNKNOWN','UNKNOWN default drift');
const regDomains=new Map(reg.domains.map(d=>[d.id,d]));ok(topo.domains.length===reg.domains.length,'domain coverage mismatch');
let capCount=0;
for(const d of topo.domains){const rd=regDomains.get(d.id);ok(rd,'unknown UI domain '+d.id);const expected=new Set(rd.capabilities.map(c=>c.id));const actual=[];d.components.forEach(c=>c.capabilities.forEach(cap=>actual.push(cap.id)));ok(actual.length===expected.size,'capability count mismatch '+d.id);for(const id of actual)ok(expected.has(id),'non-F2 capability '+d.id+'/'+id);capCount+=actual.length;}
ok(capCount===34,'expected 34 F2 capabilities');
const raw=fs.readFileSync('app/public/sentinel-topology.v1.json','utf8');
for(const forbidden of ['db_relations','rpc_refs','dependencies','evidence','surfaces','aos_','supabase','railway','server.js','service_role','token','secret'])ok(!raw.toLowerCase().includes(forbidden.toLowerCase()),'public topology leaks '+forbidden);
console.log('SENTINEL_F13_TOPOLOGY_PARITY=PASS');
console.log('SENTINEL_F13_TOPOLOGY_PRIVACY=PASS');
