'use strict'

const assert=require('assert')
const gateway=require('../../app/conversation-tool-gateway')
const business=require('../../app/conversation-business-tools')

assert.strictEqual(gateway.VERSION,'CONV-L4-TOOL-GATEWAY-V1')
assert.strictEqual(gateway.TOOL_NAMES.length,10)
assert.strictEqual(new Set(gateway.TOOL_NAMES).size,10)
for(const name of [
  'get_customer_context','get_prices','get_promotions','get_locations_payment_methods',
  'get_availability','prepare_booking','confirm_booking','get_media','handoff','create_hot_lead_signal'
]) assert(gateway.TOOL_NAMES.includes(name),'missing tool '+name)

const pay=business.safePayment({
  nombre:'Transferencia',moneda:'PEN',tipo:'BANCO',banco:'Banco',
  tipo_cuenta:'corriente',sede:'SAN ISIDRO',sedes_aplica:['SAN ISIDRO'],
  numero_cuenta:'SECRET_ACCOUNT',cci:'SECRET_CCI',titular:'SECRET_OWNER',
  datos:{secret:'SECRET_DATA'}
})
assert.strictEqual(pay.name,'Transferencia')
assert.strictEqual(pay.bank,'Banco')
assert(!Object.prototype.hasOwnProperty.call(pay,'numero_cuenta'))
assert(!Object.prototype.hasOwnProperty.call(pay,'cci'))
assert(!Object.prototype.hasOwnProperty.call(pay,'titular'))
assert(!Object.prototype.hasOwnProperty.call(pay,'datos'))
assert(!JSON.stringify(pay).includes('SECRET_'))

assert.strictEqual(business.promotionIsCurrent({activa:true,vigencia_inicio:'2026-09-01',vigencia_fin:'2026-09-30',max_usos:10,usos_actuales:2},'2026-09-13'),true)
assert.strictEqual(business.promotionIsCurrent({activa:true,vigencia_fin:'2026-09-12'},'2026-09-13'),false)
assert.strictEqual(business.promotionIsCurrent({activa:true,max_usos:2,usos_actuales:2},'2026-09-13'),false)

const handlers={}
for(const name of gateway.TOOL_NAMES)handlers[name]=async()=>({authority:'TEST',name})
const g=gateway.createToolGateway({handlers})

;(async()=>{
  const rejected=await g.execute('raw_sql',{query:'select anything'})
  assert.strictEqual(rejected.ok,false)
  assert.strictEqual(rejected.error,'TOOL_NOT_ALLOWED')

  const price=await g.execute('get_prices',{query:'toxina'})
  assert.strictEqual(price.ok,true)
  assert.strictEqual(price.data.authority,'TEST')
  assert.strictEqual(price.data.name,'get_prices')

  const failClosedHandlers=business.createBusinessToolHandlers({
    rpc:async()=>{const e=new Error('SUPABASE_REQUEST_TIMEOUT');e.code='SUPABASE_REQUEST_TIMEOUT';throw e},
    rest:async()=>[]
  })
  const failClosedGateway=gateway.createToolGateway({handlers:failClosedHandlers})
  const identity=await failClosedGateway.execute('get_customer_context',{phone:'999999999'})
  assert.strictEqual(identity.ok,true,'identity authority outage must be a governed result, not a tool crash')
  assert.strictEqual(identity.data.identity_status,'IDENTITY_AUTHORITY_UNAVAILABLE')
  assert.strictEqual(identity.data.known_customer,false)
  assert.strictEqual(identity.data.requires_human,true)
  assert.strictEqual(identity.data.authority_available,false)

  console.log('CONV_L4_TOOL_GATEWAY_CONTRACT_PASS')
})().catch(e=>{console.error(e);process.exit(1)})
