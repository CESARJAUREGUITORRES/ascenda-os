// src/main.js
import "../src/styles/main.css"
import { session } from "./lib/supabase.js"
import { register, init } from "./lib/router.js"
import { LoginPage, initLogin } from "./pages/login.js"

register("/", () => {
  // Si viene de /app (sesión inválida), NO redirigir de vuelta — mostrar login
  const sesionOk = session.isValid();
  if (sesionOk) {
    window.location.href = "/app";
    return "";
  }
  return LoginPage();
});

register("/login", LoginPage);

document.addEventListener("page:mounted", function(e) {
  if (e.detail.path === "/" || e.detail.path === "/login") initLogin();
});

init();
