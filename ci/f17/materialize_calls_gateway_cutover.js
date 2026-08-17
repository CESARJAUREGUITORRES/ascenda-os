'use strict'
const fs = require('fs')
const path = 'app/public/calls.js'
const src = fs.readFileSync(path, 'utf8')
const oldBlock = `  var headers = {'apikey':_sk,'Authorization':'Bearer '+_sk};\n\n  Promise.all([\n    fetch(_sb+'/rest/v1/aos_plantillas_whatsapp?activo=eq.true&order=orden',{headers:headers}).then(function(r){return r.json()}),\n    fetch(_sb+'/rest/v1/aos_info_tratamientos?activo=eq.true',{headers:headers}).then(function(r){return r.json()})\n  ]).then(function(results) {`
const newBlock = `  var headers = {'apikey':_sk,'Authorization':'Bearer '+_sk};\n  var _waSession = (window.AOS_getToken ? window.AOS_getToken() : '') || '';\n\n  Promise.all([\n    fetch('/api/f17/whatsapp/templates',{headers:{'X-ASCENDA-Session':_waSession},cache:'no-store'})\n      .then(function(r){if(!r.ok)throw new Error('WHATSAPP_TEMPLATE_GATEWAY_'+r.status);return r.json();})\n      .then(function(d){return d&&d.ok&&Array.isArray(d.templates)?d.templates:[];}),\n    fetch(_sb+'/rest/v1/aos_info_tratamientos?activo=eq.true',{headers:headers}).then(function(r){return r.json()})\n  ]).then(function(results) {`
const count = src.split(oldBlock).length - 1
if (count !== 1) throw new Error('Expected exactly one legacy WhatsApp template fetch block, found ' + count)
const out = src.replace(oldBlock, newBlock)
if (out.includes("/rest/v1/aos_plantillas_whatsapp?activo=eq.true&order=orden")) throw new Error('Legacy template fetch remains')
if (!out.includes("/api/f17/whatsapp/templates")) throw new Error('Governed template endpoint missing')
if (!out.includes("'X-ASCENDA-Session':_waSession")) throw new Error('ASCENDA session header missing')
fs.writeFileSync(path, out)
console.log('F17 calls consumer cutover materialized')
