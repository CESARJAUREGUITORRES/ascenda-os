/**
 * ═══════════════════════════════════════════════════════════════════
 *  KronIA Background Service Worker (MV3)
 *  Responsabilidades:
 *   - Manejar atajos de teclado (Ctrl+K / Ctrl+Shift+K)
 *   - Enviar mensajes al content script de la pestaña activa
 *   - Limpiar sesión expirada en background si hace falta
 * ═══════════════════════════════════════════════════════════════════
 */

// ─── Atajos de teclado ──────────────────────────────────────────────
chrome.commands.onCommand.addListener(function (command) {
  if (command === 'toggle-floating') {
    // Ctrl+Shift+K: mostrar/ocultar burbuja
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      if (!tabs[0] || !tabs[0].id) return;
      chrome.tabs.sendMessage(tabs[0].id, { type: 'kronia-hide-bubble' }, function () {
        if (chrome.runtime.lastError) { /* tab no inyectable, ignorar */ }
      });
    });
  }
});

// _execute_action (Ctrl+K) abre el popup automáticamente — lo maneja Chrome.
// Pero también queremos que abra el modal en la página si la extensión está inyectada.
// Lo hacemos vía onClicked del icono, que se dispara incluso con popup definido si lo cerramos.

// ─── Onboarding al instalar ─────────────────────────────────────────
chrome.runtime.onInstalled.addListener(function (details) {
  if (details.reason === 'install') {
    chrome.tabs.create({
      url: chrome.runtime.getURL('popup.html') + '?welcome=1'
    });
  }
});

// ─── Limpieza periódica de tokens expirados (cada hora) ─────────────
function programarLimpieza() {
  chrome.alarms.create('kronia-cleanup', { periodInMinutes: 60 });
}
try { programarLimpieza(); } catch (e) { /* alarms no disponible: no critico */ }

chrome.alarms && chrome.alarms.onAlarm.addListener(function (alarm) {
  if (alarm.name === 'kronia-cleanup') {
    // Verificar token actual; si expiró, limpiarlo
    chrome.storage.local.get(['kronia_session'], function (r) {
      if (r && r.kronia_session && r.kronia_session.token) {
        fetch('https://ascenda-os-production.up.railway.app/api/kronia/verify', {
          method: 'GET',
          headers: { 'Authorization': 'Bearer ' + r.kronia_session.token }
        }).then(function (resp) {
          if (resp.status === 401) chrome.storage.local.remove(['kronia_session']);
        }).catch(function () { /* sin red, no borrar */ });
      }
    });
  }
});
