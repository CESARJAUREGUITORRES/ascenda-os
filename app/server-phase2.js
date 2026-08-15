// ASCENDA OS — Phase 2 security front proxy.
// Keeps the existing application server intact while retiring legacy auth
// endpoints that exposed browser-generated OTP delivery and a fail-open CAPTCHA.
'use strict';

const http = require('http');
const https = require('https');
const { spawn } = require('child_process');

const EXTERNAL_PORT = parseInt(process.env.PORT || '4173', 10);
// Preserve production 4173→4187 and staging 4187→4188 exactly. Other explicit
// ports are test/dev scopes and receive an adjacent isolated internal port so
// sequential self-hosted CI cannot collide with a stale smoke process.
const INTERNAL_PORT = EXTERNAL_PORT === 4173 ? 4187 : (EXTERNAL_PORT === 4187 ? 4188 : EXTERNAL_PORT + 1);
const SB_URL = process.env.SUPABASE_URL || 'https://ituyqwstonmhnfshnaqz.supabase.co';
const SB_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYXNlIiwicmVmaWQiOiJpdHV5cXdzdG9ubWhuZnNobmFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';

const child = spawn(process.execPath, ['server.js'], {
  cwd: __dirname,
  env: Object.assign({}, process.env, { PORT: String(INTERNAL_PORT) }),
  stdio: ['ignore', 'inherit', 'inherit']
});

child.on('exit', (code, signal) => {
  console.error('[PHASE2-PROXY] backend exited', { code, signal });
  process.exit(code == null ? 1 : code);
});

function blocked(pathname) {
  return pathname === '/api/send-2fa' || pathname === '/api/verify-turnstile';
}

function writeJson(res, status, body, extraHeaders) {
  const headers = Object.assign({
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store, no-cache, must-revalidate'
  }, extraHeaders || {});
  res.writeHead(status, headers);
  res.end(JSON.stringify(body));
}

function authRpcProxy(req, res, rpcName) {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Cache-Control': 'no-store'
    });
    res.end();
    return;
  }
  if (req.method !== 'POST') {
    writeJson(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED', auth_version: 'v3' });
    return;
  }

  let body = '';
  let overflow = false;
  req.on('data', chunk => {
    if (overflow) return;
    body += chunk;
    if (Buffer.byteLength(body) > 16384) overflow = true;
  });
  req.on('end', () => {
    if (overflow) {
      writeJson(res, 413, { ok: false, error: 'PAYLOAD_TOO_LARGE', auth_version: 'v3' });
      return;
    }
    try { JSON.parse(body || '{}'); } catch (_) {
      writeJson(res, 400, { ok: false, error: 'INVALID_JSON', auth_version: 'v3' });
      return;
    }

    let sb;
    try { sb = new URL(SB_URL); } catch (_) {
      writeJson(res, 503, { ok: false, error: 'AUTH_UPSTREAM_CONFIG_ERROR', auth_version: 'v3' });
      return;
    }

    const payload = body || '{}';
    const upstream = https.request({
      hostname: sb.hostname,
      port: sb.port || 443,
      path: '/rest/v1/rpc/' + rpcName,
      method: 'POST',
      headers: {
        apikey: SB_ANON_KEY,
        Authorization: 'Bearer ' + SB_ANON_KEY,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
        'User-Agent': 'AscendaOS-Phase2-AuthProxy/1.0'
      },
      timeout: 12000
    }, upstreamRes => {
      let data = '';
      upstreamRes.on('data', chunk => { data += chunk; });
      upstreamRes.on('end', () => {
        res.writeHead(upstreamRes.statusCode || 502, {
          'Content-Type': upstreamRes.headers['content-type'] || 'application/json; charset=utf-8',
          'Cache-Control': 'no-store, no-cache, must-revalidate',
          'X-Ascenda-Auth-Route': 'same-origin-v3'
        });
        res.end(data || '{}');
      });
    });

    upstream.on('timeout', () => upstream.destroy(new Error('AUTH_UPSTREAM_TIMEOUT')));
    upstream.on('error', err => {
      console.error('[AUTH-V3-PROXY] upstream error', rpcName, err.message);
      if (!res.headersSent) {
        writeJson(res, 502, { ok: false, error: 'AUTH_UPSTREAM_UNAVAILABLE', auth_version: 'v3' }, {
          'X-Ascenda-Auth-Route': 'same-origin-v3'
        });
      } else {
        res.end();
      }
    });

    upstream.write(payload);
    upstream.end();
  });
}

const proxy = http.createServer((req, res) => {
  let pathname = '/';
  try { pathname = new URL(req.url, 'http://localhost').pathname; } catch (_) {}

  // Same-origin Auth V3 transport. This removes browser/network dependency on
  // direct Supabase RPC access while preserving the exact database auth contract.
  if (pathname === '/api/auth/v3/login') return authRpcProxy(req, res, 'aos_login_v3');
  if (pathname === '/api/auth/v3/verify') return authRpcProxy(req, res, 'aos_verificar_2fa_v3');

  if (blocked(pathname)) {
    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      });
      res.end();
      return;
    }
    res.writeHead(410, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store'
    });
    res.end(JSON.stringify({
      ok: false,
      error: 'LEGACY_AUTH_ENDPOINT_RETIRED',
      auth_version: 'v3'
    }));
    return;
  }

  const headers = Object.assign({}, req.headers, { host: '127.0.0.1:' + INTERNAL_PORT });
  const upstream = http.request({
    hostname: '127.0.0.1',
    port: INTERNAL_PORT,
    path: req.url,
    method: req.method,
    headers
  }, upstreamRes => {
    res.writeHead(upstreamRes.statusCode || 502, upstreamRes.headers);
    upstreamRes.pipe(res);
  });

  upstream.on('error', err => {
    if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ ok: false, error: 'UPSTREAM_UNAVAILABLE' }));
    console.error('[PHASE2-PROXY] upstream error', err.message);
  });

  req.pipe(upstream);
});

proxy.on('clientError', (err, socket) => {
  socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
});

function shutdown(signal) {
  console.log('[PHASE2-PROXY] shutting down', signal);
  proxy.close(() => process.exit(0));
  if (!child.killed) child.kill(signal);
  setTimeout(() => process.exit(1), 5000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

proxy.listen(EXTERNAL_PORT, '0.0.0.0', () => {
  console.log('[PHASE2-PROXY] listening on :' + EXTERNAL_PORT + ' -> :' + INTERNAL_PORT);
});
