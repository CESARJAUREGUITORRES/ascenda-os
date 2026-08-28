'use strict';
const assert=require('assert');
const {isConfiguredSupabaseRequest}=require('../../app/supabase-quota-target.cjs');
const host='ituyqwstonmhnfshnaqz.supabase.co';

assert.strictEqual(isConfiguredSupabaseRequest([{hostname:host,headers:{}}],host),true);
assert.strictEqual(isConfiguredSupabaseRequest([{hostname:host,headers:{'User-Agent':'legacy-no-tag'}}],host),true);
assert.strictEqual(isConfiguredSupabaseRequest([new URL('https://'+host+'/rest/v1/aos_agentes')],host),true);
assert.strictEqual(isConfiguredSupabaseRequest(['https://'+host+'/rest/v1/rpc/aos_push_vapid_config_v1'],host),true);
assert.strictEqual(isConfiguredSupabaseRequest([{hostname:'graph.facebook.com',headers:{}}],host),false);
assert.strictEqual(isConfiguredSupabaseRequest([{hostname:'example.supabase.co',headers:{}}],host),false);

console.log('WA4C_QUOTA_TARGET_PASS');
