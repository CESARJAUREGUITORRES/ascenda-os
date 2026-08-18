'use strict'
// ASCENDA S15.2 — production bootstrap that preserves Phase S intact while
// inserting the certified F17 boundary before F5.
// Effective chain: Phase S -> F17 -> F5 -> WA4 -> WA3 -> WA2 -> F4.
const childProcess=require('child_process')
const originalSpawn=childProcess.spawn

function rewriteChildArgs(command,args){
  const a=Array.isArray(args)?args.slice():args
  if(command===process.execPath&&Array.isArray(a)&&a[0]==='server-f5.js'){
    a[0]='server-f17.js'
  }
  return a
}

function installF17Boundary(){
  if(childProcess.spawn&&childProcess.spawn.__aosS152)return
  function aosSpawn(command,args,options){
    const rewritten=rewriteChildArgs(command,args)
    if(Array.isArray(args)&&Array.isArray(rewritten)&&args[0]==='server-f5.js'&&rewritten[0]==='server-f17.js'){
      console.log('[S15.2] Phase S child upgraded: server-f17.js -> server-f5.js chain')
    }
    return originalSpawn.call(childProcess,command,rewritten,options)
  }
  aosSpawn.__aosS152=true
  childProcess.spawn=aosSpawn
}

if(require.main===module){
  installF17Boundary()
  require('./server-phase-s.js')
}

module.exports={rewriteChildArgs,installF17Boundary}
