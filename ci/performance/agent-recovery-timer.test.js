'use strict'
const test=require('node:test')
const assert=require('node:assert/strict')
const fs=require('fs')

const preload=fs.readFileSync('app/agent-recovery-timer-preload.cjs','utf8')
const railway=JSON.parse(fs.readFileSync('app/railway.json','utf8'))

test('recovery timer gate is narrow and reversible',()=>{
  assert.match(preload,/AOS_FOREGROUND_PRIORITY_MODE/)
  assert.match(preload,/fn\.name !== 'guardedAutoTick'/)
  assert.match(preload,/ms === 15000 \|\| ms === 60000/)
  assert.match(preload,/hour >= 8 && hour <= 11/)
  assert.match(preload,/hour >= 20 && hour <= 23/)
  assert.match(preload,/if \(!enabled \|\| isReminderWindow\(limaHour\(\)\)\) return fn\.apply/)
})

test('production entrypoint loads timer gate only as a NODE_OPTIONS preload',()=>{
  const start=String(railway.deploy&&railway.deploy.startCommand||'')
  assert.match(start,/--require \.\/agent-recovery-timer-preload\.cjs/)
  assert.match(start,/node server-phase-s-f17\.js$/)
  assert.equal(String(railway.build&&railway.build.buildCommand||'').includes('agent-recovery-timer-preload'),false)
})

test('gate does not name foreground business paths',()=>{
  for(const token of ['aos_siguiente_lead','aos_callcenter_','aos_agenda','aos_login_v3','notification']){
    assert.equal(preload.includes(token),false,'timer gate must not intercept '+token)
  }
})
