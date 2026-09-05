from pathlib import Path
p=Path('ci/wa4-ai-sales-router/r6-conversation-ux-fastlane.test.js')
lines=[]
for line in p.read_text().splitlines():
    if "assert.equal((d.reply.match(" in line:
        indent=line[:len(line)-len(line.lstrip())]
        lines.append(indent+"assert.equal(d.reply.split('?').length-1,1);")
    elif "assert.equal((draft.reply.match(" in line:
        indent=line[:len(line)-len(line.lstrip())]
        lines.append(indent+"assert.equal(draft.reply.split('?').length-1,1);")
    else:
        lines.append(line)
p.write_text('\n'.join(lines)+'\n')
