'use strict';

const CANONICAL_NAME='Sentinel Owner Alerts';

function assertServiceClient(client){
  if(!client||typeof client.from!=='function')throw new Error('F9_TELEGRAM_SERVICE_CLIENT_REQUIRED');
}

function createSupabaseTelegramConfigProvider({serviceClient,integrationName=CANONICAL_NAME}={}){
  assertServiceClient(serviceClient);
  if(integrationName!==CANONICAL_NAME)throw new Error('F9_TELEGRAM_INTEGRATION_NAME_NOT_CANONICAL');

  return async function loadTelegramConfig(){
    const metaQuery=serviceClient
      .from('aos_integraciones')
      .select('id,tipo,nombre,estado')
      .eq('nombre',integrationName)
      .ilike('tipo','telegram')
      .eq('estado','activo')
      .limit(2);
    const meta=await metaQuery;
    if(meta?.error)throw new Error('F9_TELEGRAM_METADATA_UNAVAILABLE');
    const rows=Array.isArray(meta?.data)?meta.data:[];
    if(rows.length!==1)throw new Error(rows.length===0?'F9_TELEGRAM_INTEGRATION_NOT_CONFIGURED':'F9_TELEGRAM_INTEGRATION_AMBIGUOUS');
    const integrationId=String(rows[0].id||'');
    if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(integrationId))throw new Error('F9_TELEGRAM_INTEGRATION_ID_INVALID');

    const secretQuery=serviceClient
      .from('aos_integration_secrets_v1')
      .select('api_key,api_secret')
      .eq('integration_id',integrationId)
      .limit(2);
    const secrets=await secretQuery;
    if(secrets?.error)throw new Error('F9_TELEGRAM_SECRET_VAULT_UNAVAILABLE');
    const secretRows=Array.isArray(secrets?.data)?secrets.data:[];
    if(secretRows.length!==1)throw new Error(secretRows.length===0?'F9_TELEGRAM_SECRET_NOT_CONFIGURED':'F9_TELEGRAM_SECRET_AMBIGUOUS');

    return {
      bot_token:String(secretRows[0].api_key||''),
      chat_id:String(secretRows[0].api_secret||'')
    };
  };
}

module.exports={createSupabaseTelegramConfigProvider,CANONICAL_NAME};
