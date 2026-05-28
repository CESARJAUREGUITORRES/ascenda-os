/**
 * ═══════════════════════════════════════════════════════════════════
 *  KronIA Desktop — Electron Main Process
 *
 *  Crea una ventana que envuelve el Brain de AscendaOS.
 *  Características clave:
 *   - Modo "always-on-top" (flota sobre Excel, WhatsApp, Spotify, todo)
 *   - Sin marco (frameless), drag-region en el header del Brain
 *   - Redimensionable a tamaño mini compacto (~300x80)
 *   - Notificaciones nativas del SO
 *   - Tray icon para minimizar/restaurar
 *   - Atajos globales: Ctrl+Shift+K (toggle always-on-top), Ctrl+Shift+M (mini)
 * ═══════════════════════════════════════════════════════════════════
 */
const { app, BrowserWindow, Tray, Menu, globalShortcut, ipcMain, shell, Notification, screen } = require('electron');
const path = require('path');

const BRAIN_URL = 'https://ascenda-os-production.up.railway.app/cerebro.html';
const APP_NAME = 'KronIA';
const IS_DEV = process.argv.includes('--dev');

// Estado global
let mainWindow = null;
let tray = null;
let isMini = false;
let isAlwaysOnTop = true;

// Tamaños predefinidos
const SIZES = {
  mini:     { w: 320, h: 90,  resizable: false },
  normal:   { w: 480, h: 720, resizable: true },
  expanded: { w: 1200, h: 800, resizable: true }
};

