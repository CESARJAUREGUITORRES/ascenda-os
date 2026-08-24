from pathlib import Path

server = Path('app/server-f17.js')
text = server.read_text()
old_vars = "let notificationPumpTimer = null\nlet notificationPumpBusy = false\n"
new_vars = "let notificationPumpTimer = null\nlet notificationPumpBusy = false\nlet notificationPumpIdleLevel = 0\nconst NOTIFICATION_PUMP_ACTIVE_MS = 4000\nconst NOTIFICATION_PUMP_IDLE_MS = [8000, 15000]\n"
if old_vars not in text:
    raise SystemExit('PERF-5A drift: pump vars block not found')
text = text.replace(old_vars, new_vars, 1)
old = """async function runNotificationPump() {\n  if (notificationPumpBusy) return\n  notificationPumpBusy = true\n  try {\n    const r = await push.dispatchPendingNotifications(25)\n    if (r && (r.delivered || r.failed || r.partial)) console.log('[S15] notification push', r)\n  } catch (e) {\n    console.error('[S15] notification pump fail-open', e && e.message || e)\n  } finally {\n    notificationPumpBusy = false\n  }\n}\nfunction startNotificationPump() {\n  if (notificationPumpTimer) return\n  setImmediate(function() { runNotificationPump().catch(function(){}) })\n  notificationPumpTimer = setInterval(function() { runNotificationPump().catch(function(){}) }, 4000)\n  if (notificationPumpTimer.unref) notificationPumpTimer.unref()\n}\nfunction stopNotificationPump() {\n  if (notificationPumpTimer) clearInterval(notificationPumpTimer)\n  notificationPumpTimer = null\n}\n"""
new = """async function runNotificationPump() {\n  if (notificationPumpBusy) return { busy: true }\n  notificationPumpBusy = true\n  try {\n    const r = await push.dispatchPendingNotifications(25)\n    if (r && (r.delivered || r.failed || r.partial)) console.log('[S15] notification push', r)\n    return r || { ok: true, claimed: 0 }\n  } catch (e) {\n    console.error('[S15] notification pump fail-open', e && e.message || e)\n    return { ok: false, error: true, claimed: 0 }\n  } finally {\n    notificationPumpBusy = false\n  }\n}\nfunction notificationPumpDelay(result) {\n  const didWork = !!(result && (Number(result.claimed || 0) > 0 || Number(result.delivered || 0) > 0 || Number(result.failed || 0) > 0 || Number(result.partial || 0) > 0))\n  if (didWork) { notificationPumpIdleLevel = 0; return NOTIFICATION_PUMP_ACTIVE_MS }\n  notificationPumpIdleLevel = Math.min(notificationPumpIdleLevel + 1, NOTIFICATION_PUMP_IDLE_MS.length)\n  return NOTIFICATION_PUMP_IDLE_MS[notificationPumpIdleLevel - 1]\n}\nfunction scheduleNotificationPump(delay) {\n  if (notificationPumpTimer) clearTimeout(notificationPumpTimer)\n  notificationPumpTimer = setTimeout(function tick() {\n    notificationPumpTimer = null\n    runNotificationPump().then(function(result) {\n      scheduleNotificationPump(notificationPumpDelay(result))\n    }).catch(function() { scheduleNotificationPump(NOTIFICATION_PUMP_IDLE_MS[0]) })\n  }, Math.max(1000, Number(delay || NOTIFICATION_PUMP_ACTIVE_MS)))\n  if (notificationPumpTimer.unref) notificationPumpTimer.unref()\n}\nfunction startNotificationPump() {\n  if (notificationPumpTimer || notificationPumpBusy) return\n  setImmediate(function() {\n    runNotificationPump().then(function(result) { scheduleNotificationPump(notificationPumpDelay(result)) }).catch(function() { scheduleNotificationPump(NOTIFICATION_PUMP_IDLE_MS[0]) })\n  })\n}\nfunction stopNotificationPump() {\n  if (notificationPumpTimer) clearTimeout(notificationPumpTimer)\n  notificationPumpTimer = null\n  notificationPumpIdleLevel = 0\n}\n"""
if old not in text:
    raise SystemExit('PERF-5A drift: fixed pump block not found')
server.write_text(text.replace(old, new, 1))

contract = Path('ci/s15/contract.js')
c = contract.read_text()
old_contract = "ok(server.includes('setInterval(function() { runNotificationPump()'), 'notification pump cadence missing')"
new_contract = "ok(server.includes('function notificationPumpDelay(result)')&&server.includes('NOTIFICATION_PUMP_IDLE_MS = [8000, 15000]')&&server.includes('scheduleNotificationPump(notificationPumpDelay(result))'), 'adaptive notification pump cadence missing')"
if old_contract not in c:
    raise SystemExit('PERF-5A drift: S15 cadence contract not found')
contract.write_text(c.replace(old_contract, new_contract, 1))
print('PERF-5A patch applied')
