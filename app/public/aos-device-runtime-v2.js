// ASCENDA APP PWA V2 #517 — capability + installation identity runtime.
// Inactive until explicitly imported by the app shell.
(function(root){
  'use strict';

  var KEY='aos_installation_id_v1';

  function uuid(){
    try{if(root.crypto&&typeof root.crypto.randomUUID==='function')return root.crypto.randomUUID();}catch(_){}
    var s='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
    return s.replace(/[xy]/g,function(c){
      var r=Math.random()*16|0,v=c==='x'?r:(r&3|8);return v.toString(16);
    });
  }

  function installationId(){
    try{
      var v=root.localStorage&&root.localStorage.getItem(KEY);
      if(v&&/^[0-9a-f-]{36}$/i.test(v))return v;
      v=uuid();
      if(root.localStorage)root.localStorage.setItem(KEY,v);
      return v;
    }catch(_){return uuid();}
  }

  function standalone(){
    try{
      return !!((root.matchMedia&&root.matchMedia('(display-mode: standalone)').matches)||
        (root.navigator&&root.navigator.standalone===true));
    }catch(_){return false;}
  }

  function coarsePointer(){
    try{return !!(root.matchMedia&&root.matchMedia('(pointer: coarse)').matches);}catch(_){return false;}
  }

  function formFactor(){
    var w=0;try{w=Math.min(root.screen&&root.screen.width||0,root.innerWidth||0)||root.innerWidth||0;}catch(_){}
    if(coarsePointer()&&w>0&&w<=820)return 'MOBILE';
    if(coarsePointer()&&w>820&&w<=1366)return 'TABLET';
    return 'DESKTOP';
  }

  function osHint(){
    try{
      var p=String(root.navigator&&root.navigator.userAgentData&&root.navigator.userAgentData.platform||root.navigator&&root.navigator.platform||'').toLowerCase();
      var ua=String(root.navigator&&root.navigator.userAgent||'').toLowerCase();
      if(p.indexOf('win')>=0)return 'WINDOWS';
      if(p.indexOf('mac')>=0&&ua.indexOf('iphone')<0&&ua.indexOf('ipad')<0)return 'MACOS';
      if(ua.indexOf('android')>=0)return 'ANDROID';
      if(/iphone|ipad|ipod/.test(ua))return 'IOS';
      if(p.indexOf('linux')>=0)return 'LINUX';
    }catch(_){}
    return 'UNKNOWN';
  }

  function notificationPermission(){
    try{return typeof root.Notification!=='undefined'?String(root.Notification.permission||'default'):'unsupported';}
    catch(_){return 'unsupported';}
  }

  function supportsTel(){
    // tel: support cannot be proven from browser APIs. This is a conservative capability hint.
    var f=formFactor(),os=osHint();
    return f==='MOBILE'&&(os==='ANDROID'||os==='IOS');
  }

  function snapshot(){
    var n=root.navigator||{};
    return {
      installation_id:installationId(),
      os_family:osHint(),
      form_factor:formFactor(),
      runtime_surface:standalone()?'PWA':'WEB',
      standalone:standalone(),
      service_worker_supported:!!n.serviceWorker,
      push_supported:!!(n.serviceWorker&&root.PushManager),
      badge_supported:typeof n.setAppBadge==='function',
      notification_permission:notificationPermission(),
      tel_supported:supportsTel(),
      native_bridge:!!root.kroniaDesktop,
      focused:(function(){try{return root.document?root.document.hasFocus():null;}catch(_){return null;}})(),
      visible:(function(){try{return root.document?root.document.visibilityState==='visible':null;}catch(_){return null;}})()
    };
  }

  root.AOS_DEVICE_RUNTIME_V2={
    version:'APP-PWA-V2-517',
    installationId:installationId,
    snapshot:snapshot
  };
})(typeof window!=='undefined'?window:self);
