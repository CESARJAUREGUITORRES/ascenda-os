'use strict'

const fs=require('fs')
const assert=require('assert')

const sql=fs.readFileSync('supabase/migrations/20260904002000_wa_l8_l9_p0_certification_status_v2.sql','utf8')

assert(sql.includes('aos_wa_l8_safety_status_v2'),'L8 bounded safety status missing')
assert(sql.includes('aos_wa_l9_safety_status_v2'),'L9 bounded safety status missing')
assert(sql.includes("'readback_class','SAFETY_BOUNDED_V2'"),'bounded readback marker missing')
assert(sql.includes("where m.send_origin='AUTO' and m.direction='OUTBOUND'"),'autonomous outbound safety probe missing')
assert(sql.includes('where d.provider_dispatch is true'),'provider dispatch safety probe missing')
assert(sql.includes('COLD_AUDIT_ONLY'),'legacy global status must be explicitly cold-audit only')
assert(!/create\s+materialized\s+view|refresh\s+materialized\s+view/i.test(sql),'certification status may not create/refresh materialized views')
assert(!/statement_timeout/i.test(sql),'P0 certification fix may not change statement_timeout')

const l8=sql.match(/create or replace function public\.aos_wa_l8_safety_status_v2\(\)[\s\S]*?revoke all on function public\.aos_wa_l8_safety_status_v2\(\)/i)
const l9=sql.match(/create or replace function public\.aos_wa_l9_safety_status_v2\(\)[\s\S]*?revoke all on function public\.aos_wa_l9_safety_status_v2\(\)/i)
assert(l8&&l9,'unable to isolate bounded status definitions')
assert(!/count\s*\(/i.test(l8[0]),'L8 production safety readback must not use global COUNT')
assert(!/count\s*\(/i.test(l9[0]),'L9 production safety readback must not use global COUNT')
assert(/exists\s*\(/i.test(l8[0]),'L8 must use existence probe')
assert(/exists\s*\(/i.test(l9[0]),'L9 must use existence probe')

console.log('P0_457_CERTIFICATION_STATUS_V2_CONTRACT=PASS')
