from pathlib import Path
p=Path('ci/wa4-ai-sales-router/r6-conversation-ux-fastlane.test.js')
lines=[]
for line in p.read_text().splitlines():
    if "d.reply.match" in line:
        indent=line[:len(line)-len(line.lstrip())]
        lines.append(indent+"assert.ok(d.reply.includes('cuéntame qué zona te gustaría mejorar'));" )
    else:
        lines.append(line)
p.write_text('\n'.join(lines)+'\n')
