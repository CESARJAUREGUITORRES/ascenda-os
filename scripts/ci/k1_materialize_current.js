'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8')}
function write(p,s){fs.writeFileSync(p,s,'utf8')}
function die(m){throw new Error(m)}
function replaceOnce(s,oldv,newv,label){
  if(s.includes(newv)) return s;
  const i=s.indexOf(oldv); if(i<0) die(label+' anchor missing');
  if(s.indexOf(oldv,i+1)>=0) die(label+' anchor not unique');
  return s.slice(0,i)+newv+s.slice(i+oldv.length);
}
function beforeLastCommit(s,block,label){
  if(s.includes(block.trim().split('\n')[0])) return s;
  const i=s.lastIndexOf('\ncommit;'); if(i<0) die(label+' commit anchor missing');
  return s.slice(0,i)+block+s.slice(i);
}

// ── 1. Provider-secret authority: K1-A + K1-E read only private vault. ──
{
  const p='supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql';
  let s=read(p);
  const oldv=`    select i.api_key into v_api_key from public.aos_integraciones i
    where (lower(coalesce(i.tipo,''))='resend' or lower(coalesce(i.nombre,'')) like '%resend%')
      and coalesce(length(i.api_key),0)>10
    order by coalesce(i.principal,false) desc,i.updated_at desc nulls last limit 1;`;
  const newv=`    -- CURRENT provider-secret boundary: credential material is service-side only.
    -- aos_integraciones remains metadata/status; the key itself lives in the private vault.
    select s.api_key into v_api_key
    from public.aos_integration_secrets_v1 s
    join public.aos_integraciones i on i.id=s.integration_id
    where (lower(coalesce(s.tipo,''))='resend' or lower(coalesce(s.nombre,'')) like '%resend%')
      and coalesce(length(s.api_key),0)>10
      and lower(coalesce(i.estado,'')) in ('conectado','activo')
    order by coalesce(i.principal,false) desc,s.updated_at desc nulls last limit 1;`;
  if(!s.includes('from public.aos_integration_secrets_v1 s')) s=replaceOnce(s,oldv,newv,'K1-A private secret');
  if(s.includes('select i.api_key into v_api_key from public.aos_integraciones')) die('K1-A legacy secret authority survived');
  write(p,s);
}
{
  const p='supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql';
  let s=read(p);
  const oldv=`    select i.api_key into v_api_key
    from public.aos_integraciones i
    where (pg_catalog.lower(coalesce(i.tipo,''))='resend' or pg_catalog.lower(coalesce(i.nombre,'')) like '%resend%')
      and coalesce(pg_catalog.length(i.api_key),0)>10
    order by coalesce(i.principal,false) desc,i.updated_at desc nulls last limit 1;`;
  const newv=`    -- CURRENT provider-secret boundary: final branded Auth V3 reads only the private vault.
    select s.api_key into v_api_key
    from public.aos_integration_secrets_v1 s
    join public.aos_integraciones i on i.id=s.integration_id
    where (pg_catalog.lower(coalesce(s.tipo,''))='resend' or pg_catalog.lower(coalesce(s.nombre,'')) like '%resend%')
      and coalesce(pg_catalog.length(s.api_key),0)>10
      and pg_catalog.lower(coalesce(i.estado,'')) in ('conectado','activo')
    order by coalesce(i.principal,false) desc,s.updated_at desc nulls last limit 1;`;
  if(!s.includes('from public.aos_integration_secrets_v1 s')) s=replaceOnce(s,oldv,newv,'K1-E private secret');
  if(s.includes('select i.api_key into v_api_key')) die('K1-E legacy secret authority survived');
  write(p,s);
}

