'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');

const preload=fs.readFileSync('app/business-priority-preload.js','utf8');

test('classified background work has a bounded transport budget',()=>{
  assert.match(preload,/BACKGROUND_REQUEST_BUDGET_MS/);
  assert.match(preload,/BACKGROUND_BUDGET_EXCEEDED/);
  assert.match(preload,/600000/);
  assert.match(preload,/1800000/);
});

test('emergency foreground mode retains no reminder-cron exception',()=>{
  assert.match(preload,/if \(key && FOREGROUND_PRIORITY_MODE\) return fakeRequest/);
  assert.doesNotMatch(preload,/key === 'agent-cron-scan'\) return isReminderWindow/);
  assert.match(preload,/emergencyBackgroundLane: 'NONE'/);
});

test('critical business paths remain outside background classification',()=>{
  assert.doesNotMatch(preload,/return 'auth/);
  assert.doesNotMatch(preload,/return 'callcenter/);
  assert.doesNotMatch(preload,/return 'agenda/);
  assert.match(preload,/aos_notification_push_claim_v1/);
  assert.match(preload,/tipo_ejecucion=eq\.cron/);
});
