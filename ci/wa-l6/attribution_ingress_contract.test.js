'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const wa=require('../../app/wa-gateway');

function payload(message){
  return {object:'whatsapp_business_account',entry:[{changes:[{field:'messages',value:{metadata:{display_phone_number:'+51 999 111 222',phone_number_id:'pn-l6'},contacts:[],messages:[message]}}]}]};
}
function tp(out){return out.events.find(e=>e.event_type==='attribution.touchpoint');}

test('standard CTWA referral remains explicit and source_id ad fallback is preserved',()=>{
  const out=wa.extractWebhook(payload({id:'wamid.l6.std',from:'51911111111',timestamp:'1786807000',type:'text',text:{body:'Hola'},referral:{source_id:'ad-standard-1',source_type:'ad',source_url:'https://www.facebook.com/ads/x',headline:'Creative',ctwa_clid:'clid-1'}}));
  const t=tp(out);
  assert.ok(t);assert.equal(t.payload.ad_id,'ad-standard-1');assert.equal(t.payload.ctwa_clid,'clid-1');
  assert.equal(t.payload.campaign_id,null);assert.equal(t.payload.adset_id,null);assert.equal(t.payload.evidence_version,'WA_L6_V1');
});

test('provider extension campaign/adset/ad identifiers are preserved only when explicitly supplied',()=>{
  const out=wa.extractWebhook(payload({id:'wamid.l6.ext',from:'51911111111',timestamp:'1786807001',type:'text',text:{body:'Hola'},referral:{source_id:'creative-source',source_type:'ad',ad_id:'ad-explicit-9',campaign_id:'campaign-explicit-7',adset_id:'adset-explicit-8',ctwa_clid:'clid-2'}}));
  const t=tp(out);
  assert.equal(t.payload.ad_id,'ad-explicit-9');assert.equal(t.payload.campaign_id,'campaign-explicit-7');assert.equal(t.payload.adset_id,'adset-explicit-8');
});

test('campaign ids are never inferred from headline source URL phone username or source id',()=>{
  const out=wa.extractWebhook(payload({id:'wamid.l6.noinfer',from:'51911111111',timestamp:'1786807002',type:'text',text:{body:'Hola'},referral:{source_id:'post-44',source_type:'post',source_url:'https://example.com/campaign/secret-123',headline:'Campaign 999'}}));
  const t=tp(out);
  assert.ok(t);assert.equal(t.payload.campaign_id,null);assert.equal(t.payload.adset_id,null);assert.equal(t.payload.ad_id,null);
});

test('no provider referral produces no attribution touchpoint',()=>{
  const out=wa.extractWebhook(payload({id:'wamid.l6.unattributed',from:'51911111111',from_user_id:'bsuid-x',timestamp:'1786807003',type:'text',text:{body:'Direct'}}));
  assert.equal(tp(out),undefined);
});

test('invalid explicit campaign extension is stripped rather than normalized from another field',()=>{
  const out=wa.extractWebhook(payload({id:'wamid.l6.invalid',from:'51911111111',timestamp:'1786807004',type:'text',text:{body:'Hola'},referral:{source_id:'ad-1',source_type:'ad',campaign_id:'bad\u0001campaign',adset_id:'good-adset'}}));
  const t=tp(out);
  assert.equal(t.payload.campaign_id,null);assert.equal(t.payload.adset_id,'good-adset');assert.equal(t.payload.ad_id,'ad-1');
});
