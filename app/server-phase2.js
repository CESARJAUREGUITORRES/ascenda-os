// ASCENDA OS — Phase 2 security front proxy.
// Keeps the existing application server intact while retiring legacy auth
// endpoints that exposed browser-generated OTP delivery and a fail-open CAPTCHA.
'use strict';

const http = require('http');
const { spawn } = require('child_process');

const EXTERNAL_PORT = parseInt(process.env.PORT || '4173', 10);
const INTERNAL_PORT = EXTERNAL_PORT === 4187 ? 4188 : 4187;

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

const proxy = http.createServer((req, res) => {
  let pathname = '/';
  try { pathname = new URL(req.url, 'http://localhost').pathname; } catch (_) {}

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
