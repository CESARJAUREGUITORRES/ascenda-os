'use strict';

const fs=require('node:fs');
const readline=require('node:readline');
const {CONTRACT}=require('./triage-core.cjs');

function fail(code,msg){const e=new Error(msg||code);e.code=code;throw e;}
function loadPacket(file){
  const p=JSON.parse(fs.readFileSync(file,'utf8'));
  if(!p||p.schema_version!=='sentinel-triage-packet/v1'||p.safety?.read_only!==true||p.safety?.production_mutation!==false)fail('F11_PACKET_INVALID');
  return p;
}
function tool(name,description,inputSchema){return {name,title:name,description,inputSchema,annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true,openWorldHint:false},execution:{taskSupport:'forbidden'}};}
const EMPTY={type:'object',additionalProperties:false};
const TOOLS=[
  tool('sentinel.get_summary','Return sanitized incident and diagnostic summary.',EMPTY),
  tool('sentinel.list_evidence','List sanitized evidence, optionally filtered by kind.',{type:'object',properties:{kind:{type:'string'}},additionalProperties:false}),
  tool('sentinel.get_evidence','Return one evidence item by evidence_id.',{type:'object',properties:{evidence_id:{type:'string',pattern:'^E[0-9]{3,}$'}},required:['evidence_id'],additionalProperties:false}),
  tool('sentinel.list_hypotheses','List F10 hypotheses with causality_confirmed=false.',EMPTY),
  tool('sentinel.get_correlation','Return release/commit/deployment correlation metadata.',EMPTY),
  tool('sentinel.get_triage_packet','Return complete sanitized F11 packet.',EMPTY)
].sort((a,b)=>a.name.localeCompare(b.name));
function result(data){return {content:[{type:'text',text:JSON.stringify(data)}],structuredContent:data,isError:false};}
function toolError(code){return {content:[{type:'text',text:code}],structuredContent:{ok:false,error:code},isError:true};}
function callTool(packet,name,args){
  if(!CONTRACT.mcp_tools.includes(name))fail('F11_UNKNOWN_TOOL',name);
  if(!args||typeof args!=='object'||Array.isArray(args))args={};
  if(name==='sentinel.get_summary'){if(Object.keys(args).length) return toolError('F11_TOOL_INPUT_INVALID');return result({incident:packet.incident,diagnostic:packet.diagnostic,safety:packet.safety});}
  if(name==='sentinel.list_evidence'){
    if(Object.keys(args).some(k=>k!=='kind'))return toolError('F11_TOOL_INPUT_INVALID');
    const items=args.kind?packet.evidence.filter(e=>e.kind===args.kind):packet.evidence;return result({evidence:items});
  }
  if(name==='sentinel.get_evidence'){
    if(Object.keys(args).sort().join(',')!=='evidence_id')return toolError('F11_TOOL_INPUT_INVALID');
    const e=packet.evidence.find(x=>x.id===args.evidence_id);return e?result({evidence:e}):toolError('F11_EVIDENCE_NOT_FOUND');
  }
  if(name==='sentinel.list_hypotheses'){if(Object.keys(args).length)return toolError('F11_TOOL_INPUT_INVALID');return result({hypotheses:packet.hypotheses});}
  if(name==='sentinel.get_correlation'){if(Object.keys(args).length)return toolError('F11_TOOL_INPUT_INVALID');return result({correlation:packet.correlation});}
  if(name==='sentinel.get_triage_packet'){if(Object.keys(args).length)return toolError('F11_TOOL_INPUT_INVALID');return result(packet);}
  fail('F11_UNKNOWN_TOOL',name);
}
function handle(packet,msg){
  if(!msg||msg.jsonrpc!=='2.0')return {jsonrpc:'2.0',id:msg?.id??null,error:{code:-32600,message:'Invalid Request'}};
  if(msg.method==='notifications/initialized')return null;
  const id=msg.id;
  if(id===undefined||id===null)return null;
  if(msg.method==='initialize')return {jsonrpc:'2.0',id,result:{protocolVersion:CONTRACT.protocol.revision,capabilities:{tools:{listChanged:false}},serverInfo:{name:'sentinel-f11-triage',version:'1.0.0'}}};
  if(msg.method==='ping')return {jsonrpc:'2.0',id,result:{}};
  if(msg.method==='tools/list')return {jsonrpc:'2.0',id,result:{tools:TOOLS}};
  if(msg.method==='tools/call'){
    try{return {jsonrpc:'2.0',id,result:callTool(packet,msg.params?.name,msg.params?.arguments||{})};}
    catch(e){return {jsonrpc:'2.0',id,error:{code:-32602,message:e.code||'Invalid tool request'}};}
  }
  return {jsonrpc:'2.0',id,error:{code:-32601,message:'Method not found'}};
}
function parseArgs(argv){const o={};for(let i=0;i<argv.length;i++)if(argv[i].startsWith('--'))o[argv[i].slice(2)]=argv[++i];return o;}
if(require.main===module){
  const args=parseArgs(process.argv.slice(2));const file=args.packet||process.env.F11_PACKET_PATH;if(!file){console.error('F11_PACKET_REQUIRED');process.exit(1);}let packet;
  try{packet=loadPacket(file);}catch(e){console.error(e.code||e.message);process.exit(1);}
  const rl=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
  rl.on('line',line=>{if(!line.trim())return;let msg;try{msg=JSON.parse(line);}catch{process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:null,error:{code:-32700,message:'Parse error'}})+'\n');return;}const out=handle(packet,msg);if(out)process.stdout.write(JSON.stringify(out)+'\n');});
}
module.exports={TOOLS,handle,callTool,loadPacket};
