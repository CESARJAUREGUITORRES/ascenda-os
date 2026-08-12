/* ASCENDA OS — Marketing Attribution V2 UI adapter
 * EMERGENCY SAFE MODE — 2026-08-12
 *
 * The V2 reporting adapter is temporarily disabled after a production UI
 * regression where legacy blocks were suppressed while V2 RPCs were still
 * loading. The stable legacy Marketing renderer remains the active UI.
 *
 * IMPORTANT:
 * - No database data is removed.
 * - V2 attribution/reconstruction RPCs remain available for validation.
 * - Call Center traceability columns remain intact.
 * - Re-enable only after browser-level regression testing confirms that V2
 *   progressively enhances rendered legacy blocks instead of blanking them.
 */
(function(){
  window.__AOS_MARKETING_V2_LOADED = true;
  window.__AOS_MARKETING_V2_ACTIVE = false;
  console.warn('[ASCENDA] Marketing Attribution V2 UI en SAFE MODE; renderer legacy activo.');
})();