// ── 2. K1-B writes secrets only to private vault. ──
{
  const p='supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql';
  let s=read(p);
  const oldv=`  if v_action='disable' then
    update public.aos_integraciones set estado='pendiente',api_key=null,api_secret=null,config=null,webhook_url=null,cuenta='',updated_at=now() where id=p_id;
  elsif v_action='update' then
    update public.aos_integraciones set
      cuenta=coalesce(p_data->>'cuenta',cuenta),estado=coalesce(p_data->>'estado',estado),
      principal=coalesce((p_data->>'principal')::boolean,principal),
      api_key=case when p_data ? 'api_key' then nullif(p_data->>'api_key','') else api_key end,
      api_secret=case when p_data ? 'api_secret' then nullif(p_data->>'api_secret','') else api_secret end,
      config=case when p_data ? 'config' then p_data->'config' else config end,
      webhook_url=case when p_data ? 'webhook_url' then nullif(p_data->>'webhook_url','') else webhook_url end,
      updated_at=now()
    where id=p_id;
  else return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;`;
  const newv=`  if v_action='disable' then
    update public.aos_integraciones
      set estado='pendiente',api_key='',api_secret='',config=null,webhook_url=null,cuenta='',updated_at=now()
      where id=p_id;
    update public.aos_integration_secrets_v1
      set api_key='',api_secret='',updated_at=now()
      where integration_id=p_id;
  elsif v_action='update' then
    update public.aos_integraciones set
      cuenta=coalesce(p_data->>'cuenta',cuenta),estado=coalesce(p_data->>'estado',estado),
      principal=coalesce((p_data->>'principal')::boolean,principal),
      api_key='',api_secret='',
      config=case when p_data ? 'config' then p_data->'config' else config end,
      webhook_url=case when p_data ? 'webhook_url' then nullif(p_data->>'webhook_url','') else webhook_url end,
      updated_at=now()
    where id=p_id;
    if p_data ? 'api_key' or p_data ? 'api_secret' then
      insert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)
      select i.id,i.tipo,i.nombre,
             case when p_data ? 'api_key' then coalesce(p_data->>'api_key','') else '' end,
             case when p_data ? 'api_secret' then coalesce(p_data->>'api_secret','') else '' end,
             now(),now()
      from public.aos_integraciones i where i.id=p_id
      on conflict(integration_id) do update set
        tipo=excluded.tipo,nombre=excluded.nombre,
        api_key=case when p_data ? 'api_key' then excluded.api_key else public.aos_integration_secrets_v1.api_key end,
        api_secret=case when p_data ? 'api_secret' then excluded.api_secret else public.aos_integration_secrets_v1.api_secret end,
        updated_at=now();
    end if;
  else return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;`;
  if(!s.includes('insert into public.aos_integration_secrets_v1')) s=replaceOnce(s,oldv,newv,'K1-B private secret writer');
  if(s.includes("api_key=case when p_data ? 'api_key'")||s.includes("api_secret=case when p_data ? 'api_secret'")) die('K1-B public secret write survived');

  const piiBlock=`

-- K1 CURRENT sensitive identity read boundary.
-- Raw browser access is a minimal operational directory only. Full Team/PII
-- requires an Auth V3 app token, privileged admin identity and 2FA.
revoke all on table public.aos_usuarios from anon,authenticated;
grant select(id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios)
  on public.aos_usuarios to anon,authenticated;
revoke all on table public.aos_rrhh from anon,authenticated;
grant select(codigo_asesor,nombre,apellido,puesto,sede,estado)
  on public.aos_rrhh to anon,authenticated;
revoke all on table public.aos_team_full from public,anon,authenticated;
grant select on table public.aos_team_full to service_role;

create or replace function public.aos_team_feed_v3(
  p_token text,
  p_cargo text default null,
  p_limit integer default 200
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_i jsonb; v_rows jsonb; v_limit integer:=greatest(1,least(coalesce(p_limit,200),500));
begin
  v_i:=public.aos_kronia_identity_v3(p_token,true,'admin-team');
  if not coalesce((v_i->>'ok')::boolean,false) then return v_i; end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows
  from (
    select * from public.aos_team_full t
    where nullif(trim(coalesce(p_cargo,'')),'') is null or t.cargo=p_cargo
    order by t.nivel_jerarquia,t.nombre
    limit v_limit
  ) x;
  return jsonb_build_object('ok',true,'rows',v_rows);
end
$function$;
revoke all on function public.aos_team_feed_v3(text,text,integer) from public;
grant execute on function public.aos_team_feed_v3(text,text,integer) to anon,authenticated,service_role;
`;
  s=beforeLastCommit(s,piiBlock,'K1-B PII boundary');
  write(p,s);
}

