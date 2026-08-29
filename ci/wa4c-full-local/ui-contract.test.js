'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const ui=fs.readFileSync(path.join(root,'app/public/wa4-copilot-experience.js'),'utf8');
const shell=fs.readFileSync(path.join(root,'app/public/wa-shell-integration.js'),'utf8');
const wa3=fs.readFileSync(path.join(root,'app/server-wa3.js'),'utf8');

test('native shell mounts WA-4 Copilot experience',()=>{
  assert.match(shell,/wa4-copilot-experience\.js/);
  assert.match(shell,/ensureExperience\(\)/);
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
  assert.doesNotMatch(m[1],/api\(/);
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

test('server does not introduce AI send or auto-routing mutation',()=>{
  assert.doesNotMatch(ui,/ai_send_enabled\s*[:=]\s*true/);
  assert.doesNotMatch(ui,/auto_reply_enabled\s*[:=]\s*true/);
  assert.doesNotMatch(ui,/auto_routing_enabled\s*[:=]\s*true/);
});
