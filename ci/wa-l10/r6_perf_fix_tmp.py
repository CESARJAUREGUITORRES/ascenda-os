from pathlib import Path
p=Path('app/wa4-copilot.js')
s=p.read_text()
old="""function withDeadline(promise,ms,code){
  let timer;
  const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(code||'WA4_DEADLINE_EXCEEDED')),Math.max(250,Number(ms)||2500));});
  return Promise.race([Promise.resolve(promise),timeout]).finally(()=>clearTimeout(timer));
}
"""
if old not in s:
    raise SystemExit('R6_WITH_DEADLINE_ANCHOR_MISSING')
s=s.replace(old,'',1)
s=s.replace("const rows=await withDeadline(searchKnowledge(serviceRpc,query,'PUBLIC_CLIENT',8,['CATALOG','CATEGORY']),3500,'WA4_FAST_PRICE_SEARCH_TIMEOUT');","const rows=await searchKnowledge(serviceRpc,query,'PUBLIC_CLIENT',8,['CATALOG','CATEGORY']);",1)
s=s.replace("const contexts=await withDeadline(loadProcessContexts(serviceGet,catalogIdsFromBundles(raw)),1800,'WA4_FAST_PRICE_CONTEXT_TIMEOUT');","const contexts=await loadProcessContexts(serviceGet,catalogIdsFromBundles(raw));",1)
if 'setTimeout(' in s or 'setTimeout (' in s:
    raise SystemExit('R6_COPILOT_RECURRENT_TIMER_REMAINS')
p.write_text(s)

# Strengthen R6 regression: copilot may not become a recurrent network owner.
t=Path('ci/wa4-ai-sales-router/r6-conversation-ux-fastlane.test.js')
r=t.read_text().rstrip()+"\n\n"+"""test('R6 fast lane does not create a recurrent network owner in wa4-copilot',()=>{
  const src=fs.readFileSync(require.resolve('../../app/wa4-copilot'),'utf8');
  assert.equal(/\\bsetTimeout\\s*\\(/.test(src),false);
  assert.equal(/\\bsetInterval\\s*\\(/.test(src),false);
  assert.ok(src.includes("searchKnowledge(serviceRpc,query,'PUBLIC_CLIENT',8,['CATALOG','CATEGORY'])"));
});
"""
t.write_text(r)
