from pathlib import Path
p=Path('ci/wa4-ai-sales-router/r6-conversation-ux-fastlane.test.js')
s=p.read_text()
s=s.replace("assert.equal((d.reply.match(/\\\\?/g)||[]).length,1);","assert.equal(d.reply.split('?').length-1,1);")
s=s.replace("assert.equal((draft.reply.match(/\\\\?/g)||[]).length,1);","assert.equal(draft.reply.split('?').length-1,1);")
p.write_text(s)
