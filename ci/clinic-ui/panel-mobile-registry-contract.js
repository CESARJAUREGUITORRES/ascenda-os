'use strict'
const fs=require('fs')

const app=fs.readFileSync('app/public/app.html','utf8')
const shell=fs.readFileSync('app/public/clinic-shell-ui-v1.js','utf8')
const css=fs.readFileSync('app/public/clinic-panels-mobile-v13.css','utf8')
const callCss=fs.readFileSync('app/public/clinic-callcenter-mobile-v12.css','utf8')
const agents=fs.readFileSync('AGENTS.md','utf8')
const registry=JSON.parse(fs.readFileSync('ci/clinic-ui/panel-mobile-registry.json','utf8'))

function ok(v,m){if(!v){console.error('RESPONSIVE PANEL REGISTRY FAIL:',m);process.exit(1)}}
function parseObject(blockName){
  const re=new RegExp('var\\s+'+blockName+'\\s*=\\s*\\{([\\s\\S]*?)\\n\\s*\\};')
  const m=app.match(re)
  ok(m,blockName+' block missing')
  const out={}
  const item=/'([^']+)'\s*:\s*'([^']+)'/g
  let x
  while((x=item.exec(m[1])))out[x[1]]=x[2]
  return out
}
const viewMap=parseObject('VIEW_MAP')
const panelRoutes=parseObject('PANEL_ROUTES')
const regMap=Object.fromEntries(registry.views.map(v=>[v.view_id,v]))

for(const [view,handler] of Object.entries(viewMap)){
  ok(regMap[view],'unregistered VIEW_MAP view: '+view)
  ok(panelRoutes[handler],'handler has no PANEL_ROUTES route: '+view+' -> '+handler)
  ok(regMap[view].route===panelRoutes[handler],'route mismatch for '+view+': registry '+regMap[view].route+' vs shell '+panelRoutes[handler])
  ok(/^ADAPTED_BASELINE_/.test(regMap[view].baseline_status),'view not adapted baseline: '+view)
  if(view==='advisor-calls'){
    ok(regMap[view].adapter==='/clinic-callcenter-mobile-v12.css','Call Center reference adapter drift')
    ok(callCss.includes('.clinic-compact-ui .workspace .main-grid'),'Call Center compact adapter missing')
  }else{
    ok(regMap[view].adapter==='/clinic-panels-mobile-v13.css','V1.3 adapter missing from registry: '+view)
    ok(css.includes('data-active-view="'+view+'"'),'V1.3 CSS selector missing for '+view)
  }
}
for(const view of Object.keys(regMap))ok(viewMap[view],'registry contains stale/non-shell view: '+view)

ok(shell.includes("ws.setAttribute('data-active-view',active)"),'shell active-view scoping missing')
ok(app.includes('/clinic-panels-mobile-v13.css?v=20260915-1'),'V1.3 CSS not wired')
ok(app.includes('/clinic-callcenter-mobile-v12.css?v=20260915-1'),'Call Center V1.2 CSS not preserved')
ok(app.includes('/clinic-shell-ui-v1.js?v=20260915-3'),'shell cache-bust missing')
ok(agents.includes('ASCENDA_RESPONSIVE_UI_AGENT_CURRENT.md'),'AGENTS responsive agent bootstrap missing')
ok(agents.includes('ASCENDA_RESPONSIVE_PANEL_SKILL_V1.md'),'AGENTS responsive skill bootstrap missing')
ok(!css.includes('display:none!important'),'V1.3 must not hide operational content via display:none!important')
ok(css.includes('.clinic-compact-ui .workspace[data-active-view]'),'global compact scope missing')
ok(!css.includes('html:not(.clinic-compact-ui)'),'V1.3 must not alter desktop layout')
ok(registry.views.length===Object.keys(viewMap).length,'registry/view-map count mismatch')

console.log('Responsive panel registry coverage:',registry.views.length,'views')
console.log('ASCENDA Responsive Panel Agent/Skill V1.3 contract: PASS')
