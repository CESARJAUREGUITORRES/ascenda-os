'use strict'
const http=require('http')
const {createBookingPublicV33}=require('./booking-public-v33')
const original=http.createServer

function monitorUiV36(path,html){
  if(path==='/admin-home.html'){
    html=html.replace('<th style="text-align:center" title="Citas creadas sin llamada origen">Agenda dir.</th><th style="text-align:center">Conv%</th>','<th style="text-align:center" title="Citas creadas sin llamada origen">Agenda dir.</th><th style="text-align:center" title="Citas autogestionadas desde web, link personal o canal público">Web</th><th style="text-align:center">Conv%</th>')
      .replace('<tbody id="ah-mtb"><tr><td colspan="8">','<tbody id="ah-mtb"><tr><td colspan="9">')
      .replace("parseInt(s.agenda_directa||0)>0);","parseInt(s.agenda_directa||0)+parseInt(s.citas_web||0)>0);")
      .replace("var react=parseInt(s.reactivadas||0),direct=parseInt(s.agenda_directa||0),citas=parseInt(s.citas||0);","var react=parseInt(s.reactivadas||0),direct=parseInt(s.agenda_directa||0),web=parseInt(s.citas_web||0),citas=parseInt(s.citas||0);")
      .replace("'<td><b>'+_e(s.asesor)+'</b><br><span style=\"font-size:9px;color:#6B7BA8\">'+_e(sede)+'</span></td>'+","'<td><b>'+_e(s.asesor==='WEB'?'WEB · ORGÁNICO':s.asesor)+'</b><br><span style=\"font-size:9px;color:#6B7BA8\">'+_e(s.asesor==='WEB'?'Sin asesor':sede)+'</span></td>'+")
      .replace("'<td style=\"text-align:center;font-weight:700;color:#7C3AED\">+'+_e(s.agenda_directa||0)+'</td>'+\n            '<td style=\"text-align:center;color:#00C9A7;font-weight:600\">'+cv+'%</td>'+","'<td style=\"text-align:center;font-weight:700;color:#7C3AED\">+'+_e(s.agenda_directa||0)+'</td>'+\n            '<td style=\"text-align:center;font-weight:800;color:#0A4FBF\">+'+_e(s.citas_web||0)+'</td>'+\n            '<td style=\"text-align:center;color:#00C9A7;font-weight:600\">'+cv+'%</td>'+")
      .replace("'<td>0</td><td>+0</td><td>+0</td><td>+0</td><td>0%</td>","'<td>0</td><td>+0</td><td>+0</td><td>+0</td><td>+0</td><td>0%</td>")
  }
  if(path==='/admin-calls.html'){
    html=html.replace('<th style="text-align:center">Agenda dir.</th><th style="text-align:center">Conv%</th>','<th style="text-align:center">Agenda dir.</th><th style="text-align:center" title="Citas autogestionadas desde web, link personal o canal público">Web</th><th style="text-align:center">Conv%</th>')
      .replace('<tbody id="ac-mon"><tr><td colspan="7"','<tbody id="ac-mon"><tr><td colspan="8"')
      .replace("'<tr><td colspan=\"7\" class=\"ld\">Sin actividad</td></tr>'","'<tr><td colspan=\"8\" class=\"ld\">Sin actividad</td></tr>'")
      .replace("'<td><b>'+h(m.nombre)+'</b></td>","'<td><b>'+h(m.nombre==='WEB'?'WEB · ORGÁNICO':m.nombre)+'</b>'+(m.nombre==='WEB'?'<br><span style=\"font-size:9px;color:#6B7BA8\">Sin asesor</span>':'')+'</td>")
      .replace("'<td style=\"text-align:center;font-weight:700;color:#7C3AED;\">+'+(m.agenda_directa||0)+'</td><td style=\"text-align:center;color:#00C9A7;font-weight:600;\">'+cv+'%</td>","'<td style=\"text-align:center;font-weight:700;color:#7C3AED;\">+'+(m.agenda_directa||0)+'</td><td style=\"text-align:center;font-weight:800;color:#0A4FBF;\">+'+(m.citas_web||0)+'</td><td style=\"text-align:center;color:#00C9A7;font-weight:600;\">'+cv+'%</td>")
  }
  return html
}

if(!http.createServer.__bookingV33){
  http.createServer=function(listener){
    const booking=createBookingPublicV33({supabaseUrl:process.env.SUPABASE_URL,serviceRoleKey:process.env.SUPABASE_SERVICE_ROLE_KEY,resendApiKey:process.env.RESEND_API_KEY})
    return original.call(http,function(req,res){
      let p='/';try{p=new URL(req.url,'http://localhost').pathname}catch(_){}
      if(p==='/api/booking/public-confirmation-v33')return booking(req,res)
      if(p==='/admin-home.html'||p==='/admin-calls.html'){
        const chunks=[];const ow=res.write.bind(res);const oe=res.end.bind(res)
        res.write=function(chunk,enc,cb){if(chunk)chunks.push(Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk,enc));if(typeof cb==='function')cb();return true}
        res.end=function(chunk,enc,cb){if(chunk)chunks.push(Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk,enc));let body=Buffer.concat(chunks).toString('utf8');body=monitorUiV36(p,body);res.setHeader('content-length',Buffer.byteLength(body));ow(body);return oe(null,null,cb)}
      }
      return listener(req,res)
    })
  }
  http.createServer.__bookingV33=true
}
