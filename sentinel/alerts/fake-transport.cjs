'use strict';

class FakeTransport {
  constructor({isAvailable=true,clock=()=>new Date().toISOString(),fail=false}={}){
    this.isAvailable=isAvailable;
    this.clock=clock;
    this.fail=fail;
    this.messages=[];
  }
  available(){return this.isAvailable;}
  async send(envelope){
    if(!this.isAvailable)return {ok:false,code:'UNAVAILABLE'};
    if(this.fail)return {ok:false,code:'SYNTHETIC_FAILURE'};
    const record={...structuredClone(envelope),message_id:`fake-${this.messages.length+1}`,at:new Date(this.clock()).toISOString()};
    this.messages.push(record);
    return {ok:true,message_id:record.message_id,at:record.at};
  }
}

module.exports={FakeTransport};
