'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8')}
function write(p,s){fs.writeFileSync(p,s,'utf8')}
function replaceOnce(p,oldText,newText){
  const original=read(p);
  let s=original.replace(/\r\n/g,'\n');
  oldText=oldText.replace(/\r\n/g,'\n');
  newText=newText.replace(/\r\n/g,'\n');
  if(s.includes(newText)){console.log(`${p}: already materialized`);return}
  const i=s.indexOf(oldText);
  if(i<0)throw new Error(`${p}: expected source shape not found`);
  if(s.indexOf(oldText,i+oldText.length)>=0)throw new Error(`${p}: ambiguous source shape`);
  s=s.replace(oldText,newText);
  write(p,s);
  console.log(`${p}: materialized`);
}

replaceOnce(
  'app/public/f4-revenue-ops.js',
`  if(name==='aos_cartera_gateway'){
    return nativeFetch(input,init).then(function(r){
      try{r.clone().json().then(function(d){if(d&&d.ok)carteraRows=d.rows||[]}).catch(function(){})}catch(e){}
      return r;
    });
  }`,
`  if(name==='aos_cartera_gateway'){
    var gb=parseBody(init);
    return postRpc(url,init,'aos_cartera_gateway_v2',{
      p_token:token(),p_estado:gb.p_estado||'',p_sede:gb.p_sede||'',
      p_limit:gb.p_limit==null?100:gb.p_limit,p_offset:gb.p_offset||0
    }).then(function(r){
      try{r.clone().json().then(function(d){if(d&&d.ok)carteraRows=d.rows||[]}).catch(function(){})}catch(e){}
      return r;
    });
  }

  if(name==='aos_cartera_gateway_v2'){
    return nativeFetch(input,init).then(function(r){
      try{r.clone().json().then(function(d){if(d&&d.ok)carteraRows=d.rows||[]}).catch(function(){})}catch(e){}
      return r;
    });
  }`
);

replaceOnce(
  'ci/phase4-revenue/ui_contract.js',
`ok(!bridge.includes('aos_si_token'), 'F4 must not fall back to the Sales Intelligence token scope');`,
`ok(!bridge.includes('aos_si_token'), 'F4 must not fall back to the Sales Intelligence token scope');
ok(bridge.includes("postRpc(url,init,'aos_cartera_gateway_v2'"), 'legacy Cartera browser call must route to the Auth V3 V2 gateway');`
);

replaceOnce(
  '.github/workflows/phase4-revenue-operations.yml',
`          psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260814223000_f4_revenue_operations_core_v1.sql
          psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260814223100_f4_cartera_candidates_v2.sql`,
`          psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260814223000_f4_revenue_operations_core_v1.sql
          psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260814223100_f4_cartera_candidates_v2.sql
          psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260815191500_f4_cartera_gateway_v2_auth_chain_hotfix.sql
          def="$(psql "$DB_URL" -X -qAt -c \"select pg_get_functiondef('public.aos_cartera_gateway_v2(text,text,text,integer,integer)'::regprocedure)\")"
          printf '%s' "$def" | grep -q 'aos_f4_actor'
          if printf '%s' "$def" | grep -q 'aos_cartera_gateway('; then
            echo 'F4 Cartera V2 must not delegate back to the legacy gateway' >&2
            exit 1
          fi`
);

const bridge=read('app/public/f4-revenue-ops.js');
if(bridge.includes('aos_si_token'))throw new Error('app/public/f4-revenue-ops.js: cross-scope token reference found');
if(!bridge.includes("postRpc(url,init,'aos_cartera_gateway_v2'"))throw new Error('V2 Cartera route missing');
console.log('F4_CARTERA_V2_AUTH_CHAIN_MATERIALIZATION=PASS');
