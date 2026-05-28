# KronIA — Extensión Chrome para AscendaOS

Asistente AI flotante que aparece en cualquier pestaña del navegador.
Acceso a leads, agenda, ventas, llamadas y pacientes de Zi Vital desde donde estés.

---

## 🚀 INSTALACIÓN (modo desarrollador, 2 minutos)

### Paso 1 — Descargar la extensión

Si tienes el repo clonado, ya tienes la carpeta `chrome-extension/`. Si no, descárgala como ZIP desde GitHub y descomprime donde quieras.

### Paso 2 — Abrir Chrome en modo desarrollador

1. Abre Chrome
2. En la barra de direcciones escribe: `chrome://extensions`
3. Arriba a la derecha activa el switch **"Modo de desarrollador"**

### Paso 3 — Cargar la extensión

1. Click en **"Cargar descomprimida"** (botón arriba a la izquierda)
2. Selecciona la carpeta **`chrome-extension/`** (la que contiene `manifest.json`)
3. Listo: aparece el icono KronIA en la barra de extensiones

> 💡 **Tip:** ancla el icono haciendo click en el puzzle 🧩 y luego en el alfiler junto a KronIA.

### Paso 4 — Primera vez: iniciar sesión

Al instalar se abre una pestaña de bienvenida.
1. Click en **"Empezar"**
2. Ingresa tu usuario de AscendaOS
3. Recibirás un código de 6 dígitos en tu email
4. Ingrésalo y listo: KronIA queda activo por 24h

---

## 📍 CÓMO USAR

### Tres formas de invocar KronIA:

| Forma | Cómo | Para qué |
|---|---|---|
| **Botón flotante** 🔵 | Está siempre visible abajo a la derecha en cualquier web | Consulta rápida sin abrir popup |
| **Icono de barra** | Click en el icono K de la barra de Chrome | Dashboard con acciones rápidas |
| **Atajo de teclado** | `Ctrl+K` (Cmd+K en Mac) | Abrir el popup en segundos |

### Atajos disponibles:

- `Ctrl+K` → Abrir popup de KronIA
- `Ctrl+Shift+K` → Mostrar/ocultar botón flotante en página actual

### Mover el botón flotante:

Arrastra la burbuja a donde quieras — recuerda su posición.

---

## 🔒 SEGURIDAD

- Login con código 2FA enviado a tu email (mismo flujo que AscendaOS)
- Token de sesión válido por **24 horas**
- Al cerrar sesión el token se **revoca en el servidor** (no solo localmente)
- Permisos por rol: ADMIN ve todo, ASESOR ve solo lo propio + totales del equipo
- Nunca se guardan contraseñas (passwordless)

---

## 🎤 USO POR VOZ

1. Abre KronIA (atajo o botón flotante)
2. Click en el icono de micrófono 🎤
3. Habla tu pregunta (máximo 30 segundos)
4. KronIA transcribe y responde

---

## 🛠 RESOLUCIÓN DE PROBLEMAS

**No veo el botón flotante en una página**
- Algunas páginas (`chrome://`, Chrome Web Store) no permiten extensiones
- Recarga la página después de instalar
- Verifica que la extensión esté activa en `chrome://extensions`

**Dice "Sesión expirada"**
- Es normal después de 24h, vuelve a hacer login

**Quiero desinstalar**
- `chrome://extensions` → Quitar

---

## 📂 ARCHIVOS DE LA EXTENSIÓN

```
chrome-extension/
├── manifest.json           ← Declaración v3
├── background.js           ← Service worker
├── content-script.js       ← Inyecta widget en cada web
├── content-style.css       ← Estilos del flotante
├── popup.html / .js / .css ← UI del popup de barra
├── kronia-core.js          ← Lógica compartida con AscendaOS
└── icons/                  ← Iconos 16/48/128
```

---

## 🔄 ACTUALIZAR LA EXTENSIÓN

1. Reemplaza la carpeta con la versión nueva
2. En `chrome://extensions` click en el botón circular 🔄 de la extensión KronIA

---

**Versión 1.0.0** · CREACTIVE OS · AscendaOS v1
