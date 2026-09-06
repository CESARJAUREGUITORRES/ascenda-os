from pathlib import Path


def once(text, old, new, label):
    if new in text:
        return text
    if old not in text:
        raise SystemExit('PATCH_ANCHOR_MISSING:' + label)
    return text.replace(old, new, 1)

p=Path('app/wa4-copilot.js')
s=p.read_text()

s=once(s,
"const qualityGuard = require('./wa4-response-quality-guard');\n",
"const qualityGuard = require('./wa4-response-quality-guard');\nconst conversationStyle = require('./wa4-conversation-style');\n",
'style-require')

s=once(s,
"const APPROVED_FIRST_CONTACT_COPY = '¡Hola! 👋 Soy Sofía de Zi Vital. Claro, te ayudo 😊';\nconst APPROVED_FIRST_CONTACT_PREFIX = APPROVED_FIRST_CONTACT_COPY;",
"const APPROVED_FIRST_CONTACT_COPY = conversationStyle.APPROVED_FIRST_CONTACT_COPY;\nconst APPROVED_FIRST_CONTACT_PREFIX = APPROVED_FIRST_CONTACT_COPY;",
'style-first-contact-constant')

old_phrase="Escribe español natural de WhatsApp: breve, profesional, cálido, máximo dos párrafos cortos, pocos emojis funcionales y máximo una pregunta útil al final cuando corresponda. No des una explicación médica larga si el cliente solo pide orientación comercial general. No uses Markdown con doble asterisco; usa texto plano o formato WhatsApp simple."
new_phrase="Escribe español natural de WhatsApp: breve, profesional, cálido, pocos emojis funcionales y máximo una pregunta útil al final cuando corresponda. Para listas de precios usa un encabezado corto, saltos de línea, bullets y una sola CTA; prioriza legibilidad móvil sobre párrafos largos. Usa emojis con intención comercial (por ejemplo 👋 😊 ✨ 💉 📍 📅), no como decoración repetitiva. No des una explicación médica larga si el cliente solo pide orientación comercial general. No uses Markdown con doble asterisco; usa texto plano o formato WhatsApp simple."
s=once(s,old_phrase,new_phrase,'sales-style-policy')

old_canon="""function canonicalizePatientText(value){
  return String(value||'')
    .replace(/\\uFFFD+/g,' ')
    .replace(/\\bzi\\s+vital\\b/gi,'Zi Vital')
    .replace(/[ \\t]{2,}/g,' ');
}
"""
new_canon="""function canonicalizePatientText(value){
  return conversationStyle.clean(value);
}
"""
s=once(s,old_canon,new_canon,'style-canonicalize')

old_greeting="return {reply:APPROVED_FIRST_CONTACT_COPY+'\\n\\n¿Ya eres paciente de la clínica o es tu primera vez con nosotros?',intent:'INFO',next_action:'REPLY',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Owner-approved organic first-contact copy.'};"
new_greeting="return {reply:conversationStyle.firstContactOrganic(),intent:'INFO',next_action:'REPLY',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Owner-approved organic first-contact copy.'};"
s=once(s,old_greeting,new_greeting,'organic-style')

old_toxin="return {reply:'¡Hola! 👋 Soy Sofía de Zi Vital. Claro, te ayudo con la toxina botulínica ✨\\n\\nPara orientarte mejor, cuéntame qué zona te gustaría mejorar: frente, entrecejo, patitas de gallo o varias zonas.',intent:'INFO',next_action:'REPLY',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Owner-approved toxin first-contact copy.'};"
new_toxin="return {reply:conversationStyle.firstContactToxin(),intent:'INFO',next_action:'REPLY',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Owner-approved toxin first-contact copy.'};"
s=once(s,old_toxin,new_toxin,'toxin-style')

old_nopromo="""  const list=options.map(o=>o.name+': '+o.price).join('; ');
  return {
    reply:'No tengo una promoción vigente confirmada en el sistema para esa consulta. Como precio regular, tengo estas opciones confirmadas: '+list+'. Si deseas, puedo seguir contigo para avanzar con la cita.',
    intent:'PROMO',next_action:'REPLY',confidence:1,cited_knowledge_ids:options.map(o=>o.knowledge_id),needs_human:false,
    reason:'Ausencia de promoción READY; continuidad con precio regular gobernado.'
  };
"""
new_nopromo="""  const reply=conversationStyle.noPromotionCard(options.map(o=>({label:o.name,price:o.price})));
  return {
    reply,
    intent:'PROMO',next_action:'REPLY',confidence:1,cited_knowledge_ids:options.map(o=>o.knowledge_id),needs_human:false,
    reason:'Ausencia de promoción READY; continuidad con precio regular gobernado.'
  };
"""
s=once(s,old_nopromo,new_nopromo,'no-promo-style')

old_price="""  const lines=unique.map(o=>'• '+o.brand+' · '+o.zones+(o.zones===1?' zona':' zonas')+(o.units?' ('+o.units+')':'')+': '+o.priceLabel);
  return {reply:'Claro 😊 Para toxina botulínica, estos son los precios vigentes que tengo confirmados:\\n'+lines.join('\\n')+'\\n\\n¿Qué zona te gustaría tratar?',intent:'PRICE',next_action:'REPLY',confidence:1,cited_knowledge_ids:unique.map(o=>o.knowledge_id),needs_human:false,reason:'Deterministic READY/FRESH toxin price fast lane.'};
"""
new_price="""  const reply=conversationStyle.toxinPriceCard(unique);
  if(!reply)return null;
  return {reply,intent:'PRICE',next_action:'REPLY',confidence:1,cited_knowledge_ids:unique.map(o=>o.knowledge_id),needs_human:false,reason:'Deterministic READY/FRESH toxin price fast lane.'};
"""
s=once(s,old_price,new_price,'price-card-style')

s=once(s,
"if(s==='DATE_REQUIRED')return {reply:'Claro. ¿Qué día te gustaría venir?',intent:'BOOKING',next_action:'OFFER_BOOKING',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Falta la fecha para continuar la reserva.'};",
"if(s==='DATE_REQUIRED')return {reply:conversationStyle.bookingAskDate(runtime&&runtime.state&&runtime.state.site),intent:'BOOKING',next_action:'OFFER_BOOKING',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Falta la fecha para continuar la reserva.'};",
'booking-date-style')
s=once(s,
"if(s==='SITE_REQUIRED')return {reply:'Claro. Para revisar la agenda, ¿prefieres San Isidro o Pueblo Libre?',intent:'BOOKING',next_action:'OFFER_BOOKING',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Falta la sede para consultar disponibilidad.'};",
"if(s==='SITE_REQUIRED')return {reply:conversationStyle.bookingAskSite(),intent:'BOOKING',next_action:'OFFER_BOOKING',confidence:1,cited_knowledge_ids:[],needs_human:false,reason:'Falta la sede para consultar disponibilidad.'};",
'booking-site-style')

s=once(s,
"const reply='Para orientarte con seguridad sobre tu caso particular, prefiero derivarte con nuestro equipo clínico para que lo revise contigo. ¿Te ayudo a coordinar esa evaluación?';",
"const reply=conversationStyle.clinicalHandoff();",
'clinical-style')

p.write_text(s)

p=Path('ci/wa4-ai-sales-router/ai-router.test.js')
a=p.read_text()
req="require('./r7-conversation-product-contract.test.js');\n"
if req not in a:
    p.write_text(a.rstrip()+"\n"+req)