// ── 3. Synthetic fixture models CURRENT private vault, never production secrets. ──
{
  const p='ci/kronia-k1-phase2/fixture_pre_k1.sql'; let s=read(p);
  if(!s.includes('CURRENT aos_integraciones shape required by K1-B')) s+=`

-- CURRENT aos_integraciones shape required by K1-B (shape only).
alter table public.aos_integraciones
  add column if not exists cuenta text default '',
  add column if not exists config jsonb default '{}'::jsonb,
  add column if not exists created_at timestamptz default now(),
  add column if not exists categoria text default 'infraestructura',
  add column if not exists icono text default '🔗',
  add column if not exists descripcion text default '',
  add column if not exists api_secret text default '',
  add column if not exists webhook_url text default '',
  add column if not exists pasos_guia jsonb default '[]'::jsonb,
  add column if not exists uso_para text[] default '{}'::text[],
  add column if not exists orden integer default 0,
  add column if not exists url_api text default '',
  add column if not exists url_docs text default '',
  add column if not exists url_signup text default '',
  add column if not exists multi_cuenta boolean default false,
  add column if not exists logo_url text default '';
`;
  if(!s.includes('CURRENT provider-secret boundary (synthetic shape + dummy credential only)')) s+=`

-- CURRENT provider-secret boundary (synthetic shape + dummy credential only).
-- The browser-readable integration catalog keeps metadata; credential material
-- moves to a FORCE-RLS service-only vault exactly as in CURRENT production.
create table if not exists public.aos_integration_secrets_v1 (
  integration_id uuid primary key references public.aos_integraciones(id) on delete cascade,
  tipo text not null,
  nombre text not null,
  api_key text not null default '',
  api_secret text not null default '',
  captured_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.aos_integration_secrets_v1 enable row level security;
alter table public.aos_integration_secrets_v1 force row level security;
revoke all on table public.aos_integration_secrets_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_integration_secrets_v1 to service_role;
insert into public.aos_integration_secrets_v1(integration_id,tipo,nombre,api_key,api_secret,captured_at,updated_at)
select id,tipo,nombre,api_key,'',now(),now()
from public.aos_integraciones
where coalesce(api_key,'')<>''
on conflict(integration_id) do update
set tipo=excluded.tipo,nombre=excluded.nombre,api_key=excluded.api_key,updated_at=now();
update public.aos_integraciones set api_key='',api_secret='',updated_at=now()
where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';
`;
  write(p,s);
}

// ── 4. Recovery preserves private vault and PII least privilege. ──
{
  const p='supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql'; let s=read(p);
  if(!s.includes('alter table public.aos_integration_secrets_v1 force row level security;')){
    const anchor=`-- Integration secret material remains server-only.
revoke all on table public.aos_integraciones from anon,authenticated;`;
    const repl=`-- Integration secret material remains server-only.
alter table public.aos_integration_secrets_v1 enable row level security;
alter table public.aos_integration_secrets_v1 force row level security;
revoke all on table public.aos_integration_secrets_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_integration_secrets_v1 to service_role;
update public.aos_integraciones set api_key='',api_secret='' where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';
revoke all on table public.aos_integraciones from anon,authenticated;`;
    s=replaceOnce(s,anchor,repl,'recovery private vault');
  }
  const pii=`

-- Sensitive identity reads remain least-privilege during recovery.
revoke all on table public.aos_usuarios from anon,authenticated;
grant select(id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios)
  on public.aos_usuarios to anon,authenticated;
revoke all on table public.aos_rrhh from anon,authenticated;
grant select(codigo_asesor,nombre,apellido,puesto,sede,estado) on public.aos_rrhh to anon,authenticated;
revoke all on table public.aos_team_full from public,anon,authenticated;
grant select on table public.aos_team_full to service_role;
`;
  s=beforeLastCommit(s,pii,'recovery PII'); write(p,s);
}

