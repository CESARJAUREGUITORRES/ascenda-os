/**
 * KronIA Service Worker — minimo para habilitar PWA
 *
 * NO cachea archivos (delego al header Cache-Control del server) para
 * evitar que se vea version vieja del Brain. Solo permite la instalacion
 * como PWA en Chrome/Edge/Safari.
 *
 * Si en el futuro queremos offline, agregar logica de cache aqui.
 */
const SW_VERSION = '1.0.0';

self.addEventListener('install', function(event) {
  /* Activa este SW inmediatamente sin esperar a que se cierren tabs */
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  /* Toma control de las tabs abiertas */
  event.waitUntil(self.clients.claim());
});

/* Fetch: pasthrough total (siempre desde la red, no cacheamos) */
self.addEventListener('fetch', function(event) {
  /* No interceptar — dejar que el navegador haga la peticion directa */
  return;
});

/* Notificaciones push (placeholder para futuro) */
self.addEventListener('push', function(event) {
  if (!event.data) return;
  try {
    var data = event.data.json();
    event.waitUntil(
      self.registration.showNotification(data.title || 'KronIA', {
        body: data.body || '',
        icon: '/icons/kronia-192.png',
        badge: '/icons/kronia-192.png',
        tag: data.tag || 'kronia',
        renotify: true
      })
    );
  } catch (e) { /* silent */ }
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url.indexOf('/cerebro.html') !== -1 && 'focus' in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow('/cerebro.html');
    })
  );
});
