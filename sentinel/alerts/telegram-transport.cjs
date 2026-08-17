'use strict';

const BOT_TOKEN=/^[0-9]{5,20}:[A-Za-z0-9_-]{20,200}$/;
const CHAT_ID=/^(?:-?[0-9]{1,20}|@[A-Za-z0-9_]{5,64})$/;

class TelegramTransport {
  constructor({configProvider,fetchImpl=globalThis.fetch,enabled=false,timeoutMs=5000}={}){
    if(typeof configProvider!=='function')throw new Error('F9_TELEGRAM_CONFIG_PROVIDER_REQUIRED');
    if(typeof fetchImpl!=='function')throw new Error('F9_TELEGRAM_FETCH_REQUIRED');
    if(!Number.isInteger(timeoutMs)||timeoutMs<500||timeoutMs>15000)throw new Error('F9_TELEGRAM_TIMEOUT_INVALID');
    this.configProvider=configProvider;
    this.fetchImpl=fetchImpl;
    this.enabled=enabled===true;
    this.timeoutMs=timeoutMs;
  }

  available(){return this.enabled;}

  async send(envelope){
    if(!this.enabled)return {ok:false,code:'UNAVAILABLE'};
    if(!envelope||envelope.channel!=='telegram-owner'||typeof envelope.text!=='string'||envelope.text.length<1||envelope.text.length>4096){
      return {ok:false,code:'INVALID_ENVELOPE'};
    }

    let config;
    try{config=await this.configProvider();}catch{return {ok:false,code:'UNAVAILABLE'};}
    const token=String(config?.bot_token||'');
    const chatId=String(config?.chat_id||'');
    if(!BOT_TOKEN.test(token)||!CHAT_ID.test(chatId))return {ok:false,code:'MISCONFIGURED'};

    const controller=new AbortController();
    const timer=setTimeout(()=>controller.abort(),this.timeoutMs);
    try{
      const response=await this.fetchImpl(`https://api.telegram.org/bot${token}/sendMessage`,{
        method:'POST',
        headers:{'content-type':'application/json'},
        body:JSON.stringify({chat_id:chatId,text:envelope.text,link_preview_options:{is_disabled:true}}),
        signal:controller.signal
      });
      let body=null;
      try{body=await response.json();}catch{return {ok:false,code:'INVALID_RESPONSE'};}
      if(!response.ok||body?.ok!==true){
        const retry=Number(body?.parameters?.retry_after);
        return {ok:false,code:response.status===429?'RATE_LIMITED':'TELEGRAM_REJECTED',retry_after:Number.isFinite(retry)&&retry>0?retry:null};
      }
      const messageId=body?.result?.message_id;
      if(!Number.isInteger(messageId))return {ok:false,code:'ACK_MISSING'};
      return {ok:true,message_id:String(messageId),at:new Date().toISOString()};
    }catch(err){
      if(err?.name==='AbortError')return {ok:false,code:'TIMEOUT'};
      return {ok:false,code:'NETWORK_ERROR'};
    }finally{
      clearTimeout(timer);
    }
  }
}

module.exports={TelegramTransport};