// ── 5. Browser Team compatibility + canonical token. ──
{
  const p='app/public/k1-browser-security.js'; let s=read(p);
  const ivar="var SAFE_INTEGRATION_COLUMNS='id,tipo,nombre,cuenta,estado,principal,categoria,icono,descripcion,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url,created_at,updated_at';";
  if(!s.includes('var SAFE_USER_COLUMNS=')){
    if(!s.includes(ivar)) die('browser safe-integration anchor missing');
    s=s.replace(ivar,ivar+"\n  var SAFE_USER_COLUMNS='id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios';\n  var SAFE_RRHH_COLUMNS='codigo_asesor,nombre,apellido,puesto,sede,estado';");
  }
  if(!s.includes('function filterTeamRows')){
    const anchor='  function targetIdFrom(u){'; if(!s.includes(anchor)) die('browser helper anchor missing');
    const helper=`  function filterTeamRows(u,rows){
    rows=Array.isArray(rows)?rows.slice():[];
    ['id','codigo_asesor','cargo','sede','activo'].forEach(function(k){var v=u.searchParams.get(k)||'';if(v.indexOf('eq.')===0){v=decodeURIComponent(v.slice(3));rows=rows.filter(function(r){return String(r[k])===v})}});
    var sel=String(u.searchParams.get('select')||'*');
    if(sel&&sel!=='*'&&sel.indexOf('(')<0){var keys=sel.split(',').map(function(x){return x.trim()}).filter(Boolean);rows=rows.map(function(r){var o={};keys.forEach(function(k){if(Object.prototype.hasOwnProperty.call(r,k))o[k]=r[k]});return o})}
    var lim=Number(u.searchParams.get('limit')||500);if(Number.isFinite(lim)&&lim>0)rows=rows.slice(0,Math.min(lim,500));
    return rows;
  }
`;
    s=s.replace(anchor,helper+anchor);
  }
  if(!s.includes("u.pathname==='/rest/v1/aos_team_full'")){
    const anchor="    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_agente_logs'){"; if(!s.includes(anchor)) die('browser route anchor missing');
    const route=`    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_team_full'){
      var cargo=(u.searchParams.get('cargo')||'').replace(/^eq\\./,'');
      return rpcJson('aos_team_feed_v3',{p_token:token(),p_cargo:cargo?decodeURIComponent(cargo):null,p_limit:Number(u.searchParams.get('limit')||500)}).then(function(d){return resp(filterTeamRows(u,d.rows||[]),200)});
    }
    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_usuarios'){
      return rpcJson('aos_team_feed_v3',{p_token:token(),p_cargo:null,p_limit:500}).then(function(d){return resp(filterTeamRows(u,d.rows||[]),200)}).catch(function(){u.searchParams.set('select',SAFE_USER_COLUMNS);return nativeFetch(u.toString(),init)});
    }
    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_rrhh'){
      u.searchParams.set('select',SAFE_RRHH_COLUMNS);return nativeFetch(u.toString(),init);
    }
`;
    s=s.replace(anchor,route+'\n'+anchor);
  }
  write(p,s);
}
{
  const p='app/public/admin-team.html'; let s=read(p);
  s=s.split("sessionStorage.getItem('aos_si_token')||''").join("sessionStorage.getItem('aos_app_token')||''");
  if(s.includes('aos_si_token')) die('admin-team alternate token survived'); write(p,s);
}

// ── 6. SQL certificate for raw PII closure. ──
{
  const p='ci/kronia-k1-phase2/001_k1_phase2_certificate.sql'; let s=read(p);
  if(!s.includes('KRONIA_K1_CURRENT_SENSITIVE_READ_BOUNDARY=PASS')) s+=`

-- K1P2-CURRENT-PII: raw sensitive Team/identity reads must be closed.
do $$
declare j jsonb;
begin
  if has_table_privilege('anon','public.aos_team_full','SELECT') or has_table_privilege('authenticated','public.aos_team_full','SELECT') then
    raise exception 'K1P2-PII-01 aos_team_full remains browser-readable';
  end if;
  if has_table_privilege('anon','public.aos_usuarios','SELECT') or has_table_privilege('anon','public.aos_rrhh','SELECT') then
    raise exception 'K1P2-PII-02 raw identity table-level SELECT remains open';
  end if;
  if has_column_privilege('anon','public.aos_usuarios','sueldo','SELECT')
     or has_column_privilege('anon','public.aos_usuarios','dni','SELECT')
     or has_column_privilege('anon','public.aos_usuarios','direccion','SELECT')
     or has_column_privilege('anon','public.aos_usuarios','contacto_emergencia','SELECT')
     or has_column_privilege('anon','public.aos_rrhh','password_hash','SELECT') then
    raise exception 'K1P2-PII-03 sensitive identity columns remain browser-readable';
  end if;
  if not has_column_privilege('anon','public.aos_usuarios','id','SELECT')
     or not has_column_privilege('anon','public.aos_rrhh','codigo_asesor','SELECT') then
    raise exception 'K1P2-PII-04 minimal directory compatibility missing';
  end if;
  if not has_function_privilege('anon','public.aos_team_feed_v3(text,text,integer)','EXECUTE') then
    raise exception 'K1P2-PII-05 secure Team feed unavailable';
  end if;
  j:=public.aos_team_feed_v3('invalid-token',null,10);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-PII-06 Team feed accepted invalid authority'; end if;
end $$;
\\echo 'KRONIA_K1_CURRENT_SENSITIVE_READ_BOUNDARY=PASS'
`;
  write(p,s);
}

