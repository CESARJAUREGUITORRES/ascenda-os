'use strict';

// TEST-ONLY transport shim for WA-4C FULL LOCAL integration.
// Loaded only by the self-hosted local workflow. It never ships in Railway NODE_OPTIONS.
const http = require('http');
const https = require('https');
const { EventEmitter } = require('events');

if (!global.__ASCENDA_WA4C_FULL_LOCAL_PRELOAD__) {
  const baseHttpsRequest = https.request;
  const baseHttpsGet = https.get;
  let metaSequence = 0;

  function hostFromArgs(args) {
    const first = args && args[0];
    try {
      if (typeof first === 'string' || first instanceof URL) return new URL(first).hostname.toLowerCase();
    } catch (_) {}
    if (first && typeof first === 'object') return String(first.hostname || first.host || '').split(':')[0].toLowerCase();
    return '';
  }

  function pathFromArgs(args) {
    const first = args && args[0];
    try {
      if (typeof first === 'string' || first instanceof URL) {
        const u = new URL(first);
        return u.pathname + u.search;
      }
    } catch (_) {}
    return first && typeof first === 'object' ? String(first.path || '/') : '/';
  }

  function methodFromArgs(args) {
    const first = args && args[0];
    return String(first && typeof first === 'object' && first.method || 'GET').toUpperCase();
  }

  function isLocalHost(host) {
    return host === '127.0.0.1' || host === 'localhost' || host === '::1';
  }

  function httpArgs(args) {
    const out = Array.prototype.slice.call(args || []);
    const first = out[0];
    if (typeof first === 'string') {
      const u = new URL(first);
      u.protocol = 'http:';
      out[0] = u;
    } else if (first instanceof URL) {
      const u = new URL(first.toString());
      u.protocol = 'http:';
      out[0] = u;
    } else if (first && typeof first === 'object') {
      out[0] = Object.assign({}, first, { protocol: 'http:' });
    }
    return out;
  }

  class SyntheticRequest extends EventEmitter {
    constructor(callback, responder) {
      super();
      this.chunks = [];
      this.finished = false;
      this.responder = responder;
      if (typeof callback === 'function') this.on('response', callback);
    }
    write(chunk) {
      if (chunk != null) this.chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk)));
      return true;
    }
    setTimeout() { return this; }
    setHeader() { return this; }
    getHeader() { return undefined; }
    removeHeader() { return this; }
    abort() { return this.destroy(new Error('ABORTED')); }
    destroy(err) {
      if (this.finished) return this;
      this.finished = true;
      if (err) setImmediate(() => this.emit('error', err));
      return this;
    }
    end(chunk) {
      if (this.finished) return this;
      if (chunk != null) this.write(chunk);
      this.finished = true;
      const raw = Buffer.concat(this.chunks).toString('utf8');
      setImmediate(() => {
        let answer;
        try { answer = this.responder(raw) || {}; }
        catch (e) { this.emit('error', e); return; }
        const res = new EventEmitter();
        res.statusCode = Number(answer.status || 200);
        res.headers = Object.assign({ 'content-type': 'application/json' }, answer.headers || {});
        this.emit('response', res);
        const payload = answer.raw != null ? String(answer.raw) : JSON.stringify(answer.body == null ? {} : answer.body);
        setImmediate(() => {
          if (payload) res.emit('data', Buffer.from(payload));
          res.emit('end');
        });
      });
      return this;
    }
  }

  function callbackFromArgs(args) {
    const last = args && args.length ? args[args.length - 1] : null;
    return typeof last === 'function' ? last : null;
  }

  function money(currency, value) {
    const n = Number(value);
    if (!Number.isFinite(n)) return null;
    const txt = Number.isInteger(n) ? String(n) : n.toFixed(2);
    return String(currency || '').toUpperCase() === 'USD' ? ('US$ ' + txt) : ('S/ ' + txt);
  }

  function firstCatalogItem(items) {
    return (Array.isArray(items) ? items : []).find(x => x && x.domain === 'CATALOG') || (Array.isArray(items) ? items[0] : null) || null;
  }

  function groqResponse(method, path, raw) {
    if (method === 'GET' && path.startsWith('/openai/v1/models')) {
      return { body: { data: [
        { id: 'openai/gpt-oss-20b' },
        { id: 'openai/gpt-oss-120b' },
        { id: 'openai/gpt-oss-safeguard-20b' },
        { id: 'qwen/qwen3.6-27b' }
      ] } };
    }
    if (method !== 'POST' || !path.startsWith('/openai/v1/chat/completions')) {
      return { status: 404, body: { error: { code: 'LOCAL_MOCK_ROUTE_NOT_FOUND', message: 'Route not mocked' } } };
    }
    const req = JSON.parse(raw || '{}');
    const messages = Array.isArray(req.messages) ? req.messages : [];
    const system = String(messages[0] && messages[0].content || '');
    let response;
    if (system.includes('Evalúa MENSAJE DEL CLIENTE')) {
      response = { allow: true, category: 'SAFE', rationale: 'FULL_LOCAL deterministic safety pass.' };
    } else {
      const user = [...messages].reverse().find(x => x && x.role === 'user');
      let facts = {};
      try { facts = JSON.parse(String(user && user.content || '{}')); } catch (_) {}
      const bundle = facts.GOVERNED_KNOWLEDGE || {};
      const items = Array.isArray(bundle.items) ? bundle.items : [];
      const primary = firstCatalogItem(items);
      const pb = facts.PLAYBOOK || {};
      const stage = String(pb.commercial_stage || 'INFO').toUpperCase();
      const citation = primary && primary.knowledge_id ? [String(primary.knowledge_id)] : [];
      const title = String(primary && primary.title || 'esta opción').trim();
      const f = primary && primary.facts || {};
      const quote = Array.isArray(pb.quote_or_payment_context) ? pb.quote_or_payment_context[0] : null;
      let reply = '';
      let intent = 'OTHER';
      let nextAction = String(pb.recommended_next_action || 'REPLY').toUpperCase();
      if (!['REPLY','OFFER_BOOKING','HUMAN_CLINICAL','HUMAN_COMMERCIAL'].includes(nextAction)) nextAction = 'REPLY';
      if (stage === 'INFO') {
        intent = 'INFO';
        reply = String(f.descripcion_comercial || f.beneficios || '').trim();
        if (!reply) reply = title + ' cuenta con información comercial gobernada disponible para el asesor.';
        if (f.included_benefit) reply += ' Incluye: ' + String(f.included_benefit).trim() + '.';
      } else if (stage === 'PRICE_QUOTE') {
        intent = 'PRICE';
        const value = quote && money(quote.currency, quote.quote_price);
        reply = value ? (title + ' tiene un valor vigente de ' + value + '.') : ('Puedo ayudarte a revisar el valor vigente de ' + title + '.');
      } else if (stage === 'PAYMENT') {
        const value = quote && money(quote.currency, quote.quote_price);
        reply = value ? ('Para ' + title + ', el valor gobernado es ' + value + '. El asesor puede explicarte las alternativas de pago sin modificar el alcance.') : ('El asesor puede explicarte las alternativas de pago de ' + title + ' sin modificar el alcance del proceso.');
      } else if (stage === 'OBJECTION') {
        intent = 'OBJECTION';
        reply = 'Entiendo tu inquietud. Podemos revisar contigo el alcance y el valor de ' + title + ' sin inventar descuentos ni retirar componentes de forma automática.';
      } else if (stage === 'CONTINUITY') {
        reply = 'Podemos revisar la continuidad de ' + title + ' según la evidencia comercial disponible, sin agregar productos o servicios automáticamente.';
      } else if (stage === 'BOOKING') {
        intent = 'BOOKING';
        nextAction = 'OFFER_BOOKING';
        reply = 'Puedo ayudarte a coordinar una cita con el equipo. La disponibilidad debe confirmarse en Agenda.';
      } else {
        reply = 'Puedo ayudarte con información gobernada sobre ' + title + '.';
      }
      response = {
        reply,
        intent,
        next_action: nextAction,
        confidence: 0.98,
        cited_knowledge_ids: citation,
        needs_human: nextAction.startsWith('HUMAN_'),
        reason: 'FULL_LOCAL_DETERMINISTIC_PROVIDER'
      };
    }
    const model = String(req.model || 'openai/gpt-oss-20b');
    return { body: {
      id: 'chatcmpl-local-' + Date.now(), object: 'chat.completion', model,
      choices: [{ index: 0, message: { role: 'assistant', content: JSON.stringify(response) }, finish_reason: 'stop' }],
      usage: { prompt_tokens: 120, completion_tokens: 48, total_tokens: 168 }
    } };
  }

  function metaResponse(method, path, raw) {
    if (method === 'GET' && path.includes('/me?')) return { body: { id: 'local-meta-user' } };
    if (method === 'GET') return { body: { id: 'local-phone-id', display_phone_number: '+51999999999', verified_name: 'ASCENDA FULL LOCAL' } };
    if (method === 'POST' && /\/messages(?:\?|$)/.test(path)) {
      let body = {};
      try { body = JSON.parse(raw || '{}'); } catch (_) {}
      if (!body.messaging_product || !body.type) return { status: 400, body: { error: { code: 100, message: 'Invalid local Meta payload' } } };
      metaSequence += 1;
      return { body: { messaging_product: 'whatsapp', contacts: [{ input: body.to || body.recipient || 'local', wa_id: body.to || 'local' }], messages: [{ id: 'wamid.LOCAL.' + String(metaSequence).padStart(4, '0') }] } };
    }
    return { status: 404, body: { error: { code: 404, message: 'Local Meta route not mocked' } } };
  }

  https.request = function fullLocalHttpsRequest() {
    const args = Array.prototype.slice.call(arguments);
    const host = hostFromArgs(args);
    if (process.env.ASCENDA_FULL_LOCAL === '1' && isLocalHost(host)) {
      return http.request.apply(http, httpArgs(args));
    }
    if (process.env.ASCENDA_FULL_LOCAL === '1' && host === 'api.groq.com') {
      const cb = callbackFromArgs(args), method = methodFromArgs(args), path = pathFromArgs(args);
      return new SyntheticRequest(cb, raw => groqResponse(method, path, raw));
    }
    if (process.env.ASCENDA_FULL_LOCAL === '1' && host === 'graph.facebook.com') {
      const cb = callbackFromArgs(args), method = methodFromArgs(args), path = pathFromArgs(args);
      return new SyntheticRequest(cb, raw => metaResponse(method, path, raw));
    }
    return baseHttpsRequest.apply(https, args);
  };

  https.get = function fullLocalHttpsGet() {
    const req = https.request.apply(https, arguments);
    req.end();
    return req;
  };

  global.__ASCENDA_WA4C_FULL_LOCAL_PRELOAD__ = {
    installed: true,
    mode: 'FULL_LOCAL',
    transports: ['local-http-postgrest', 'groq-deterministic', 'meta-deterministic'],
    production_network_mutation: false
  };

  process.on('exit', () => {
    // Keep references only for debuggability; no global restoration is required at process exit.
    void baseHttpsGet;
  });
}
