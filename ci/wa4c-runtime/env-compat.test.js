'use strict';
const assert=require('assert');
const path=require('path');
const mod=path.resolve(__dirname,'../../app/email-runtime-env-compat.cjs');

function run(env){
  const prev={canonical:process.env.SUPABASE_SERVICE_ROLE_KEY,alias:process.env.service_role};
  delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  delete process.env.service_role;
  if(Object.prototype.hasOwnProperty.call(env,'canonical'))process.env.SUPABASE_SERVICE_ROLE_KEY=env.canonical;
  if(Object.prototype.hasOwnProperty.call(env,'alias'))process.env.service_role=env.alias;
  delete require.cache[require.resolve(mod)];
  require(mod);
  const out={canonical:process.env.SUPABASE_SERVICE_ROLE_KEY,alias:process.env.service_role};
  if(prev.canonical===undefined)delete process.env.SUPABASE_SERVICE_ROLE_KEY;else process.env.SUPABASE_SERVICE_ROLE_KEY=prev.canonical;
  if(prev.alias===undefined)delete process.env.service_role;else process.env.service_role=prev.alias;
  return out;
}

assert.deepStrictEqual(run({alias:'alias-secret'}),{canonical:'alias-secret',alias:'alias-secret'});
assert.deepStrictEqual(run({canonical:'canonical-secret'}),{canonical:'canonical-secret',alias:'canonical-secret'});
assert.deepStrictEqual(run({canonical:'canonical-secret',alias:'alias-secret'}),{canonical:'canonical-secret',alias:'alias-secret'});
assert.deepStrictEqual(run({}),{canonical:undefined,alias:undefined});
console.log('WA4C_ENV_COMPAT_PASS');