// ── 7. Chrome floating UI uses Auth V3 and does not persist conversation history. ──
{
  const p='chrome-extension/manifest.json'; let s=read(p);
  const oldv='"js": ["kronia-core.js", "content-script.js"]';
  const newv='"js": ["kronia-core.js", "k1-extension-auth.js", "content-script.js"]';
  if(!s.includes(newv)) s=replaceOnce(s,oldv,newv,'Chrome manifest Auth V3'); write(p,s);
}
{
  const p='chrome-extension/content-script.js'; let s=read(p);
  const oldLogin=`  var loginUsuario = el('input', { type: 'text', placeholder: 'Tu usuario', autocomplete: 'username' });
  var btnPedirCodigo = el('button', { text: 'Enviar código a mi email' });
  var step1 = el('div', { class: 'kronia-login-step active' }, [
    el('label', { text: 'Usuario' }),
    loginUsuario,
    btnPedirCodigo
  ]);`;
  const newLogin=`  var loginUsuario = el('input', { type: 'text', placeholder: 'Tu usuario', autocomplete: 'username' });
  var loginPassword = el('input', { type: 'password', placeholder: 'Tu contraseña', autocomplete: 'current-password' });
  var btnPedirCodigo = el('button', { text: 'Continuar' });
  var step1 = el('div', { class: 'kronia-login-step active' }, [
    el('label', { text: 'Usuario' }),
    loginUsuario,
    el('label', { text: 'Contraseña' }),
    loginPassword,
    btnPedirCodigo
  ]);`;
  if(!s.includes("var loginPassword = el('input'")) s=replaceOnce(s,oldLogin,newLogin,'Chrome floating password');
  const oldHandler=`  btnPedirCodigo.addEventListener('click', function () {
    var u = loginUsuario.value.trim();
    if (!u) { loginErr.textContent = 'Ingresa tu usuario'; return; }
    loginErr.textContent = '';
    btnPedirCodigo.disabled = true;
    btnPedirCodigo.textContent = 'Enviando...';
    state.loginUsuario = u;
    core.loginRequest(u).then(function (r) {
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Enviar código a mi email';
      if (r && r.ok) {
        document.querySelector('.kronia-codigo-ok').textContent =
          '✓ Código enviado a ' + (r.email_oculto || 'tu email');
        step1.classList.remove('active');
        step2.classList.add('active');
        loginCodigo.focus();
      } else {
        loginErr.textContent = (r && r.error) || 'No se pudo enviar el código';
      }
    }).catch(function (e) {
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Enviar código a mi email';
      loginErr.textContent = 'Error de conexión';
    });
  });`;
  const newHandler=`  btnPedirCodigo.addEventListener('click', function () {
    var u = loginUsuario.value.trim(), pw = loginPassword.value;
    if (!u || !pw) { loginErr.textContent = 'Ingresa usuario y contraseña'; return; }
    loginErr.textContent = '';
    btnPedirCodigo.disabled = true;
    btnPedirCodigo.textContent = 'Verificando...';
    state.loginUsuario = u;
    core.loginRequest(u, pw).then(function (r) {
      loginPassword.value = '';
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Continuar';
      if (r && r.ok && r.token) {
        state.authenticated = true;
        state.user = core.getUser();
        core.persist(chrome.storage.local);
        setStatus('· ' + ((state.user&&state.user.usuario)||u), '#fff');
        showLogin(false);
        welcomeMessage();
        return;
      }
      if (r && r.ok && r.require_2fa) {
        document.querySelector('.kronia-codigo-ok').textContent =
          '✓ Código enviado a ' + (r.email_masked || r.email_oculto || 'tu email');
        step1.classList.remove('active');
        step2.classList.add('active');
        loginCodigo.focus();
      } else {
        loginErr.textContent = (r && r.error) || 'No se pudo iniciar sesión';
      }
    }).catch(function () {
      loginPassword.value = '';
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Continuar';
      loginErr.textContent = 'Error de conexión';
    });
  });`;
  if(!s.includes('core.loginRequest(u, pw)')) s=replaceOnce(s,oldHandler,newHandler,'Chrome Auth V3 handler');
  s=s.split("      loginUsuario.value = '';\n      loginCodigo.value = '';" ).join("      loginUsuario.value = '';\n      if (loginPassword) loginPassword.value = '';\n      loginCodigo.value = '';");
  const oldKey=`  loginUsuario.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnPedirCodigo.click(); }
  });`;
  const newKey=`  loginUsuario.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); loginPassword.focus(); }
  });
  loginPassword.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnPedirCodigo.click(); }
  });`;
  if(!s.includes("loginPassword.addEventListener('keydown'")) s=replaceOnce(s,oldKey,newKey,'Chrome password keyboard');
  if(!s.includes('core.loginRequest(u, pw)')) die('Chrome Auth V3 request missing'); write(p,s);
}
{
  const p='chrome-extension/kronia-core.js'; let s=read(p);
  const oldv=`        var data = {
          token: state.token,
          user: state.user,
          historial: state.historial
        };`;
  const newv=`        var data = {
          token: state.token,
          user: state.user
        };`;
  if(s.includes(oldv)) s=s.replace(oldv,newv);
  s=s.replace("            if (Array.isArray(data.historial)) state.historial = data.historial;\n",'');
  if(s.includes('historial: state.historial')||s.includes('data.historial')) die('persistent Chrome history survived'); write(p,s);
}

