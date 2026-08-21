import fs from 'node:fs';

const path = 'app/public/calls.html';
const marker = '<script src="/calls-loop6.js?v=20260821-loop6"></script>';
const obsoletePolicyMarker = '<script src="/calls-loop6-policy-v2.js?v=20260821-loop6-policy-v2"></script>';
const anchor = '<!-- KronIA Chat — en app.html (persistente entre paneles) -->';
let text = fs.readFileSync(path, 'utf8');
let changed = false;

if (text.includes(obsoletePolicyMarker)) {
  text = text.split(obsoletePolicyMarker + '\n').join('');
  text = text.split(obsoletePolicyMarker).join('');
  changed = true;
  console.log('LOOP6_OBSOLETE_POLICY_LOADER=REMOVED');
}

const count = text.split(marker).length - 1;
if (count > 1) throw new Error(`LOOP6 loader duplicated: ${count}`);
if (count === 0) {
  if (!text.includes(anchor)) throw new Error('LOOP6 loader anchor not found');
  text = text.replace(anchor, `${marker}\n${anchor}`);
  changed = true;
  console.log('LOOP6_LOADER_PATCH=APPLIED');
} else {
  console.log('LOOP6_LOADER_PATCH=ALREADY_PRESENT');
}

if (changed) fs.writeFileSync(path, text, 'utf8');
