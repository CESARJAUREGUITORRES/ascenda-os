import fs from 'node:fs';

const path = 'app/public/calls.html';
const baseMarker = '<script src="/calls-loop6.js?v=20260821-loop6"></script>';
const policyMarker = '<script src="/calls-loop6-policy-v2.js?v=20260821-loop6-policy-v2"></script>';
const anchor = '<!-- KronIA Chat — en app.html (persistente entre paneles) -->';
let text = fs.readFileSync(path, 'utf8');

const baseCount = text.split(baseMarker).length - 1;
const policyCount = text.split(policyMarker).length - 1;
if (baseCount !== 1) throw new Error(`Expected exactly one Loop 6 base loader, found ${baseCount}`);
if (policyCount > 1) throw new Error(`LOOP6 policy loader duplicated: ${policyCount}`);

if (policyCount === 0) {
  if (!text.includes(anchor)) throw new Error('LOOP6 loader anchor not found');
  text = text.replace(anchor, `${policyMarker}\n${anchor}`);
  fs.writeFileSync(path, text, 'utf8');
  console.log('LOOP6_POLICY_LOADER_PATCH=APPLIED');
} else {
  console.log('LOOP6_POLICY_LOADER_PATCH=ALREADY_PRESENT');
}