// ── 8. Self-contained permanent runtime contract assertions. ──
{
  const p='ci/kronia-k1-phase2/runtime_contract.py'; let s=read(p);
  if(!s.includes('KRONIA_K1_CURRENT_NODE_MATERIALIZED_CONTRACT')) s+=String.raw`

# KRONIA_K1_CURRENT_NODE_MATERIALIZED_CONTRACT
from pathlib import Path as _K1Path
_k1root=_K1Path(__file__).resolve().parents[2]
_k1a=(_k1root/'supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql').read_text()
_k1b=(_k1root/'supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql').read_text()
_k1e=(_k1root/'supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql').read_text()
_k1r=(_k1root/'supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql').read_text()
_k1browser=(_k1root/'app/public/k1-browser-security.js').read_text()
_k1team=(_k1root/'app/public/admin-team.html').read_text()
_k1manifest=(_k1root/'chrome-extension/manifest.json').read_text()
_k1content=(_k1root/'chrome-extension/content-script.js').read_text()
_k1core=(_k1root/'chrome-extension/kronia-core.js').read_text()
assert 'from public.aos_integration_secrets_v1 s' in _k1a and 'select i.api_key into v_api_key from public.aos_integraciones' not in _k1a
assert 'from public.aos_integration_secrets_v1 s' in _k1e and 'select i.api_key into v_api_key' not in _k1e
assert 'insert into public.aos_integration_secrets_v1' in _k1b and 'update public.aos_integration_secrets_v1' in _k1b
assert "api_key=case when p_data ? 'api_key'" not in _k1b and "api_secret=case when p_data ? 'api_secret'" not in _k1b
assert 'aos_team_feed_v3' in _k1b and 'revoke all on table public.aos_team_full from public,anon,authenticated' in _k1b
assert 'SAFE_USER_COLUMNS' in _k1browser and 'SAFE_RRHH_COLUMNS' in _k1browser
assert 'aos_si_token' not in _k1team and 'aos_app_token' in _k1team
assert '"js": ["kronia-core.js", "k1-extension-auth.js", "content-script.js"]' in _k1manifest
assert 'core.loginRequest(u, pw)' in _k1content
assert 'historial: state.historial' not in _k1core and 'data.historial' not in _k1core
assert 'force row level security' in _k1r and 'Sensitive identity reads remain least-privilege during recovery.' in _k1r
print('KRONIA_K1_CURRENT_NODE_MATERIALIZED_CONTRACT=PASS')
`;
  write(p,s);
}

// Final static invariants.
const A=read('supabase/migrations/20260814170000_kronia_k1_private_credentials_auth_v3.sql');
const B=read('supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql');
const E=read('supabase/migrations/20260814171800_kronia_k1_auth_v3_branded_alignment.sql');
const R=read('supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql');
if(!A.includes('from public.aos_integration_secrets_v1 s')||A.includes('select i.api_key into v_api_key from public.aos_integraciones')) die('final K1-A invariant failed');
if(!E.includes('from public.aos_integration_secrets_v1 s')||E.includes('select i.api_key into v_api_key')) die('final K1-E invariant failed');
if(!B.includes('insert into public.aos_integration_secrets_v1')||!B.includes('aos_team_feed_v3')) die('final K1-B invariant failed');
if(!R.includes('force row level security')||!R.includes('Sensitive identity reads remain least-privilege during recovery.')) die('final recovery invariant failed');
console.log('KRONIA_K1_CURRENT_NODE_MATERIALIZER=PASS');