// ─────────────────────────────────────────────────────────────────
// CREAR VENTANA PRINCIPAL
// ─────────────────────────────────────────────────────────────────
function createWindow() {
  const { width: screenW, height: screenH } = screen.getPrimaryDisplay().workAreaSize;

  // Posición inicial: esquina inferior derecha
  const initW = SIZES.normal.w;
  const initH = SIZES.normal.h;
  const initX = screenW - initW - 20;
  const initY = screenH - initH - 20;

  mainWindow = new BrowserWindow({
    width: initW,
    height: initH,
    x: initX,
    y: initY,
    minWidth: 280,
    minHeight: 70,
    title: APP_NAME,
    icon: path.join(__dirname, 'assets', 'icon.png'),
    frame: false,                  // sin marco nativo del SO
    transparent: false,
    alwaysOnTop: isAlwaysOnTop,    // ★ CLAVE: flota sobre todo
    skipTaskbar: false,            // sí aparece en taskbar
    resizable: true,
    fullscreenable: true,
    backgroundColor: '#F8FAFE',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,              // necesario para preload con APIs nativas
      webSecurity: true,
      allowRunningInsecureContent: false
    },
    show: false                    // no mostrar hasta que esté ready
  });

  // Cargar el Brain de AscendaOS en producción (o local en dev)
  mainWindow.loadURL(BRAIN_URL);

  // Mostrar cuando termine de cargar
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    if (isAlwaysOnTop) mainWindow.setAlwaysOnTop(true, 'floating');
  });

  // DevTools en modo dev
  if (IS_DEV) mainWindow.webContents.openDevTools({ mode: 'detach' });

  // Manejar links externos (abrir en navegador, no en Electron)
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.indexOf('ascenda-os-production.up.railway.app') !== -1) {
      // Links internos: abrir en nueva ventana Electron
      return { action: 'allow' };
    }
    shell.openExternal(url);
    return { action: 'deny' };
  });

  // Al cerrar: ocultar en lugar de cerrar (queda en tray)
  mainWindow.on('close', (e) => {
    if (!app.isQuitting) {
      e.preventDefault();
      mainWindow.hide();
      mostrarNotificacion('KronIA sigue activa', 'Se minimizó a la bandeja del sistema. Click derecho en el icono para opciones.');
    }
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

// ─────────────────────────────────────────────────────────────────
// TRAY ICON (bandeja del sistema)
// ─────────────────────────────────────────────────────────────────
function createTray() {
  const iconPath = path.join(__dirname, 'assets', 'icon.png');
  try {
    tray = new Tray(iconPath);
  } catch (e) {
    console.warn('No se pudo crear tray icon:', e.message);
    return;
  }
  tray.setToolTip('KronIA — Asistente AI AscendaOS');
  refreshTrayMenu();
  tray.on('double-click', () => mostrarVentana());
}

function refreshTrayMenu() {
  if (!tray) return;
  const menu = Menu.buildFromTemplate([
    { label: 'Mostrar KronIA', click: mostrarVentana },
    { type: 'separator' },
    { label: isMini ? '↗ Tamaño normal' : '↙ Tamaño mini', click: toggleMini },
    {
      label: isAlwaysOnTop ? '☑ Siempre encima' : '☐ Siempre encima',
      click: toggleAlwaysOnTop
    },
    { type: 'separator' },
    { label: 'Abrir AscendaOS en navegador', click: () => shell.openExternal('https://ascenda-os-production.up.railway.app/') },
    { type: 'separator' },
    { label: 'Salir KronIA', click: () => { app.isQuitting = true; app.quit(); } }
  ]);
  tray.setContextMenu(menu);
}

// ─────────────────────────────────────────────────────────────────
// ACCIONES DE VENTANA
// ─────────────────────────────────────────────────────────────────
function mostrarVentana() {
  if (!mainWindow) { createWindow(); return; }
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.focus();
}

function toggleMini() {
  if (!mainWindow) return;
  isMini = !isMini;
  const size = isMini ? SIZES.mini : SIZES.normal;
  mainWindow.setResizable(size.resizable);
  mainWindow.setSize(size.w, size.h, true);
  if (isMini) {
    // En mini reposicionar abajo-derecha
    const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize;
    mainWindow.setPosition(sw - size.w - 12, sh - size.h - 12, true);
  }
  // Informar al renderer
  if (mainWindow && mainWindow.webContents) {
    mainWindow.webContents.send('kronia-set-mode', isMini ? 'mini' : 'normal');
  }
  refreshTrayMenu();
}

function toggleAlwaysOnTop() {
  if (!mainWindow) return;
  isAlwaysOnTop = !isAlwaysOnTop;
  mainWindow.setAlwaysOnTop(isAlwaysOnTop, 'floating');
  refreshTrayMenu();
  mostrarNotificacion('KronIA', isAlwaysOnTop ? 'Ahora flota sobre todo' : 'Comportamiento normal');
}

function mostrarNotificacion(titulo, cuerpo) {
  if (!Notification.isSupported()) return;
  try {
    const n = new Notification({
      title: titulo,
      body: cuerpo,
      icon: path.join(__dirname, 'assets', 'icon.png'),
      silent: false
    });
    n.on('click', () => mostrarVentana());
    n.show();
  } catch (e) { /* silent */ }
}

// ─────────────────────────────────────────────────────────────────
// ATAJOS GLOBALES (funcionan en todo el sistema, no solo dentro de la app)
// ─────────────────────────────────────────────────────────────────
function registrarAtajos() {
  // Ctrl+Shift+K: mostrar/ocultar KronIA
  globalShortcut.register('CommandOrControl+Shift+K', () => {
    if (!mainWindow) { createWindow(); return; }
    if (mainWindow.isVisible() && mainWindow.isFocused()) mainWindow.hide();
    else mostrarVentana();
  });

  // Ctrl+Shift+M: toggle mini/normal
  globalShortcut.register('CommandOrControl+Shift+M', toggleMini);

  // Ctrl+Shift+T: toggle always-on-top
  globalShortcut.register('CommandOrControl+Shift+T', toggleAlwaysOnTop);
}

// ─────────────────────────────────────────────────────────────────
// IPC: comunicación con el renderer (Brain)
// ─────────────────────────────────────────────────────────────────
ipcMain.handle('kronia-notify', (event, payload) => {
  mostrarNotificacion(payload && payload.title || 'KronIA', payload && payload.body || '');
  return { ok: true };
});

ipcMain.handle('kronia-set-size', (event, modo) => {
  if (modo === 'mini' || modo === 'normal' || modo === 'expanded') {
    const wasMini = isMini;
    if (modo === 'mini' && !wasMini) toggleMini();
    if (modo === 'normal' && wasMini) toggleMini();
    if (modo === 'expanded') {
      isMini = false;
      mainWindow.setResizable(true);
      mainWindow.setSize(SIZES.expanded.w, SIZES.expanded.h, true);
      mainWindow.center();
      refreshTrayMenu();
    }
  }
  return { ok: true, mode: modo };
});

ipcMain.handle('kronia-toggle-top', () => {
  toggleAlwaysOnTop();
  return { ok: true, alwaysOnTop: isAlwaysOnTop };
});

ipcMain.handle('kronia-window-drag', () => ({ ok: true })); /* manejado vía CSS -webkit-app-region */

ipcMain.handle('kronia-window-close', () => {
  if (mainWindow) mainWindow.hide();
  return { ok: true };
});

ipcMain.handle('kronia-window-minimize', () => {
  if (mainWindow) mainWindow.minimize();
  return { ok: true };
});

// ─────────────────────────────────────────────────────────────────
// EVENTOS DEL APP
// ─────────────────────────────────────────────────────────────────
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) mostrarVentana();
  });

  app.whenReady().then(() => {
    createWindow();
    createTray();
    registrarAtajos();
  });

  app.on('window-all-closed', (e) => {
    // No cerrar app si quedó en tray
    if (process.platform !== 'darwin') {
      // En Windows/Linux: solo quit si fue explícito
      if (app.isQuitting) app.quit();
    }
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
    else mostrarVentana();
  });

  app.on('will-quit', () => {
    globalShortcut.unregisterAll();
  });
}
