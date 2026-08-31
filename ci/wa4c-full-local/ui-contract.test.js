'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const ui=fs.readFileSync(path.join(root,'app/public/wa4-copilot-experience.js'),'utf8');
const shell=fs.readFileSync(path.join(root,'app/public/wa-shell-integration.js'),'utf8');
const wa3=fs.readFileSync(path.join(root,'app/server-wa3.js'),'utf8');
const agenda=fs.readFileSync(path.join(root,'app/public/agendar-v2.html'),'utf8');
const agendaLegacy=fs.readFileSync(path.join(root,'app/public/agendar.html'),'utf8');

test('native shell mounts and refreshes WA-4 Copilot experience',()=>{
  assert.match(shell,/wa4-copilot-experience\.js/);
  assert.match(shell,/ensureExperience\(\)/);
  assert.match(shell,/refreshExperience\(\)/);
  assert.match(shell,/__wa4CopilotExperience/);
});

test('Copilot suggestion is explicit and advisor-only',()=>{
  assert.match(ui,/\/api\/wa4\/conversations\/.*\/suggest/);
  assert.match(ui,/Generar sugerencia/);
  assert.match(ui,/Usar respuesta/);
  assert.match(ui,/AUTO SEND OFF/);
  assert.match(ui,/auto_send:false/);
});

test('Use response only writes composer and never calls send endpoint',()=>{
  const m=ui.match(/function useSuggestion\(\)\{([\s\S]*?)\}\nfunction prepare/);
  assert(m,'useSuggestion body missing');
  assert.match(m[1],/ta\.value=/);
  assert.doesNotMatch(m[1],/\/send/);
  assert.doesNotMatch(m[1],/apiCall\(/);
});

test('interactive send remains a second explicit human action',()=>{
  assert.match(ui,/Preparar botones/);
  assert.match(ui,/Preparar lista/);
  assert.match(ui,/Enviar opciones/);
  assert.match(ui,/function sendDraft\(\)/);
  assert.match(ui,/\/api\/wa3\/conversations\/.*\/send/);
  assert.match(wa3,/aos_wa3_human_send_authorize_v1/);
  assert.match(wa3,/interactive_buttons/);
  assert.match(wa3,/interactive_list/);
});

test('Copilot extension adds no polling timer or mutation observer',()=>{
  assert.doesNotMatch(ui,/\bsetInterval\s*\(/);
  assert.doesNotMatch(ui,/\bsetTimeout\s*\(/);
  assert.doesNotMatch(ui,/\bMutationObserver\s*\(/);
  assert.match(ui,/document\.addEventListener\('click'/);
});

test('server does not introduce AI send or auto-routing mutation',()=>{
  assert.doesNotMatch(ui,/ai_send_enabled\s*[:=]\s*true/);
  assert.doesNotMatch(ui,/auto_reply_enabled\s*[:=]\s*true/);
  assert.doesNotMatch(ui,/auto_routing_enabled\s*[:=]\s*true/);
});

test('public agenda consumes the same canonical booking authority as WA-4C',()=>{
  assert.match(agenda,/aos_booking_public_catalog_v2/);
  assert.match(agenda,/aos_booking_availability_v2/);
  assert.match(agenda,/aos_agendar_publica_v2/);
  assert.match(agenda,/SITE_POOL/);
  assert.match(agenda,/Enfermería de turno/);
  assert.match(agenda,/p_profesional_id:AG\.slot\.mode==='EXACT_PROVIDER'\?AG\.slot\.professional_id:null/);
  assert.match(agendaLegacy,/agendar-v2\.html/);
});
