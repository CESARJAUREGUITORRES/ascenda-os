import fs from 'node:fs';

const path = 'app/public/calls.html';
const marker = '<script src="/calls-loop6.js?v=20260821-loop6"></script>';
const anchor = '<!-- KronIA Chat — en app.html (persistente entre paneles) -->';
let text = fs.readFileSync(path, 'utf8');
const count = text.split(marker).length - 1;
if (count > 1) throw new Error(`LOOP6 loader duplicated: ${count}`);
if (count === 0) {
  if (!text.includes(anchor)) throw new Error('LOOP6 loader anchor not found');
  text = text.replace(anchor, `${marker}\n${anchor}`);
  fs.writeFileSync(path, text, 'utf8');
  console.log('LOOP6_LOADER_PATCH=APPLIED');
} else {
  console.log('LOOP6_LOADER_PATCH=ALREADY_PRESENT');
}
