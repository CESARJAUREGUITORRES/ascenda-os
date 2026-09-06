'use strict';

const VERSION='WA4-CONVERSATION-STYLE-V1';
const BRAND='Zi Vital';
const PERSONA='Sofía';

const APPROVED_FIRST_CONTACT_COPY='¡Hola! 👋 Soy Sofía de Zi Vital. Claro, te ayudo 😊';

function clean(value){
  return String(value||'')
    .replace(/\uFFFD+/g,' ')
    .replace(/\bzi\s+vital\b/gi,BRAND)
    .replace(/[ \t]{2,}/g,' ')
    .replace(/\n{3,}/g,'\n\n')
    .trim();
}
function money(currency,value){
  const n=Number(value);
  if(!Number.isFinite(n))return null;
  const amount=Number.isInteger(n)?String(n):n.toFixed(2);
  return String(currency||'PEN').toUpperCase()==='USD'?'USD '+amount:'S/ '+amount;
}
function firstContactOrganic(){
  return APPROVED_FIRST_CONTACT_COPY+'\n\n¿Ya eres paciente de la clínica o es tu primera vez con nosotros?';
}
function firstContactTreatment(label){
  const treatment=clean(label||'este tratamiento').toLowerCase();
  return APPROVED_FIRST_CONTACT_COPY+'\n\n✨ Te ayudo con '+treatment+'.\nCuéntame qué zona o resultado te interesa mejorar.';
}
function firstContactToxin(){
  return APPROVED_FIRST_CONTACT_COPY+'\n\n✨ Te ayudo con la toxina botulínica.\nPara orientarte bien, cuéntame qué zona te gustaría mejorar: frente, entrecejo, patitas de gallo o varias zonas.';
}
function groupToxinOptions(options){
  const rows=(Array.isArray(options)?options:[]).filter(Boolean).slice(0,8);
  const byZone=new Map();
  for(const o of rows){
    const zones=Number(o.zones||0);
    if(!zones)continue;
    if(!byZone.has(zones))byZone.set(zones,[]);
    byZone.get(zones).push(o);
  }
  return [...byZone.entries()].sort((a,b)=>a[0]-b[0]);
}
function toxinPriceCard(options){
  const groups=groupToxinOptions(options);
  if(!groups.length)return null;
  const lines=['✨ *TOXINA BOTULÍNICA*','Estos son los precios vigentes que tengo confirmados:',''];
  for(const [zones,rows] of groups){
    lines.push('💉 *'+zones+(zones===1?' zona*':' zonas*'));
    for(const o of rows.sort((a,b)=>Number(a.price||0)-Number(b.price||0)||String(a.brand||'').localeCompare(String(b.brand||'')))){
      const price=o.priceLabel||money(o.currency||'PEN',o.price);
      if(!price)continue;
      const units=o.units?' '+String(o.units):'';
      lines.push('• '+clean(o.brand||'Opción')+units+' — '+price);
    }
    lines.push('');
  }
  lines.push('¿Qué zonas te gustaría tratar? 😊');
  return clean(lines.join('\n'));
}
function noPromotionCard(options){
  const rows=(Array.isArray(options)?options:[]).filter(Boolean).slice(0,6);
  const lines=['😊 Por ahora no tengo una promoción adicional vigente confirmada para esta consulta.'];
  if(rows.length){
    lines.push('','✨ *Precios regulares vigentes*');
    for(const o of rows){
      const label=clean(o.label||o.name||'Opción');
      const price=o.priceLabel||o.price||money(o.currency||'PEN',o.amount);
      if(label&&price)lines.push('• '+label+' — '+price);
    }
  }
  lines.push('','Si quieres, te ayudo a elegir según las zonas o revisamos una cita 📅');
  return clean(lines.join('\n'));
}
function bookingAskSite(){
  return 'Claro 😊 Te ayudo a avanzar con la cita 📅\n\n¿En qué sede prefieres atenderte: San Isidro o Pueblo Libre?';
}
function bookingAskDate(site){
  const label=site==='SAN_ISIDRO'?'San Isidro':(site==='PUEBLO_LIBRE'?'Pueblo Libre':'la sede elegida');
  return 'Perfecto 😊 '+label+'.\n\n¿Qué día te gustaría venir? 📅';
}
function clinicalHandoff(){
  return 'Gracias por contármelo 😊 Para orientarte con seguridad sobre tu caso particular, prefiero que nuestro equipo clínico lo revise contigo.\n\nPuedo ayudarte a coordinar una evaluación.';
}
function styleMetrics(text){
  const s=String(text||'');
  const emoji=(s.match(/[\u{1F300}-\u{1FAFF}]/gu)||[]).length;
  const questions=(s.match(/\?/g)||[]).length;
  const lines=s.split('\n').length;
  return {chars:s.length,emoji,questions,lines};
}

module.exports={VERSION,BRAND,PERSONA,APPROVED_FIRST_CONTACT_COPY,clean,money,firstContactOrganic,firstContactTreatment,firstContactToxin,toxinPriceCard,noPromotionCard,bookingAskSite,bookingAskDate,clinicalHandoff,styleMetrics};
