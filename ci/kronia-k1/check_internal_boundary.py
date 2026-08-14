from pathlib import Path

server=Path('app/server.js').read_text(encoding='utf-8')
app=Path('app/public/app.html').read_text(encoding='utf-8')
agents=Path('app/public/agents.html').read_text(encoding='utf-8')
brain=Path('app/public/cerebro.html').read_text(encoding='utf-8')
config=Path('app/public/admin-config.html').read_text(encoding='utf-8')

fail=[]
def req(text,needle,label):
    if needle not in text: fail.append('MISSING: '+label)
def forbid(text,needle,label):
    if needle in text: fail.append('FORBIDDEN: '+label)

# Server-owned storage.
req(server,'function sbServiceGet(endpoint)','service-role GET helper')
req(server,'function sbServicePost(endpoint, body, method)','service-role write helper')
req(server,"sbServicePost('/rest/v1/aos_kronia_conversaciones'",'conversation writes are service-owned')
req(server,"sbServicePost('/rest/v1/aos_agente_logs'",'agent log writes are service-owned')
req(server,"sbServicePost('/rest/v1/aos_agente_acciones'",'agent action writes are service-owned')
forbid(server,"sbPost('/rest/v1/aos_kronia_conversaciones'",'anon conversation writer survives')
forbid(server,"sbPost('/rest/v1/aos_agente_logs'",'anon agent-log writer survives')
forbid(server,"sbPost('/rest/v1/aos_agente_acciones'",'anon agent-action writer survives')
req(server,"p === '/api/agents/logs'",'ADMIN agent-log feed exists')
req(server,"p === '/api/kronia/audit-feed'",'bearer audit feed exists')
req(server,"p === '/api/kronia/admin/security-dashboard'",'ADMIN security dashboard exists')
req(server,"sbServiceRpc('aos_security_dashboard'",'security dashboard executes server-side')

# Agent Office can no longer read internal logs directly or call agent APIs anonymously.
req(agents,'function k1AgentHeaders(extra)','Agent Office bearer helper')
req(agents,'secureAgentLogs({limit:40})','Agent Office activity uses protected log feed')
req(agents,'secureAgentLogs({agent_id:agent.id,limit:20})','Agent detail uses protected log feed')
forbid(agents,"/rest/v1/aos_agente_logs?",'Agent Office reads agent logs directly from Supabase')
req(agents,"headers: k1AgentHeaders({ 'Content-Type': 'application/json' })",'Agent POST calls carry Bearer')
req(agents,"/api/agents/costs',{headers:k1AgentHeaders()}",'Agent costs carry Bearer')

# Main shell first-load agent feed uses protected API.
req(app,"/api/agents/logs?limit=8",'main shell agent feed protected')
forbid(app,"supabase.co/rest/v1/aos_agente_logs?",'main shell reads agent logs directly')

# Brain receives only sanitized audit events through the app boundary.
req(brain,"/api/kronia/audit-feed?after_id=",'Brain audit polling is tokenized')
req(brain,"direct Realtime subscription to audit table removed",'Brain direct audit Realtime removed')
forbid(brain,"/rest/v1/aos_log_auditoria?",'Brain reads audit table directly')
forbid(brain,"realtime:public:aos_log_auditoria",'Brain subscribes directly to audit table')

# Admin security UI receives a tokenized server read model and sanitized audit rows.
req(config,"/api/kronia/admin/security-dashboard",'config security dashboard is ADMIN API')
forbid(config,"/rest/v1/rpc/aos_security_dashboard",'config calls security RPC directly')
forbid(config,"/rest/v1/aos_log_auditoria?",'config reads audit table directly')

if fail:
    print('KRONIA_K1_INTERNAL_BOUNDARY=FAIL')
    for x in fail: print(' -',x)
    raise SystemExit(1)
print('KRONIA_K1_INTERNAL_BOUNDARY=PASS')
