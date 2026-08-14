from pathlib import Path

src_path = Path('ci/kronia-k1/apply_runtime_patch.py')
src = src_path.read_text(encoding='utf-8')
old = "    out, n = re.subn(pattern, repl, text, count=1, flags=flags)"
new = "    if r'\\1' in repl or r'\\g<' in repl:\n        out, n = re.subn(pattern, repl, text, count=1, flags=flags)\n    else:\n        out, n = re.subn(pattern, lambda _m: repl, text, count=1, flags=flags)"
if old not in src:
    raise SystemExit('K1 patch engine anchor not found')
src = src.replace(old, new, 1)
code = compile(src, str(src_path), 'exec')
exec(code, {'__name__': '__main__', '__file__': str(src_path)})
