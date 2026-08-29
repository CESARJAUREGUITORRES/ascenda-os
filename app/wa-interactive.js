'use strict';

function fail(code){throw Object.assign(new Error(code),{status:400});}
function text(v,max){return String(v==null?'':v).trim().slice(0,max);}
function id(v){const s=text(v,256);if(!s||/[\u0000-\u001f\u007f]/.test(s))fail('INTERACTIVE_ID_REQUIRED');return s;}
function recipient(v){const s=String(v||'').trim();if(!s)fail('INVALID_RECIPIENT');return s;}

function buttons(input){
  const d=input||{},body=text(d.text||d.body,1024);if(!body)fail('INTERACTIVE_BODY_REQUIRED');
  const rows=Array.isArray(d.buttons)?d.buttons:[];if(rows.length<1||rows.length>3)fail('INTERACTIVE_BUTTON_COUNT');
  const seen=new Set();
  const out=rows.map((r)=>{const rid=id(r&&r.id),title=text(r&&r.title,20);if(!title)fail('INTERACTIVE_BUTTON_TITLE_REQUIRED');if(String(r&&r.title||'').trim().length>20)fail('INTERACTIVE_BUTTON_TITLE_TOO_LONG');if(seen.has(rid))fail('INTERACTIVE_DUPLICATE_ID');seen.add(rid);return {type:'reply',reply:{id:rid,title}};});
  const payload={messaging_product:'whatsapp',recipient_type:'individual',to:recipient(d.to),type:'interactive',interactive:{type:'button',body:{text:body},action:{buttons:out}}};
  const footer=text(d.footer,60);if(footer)payload.interactive.footer={text:footer};
  Object.defineProperty(payload,'_ascenda_message_type',{value:'interactive_buttons',enumerable:false});
  return payload;
}

function list(input){
  const d=input||{},body=text(d.text||d.body,1024),button=text(d.button_text||d.button,20);if(!body)fail('INTERACTIVE_BODY_REQUIRED');if(!button)fail('INTERACTIVE_LIST_BUTTON_REQUIRED');if(String(d.button_text||d.button||'').trim().length>20)fail('INTERACTIVE_LIST_BUTTON_TOO_LONG');
  const sections=Array.isArray(d.sections)?d.sections:[];if(sections.length<1||sections.length>10)fail('INTERACTIVE_LIST_SECTION_COUNT');
  let total=0;const seen=new Set();
  const clean=sections.map((s)=>{const rows=Array.isArray(s&&s.rows)?s.rows:[];if(!rows.length)fail('INTERACTIVE_LIST_ROWS_REQUIRED');const sectionTitle=text(s&&s.title,24);if(String(s&&s.title||'').trim().length>24)fail('INTERACTIVE_SECTION_TITLE_TOO_LONG');const cleanRows=rows.map((r)=>{total++;const rid=id(r&&r.id),title=text(r&&r.title,24),description=text(r&&r.description,72);if(!title)fail('INTERACTIVE_ROW_TITLE_REQUIRED');if(String(r&&r.title||'').trim().length>24)fail('INTERACTIVE_ROW_TITLE_TOO_LONG');if(String(r&&r.description||'').trim().length>72)fail('INTERACTIVE_ROW_DESCRIPTION_TOO_LONG');if(seen.has(rid))fail('INTERACTIVE_DUPLICATE_ID');seen.add(rid);const row={id:rid,title};if(description)row.description=description;return row;});const sec={rows:cleanRows};if(sectionTitle)sec.title=sectionTitle;return sec;});
  if(total>10)fail('INTERACTIVE_LIST_ROW_LIMIT');
  const payload={messaging_product:'whatsapp',recipient_type:'individual',to:recipient(d.to),type:'interactive',interactive:{type:'list',body:{text:body},action:{button,sections:clean}}};
  const footer=text(d.footer,60);if(footer)payload.interactive.footer={text:footer};
  Object.defineProperty(payload,'_ascenda_message_type',{value:'interactive_list',enumerable:false});
  return payload;
}

function build(input){const type=String(input&&input.type||'').toLowerCase();if(type==='interactive_buttons')return buttons(input);if(type==='interactive_list')return list(input);fail('UNSUPPORTED_INTERACTIVE_TYPE');}
function messageType(payload){return String(payload&&payload._ascenda_message_type||payload&&payload.type||'unknown');}
function messageBody(payload){if(payload&&payload.text&&payload.text.body)return String(payload.text.body);if(payload&&payload.interactive&&payload.interactive.body)return String(payload.interactive.body.text||'');return '';}

module.exports={build,buttons,list,messageType,messageBody};
