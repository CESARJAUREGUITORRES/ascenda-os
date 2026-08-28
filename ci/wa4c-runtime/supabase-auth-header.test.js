'use strict';
const assert=require('assert');
const {buildSupabaseHeaders}=require('../../app/supabase-runtime-auth.cjs');

let h=buildSupabaseHeaders('sb_secret_example',{'Content-Type':'application/json'});
assert.strictEqual(h.apikey,'sb_secret_example');
assert.strictEqual(Object.prototype.hasOwnProperty.call(h,'Authorization'),false);
assert.strictEqual(h['Content-Type'],'application/json');

h=buildSupabaseHeaders('sb_publishable_example');
assert.strictEqual(h.apikey,'sb_publishable_example');
assert.strictEqual(Object.prototype.hasOwnProperty.call(h,'Authorization'),false);

h=buildSupabaseHeaders('legacy.jwt.key');
assert.strictEqual(h.apikey,'legacy.jwt.key');
assert.strictEqual(h.Authorization,'Bearer legacy.jwt.key');

h=buildSupabaseHeaders('');
assert.strictEqual(h.apikey,'');
assert.strictEqual(Object.prototype.hasOwnProperty.call(h,'Authorization'),false);

console.log('WA4C_SUPABASE_AUTH_HEADER_PASS');
