'use strict';
const crypto=require('crypto');
const ExcelJS=require('exceljs');

const HEADERS=['F. creación de paciente','ID del paciente','Teléfono','Nombres','Apellidos','Email','N° documento','Sexo','Fecha de nacimiento','Dirección','Ocupación','Apoderado','¿Cómo nos conoció?','Referencia de Procedencia','Campo opcional 1','Campo opcional 2','Nota clínica','Alergias','Grupo','Línea de negocio','N° HC','Inactivo','Etiquetas','Última cita','Próxima cita','Tarea','Último presupuesto'];
const HEADER_SET=new Set(HEADERS);
const MAX_FILE_BYTES=12*1024*1024;
const MAX_ROWS=5000;

function text(v){if(v==null)return'';if(v instanceof Date)return v.toISOString().slice(0,10);if(typeof v==='object'){if(v.text!=null)return String(v.text).trim();if(v.result!=null)return text(v.result);if(Array.isArray(v.richText))return v.richText.map(x=>x.text||'').join('').trim();if(v.hyperlink&&v.text)return String(v.text).trim();}return String(v).trim();}
function asciiUpper(v){let s=text(v).toUpperCase();try{s=s.normalize('NFD').replace(/[\u0300-\u036f]/g,'');}catch(_){}return s.replace(/[^A-Z0-9 ]+/g,' ').replace(/\s+/g,' ').trim();}
function lower(v){const s=text(v).toLowerCase();return s||null;}
function digits(v){return text(v).replace(/\D/g,'');}
function normalizePhone(v){const raw=text(v);if(!raw)return{raw:null,key:null,type:'MISSING'};let d=digits(raw);if(d.startsWith('0051'))d=d.slice(4);if(d.startsWith('51')&&d.length===11)d=d.slice(2);if(/^9\d{8}$/.test(d))return{raw,key:d,type:'PERU_9'};if(d.length>=8&&d.length<=15)return{raw,key:d,type:'NON_STANDARD'};return{raw,key:null,type:'INVALID'};}
function normalizeDoc(v){const raw=text(v);if(!raw)return{raw:null,key:null,type:'MISSING'};const d=digits(raw);if(/^\d{8}$/.test(d))return{raw,key:d,type:'DNI8'};const k=raw.toUpperCase().replace(/[^A-Z0-9]/g,'');return{raw,key:k||null,type:k?'NON_DNI':'INVALID'};}
function normalizeEmail(v){const raw=text(v);if(!raw)return{raw:null,key:null};const k=raw.toLowerCase();return{raw,key:/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(k)?k:null};}
function isoDate(v){if(v==null||v==='')return null;if(v instanceof Date&&!isNaN(v))return v.toISOString().slice(0,10);const s=text(v);if(!s)return null;let m=s.match(/^(\d{4})[-\/]([01]?\d)[-\/]([0-3]?\d)/);if(m)return `${m[1]}-${String(m[2]).padStart(2,'0')}-${String(m[3]).padStart(2,'0')}`;m=s.match(/^([0-3]?\d)[-\/]([01]?\d)[-\/](\d{4})/);if(m)return `${m[3]}-${String(m[2]).padStart(2,'0')}-${String(m[1]).padStart(2,'0')}`;return null;}
function birth(v){const raw=text(v)||null,iso=isoDate(v);if(!raw)return{raw:null,date:null,quality:'MISSING'};if(!iso)return{raw,date:null,quality:'UNPARSEABLE'};const y=Number(iso.slice(0,4)),now=new Date().getUTCFullYear();if(y>now)return{raw,date:null,quality:'FUTURE'};if(y<1900)return{raw,date:null,quality:'IMPLAUSIBLE_OLD'};return{raw,date:iso,quality:'VALID'};}
function address(v){const raw=text(v)||null;if(!raw)return{raw:null,street:null,district:null,province:null,department:null,status:'MISSING'};const p=raw.split(',').map(x=>x.trim()).filter(Boolean);if(p.length<3)return{raw,street:raw,district:null,province:null,department:null,status:'UNPARSEABLE'};return{raw,street:p.slice(0,-3).join(', ')||null,district:p[p.length-3],province:p[p.length-2],department:p[p.length-1],status:'PARSED_RIGHT'};}
function budget(v){const raw=text(v)||null;if(!raw)return{raw:null,a:null,b:null};const m=raw.match(/^\s*([\d.,]+)\s*\/\s*([\d.,]+)\s*$/);if(!m)return{raw,a:null,b:null};const n=x=>{const z=Number(String(x).replace(/,/g,''));return Number.isFinite(z)?z:null};return{raw,a:n(m[1]),b:n(m[2])};}
function stablePayload(row){const o={};for(const h of HEADERS)o[h]=text(row[h]);return o;}
function sha256Buffer(b){return crypto.createHash('sha256').update(b).digest('hex');}
function sha256Text(s){return crypto.createHash('sha256').update(s,'utf8').digest('hex');}
function rowHash(payload){return sha256Text(JSON.stringify(payload));}
function seedHash(sourceSha,rowNum,phone,doc,email,nameKey){let seed='ROW:'+sourceSha+':'+rowNum;if(email.key)seed='EMAIL:'+email.key;else if(doc.type==='DNI8'&&doc.key&&nameKey)seed='DNI_NAME:'+doc.key+'|'+nameKey;else if(phone.type==='PERU_9'&&phone.key&&nameKey)seed='PHONE_NAME:'+phone.key+'|'+nameKey;return sha256Text(seed);}
function tags(v){return text(v)||null;}

