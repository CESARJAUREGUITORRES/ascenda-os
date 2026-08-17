'use strict'
const fs = require('fs')
const path = 'app/public/calls.js'
const src = fs.readFileSync(path, 'utf8')
const needle = "fetch(_sb+'/rest/v1/aos_plantillas_whatsapp?activo=eq.true&order=orden',{headers:headers}).then(function(r){return r.json()})"
const count = src.split(needle).length - 1
if (count !== 1) throw new Error('Expected exactly one legacy WhatsApp template fetch, found ' + count)
const replacement = "fetch('/api/f17/whatsapp/templates',{headers:{'X-ASCENDA-Session':((window.AOS_getToken?window.AOS_getToken():'')||'')},cache:'no-store'}).then(function(r){if(!r.ok)throw new Error('WHATSAPP_TEMPLATE_GATEWAY_'+r.status);return r.json();}).then(function(d){return d&&d.ok&&Array.isArray(d.templates)?d.templates:[];})"
const out = src.replace(needle, replacement)
if (out.includes("/rest/v1/aos_plantillas_whatsapp?activo=eq.true&order=orden")) throw new Error('Legacy template fetch remains')
if (!out.includes("/api/f17/whatsapp/templates")) throw new Error('Governed template endpoint missing')
if (!out.includes("'X-ASCENDA-Session'")) throw new Error('ASCENDA session header missing')
fs.writeFileSync(path, out)
console.log('F17 calls consumer cutover materialized')
