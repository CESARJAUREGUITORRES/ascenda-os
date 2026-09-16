'use strict'
const fs=require('fs'),assert=require('assert')
const ui=require('../../app/booking-v34-ui-transform')
const server=fs.readFileSync('app/server-phase-s-f17.js','utf8')
const migration=fs.readFileSync('supabase/migrations/20260916151000_booking_v34_all_user_permanent_links.sql','utf8')
let fixture='<div class="hero"><div class="brand"><span class="mark"><i></i><i></i><i></i><i></i></span><b>ASCENDA · ZI VITAL</b></div><h1>Agenda tu cita</h1><p>Elige profesional, tratamiento, fecha y horario disponible</p></div>'
fixture+="let email=document.getElementById('fe').value.trim();if(email)fetch('/api/send-template',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({to:email,template:'confirmacion_cita',nombre:(n+' '+a).trim(),tratamiento:AG.selTreatment.nombre,hora:AG.selHora,sede:AG.selSede,fecha:AG.selFecha})}).catch(()=>{})"
const out=ui.transformBookingHtml(fixture)
assert(out.includes('Agenda de Citas')&&!out.includes('ASCENDA · ZI VITAL'))
assert(out.includes('/api/booking/public-confirmation-v33')&&!out.includes("fetch('/api/send-template'"))
assert(server.includes("pathname==='/api/booking/public-confirmation-v33'")&&server.includes("pathname==='/agendar-v2.html'"))
assert(migration.includes('from public.aos_usuarios u')&&migration.includes('u.activo=true'))
assert(!migration.includes("upper(coalesce(rol,'')) in ('ASESOR','ADMIN')"))
console.log('BOOKING-V3.4 contract PASS')
