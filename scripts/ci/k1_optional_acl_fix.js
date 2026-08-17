'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n')}
function write(p,s){fs.writeFileSync(p,s,'utf8')}
function die(m){throw new Error(m)}

const migration='supabase/migrations/20260817170100_kronia_k1_app_token_control_plane.sql';
{
  let s=read(migration);
  const start=s.indexOf('-- Raw implementations are never browser-callable after K1.');
  const end=s.indexOf('-- ══════════════════════════════════════════════════════════════════════════════\n-- 2. Authoritative audit/log stores',start);
  if(start<0||end<0)die('K1-B optional ACL anchors missing');
  const replacement=`-- Raw implementations and retired token helpers are never browser-callable after K1.\n-- Optional legacy RPCs are resolved with to_regprocedure(): production revokes every\n-- function that exists, while clean/staging installs do not abort on absent legacy code.\ndo $acl$\ndeclare v_sig text; r regprocedure;\nbegin\n  foreach v_sig in array array[\n    'public.aos_editar_venta(bigint,jsonb,text,text,text)',\n    'public.aos_kronia_agregar_nota_paciente(text,text,text)',\n    'public.aos_kronia_buscar_cita(text,text,text)',\n    'public.aos_kronia_buscar_paciente(text)',\n    'public.aos_kronia_buscar_venta(text,text,text)',\n    'public.aos_kronia_editar_cita(bigint,jsonb,text,text)',\n    'public.aos_kronia_editar_paciente(text,jsonb,text)',\n    'public.aos_kronia_explorar(text,text,jsonb)',\n    'public.aos_kronia_marcar_estado_cita(bigint,text,text,text)',\n    'public.aos_kronia_reprogramar_seguimiento(text,text,text,text,text)',\n    'public.aos_kronia_obtener_insights_sofia()',\n    'public.aos_kronia_stats_agenda()',\n    'public.aos_kronia_stats_leads()',\n    'public.aos_kronia_stats_llamadas()',\n    'public.aos_kronia_stats_pacientes()',\n    'public.aos_kronia_limpiar_tokens_expirados()',\n    'public.aos_kronia_emitir_token(text,text,text,text,text,text,text)',\n    'public.aos_kronia_verify_token(text)',\n    'public.aos_kronia_revocar_token(text)'\n  ] loop\n    r:=to_regprocedure(v_sig);\n    if r is not null then\n      execute format('revoke all on function %s from public,anon,authenticated',r);\n      execute format('grant execute on function %s to service_role',r);\n    end if;\n  end loop;\nend\n$acl$;\n\n-- Legacy KronIA tokens are no longer an authority source.\nalter table public.aos_kronia_tokens enable row level security;\ndrop policy if exists kronia_tokens_service_only on public.aos_kronia_tokens;\ncreate policy kronia_tokens_service_only on public.aos_kronia_tokens for all to service_role using(true) with check(true);\nrevoke all on table public.aos_kronia_tokens from public,anon,authenticated;\ngrant all on table public.aos_kronia_tokens to service_role;\n\n`;
  s=s.slice(0,start)+replacement+s.slice(end);
  if(s.includes("'public.aos_kronia_agregar_nota_paciente(text,text,text)'::regprocedure"))die('hard regprocedure cast survived K1-B');
  if(!s.includes('r:=to_regprocedure(v_sig);'))die('guarded optional ACL resolver missing K1-B');
  write(migration,s);
}

const rollback='supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql';
{
  let s=read(rollback);
  const start=s.indexOf('-- Never restore raw browser-callable business/KronIA authority.');
  const end=s.indexOf('-- Sensitive identity reads remain least-privilege during recovery.',start);
  if(start<0||end<0)die('recovery optional ACL anchors missing');
  const replacement=`-- Never restore raw browser-callable business/KronIA authority.\n-- Recovery is idempotent even when a clean install never had a legacy RPC.\ndo $acl$\ndeclare v_sig text; r regprocedure;\nbegin\n  foreach v_sig in array array[\n    'public.aos_editar_venta(bigint,jsonb,text,text,text)',\n    'public.aos_kronia_agregar_nota_paciente(text,text,text)',\n    'public.aos_kronia_buscar_cita(text,text,text)',\n    'public.aos_kronia_buscar_paciente(text)',\n    'public.aos_kronia_buscar_venta(text,text,text)',\n    'public.aos_kronia_editar_cita(bigint,jsonb,text,text)',\n    'public.aos_kronia_editar_paciente(text,jsonb,text)',\n    'public.aos_kronia_explorar(text,text,jsonb)',\n    'public.aos_kronia_marcar_estado_cita(bigint,text,text,text)',\n    'public.aos_kronia_reprogramar_seguimiento(text,text,text,text,text)',\n    'public.aos_login(text,text)',\n    'public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text)',\n    'public.aos_admin_cambiar_password(uuid,text)',\n    'public.aos_admin_cambiar_password(text,text,text,text)',\n    'public.aos_cambiar_password(text,text,text)'\n  ] loop\n    r:=to_regprocedure(v_sig);\n    if r is not null then execute format('revoke all on function %s from public,anon,authenticated',r); end if;\n  end loop;\nend\n$acl$;\n\n`;
  s=s.slice(0,start)+replacement+s.slice(end);
  if(s.includes('::regprocedure'))die('hard regprocedure cast survived recovery');
  if(!s.includes('r:=to_regprocedure(v_sig);'))die('guarded optional ACL resolver missing recovery');
  write(rollback,s);
}

const contract='ci/kronia-k1-phase2/security_static_contract.py';
{
  let s=read(contract);
  const anchor="if 'aos_integration_secrets_v1' not in sql: fail('private provider vault missing')\n";
  const check="if \"::regprocedure\" in text(MIG/'20260817170100_kronia_k1_app_token_control_plane.sql'): fail('hard optional legacy regprocedure cast in K1-B')\nif \"r:=to_regprocedure(v_sig);\" not in text(MIG/'20260817170100_kronia_k1_app_token_control_plane.sql'): fail('guarded optional K1-B ACL resolver missing')\n";
  if(!s.includes(check)){
    if(!s.includes(anchor))die('static contract insertion anchor missing');
    s=s.replace(anchor,anchor+check);
  }
  const recoveryAnchor="recovery=text(ROOT/'supabase'/'rollbacks'/'20260814_kronia_k1_phase2_safe_recovery.sql').lower()\n";
  const recoveryCheck="if '::regprocedure' in recovery or 'to_regprocedure(v_sig)' not in recovery: fail('recovery optional RPC ACL is not idempotent')\n";
  if(!s.includes(recoveryCheck)){
    if(!s.includes(recoveryAnchor))die('recovery static contract anchor missing');
    s=s.replace(recoveryAnchor,recoveryAnchor+recoveryCheck);
  }
  write(contract,s);
}

console.log('KRONIA_K1_OPTIONAL_RPC_ACL_FIX=PASS');
