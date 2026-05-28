# KronIA Desktop

App de escritorio que envuelve el Brain de AscendaOS en una ventana flotante.

**Característica principal:** la ventana puede ponerse en modo "siempre encima" y flotar sobre TODO el sistema operativo — Excel, WhatsApp Desktop, Spotify, navegadores, lo que sea. KronIA te avisa por voz Y con notificaciones nativas del sistema cuando entra una venta, cita o lead.

---

## 🎯 Características

| Función | Atajo |
|---|---|
| Mostrar / ocultar KronIA | `Ctrl+Shift+K` |
| Cambiar entre tamaño mini y normal | `Ctrl+Shift+M` |
| Activar/desactivar "siempre encima" | `Ctrl+Shift+T` |

**Tres tamaños:**
- **Mini** (320×90): solo el chip con waveform — ideal para mantener visible mientras trabajas en otra cosa
- **Normal** (480×720): Brain con visualización del grafo
- **Expanded** (1200×800): Brain en grande, panel completo

**Tray icon:** click derecho en el icono de la bandeja del sistema para todas las opciones.

---

## 🛠 INSTALACIÓN (modo dev) — Para probar antes de empaquetar

Requisitos: Node.js v18+ instalado en tu PC.

```bash
cd electron-app
npm install
npm start
```

Se abre KronIA en modo desarrollo. Cierra con Ctrl+C en la terminal.

---

## 📦 EMPAQUETADO — Generar instalador

Para crear el `.exe` (Windows) instalable que tú y tu equipo van a usar:

```bash
cd electron-app
npm install
npm run build:win
```

Se genera en `dist/`:
- `KronIA Setup 1.0.0.exe` — instalador NSIS (con uninstaller)
- `KronIA 1.0.0.exe` — versión portable (sin instalación)

Para Mac (.dmg):
```bash
npm run build:mac
```

Para Linux (AppImage):
```bash
npm run build:linux
```

---

## 🚀 USO DESPUÉS DE INSTALAR

1. Doble click en el instalador descargado
2. KronIA queda en tu menú Inicio y escritorio
3. Al abrirla aparece la ventana del Brain con el icono en la bandeja del sistema
4. Pasa al modo **mini** (botón ▢ arriba a la derecha o `Ctrl+Shift+M`)
5. Ahora la ventana mini queda flotando sobre todo — puedes trabajar en Excel/WhatsApp y KronIA te avisa
6. Cuando alguien hace una venta: notificación del SO + KronIA habla en voz alta

---

## 📂 ESTRUCTURA

```
electron-app/
├── package.json          ← Config y scripts de build
├── src/
│   ├── main.js           ← Proceso principal (ventana, tray, atajos)
│   ├── preload.js        ← Bridge entre Brain y APIs nativas
│   └── assets/
│       └── icon.png      ← Icono de la app (128x128)
└── dist/                 ← (generado tras build) instaladores
```

**Importante:** el Brain se carga desde `https://ascenda-os-production.up.railway.app/cerebro.html`, así que la app SIEMPRE muestra la última versión sin tener que actualizarla. Cuando hagamos cambios al Brain, se reflejan automáticamente.

---

## 🔄 ACTUALIZAR LA APP

Si cambia la lógica del Electron (no el Brain), genera un nuevo instalador con `npm run build:win` y distribúyelo a tu equipo. Mientras solo cambies el Brain en AscendaOS, no necesitas actualizar la app.

---

**Versión 1.0.0** · CREACTIVE OS · KronIA Desktop
