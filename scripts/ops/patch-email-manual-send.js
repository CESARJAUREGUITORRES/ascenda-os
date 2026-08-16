'use strict';

const fs = require('fs');
const path = require('path');

const target = path.join(process.cwd(), 'app', 'public', 'admin-email.html');
let src = fs.readFileSync(target, 'utf8');

function replaceOnce(needle, replacement, label) {
  const count = src.split(needle).length - 1;
  if (count !== 1) throw new Error(label + ': expected 1 occurrence, found ' + count);
  src = src.replace(needle, replacement);
}

function replaceCount(needle, replacement, expected, label) {
  const count = src.split(needle).length - 1;
  if (count !== expected) throw new Error(label + ': expected ' + expected + ' occurrence(s), found ' + count);
  src = src.split(needle).join(replacement);
}

replaceOnce(
  '      <button class="mbtn mbtn-p" onclick="openNewCampania()">+ Nueva Campaña</button>',
  '      <button class="mbtn mbtn-g" onclick="openManualEmail()">✉️ Enviar Email</button>\n      <button class="mbtn mbtn-p" onclick="openNewCampania()">+ Nueva Campaña</button>',
  'header manual-send button'
);

replaceOnce(
  "function rpc(fn,params,cb){emCall('LEGACY_RPC',{name:fn,params:params||{}}).then(function(r){cb(r.data);}).catch(function(e){console.error(fn,e);showToast('Error de sesión/email',e.message,true);});}\n",
  "function rpc(fn,params,cb){emCall('LEGACY_RPC',{name:fn,params:params||{}}).then(function(r){cb(r.data);}).catch(function(e){console.error(fn,e);showToast('Error de sesión/email',e.message,true);});}\nfunction rpcSilent(fn,params,cb){emCall('LEGACY_RPC',{name:fn,params:params||{}}).then(function(r){cb(r.data);}).catch(function(e){console.warn('[EMAIL-MKT] fallback RPC no disponible:',fn,e.message);});}\n",
  'silent fallback RPC helper'
);

replaceCount("rpc('aos_email_dashboard'", "rpcSilent('aos_email_dashboard'", 2, 'dashboard fallback RPCs');

const manualFunctions = `function openManualEmail(){
  _sendClientRequestId='';
  var html='<div style="font-family:Exo 2;font-weight:800;font-size:16px;margin-bottom:4px;">Nuevo Email</div>';
  html+='<div style="font-size:10px;color:#6B7BA8;margin-bottom:14px;">Envío manual transaccional mediante el gateway seguro de ASCENDA. La API de Resend nunca se expone al navegador.</div>';
  html+='<div style="margin-bottom:10px;"><label style="font-size:9px;font-weight:700;color:#6B7BA8;">Email destinatario</label><input class="mi" id="manual-email" type="email" autocomplete="off" placeholder="correo@dominio.com" style="margin-top:4px;"></div>';
  html+='<div style="margin-bottom:14px;"><label style="font-size:9px;font-weight:700;color:#6B7BA8;">Nombre</label><input class="mi" id="manual-name" autocomplete="off" placeholder="Nombre del destinatario" style="margin-top:4px;"></div>';
  html+='<div style="display:flex;gap:8px;"><button class="mbtn mbtn-g" onclick="continueManualEmail()">Continuar →</button><button class="mbtn mbtn-c" onclick="el(\\'m-send\\').classList.remove(\\'open\\')">Cancelar</button></div>';
  el('ms-body').innerHTML=html;
  el('m-send').classList.add('open');
  setTimeout(function(){var input=document.getElementById('manual-email');if(input)input.focus();},50);
}
function continueManualEmail(){
  var email=String(el('manual-email').value||'').trim();
  var nombre=String(el('manual-name').value||'').trim()||'Paciente';
  if(!email||email.length>320||!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(email)){showToast('Email inválido','Ingresa un correo válido antes de continuar',true);return;}
  el('m-send').classList.remove('open');
  setTimeout(function(){enviarEmailA(email,nombre,'');},0);
}

`;
replaceOnce('function enviarEmailA(email,nombre,numero){', manualFunctions + 'function enviarEmailA(email,nombre,numero){', 'manual-send functions');

replaceOnce(
  "  q('aos_email_plantillas','select=id,nombre,tipo,asunto&activo=eq.true&order=nombre',function(tpls){\n    var html=",
  "  q('aos_email_plantillas','select=id,nombre,tipo,asunto&activo=eq.true&order=nombre',function(tpls){\n    var manualTypes={agradecimiento:true,agradecimiento_visita:true,bienvenida:true,catalogo:true,comprobante:true,confirmacion_cita:true,confirmacion_pago:true,no_asistencia:true,recibo_venta:true,recordatorio:true,recordatorio_hoy:true,reprogramacion:true,saldo_pendiente:true,seguimiento:true};\n    tpls=(tpls||[]).filter(function(t){return manualTypes[String(t.tipo||'').toLowerCase().trim()]===true;});\n    if(!tpls.length){showToast('Sin plantillas transaccionales','No hay una plantilla activa autorizada para envío manual',true);return;}\n    var html=",
  'manual template allowlist'
);

fs.writeFileSync(target, src, 'utf8');

const checks = [
  'onclick="openManualEmail()"',
  'function openManualEmail()',
  'function continueManualEmail()',
  'function rpcSilent(',
  "emCall('LEGACY_SEND'",
  'manualTypes={agradecimiento:true'
];
for (const check of checks) {
  if (!src.includes(check)) throw new Error('missing expected output: ' + check);
}
if ((src.match(/rpcSilent\('aos_email_dashboard'/g) || []).length !== 2) throw new Error('dashboard fallback was not isolated exactly twice');
if ((src.match(/onclick="openManualEmail\(\)"/g) || []).length !== 1) throw new Error('manual-send button count mismatch');
if ((src.match(/function openManualEmail\(\)/g) || []).length !== 1) throw new Error('manual-send function count mismatch');

const script = src.match(/<script>([\s\S]*?)<\/script>/);
if (!script) throw new Error('script block not found');
fs.writeFileSync(path.join(process.cwd(), 'email-admin-check.tmp.js'), script[1], 'utf8');
console.log('EMAIL_MANUAL_SEND_PATCH=PASS');
