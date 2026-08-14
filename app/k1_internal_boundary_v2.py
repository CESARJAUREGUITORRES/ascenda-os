from pathlib import Path

ROOT=Path(__file__).resolve().parent
base=ROOT/'k1_internal_boundary.py'
src=base.read_text(encoding='utf-8')

old='check_pattern = re.compile(r"function checkSB\\(\\)\\{.*?\\n\\}\\nsetInterval\\(checkSB, 30000\\);", re.S)'
new='check_pattern = re.compile(r"function checkSB\\(\\)\\{.*?setInterval\\(checkSB, 30000\\);", re.S)'
if old not in src:
    raise SystemExit('K1 internal v2: Brain check pattern anchor missing')
src=src.replace(old,new,1)

exec(compile(src,str(base),'exec'),{'__name__':'__main__','__file__':str(base)})
