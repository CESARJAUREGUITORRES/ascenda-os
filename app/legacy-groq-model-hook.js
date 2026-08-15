'use strict';
// WA-4 compatibility hook for the historical monolith.
// 1) migrates retired Groq model IDs in memory;
// 2) redirects legacy provider-secret reads to server-only environment variables;
// 3) removes the historical Resend literal fallback at runtime.
// It transforms only app/server.js and never writes the source file.
const Module = require('module');
const fs = require('fs');
const path = require('path');

const TARGET = path.resolve(__dirname, 'server.js');
const ORIGINAL = Module._extensions['.js'];
const ENABLED = String(process.env.ASCENDA_GROQ_COMPAT || '').toLowerCase() === '1';

function transform(src) {
  let out = String(src);
  out = out.split('llama-3.1-8b-instant').join('openai/gpt-oss-20b');
  out = out.split('llama-3.3-70b-versatile').join('openai/gpt-oss-120b');

  const groqQuery = "sbGet('/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1')";
  out = out.split(groqQuery).join("Promise.resolve([{api_key:process.env.GROQ_API_KEY||''}])");

  const agentKeyQuery = "sbFetch('/rest/v1/aos_integraciones?select=tipo,api_key&tipo=in.(groq,gemini)')";
  out = out.split(agentKeyQuery).join("Promise.resolve([{tipo:'groq',api_key:process.env.GROQ_API_KEY||''},{tipo:'gemini',api_key:process.env.GEMINI_API_KEY||''}])");

  out = out.replace(
    /function getKey\(tipo, cb\) \{/,
    "function getKey(tipo, cb) {\n          var __aosKey = tipo==='gemini' ? (process.env.GEMINI_API_KEY||'') : tipo==='groq' ? (process.env.GROQ_API_KEY||'') : tipo==='api' ? (process.env.OPENAI_API_KEY||'') : '';\n          if (__aosKey) { cb(__aosKey); return }"
  );

  if (!out.includes('function __ascendaLegacyKeyResponse(')) {
    out = "function __ascendaLegacyKeyResponse(key, cb) {\n  const Readable = require('stream').Readable;\n  const response = Readable.from([JSON.stringify([{api_key:key||''}])]);\n  process.nextTick(function(){ cb(response); });\n  return { on: function(){ return this; } };\n}\n" + out;
  }
  out = out.replace(
    /https\.get\(\{\s*hostname:\s*'ituyqwstonmhnfshnaqz\.supabase\.co',\s*path:\s*'\/rest\/v1\/aos_integraciones\?tipo=eq\.groq&estado=eq\.conectado&select=api_key&limit=1',\s*headers:\s*\{\s*'apikey':\s*SB_KEY,\s*'Authorization':\s*'Bearer '\s*\+\s*SB_KEY\s*\}\s*\},\s*function\(r\)\s*\{/g,
    "__ascendaLegacyKeyResponse(process.env.GROQ_API_KEY||'', function(r) {"
  );

  out = out.replace(/process\.env\.RESEND_API_KEY\s*\|\|\s*'re_[A-Za-z0-9_]+'/g, "process.env.RESEND_API_KEY || ''");

  out = out.replace(
    /'openai\/gpt-oss-120b'\s*:\s*\{\s*input:\s*0,\s*output:\s*0,\s*motor:\s*'groq'\s*\}/g,
    "'openai/gpt-oss-120b': { input: 0.15, output: 0.60, motor: 'groq' }"
  );
  if (out.includes('var TOKEN_COSTS = {') && !out.includes("'openai/gpt-oss-20b':")) {
    out = out.replace(
      'var TOKEN_COSTS = {',
      "var TOKEN_COSTS = {\n  'openai/gpt-oss-20b':        { input: 0.075, output: 0.30, motor: 'groq' },"
    );
  }
  return out;
}

if (ENABLED) {
  Module._extensions['.js'] = function wa4Extension(mod, filename) {
    if (path.resolve(filename) !== TARGET) return ORIGINAL(mod, filename);
    const source = transform(fs.readFileSync(filename, 'utf8'));
    if (source.includes('llama-3.1-8b-instant') || source.includes('llama-3.3-70b-versatile')) {
      throw new Error('WA4_DEPRECATED_GROQ_MODEL_REMAINS');
    }
    if (source.includes("aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key")) {
      throw new Error('WA4_LEGACY_GROQ_SECRET_READ_REMAINS');
    }
    return mod._compile(source, filename);
  };
}

module.exports = { transform, enabled: ENABLED };
