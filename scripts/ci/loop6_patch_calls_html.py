from pathlib import Path

path = Path('app/public/calls.html')
tag = '<script src="/calls-loop6.js?v=20260821-loop6-v1"></script>'
text = path.read_text(encoding='utf-8')
if tag not in text:
    text = text.rstrip() + '\n' + tag + '\n'
    path.write_text(text, encoding='utf-8')
    print('PATCHED calls.html')
else:
    print('ALREADY_PATCHED calls.html')
