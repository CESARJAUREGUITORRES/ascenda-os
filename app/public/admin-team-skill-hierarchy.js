/* WA-4C · Professional Skill Hierarchy V1
 * Admin > Equipo override.
 * Loads before the inline panel script; installs overrides on next tick so legacy
 * functions exist first. Parent skills remain backward-compatible, children are opt-in scopes.
 */
(function(){
  'use strict';
  var H={ready:false,data:null,baseLoad:null,baseSaveU:null,baseSaveServicios:null};

  function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
  function norm(s){return String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim();}
  function icon(cat){return ({'FACIAL':'🧖','INYECTABLES':'💉','APARATOLOGÍA':'⚡','CORPORAL':'🏋️','CAPILAR':'💇','CONSULTA':'🩺','COMBO':'📦','OTROS':'📋','GENERAL':'📋'})[cat]||'📋';}
  function byId(id){return document.getElementById(id);}

  function injectCss(){
    if(byId('wa4c-skill-hierarchy-css'))return;
    var st=document.createElement('style');st.id='wa4c-skill-hierarchy-css';
    st.textContent=[
      '.sh-cat{border:1px solid #E6ECF7;border-radius:12px;margin:0 0 10px;background:#FBFCFF;overflow:hidden}',
      '.sh-cat-h{display:flex;align-items:center;gap:7px;padding:8px 10px;background:#F3F7FE;border-bottom:1px solid #E6ECF7;font-size:9px;font-weight:800;color:#0A4FBF;text-transform:uppercase;letter-spacing:.45px}',
      '.sh-skill{background:#fff;border-bottom:1px solid #EEF2F8}.sh-skill:last-child{border-bottom:0}',
      '.sh-head{display:flex;align-items:center;gap:7px;padding:7px 9px;min-height:34px}',
      '.sh-parent{accent-color:#00C9A7;width:14px;height:14px;flex:0 0 auto}',
      '.sh-name{font-size:9px;font-weight:750;color:#243453;flex:1;min-width:0}',
      '.sh-role{font-size:6.5px;font-weight:800;padding:2px 5px;border-radius:999px;background:#EEF4FF;color:#0A4FBF}',
      '.sh-sum{font-size:7px;font-weight:700;color:#6B7BA8;white-space:nowrap}',
      '.sh-toggle{border:0;background:#F1F5FB;color:#0A4FBF;border-radius:6px;font-size:8px;font-weight:800;padding:4px 7px;cursor:pointer}',
      '.sh-procs{display:none;padding:0 9px 8px 30px;background:#FCFDFE}.sh-procs.open{display:block}',
      '.sh-procbar{display:flex;align-items:center;gap:6px;padding:5px 0 6px;border-top:1px dashed #E4EAF5}',
      '.sh-mode{font-size:7px;color:#6B7BA8;font-weight:700;flex:1}',
      '.sh-reset{font-size:7px;border:1px solid #CFE0FA;background:#F3F7FE;color:#0A4FBF;border-radius:6px;padding:3px 6px;cursor:pointer;font-weight:700}',
      '.sh-proclist{display:grid;grid-template-columns:repeat(auto-fit,minmax(175px,1fr));gap:4px}',
      '.sh-proc{display:flex;align-items:center;gap:5px;border:1px solid #E5EAF3;border-radius:7px;padding:5px 7px;background:#fff;font-size:8px;color:#4C5C7C;cursor:pointer}',
      '.sh-proc.on{border-color:#9DE7D9;background:#F1FFFB;color:#047857}.sh-proc input{accent-color:#00C9A7}',
      '.sh-var{margin-left:auto;font-size:6px;color:#91A0BA;white-space:nowrap}',
      '.sh-empty{font-size:7px;color:#9AAAC8;padding:5px 0;font-style:italic}',
      '.sh-note{font-size:8px;color:#556887;background:#F8FAFF;border:1px solid #E6ECF7;border-radius:9px;padding:7px 9px;margin-bottom:9px;line-height:1.45}',
      '.sh-note b{color:#0A4FBF}'
    ].join('');
    document.head.appendChild(st);
  }

  function rpcCall(fn,p){
    return fetch(window.SB+'/rest/v1/rpc/'+fn,{
      method:'POST',
      headers:{'apikey':window.SK,'Authorization':'Bearer '+window.SK,'Content-Type':'application/json'},
      body:JSON.stringify(p||{})
    }).then(function(r){
      return r.text().then(function(t){
        var d;try{d=t?JSON.parse(t):{};}catch(e){d={raw:t};}
        if(!r.ok)throw new Error((d&&d.message)||('HTTP '+r.status));
        return d;
      });
    });
  }

  function currentCode(){
    var e=byId('eu-codigo');
    if(e&&e.value)return e.value;
    var u=currentUser();return u&&u.codigo_asesor||'';
  }
  function currentUser(){
    var id=byId('eu-id');var uid=id&&id.value;
    if(uid&&window.U)return window.U.find(function(x){return x.id===uid;});
    return null;
  }

  function loadHierarchy(userServicios){
    injectCss();
    var grid=byId('eu-servicios-grid');if(!grid)return;
    var code=currentCode();
    if(!code){if(H.baseLoad)return H.baseLoad(userServicios);grid.innerHTML='<div class="sh-empty">Perfil sin código operativo.</div>';return;}
    grid.innerHTML='<div style="font-size:9px;color:#6B7BA8;padding:8px;">⏳ Cargando matriz clínica gobernada...</div>';
    rpcCall('aos_team_skill_hierarchy_v1',{p_codigo_asesor:code}).then(function(d){
      if(!d||d.ok!==true)throw new Error(d&&d.error||'HIERARCHY_NOT_READY');
      H.data=d;renderHierarchy(d);
    }).catch(function(err){
      console.error('[WA4C hierarchy]',err);
      grid.innerHTML='<div style="font-size:9px;color:#DC2626;padding:8px;">No se pudo cargar la jerarquía clínica. '+esc(err.message)+'</div>';
    });
  }

  function renderHierarchy(d){
    var grid=byId('eu-servicios-grid');if(!grid)return;
    var html='<div class="sh-note"><b>Autoridad clínica:</b> categoría → skill → procedimiento → profesional → horario. Las variantes comerciales (x1/x3, packs, zonas) heredan el procedimiento y no crean skills duplicadas. Solo se muestran skills compatibles con '+esc(d.profile_type)+'.</div>';
    (d.categories||[]).forEach(function(cat){
      html+='<section class="sh-cat"><div class="sh-cat-h">'+icon(cat.category)+' '+esc(cat.category)+'</div>';
      (cat.skills||[]).forEach(function(s){
        var procs=s.procedures||[],enabled=procs.filter(function(p){return p.enabled;}).length;
        var expandable=procs.length>1||(procs.length===1&&norm(procs[0].name)!==norm(s.skill));
        var role=s.requires_doctor&&s.requires_nursing?'AMBOS':(s.requires_doctor?'DOCTORA':'ENFERMERÍA');
        var mode=s.scope_mode||'INHERIT';
        var sum=procs.length?(mode==='EXPLICIT'?'Personalizado '+enabled+'/'+procs.length:'Todos '+procs.length):'Skill padre';
        html+='<div class="sh-skill" data-skill="'+esc(s.skill)+'" data-scope="'+esc(mode)+'">';
        html+='<div class="sh-head"><input type="checkbox" class="eu-svc sh-parent" value="'+esc(s.skill)+'" '+(s.parent_enabled?'checked':'')+' onchange="WA4CSkillHierarchy.parentChanged(this)">';
        html+='<div class="sh-name">'+esc(s.skill)+'</div><span class="sh-role">'+role+'</span><span class="sh-sum">'+esc(sum)+'</span>';
        if(expandable)html+='<button type="button" class="sh-toggle" onclick="WA4CSkillHierarchy.toggle(this)">▾ Procedimientos</button>';
        html+='</div>';
        if(expandable){
          html+='<div class="sh-procs"><div class="sh-procbar"><span class="sh-mode">'+(mode==='EXPLICIT'?'Selección personalizada':'Heredado: todos los procedimientos')+'</span><button type="button" class="sh-reset" onclick="WA4CSkillHierarchy.inherit(this)">↺ Usar todos</button></div><div class="sh-proclist">';
          procs.forEach(function(p){
            var checked=s.parent_enabled&&p.enabled;
            html+='<label class="sh-proc '+(checked?'on':'')+'"><input type="checkbox" class="sh-proc-cb" data-key="'+esc(p.key)+'" '+(checked?'checked':'')+' '+(!s.parent_enabled?'disabled':'')+' onchange="WA4CSkillHierarchy.procChanged(this)"><span>'+esc(p.name)+'</span><span class="sh-var">'+Number(p.variant_count||1)+' var.</span></label>';
          });
          html+='</div></div>';
        }
        html+='</div>';
      });
      html+='</section>';
    });
    grid.innerHTML=html;
  }

  function cardFrom(node){return node&&node.closest('.sh-skill');}
  function updateCard(card){
    if(!card)return;
    var parent=card.querySelector('.sh-parent'),procs=[].slice.call(card.querySelectorAll('.sh-proc-cb'));
    var count=procs.filter(function(x){return x.checked;}).length,mode=card.dataset.scope||'INHERIT';
    var sum=card.querySelector('.sh-sum'),modeEl=card.querySelector('.sh-mode');
    if(sum)sum.textContent=procs.length?(mode==='EXPLICIT'?'Personalizado '+count+'/'+procs.length:'Todos '+procs.length):'Skill padre';
    if(modeEl)modeEl.textContent=mode==='EXPLICIT'?'Selección personalizada':'Heredado: todos los procedimientos';
    procs.forEach(function(cb){cb.disabled=!parent.checked;var l=cb.closest('.sh-proc');if(l)l.classList.toggle('on',parent.checked&&cb.checked);});
  }

  function parentChanged(cb){
    var card=cardFrom(cb);if(!card)return;
    if(cb.checked && card.dataset.scope!=='EXPLICIT'){
      card.querySelectorAll('.sh-proc-cb').forEach(function(x){x.checked=true;});
    }
    updateCard(card);
  }
  function procChanged(cb){
    var card=cardFrom(cb);if(!card)return;
    card.dataset.scope='EXPLICIT';updateCard(card);
  }
  function inherit(btn){
    var card=cardFrom(btn);if(!card)return;
    card.dataset.scope='INHERIT';
    card.querySelectorAll('.sh-proc-cb').forEach(function(x){x.checked=true;});
    updateCard(card);
  }
  function toggle(btn){
    var card=cardFrom(btn),p=card&&card.querySelector('.sh-procs');if(!p)return;
    p.classList.toggle('open');btn.textContent=p.classList.contains('open')?'▴ Procedimientos':'▾ Procedimientos';
  }
  function all(val){
    document.querySelectorAll('.sh-parent').forEach(function(cb){cb.checked=!!val;parentChanged(cb);});
  }

  function collect(){
    var parents=[],scopes=[];
    document.querySelectorAll('.sh-skill').forEach(function(card){
      var parent=card.querySelector('.sh-parent');if(!parent||!parent.checked)return;
      parents.push(parent.value);
      var proc=[].slice.call(card.querySelectorAll('.sh-proc-cb'));
      if(!proc.length)return;
      if(card.dataset.scope==='EXPLICIT'){
        scopes.push({capability:parent.value,mode:'EXPLICIT',enabled_keys:proc.filter(function(x){return x.checked;}).map(function(x){return x.getAttribute('data-key');})});
      }else{
        scopes.push({capability:parent.value,mode:'INHERIT',enabled_keys:[]});
      }
    });
    return {parents:parents,scopes:scopes};
  }

  function persist(uid){
    if(!byId('eu-servicios-grid')||!document.querySelector('.sh-skill'))return Promise.resolve({ok:true,skipped:true});
    var c=collect(),cmp=byId('eu-cmp')?byId('eu-cmp').value.trim():null;
    return rpcCall('aos_team_save_skill_hierarchy_v1',{
      p_user_id:uid,p_parent_skills:c.parents,p_scopes:c.scopes,p_cmp:cmp
    }).then(function(d){if(!d||d.ok!==true)throw new Error(d&&d.error||'SAVE_HIERARCHY_FAILED');return d;});
  }

  function install(){
    if(H.ready||typeof window.loadSvcGrid!=='function'||typeof window.saveU!=='function'){setTimeout(install,20);return;}
    H.ready=true;injectCss();
    H.baseLoad=window.loadSvcGrid;H.baseSaveU=window.saveU;H.baseSaveServicios=window.saveServicios;
    window.loadSvcGrid=loadHierarchy;
    window.selAllSvc=all;
    window.saveServicios=function(uid){
      persist(uid).then(function(){
        if(window.showToast)window.showToast('Skills guardadas — jerarquía clínica actualizada');
        var u=(window.U||[]).find(function(x){return x.id===uid;});if(u)loadHierarchy(u.servicios||[]);
      }).catch(function(e){console.error(e);if(window.showToast)window.showToast('Error guardando skills: '+e.message);});
    };
    window.saveU=function(id){
      var btn=document.querySelector('#mu-body .mbtn-g');if(btn){btn.disabled=true;btn.dataset.old=btn.textContent;btn.textContent='⏳ Guardando skills...';}
      persist(id).then(function(){
        if(btn){btn.disabled=false;btn.textContent=btn.dataset.old||'💾 Guardar';}
        H.baseSaveU(id);
      }).catch(function(e){
        if(btn){btn.disabled=false;btn.textContent=btn.dataset.old||'💾 Guardar';}
        console.error('[WA4C hierarchy save]',e);
        if(window.showToast)window.showToast('No se guardó: '+e.message);
      });
    };
    window.WA4CSkillHierarchy={toggle:toggle,parentChanged:parentChanged,procChanged:procChanged,inherit:inherit,collect:collect,reload:loadHierarchy};
    console.log('[WA4C] Professional Skill Hierarchy V1 active');
  }
  setTimeout(install,0);
})();
