from pathlib import Path


def once(text, old, new, label):
    if new in text:
        return text
    if old not in text:
        raise SystemExit('PATCH_ANCHOR_MISSING:' + label)
    return text.replace(old, new, 1)

p=Path('app/push-notifications-s14.js')
s=p.read_text()
s=once(s,
"    const current = await rpc('aos_push_vapid_config_v1', {})",
"    let current\n    try { current = await rpc('aos_push_vapid_runtime_config_v2', {}) }\n    catch (_) { current = await rpc('aos_push_vapid_config_v1', {}) }",
'vapid-runtime-v2')
old="""      try {
        target = await rpc('aos_push_targets_for_wa_v1', {
          contact_number: digits(m.from_number),
          phone_number_id: text(m.phone_number_id, 128),
          provider_message_id: text(m.provider_message_id, 256)
        })
      } catch (e) {
        totals.failed++
        logger.error('[S14] target resolution failed', e.message)
        continue
      }
"""
new="""      const targetPayload = {
        contact_number: digits(m.from_number),
        phone_number_id: text(m.phone_number_id, 128),
        provider_message_id: text(m.provider_message_id, 256)
      }
      try {
        try { target = await rpc('aos_push_targets_for_wa_v2', targetPayload) }
        catch (_) { target = await rpc('aos_push_targets_for_wa_v1', targetPayload) }
      } catch (e) {
        totals.failed++
        logger.error('[S14] target resolution failed', e.message)
        continue
      }
"""
s=once(s,old,new,'target-v2')
p.write_text(s)

p=Path('ci/wa-s14/contract.js')
s=p.read_text()
anchor="const migration=fs.readFileSync(path.join(root,'supabase/migrations/20260817221500_wa_s14_web_push_notification_transport.sql'),'utf8')\n"
new_anchor=anchor+"const r7prod=fs.readFileSync(path.join(root,'supabase/migrations/20260909234000_wa_s14_event_push_priority_v2.sql'),'utf8')\n"
s=once(s,anchor,new_anchor,'contract-migration-read')
check="ok(migration.includes(\"grant execute on function public.aos_push_vapid_config_v1(jsonb) to service_role\"),'VAPID config RPC must be service-role only')\n"
new_check=check+"ok(push.includes(\"aos_push_vapid_runtime_config_v2\"),'R7 runtime VAPID RPC missing')\nok(r7prod.includes(\"grant execute on function public.aos_push_vapid_runtime_config_v2(jsonb) to service_role\"),'R7 runtime VAPID RPC must be service-role only')\n"
s=once(s,check,new_check,'contract-vapid-v2')
target_check="ok(push.includes(\"aos_push_dispatch_claim_v1\"),'per-device dedupe claim missing')\n"
new_target_check="ok(push.includes(\"aos_push_targets_for_wa_v2\"),'R7 bounded queue notification target RPC missing')\nok(r7prod.includes(\"QUEUE_SUPERVISOR_FALLBACK\"),'R7 unassigned HUMAN_REQUESTED bounded fallback missing')\nok(r7prod.includes(\"limit 1;\"),'R7 queue notification fallback must select one recipient only')\n"+target_check
s=once(s,target_check,new_target_check,'contract-target-v2')
p.write_text(s)
