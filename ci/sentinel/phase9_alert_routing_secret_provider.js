'use strict';

const assert=require('node:assert/strict');
const {createSupabaseTelegramConfigProvider,CANONICAL_NAME}=require('../../sentinel/alerts/supabase-telegram-config-provider.cjs');

function fakeClient({integrations=[],secrets=[],metaError=null,secretError=null}={}){
  return {
    from(table){
      const filters=[];
      const api={
        select(){return api;},
        eq(k,v){filters.push(['eq',k,v]);return api;},
        ilike(k,v){filters.push(['ilike',k,v]);return api;},
        limit(){
          if(table==='aos_integraciones'){
            if(metaError)return Promise.resolve({data:null,error:{message:metaError}});
            let rows=integrations.slice();
            for(const [kind,k,v] of filters){
              if(kind==='eq')rows=rows.filter(r=>String(r[k])===String(v));
              if(kind==='ilike')rows=rows.filter(r=>String(r[k]||'').toLowerCase()===String(v).toLowerCase());
            }
            return Promise.resolve({data:rows.slice(0,2),error:null});
          }
          if(table==='aos_integration_secrets_v1'){
            if(secretError)return Promise.resolve({data:null,error:{message:secretError}});
            let rows=secrets.slice();
            for(const [kind,k,v] of filters){if(kind==='eq')rows=rows.filter(r=>String(r[k])===String(v));}
            return Promise.resolve({data:rows.slice(0,2),error:null});
          }
          return Promise.resolve({data:null,error:{message:'unexpected table'}});
        }
      };
      return api;
    }
  };
}

(async()=>{
  const id='123e4567-e89b-42d3-a456-426614174000';
  const token='123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghi';
  const chat='-1001234567890';
  const provider=createSupabaseTelegramConfigProvider({
    serviceClient:fakeClient({
      integrations:[{id,tipo:'telegram',nombre:CANONICAL_NAME,estado:'activo'}],
      secrets:[{integration_id:id,api_key:token,api_secret:chat}]
    })
  });
  const cfg=await provider();
  assert.deepEqual(cfg,{bot_token:token,chat_id:chat});

  await assert.rejects(
    createSupabaseTelegramConfigProvider({serviceClient:fakeClient()})(),
    /F9_TELEGRAM_INTEGRATION_NOT_CONFIGURED/
  );
  await assert.rejects(
    createSupabaseTelegramConfigProvider({serviceClient:fakeClient({integrations:[
      {id,tipo:'telegram',nombre:CANONICAL_NAME,estado:'activo'},
      {id:'223e4567-e89b-42d3-a456-426614174000',tipo:'telegram',nombre:CANONICAL_NAME,estado:'activo'}
    ]})})(),
    /F9_TELEGRAM_INTEGRATION_AMBIGUOUS/
  );
  await assert.rejects(
    createSupabaseTelegramConfigProvider({serviceClient:fakeClient({integrations:[{id,tipo:'telegram',nombre:CANONICAL_NAME,estado:'activo'}]})})(),
    /F9_TELEGRAM_SECRET_NOT_CONFIGURED/
  );
  await assert.rejects(
    createSupabaseTelegramConfigProvider({serviceClient:fakeClient({integrations:[{id,tipo:'telegram',nombre:CANONICAL_NAME,estado:'activo'}],metaError:'synthetic'})})(),
    /F9_TELEGRAM_METADATA_UNAVAILABLE/
  );
  assert.throws(()=>createSupabaseTelegramConfigProvider({serviceClient:fakeClient(),integrationName:'Other Telegram'}),/F9_TELEGRAM_INTEGRATION_NAME_NOT_CANONICAL/);

  const src=require('fs').readFileSync(require('path').resolve(__dirname,'../../sentinel/alerts/supabase-telegram-config-provider.cjs'),'utf8');
  assert.match(src,/aos_integration_secrets_v1/);
  assert.doesNotMatch(src,/console\.(log|error|warn)/);
  assert.doesNotMatch(src,/process\.env/);

  console.log(JSON.stringify({
    ok:true,
    certificate:'SENTINEL_F9_SECRET_PROVIDER_CONTRACT_PASS',
    canonical_integration_name:CANONICAL_NAME,
    service_side_vault_only:true,
    public_secret_fallback:false,
    logging_of_secrets:false,
    live_secret_values_used:false
  }));
})().catch(e=>{console.error(e.stack||e);process.exit(1);});
