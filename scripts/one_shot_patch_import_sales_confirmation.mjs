import fs from 'node:fs';

const file = 'app/public/app.html';
let src = fs.readFileSync(file, 'utf8');
const guard = 'ASCENDA_IMPORT_SALES_CONFIRMATION_20260812';
if (src.includes(guard)) {
  console.log('Import sales confirmation already present.');
  process.exit(0);
}

const marker = '    /* ═══ ANTI-DUPLICADO: bloquear flag + botón mientras procesa ═══ */';
const salesStart = "    var valid=_impVentas.map(function(r){";
const start = src.indexOf(salesStart);
if (start < 0) throw new Error('Sales import mapping marker not found');
const at = src.indexOf(marker, start);
if (at < 0) throw new Error('Sales import save marker not found after mapping');
if (src.indexOf(salesStart, start + 1) >= 0) throw new Error('Sales import mapping marker is not unique');

const insertion = `    /* ${guard}\n       Safety gate: the selected date is applied to every row in this pasted batch. */\n    if(!fecha){\n      if(window.AOS_showToast)AOS_showToast('Selecciona la fecha de las ventas antes de importar','','toast-alerta');\n      return;\n    }\n    var importInvalidos=valid.filter(function(r){var x=Number(r.monto);return !Number.isFinite(x)||x<=0;});\n    if(importInvalidos.length){\n      if(window.AOS_showToast)AOS_showToast('Hay '+importInvalidos.length+' monto(s) inválido(s). Corrige el lote antes de guardar.','','toast-alerta');\n      return;\n    }\n    var importTotal=valid.reduce(function(sum,r){return sum+Number(r.monto||0);},0);\n    var importFecha=fecha.split('-').reverse().join('/');\n    var importFechaObj=new Date(fecha+'T12:00:00');\n    var importHoy=new Date();importHoy.setHours(12,0,0,0);\n    var importDiff=Math.round((importFechaObj-importHoy)/86400000);\n    var importAviso=importDiff===0?'':'\\n\\n⚠ La fecha seleccionada no es hoy. Esto es correcto solo si estás cargando ventas históricas.';\n    var importOk=window.confirm(\n      'CONFIRMAR IMPORTACIÓN DE VENTAS\\n\\n'+\n      'Fecha que se guardará: '+importFecha+'\\n'+\n      'Sede: '+sede+'\\n'+\n      'Filas: '+valid.length+'\\n'+\n      'Total: S/'+importTotal.toLocaleString('es-PE',{minimumFractionDigits:2,maximumFractionDigits:2})+\n      importAviso+'\\n\\n'+\n      'IMPORTANTE: esta fecha se aplicará a TODAS las filas del lote.\\n\\n¿Confirmas que FECHA, SEDE, FILAS y TOTAL son correctos?'\n    );\n    if(!importOk){\n      if(window.AOS_showToast)AOS_showToast('Importación cancelada. No se guardó ninguna venta.','','toast-alerta');\n      return;\n    }\n`;

src = src.slice(0, at) + insertion + src.slice(at);
fs.writeFileSync(file, src);
console.log('Import sales confirmation inserted safely.');
