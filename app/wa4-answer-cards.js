'use strict';
const crypto=require('crypto');

const VERSION='WA4-ANSWER-CARDS-R1';
const MAX_ITEMS=6;
const CACHE_MAX=128;
const cache=new Map();

function text(v,n){const s=String(v==null?'':v).trim();return s?s.slice(0,n):'';}
function list(v,n,maxChars){return Array.isArray(v)?v.slice(0,n).map(x=>text(x,maxChars)).filter(Boolean):[];}
function number(v){const n=Number(v);return Number.isFinite(n)?n:null;}
function bool(v){return typeof v==='boolean'?v:null;}

function compactFaqs(v){
  if(!Array.isArray(v))return [];
  const out=[];
  for(const x of v.slice(0,3)){
    if(!x||typeof x!=='object'||Array.isArray(x))continue;
    const q=text(x.q,160),a=text(x.a,360);
    if(q||a)out.push({q,a});
  }
  return out;
}

function factsFor(domain,facts){
  const d=String(domain||'').toUpperCase(),f=facts&&typeof facts==='object'&&!Array.isArray(facts)?facts:{},out={};
  const putText=(k,n=240)=>{const v=text(f[k],n);if(v)out[k]=v;};
  const putNum=k=>{const v=number(f[k]);if(v!=null)out[k]=v;};
  const putBool=k=>{const v=bool(f[k]);if(v!=null)out[k]=v;};
  if(d==='CATALOG'){
    ['tipo','nombre','nombre_corto','categoria','moneda','duracion_sesion','frecuencia'].forEach(k=>putText(k,160));
    ['precio_base','precio_oferta','num_sesiones'].forEach(putNum);
    putText('descripcion_comercial',420);putText('included_benefit',260);
    const beneficios=list(f.beneficios,5,180);if(beneficios.length)out.beneficios=beneficios;
    const faqs=compactFaqs(f.faqs);if(faqs.length)out.faqs=faqs;
    putBool('requiere_doctora');putBool('requiere_enfermeria');
    if(f.catalog_identity&&typeof f.catalog_identity==='object'&&!Array.isArray(f.catalog_identity)){
      const identity={};
      for(const k of ['family_name','commercial_variant','brand','zones','unit_cap','syringes','volume_ml']){
        const v=f.catalog_identity[k];if(typeof v==='number'&&Number.isFinite(v))identity[k]=v;else{const t=text(v,120);if(t)identity[k]=t;}
      }
      if(Object.keys(identity).length)out.catalog_identity=identity;
    }
  }else if(d==='PROMOTION'){
    ['nombre','tipo_descuento','codigo','vigencia_inicio','vigencia_fin'].forEach(k=>putText(k,180));putText('descripcion',420);putNum('valor_descuento');
    const tratamientos=list(f.tratamientos,8,140);if(tratamientos.length)out.tratamientos=tratamientos;
    const segmentos=list(f.segmentos,8,120);if(segmentos.length)out.segmentos=segmentos;
  }else if(d==='BRANCH'){
    ['nombre','telefono'].forEach(k=>putText(k,160));putText('direccion',320);putText('maps_link',320);
  }else if(d==='HOURS'){
    ['sede','dia_semana','hora_apertura','hora_cierre'].forEach(k=>putText(k,80));putBool('activo');
  }else if(d==='CATEGORY'){
    putText('nombre',180);putText('descripcion_comercial',420);const beneficios=list(f.beneficios,5,180);if(beneficios.length)out.beneficios=beneficios;const faqs=compactFaqs(f.faqs);if(faqs.length)out.faqs=faqs;
  }else if(d==='CLINIC_KNOWLEDGE'){
    ['code','node_type','parent_code','title','risk_level','audience'].forEach(k=>putText(k,160));putText('answer',700);
  }
  return out;
}

function fingerprint(bundle,maxItems){
  const source=Array.isArray(bundle&&bundle.items)?bundle.items.slice(0,maxItems):[];
  const material=source.map(x=>({id:x&&x.knowledge_id,domain:x&&x.domain,fresh:x&&x.freshness_state,evidence:x&&x.evidence_ref,facts:x&&x.facts}));
  return crypto.createHash('sha256').update(JSON.stringify(material)).digest('hex');
}
function trimCache(){while(cache.size>CACHE_MAX)cache.delete(cache.keys().next().value);}

function build(bundle,options){
  const opts=options||{},limit=Math.max(1,Math.min(Number(opts.maxItems||MAX_ITEMS),MAX_ITEMS));
  const fp=fingerprint(bundle,limit),cached=cache.get(fp);if(cached)return cached;
  const source=Array.isArray(bundle&&bundle.items)?bundle.items:[],items=[];
  for(const item of source){
    if(items.length>=limit)break;
    if(!item||!item.knowledge_id)continue;
    items.push({
      knowledge_id:text(item.knowledge_id,160),domain:text(item.domain,80),title:text(item.title,180),
      authority_tier:Number(item.authority_tier||99),freshness_state:text(item.freshness_state,80),
      facts:factsFor(item.domain,item.facts),
      evidence:{version:text(item.evidence_ref&&item.evidence_ref.version,120),source_code:text(item.evidence_ref&&item.evidence_ref.source_code,120)}
    });
  }
  const out=Object.freeze({version:VERSION,source_version:text(bundle&&bundle.version,80),audience:'PUBLIC_CLIENT',authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false,price_authority:text(bundle&&bundle.price_authority,80)||null,price_stage:bundle&&bundle.price_stage===true,fingerprint:fp,items});
  cache.set(fp,out);trimCache();return out;
}

function stats(){return {version:VERSION,size:cache.size,max:CACHE_MAX};}
function clear(){cache.clear();}
module.exports={VERSION,MAX_ITEMS,factsFor,build,stats,clear};
