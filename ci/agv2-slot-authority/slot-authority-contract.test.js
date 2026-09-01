const fs=require('fs');
const assert=require('assert');
const {test}=require('node:test');

const sql=fs.readFileSync('supabase/migrations/20260901123000_agv2_slot_authority_v2.sql','utf8');

function must(re,msg){assert.match(sql,re,msg);}

test('L2 freezes 30-minute grid and 5/6 capacity without duration slot blocking',()=>{
  must(/reservation_grid_min[^\n]*default 30/i,'30-min grid missing');
  must(/soft_capacity[^\n]*default 5/i,'soft capacity 5 missing');
  must(/overflow_capacity[^\n]*default 6/i,'overflow capacity 6 missing');
  must(/duration_blocks_future_booking boolean not null default false/i,'duration must not consume future slots');
  must(/autonomous_overflow_enabled boolean not null default false/i,'autonomous overflow must start safe-off');
});

test('clinical timing is procedure-aware and fail-closed',()=>{
  must(/aos_booking_timing_authority_v2/,'timing table missing');
  must(/aos_booking_procedure_for_service_v1/,'procedure resolver missing');
  must(/TIMING_AUTHORITY_MISSING/,'missing timing must fail closed');
  must(/HARD_RESOURCE_AUTHORITY_NOT_WIRED/,'hard resource constraint must fail closed until wired');
});

test('critical canary families have explicit business timing',()=>{
  must(/\('TOXINA','\*',15,30,30,0\)/,'toxina timing missing');
  must(/\('HIFU','\*',45,60,60,0\)/,'HIFU timing missing');
  must(/\('HIDROFACIAL','\*',60,60,60,0\)/,'hidrofacial timing missing');
  must(/\('CRIOLIPOLISIS','\*',90,90,90,0\)/,'criolipolisis timing missing');
  must(/CELLBOOSTER GLOW',30,30,30,0/,'Cellbooster timing missing');
});

test('AGV2 BOOK/REBOOK selected slot consumes L2 authority but live V1 availability is not replaced',()=>{
  must(/create or replace function public\.aos_booking_slot_authority_v2/i,'L2 slot authority missing');
  must(/v_av:=coalesce\(public\.aos_booking_slot_authority_v2/i,'AGV2 selected slot not wired to L2');
  assert.doesNotMatch(sql,/create or replace function public\.aos_booking_availability_v2\s*\(/i,'live V1/public availability must remain untouched in L2 dormant rollout');
});

test('safe-off autonomous boundary remains intact',()=>{
  assert.doesNotMatch(sql,/(auto_reply_enabled|ai_send_enabled|auto_routing_enabled)\s*=\s*true/i);
  assert.doesNotMatch(sql,/autonomous_overflow_enabled\s*=\s*true/i);
});
