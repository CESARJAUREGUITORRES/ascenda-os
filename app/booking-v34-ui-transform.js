'use strict'

const HERO_OLD='<div class="hero"><div class="brand"><span class="mark"><i></i><i></i><i></i><i></i></span><b>ASCENDA · ZI VITAL</b></div><h1>Agenda tu cita</h1><p>Elige profesional, tratamiento, fecha y horario disponible</p></div>'
const HERO_NEW='<div class="hero"><h1>Agenda de Citas</h1><p>Elige profesional, tratamiento, fecha y horario disponible</p></div>'
const EMAIL_OLD="let email=document.getElementById('fe').value.trim();if(email)fetch('/api/send-template',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({to:email,template:'confirmacion_cita',nombre:(n+' '+a).trim(),tratamiento:AG.selTreatment.nombre,hora:AG.selHora,sede:AG.selSede,fecha:AG.selFecha})}).catch(()=>{})"
const EMAIL_NEW="let email=document.getElementById('fe').value.trim();if(email&&r.agenda_id)fetch('/api/booking/public-confirmation-v33',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({appointment_id:r.agenda_id})}).catch(()=>{})"

function transformBookingHtml(html){return String(html||'').replace(HERO_OLD,HERO_NEW).replace(EMAIL_OLD,EMAIL_NEW)}
function wrapBookingUiResponse(res){
  const write=res.write.bind(res),end=res.end.bind(res),writeHead=res.writeHead.bind(res)
  let chunks=[]
  res.writeHead=function(status,headers){
    if(headers&&typeof headers==='object'){headers=Object.assign({},headers);delete headers['Content-Length'];delete headers['content-length']}
    try{res.removeHeader('Content-Length')}catch(_){}
    return writeHead(status,headers)
  }
  res.write=function(chunk,enc,cb){chunks.push(Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk,enc));if(typeof cb==='function')cb();return true}
  res.end=function(chunk,enc,cb){if(chunk)chunks.push(Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk,enc));let body=Buffer.concat(chunks).toString('utf8');try{res.removeHeader('Content-Length')}catch(_){};return end(transformBookingHtml(body),'utf8',cb)}
  return res
}
module.exports={transformBookingHtml,wrapBookingUiResponse}
