'use strict';
window.AscendaBookingV33={
  validEmail:function(v){return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v||'').trim())},
  deliver:function(appointmentId){return fetch('/api/booking/public-confirmation-v33',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({appointment_id:appointmentId})}).then(async function(r){var j={};try{j=await r.json()}catch(_){}if(!r.ok||!j.ok)throw new Error(j.error||'BOOKING_CONFIRMATION_FAILED');return j})}
};
