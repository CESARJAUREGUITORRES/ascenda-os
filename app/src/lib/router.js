// src/lib/router.js
// Router SPA minimalista — sin librerías externas

const routes = {}
let currentPage = null

export function register(path, fn) {
  routes[path] = fn
}

export function navigate(path, data = {}) {
  window.history.pushState(data, '', path)
  render(path, data)
}

export function render(path, data = {}) {
  const fn = routes[path] || routes['/404'] || (() => '<h1>404</h1>')
  const app = document.getElementById('app')
  if (app) {
    app.innerHTML = fn(data)
    currentPage = path
    // Disparar evento para que cada página inicialice su JS
    document.dispatchEvent(new CustomEvent('page:mounted', { detail: { path, data } }))
  }
}

export function init() {
  window.addEventListener('popstate', (e) => {
    render(window.location.pathname, e.state || {})
  })
  render(window.location.pathname)
}
