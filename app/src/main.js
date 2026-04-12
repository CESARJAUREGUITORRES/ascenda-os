// src/main.js
import "../src/styles/main.css"
import { session } from "./lib/supabase.js"
import { register, init, navigate } from "./lib/router.js"
import { LoginPage, initLogin } from "./pages/login.js"

// Login route
register("/", () => {
  if (session.isValid()) {
    window.location.href = "/app";
    return "";
  }
  return LoginPage();
});

register("/login", LoginPage);

// Inicializar login
document.addEventListener("page:mounted", function(e) {
  var path = e.detail.path;
  if (path === "/" || path === "/login") initLogin();
});

init();
