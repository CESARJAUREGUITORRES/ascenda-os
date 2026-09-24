'use strict'

/*
 * ASCENDA OS · P0 DB Recovery Timer Gate
 *
 * During AOS_FOREGROUND_PRIORITY_MODE the legacy server.js `guardedAutoTick`
 * scheduler is allowed to execute only inside the already-certified Lima
 * reminder windows (08:00-11:59 and 20:00-23:59). If the shared DB background
 * circuit is open after a failed reminder attempt, the whole tick is skipped
 * until that circuit expires. This prevents key loads and agent scans from
 * continuing to consume connections while Supabase recovers.
 *
 * Scope is intentionally surgical: only a callback named exactly
 * `guardedAutoTick` with the certified 15s bootstrap or 60s interval is gated.
 * No application HTTP timers, Call Center, Auth, Agenda, push or email timers
 * are modified.
 */

if (!global.__AOS_AGENT_RECOVERY_TIMER_GATE_V1__) {
  global.__AOS_AGENT_RECOVERY_TIMER_GATE_V1__ = true

  const enabled = /^(1|true|yes|on)$/i.test(String(process.env.AOS_FOREGROUND_PRIORITY_MODE || 'false'))
  const nativeSetInterval = global.setInterval.bind(global)
  const nativeSetTimeout = global.setTimeout.bind(global)

  function limaHour() {
    const forced = Number(process.env.AOS_TEST_LIMA_HOUR)
    if (Number.isInteger(forced) && forced >= 0 && forced <= 23) return forced
    return (new Date().getUTCHours() + 19) % 24
  }

  function isReminderWindow(hour) {
    return (hour >= 8 && hour <= 11) || (hour >= 20 && hour <= 23)
  }

  function isCertifiedAgentTimer(fn, delay) {
    if (typeof fn !== 'function' || fn.name !== 'guardedAutoTick') return false
    const ms = Number(delay || 0)
    return ms === 15000 || ms === 60000
  }

  function recoveryCircuitOpen() {
    const runtime = global.__AOS_BUSINESS_PRIORITY_V1__
    return !!(runtime && typeof runtime.circuitOpen === 'function' && runtime.circuitOpen('agent-cron-scan'))
  }

  function gatedCallback(fn) {
    return function aosRecoveryGuardedAutoTick() {
      if (!enabled) return fn.apply(this, arguments)
      if (!isReminderWindow(limaHour())) return undefined
      if (recoveryCircuitOpen()) return undefined
      return fn.apply(this, arguments)
    }
  }

  global.setInterval = function aosRecoverySetInterval(fn, delay) {
    const args = Array.prototype.slice.call(arguments, 2)
    if (!enabled || !isCertifiedAgentTimer(fn, delay)) return nativeSetInterval(fn, delay, ...args)
    console.log('[P0-AGENTS] guarded auto-tick recovery gate active', { interval_ms: Number(delay), reminderWindowsLima: '08-11,20-23', sharedCircuitAware: true })
    return nativeSetInterval(gatedCallback(fn), delay, ...args)
  }

  global.setTimeout = function aosRecoverySetTimeout(fn, delay) {
    const args = Array.prototype.slice.call(arguments, 2)
    if (!enabled || !isCertifiedAgentTimer(fn, delay)) return nativeSetTimeout(fn, delay, ...args)
    return nativeSetTimeout(gatedCallback(fn), delay, ...args)
  }

  global.__AOS_AGENT_RECOVERY_TIMER_GATE_STATE__ = {
    version: 'p0-agent-timer-v2-circuit-aware',
    enabled: enabled,
    isReminderWindow: isReminderWindow,
    isCertifiedAgentTimer: isCertifiedAgentTimer,
    recoveryCircuitOpen: recoveryCircuitOpen
  }

  console.log('[P0-AGENTS] recovery timer gate ready', { enabled: enabled, reminderWindowsLima: '08-11,20-23', sharedCircuitAware: true })
}
