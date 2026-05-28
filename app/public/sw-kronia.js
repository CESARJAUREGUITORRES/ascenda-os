/**
 * KronIA Service Worker v1.1.0
 *
 * ESTRATEGIA NETWORK-FIRST AGRESIVO:
 * - HTML/JS/CSS/JSON: SIEMPRE buscar en red con cache: 'no-store'
 *   (asi la PWA muestra siempre la ultima version sin reinstalar)
 * - Iconos PNG: cache-first (no cambian seguido)
 *
 * Fix: en v1.0.0 era passthrough total, pero la cache HTTP del navegador
 * dentro de la PWA seguia mostrando version vieja del Brain.
 * Ahora interceptamos y forzamos no-store en recursos dinamicos.
 */
const SW_VERSION = '1.1.0';
const STATIC_CACHE = 'kronia-static-v1';

/* Recursos estaticos que SI conviene cachear (no cambian) */
const STATIC_PATTERNS = [
  /\.png$/i, /\.jpg$/i, /\.jpeg$/i, /\.webp$/i, /\.gif$/i, /\.svg$/i,
  /\.woff2?$/i, /\.ttf$/i, /\.ico$/i
];

self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    Promise.all([
      self.clients.claim(),
      /* Limpiar caches viejos */
      caches.keys().then(function(names) {
        return Promise.all(
          names.filter(function(n) { return n !== STATIC_CACHE; })
               .map(function(n) { return caches.delete(n); })
        );
      })
    ])
  );
});

self.addEventListener('fetch', function(event) {
  const req = event.request;
  /* Solo GET */
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  /* Solo same-origin (no interceptar Supabase ni APIs externas) */
  if (url.origin !== self.location.origin) return;

  const isStatic = STATIC_PATTERNS.some(function(rx) { return rx.test(url.pathname); });

  if (isStatic) {
    /* Cache-first para estaticos */
    event.respondWith(
      caches.open(STATIC_CACHE).then(function(cache) {
        return cache.match(req).then(function(cached) {
          if (cached) return cached;
          return fetch(req).then(function(resp) {
            if (resp && resp.ok) cache.put(req, resp.clone());
            return resp;
          }).catch(function() { return cached || Response.error(); });
        });
      })
    );
  } else {
    /* Network-first agresivo: pedir SIEMPRE a la red, sin cache HTTP */
    event.respondWith(
      fetch(new Request(req, { cache: 'no-store' })).catch(function() {
        /* Fallback offline: intentar servir desde cache si existe */
        return caches.match(req);
      })
    );
  }
});

/* Notificaciones push */
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

/* Mensaje del cliente: forzar update */
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
