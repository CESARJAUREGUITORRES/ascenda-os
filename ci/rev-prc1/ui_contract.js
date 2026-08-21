'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8');}
function ok(c,m){if(!c)throw new Error(m);}
const ui=read('app/public/rev-prc1-product-resolution-center.js');
const canary=read('app/public/f4-production-canary-hotfix.js');
const v1=read('supabase/migrations/20260821122500_f4_revenue_prc1_product_resolution_center_v1.sql');
const v2=read('supabase/migrations/20260821130000_f4_revenue_prc1_product_resolution_center_v2.sql');
for(const m of ['aos_product_review_admin_v2','aos_product_review_resolve_v2','aos_product_review_reopen_v1','aos_product_batch_review_v1']) ok(ui.includes(m),`missing UI RPC ${m}`);
for(const m of ['Por validar','Resueltos','Excluidos','Todos los años','Todos los meses','Todas las sedes','Vista previa del impacto','Editar venta','Reabrir para corregir']) ok(ui.includes(m),`missing modal feature: ${m}`);
ok(ui.includes("host.insertBefore(b,cfg)"),'Validate products button must be inserted before Config');
ok(ui.includes("window.abrirEditorVenta"),'modal must reuse governed Sales editor');
ok(ui.includes('la descripción original de cada venta NO será modificada'),'impact preview must preserve raw sale evidence');
ok(ui.includes("p_default_qty")&&ui.includes("p_default_is_pack"),'physical quantity/pack controls missing');
ok(ui.includes("r.treatment<>'OTROS'")===false,'runtime must not contain SQL classification logic');
ok(v2.includes("r.treatment<>'OTROS'")&&v2.includes("OTROS is always SERVICIO"),'OTROS=SERVICIO batch contract missing');
ok(v2.includes('aos_product_review_admin_v2')&&v2.includes('p_year integer')&&v2.includes('p_month integer')&&v2.includes('p_sede text')&&v2.includes('p_search text'),'historical filter SQL contract missing');
ok(v2.includes('OWNER_REOPENED')&&v2.includes('REV_PRC1_PRODUCT_REOPEN'),'audited correction/reopen contract missing');
ok(!v1.toLowerCase().includes('update public.aos_ventas')&&!v2.toLowerCase().includes('update public.aos_ventas'),'PRC migrations must never mutate raw sales');
ok(canary.includes('20260821-prc1-v3-authbridge'),'deterministic PRC1 v3 auth-bridge runtime version missing');
ok(!ui.toLowerCase().includes('service_role'),'browser PRC must not contain service_role');
console.log('REV-PRC1 UI/governance contract PASS');
