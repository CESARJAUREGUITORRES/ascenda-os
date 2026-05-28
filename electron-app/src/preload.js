/**
 * ═══════════════════════════════════════════════════════════════════
 *  KronIA Preload Script
 *  Expone APIs nativas seguras al renderer (Brain) vía contextBridge.
 *  El Brain detecta window.kroniaDesktop y activa modo desktop.
 * ═══════════════════════════════════════════════════════════════════
 */
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('kroniaDesktop', {
  /* Marca para detección desde el Brain */
  version: '1.0.0',
  isDesktop: true,
  platform: process.platform,

  /* Notificaciones nativas del SO */
  notify: function (title, body) {
    return ipcRenderer.invoke('kronia-notify', { title: title, body: body });
  },

  /* Cambiar tamaño de ventana (mini / normal / expanded) */
  setMode: function (modo) {
    return ipcRenderer.invoke('kronia-set-size', modo);
  },

  /* Toggle always-on-top */
  toggleAlwaysOnTop: function () {
    return ipcRenderer.invoke('kronia-toggle-top');
  },

  /* Controles de ventana frameless */
  windowClose: function () {
    return ipcRenderer.invoke('kronia-window-close');
  },
  windowMinimize: function () {
    return ipcRenderer.invoke('kronia-window-minimize');
  },

  /* Escuchar comandos del proceso principal */
  onSetMode: function (callback) {
    ipcRenderer.on('kronia-set-mode', function (event, modo) {
      try { callback(modo); } catch (e) { /* silent */ }
    });
  }
});

/* Inyectar CSS al cargar la página para drag region y controles de ventana */
window.addEventListener('DOMContentLoaded', function () {
  /* Añade clase al body para que CSS del Brain pueda detectar modo desktop */
  document.body.classList.add('kronia-desktop-mode');

  /* Inyectar CSS overrides específicos del modo desktop */
  var style = document.createElement('style');
  style.textContent = `
    /* En modo desktop, el header del Brain es la zona de drag de la ventana */
    .kronia-desktop-mode #brand {
      -webkit-app-region: drag;
      cursor: grab;
    }
    .kronia-desktop-mode #brand button,
    .kronia-desktop-mode #brand a,
    .kronia-desktop-mode #brand input,
    .kronia-desktop-mode #brand select {
      -webkit-app-region: no-drag;
    }
    .kronia-desktop-mode #kronia,
    .kronia-desktop-mode #ctrls,
    .kronia-desktop-mode #metrics,
    .kronia-desktop-mode #mic-modal {
      -webkit-app-region: no-drag;
    }
    /* Controles de ventana adicionales (— □ ×) */
    .kronia-window-controls {
      position: fixed;
      top: 6px;
      right: 6px;
      z-index: 9999;
      display: flex;
      gap: 4px;
      -webkit-app-region: no-drag;
    }
    .kronia-window-controls button {
      width: 28px;
      height: 24px;
      border-radius: 6px;
      border: 1px solid rgba(10,79,191,0.10);
      background: rgba(255,255,255,0.85);
      backdrop-filter: blur(8px);
      cursor: pointer;
      font-size: 12px;
      line-height: 1;
      color: rgba(7,29,74,0.65);
      transition: background 0.15s;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .kronia-window-controls button:hover {
      background: rgba(0,201,167,0.15);
      color: #071D4A;
    }
    .kronia-window-controls button.close:hover {
      background: rgba(229,57,53,0.85);
      color: #fff;
    }
  `;
  document.head.appendChild(style);

  /* Agregar controles de ventana (— □ ×) */
  var controls = document.createElement('div');
  controls.className = 'kronia-window-controls';
  controls.innerHTML = `
    <button id="kde-min" title="Minimizar">&#8211;</button>
    <button id="kde-mode" title="Mini/Normal">&#9744;</button>
    <button id="kde-pin" title="Siempre encima">&#128204;</button>
    <button id="kde-close" class="close" title="Ocultar">&#215;</button>
  `;
  document.body.appendChild(controls);

  /* Cablear botones */
  document.getElementById('kde-min').addEventListener('click', function () {
    window.kroniaDesktop.windowMinimize();
  });
  document.getElementById('kde-close').addEventListener('click', function () {
    window.kroniaDesktop.windowClose();
  });
  document.getElementById('kde-pin').addEventListener('click', function () {
    window.kroniaDesktop.toggleAlwaysOnTop();
  });

  /* Botón mini/normal con estado visual */
  var modoActual = 'normal';
  document.getElementById('kde-mode').addEventListener('click', function () {
    modoActual = (modoActual === 'mini') ? 'normal' : 'mini';
    window.kroniaDesktop.setMode(modoActual);
  });

  /* Recibir cambios de modo desde main */
  if (window.kroniaDesktop.onSetMode) {
    window.kroniaDesktop.onSetMode(function (modo) {
      modoActual = modo;
      if (modo === 'mini') {
        document.body.classList.add('kronia-mini-window');
      } else {
        document.body.classList.remove('kronia-mini-window');
      }
      /* Si el chip KronIA del Brain existe, activar su modo .mini */
      if (typeof window.setKKMode === 'function') {
        try {
          window.setKKMode(modo === 'mini' ? 'mini' : 'expanded');
        } catch (e) { /* silent */ }
      }
    });
  }

  /* Notificar al Brain cuando KronIA habla proactivamente para que
     también dispare notificación nativa del SO */
  setTimeout(function () {
    /* Hook al speakProactive del Brain si existe */
    if (typeof window.speakProactive === 'function') {
      var orig = window.speakProactive;
      window.speakProactive = function (mensaje) {
        try {
          window.kroniaDesktop.notify('KronIA', mensaje);
        } catch (e) { /* silent */ }
        return orig.apply(this, arguments);
      };
    }
  }, 4000);
});