async function parseWorkbook(buffer){
 if(!Buffer.isBuffer(buffer)||!buffer.length)throw Object.assign(new Error('EMPTY_FILE'),{status:400});
 if(buffer.length>MAX_FILE_BYTES)throw Object.assign(new Error('FILE_TOO_LARGE'),{status:413});
 const wb=new ExcelJS.Workbook();await wb.xlsx.load(buffer);
 const ws=wb.getWorksheet('Hoja 1')||wb.worksheets[0];if(!ws)throw Object.assign(new Error('WORKSHEET_MISSING'),{status:400});
 const headers=[];for(let c=1;c<=27;c++)headers.push(text(ws.getCell(1,c).value));
 if(headers.length!==HEADERS.length||headers.some((h,i)=>h!==HEADERS[i]))throw Object.assign(new Error('SCHEMA_MISMATCH'),{status:409,details:{headers}});
 const rows=[];for(let r=2;r<=ws.rowCount;r++){
   const obj={};let has=false;for(let c=1;c<=27;c++){const v=ws.getCell(r,c).value;obj[HEADERS[c-1]]=v;if(text(v))has=true;}if(!has)continue;
   rows.push({excelRow:r,data:obj});if(rows.length>MAX_ROWS)throw Object.assign(new Error('ROW_LIMIT_EXCEEDED'),{status:413});
 }
 return rows;
}
function normalizeRow(item,sourceSha){
 const x=item.data,p=normalizePhone(x['Teléfono']),d=normalizeDoc(x['N° documento']),e=normalizeEmail(x['Email']);
 const names=text(x['Nombres'])||null,surnames=text(x['Apellidos'])||null,nameKey=asciiUpper(`${names||''} ${surnames||''}`)||null;
 const b=birth(x['Fecha de nacimiento']),a=address(x['Dirección']),bu=budget(x['Último presupuesto']);
 const payload=stablePayload(x),sourceId=text(x['ID del paciente']);if(!sourceId)throw Object.assign(new Error('SOURCE_PATIENT_ID_MISSING'),{status:409,row:item.excelRow});
 return {source_row_num:item.excelRow,source_patient_id:sourceId,source_created_date:isoDate(x['F. creación de paciente']),phone_raw:p.raw,phone_key:p.key,phone_type:p.type,names_raw:names,surnames_raw:surnames,name_key:nameKey,email_raw:e.raw,email_key:e.key,document_raw:d.raw,document_key:d.key,document_type:d.type,sex_raw:text(x['Sexo'])||null,birth_date_raw:b.raw,birth_date:b.date,birth_quality:b.quality,address_raw:a.raw,address_street:a.street,district:a.district,province:a.province,department:a.department,address_parse_status:a.status,occupation:text(x['Ocupación'])||null,guardian:text(x['Apoderado'])||null,acquisition_channel:text(x['¿Cómo nos conoció?'])||null,acquisition_reference:text(x['Referencia de Procedencia'])||null,clinical_note:text(x['Nota clínica'])||null,allergies:text(x['Alergias'])||null,business_line:text(x['Línea de negocio'])||null,hc_raw:text(x['N° HC'])||null,inactive_raw:text(x['Inactivo'])||null,tags_raw:tags(x['Etiquetas']),last_appointment:isoDate(x['Última cita']),next_appointment:isoDate(x['Próxima cita']),task_raw:text(x['Tarea'])||null,last_budget_raw:bu.raw,budget_num_a:bu.a,budget_num_b:bu.b,row_content_hash:rowHash(payload),identity_seed_hash:seedHash(sourceSha,item.excelRow,p,d,e,nameKey),raw_payload:payload};
}
async function parseAndNormalize(buffer){const sourceSha=sha256Buffer(buffer),parsed=await parseWorkbook(buffer);return{sourceSha,rows:parsed.map(r=>normalizeRow(r,sourceSha)),columns:HEADERS.length};}
module.exports={HEADERS,MAX_FILE_BYTES,parseAndNormalize,sha256Buffer,normalizePhone,normalizeDoc,normalizeEmail,asciiUpper,address,budget};
