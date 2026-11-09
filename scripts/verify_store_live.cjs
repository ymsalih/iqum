// Public, read-only smoke checks. No authentication account or game data created.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),base='https://europe-west1-iqum-4734b.cloudfunctions.net';
(async()=>{
  const checks=[];
  async function rpc(action,payload={}){const response=await fetch(base+'/api',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({data:{action,payload}}),signal:AbortSignal.timeout(30000)});return {status:response.status,body:await response.json()};}
  const clock=await rpc('getServerTime');assert.equal(clock.status,200);assert.ok(Number.isFinite(clock.body.result.serverNow));checks.push({name:'public_clock_monitoring_mode',status:clock.status});
  for(const action of ['getProfile','requestAccountDeletion','acceptLegalTerms']){const result=await rpc(action,{requestId:crypto.randomBytes(16).toString('hex'),version:'2026-11-09'});assert.equal(result.status,401);checks.push({name:action+'_requires_auth',status:result.status});}
  const receipt=await rpc('getDeletionStatus',{uid:'nonexistent-readiness-'+crypto.randomBytes(16).toString('hex'),requestId:crypto.randomBytes(16).toString('hex')});assert.equal(receipt.status,200);assert.equal(receipt.body.result.state,'unknown');assert.deepEqual(Object.keys(receipt.body.result).sort(),['serverNow','state']);checks.push({name:'receipt_returns_no_profile_or_identity',status:receipt.status});
  for(const task of ['eraseAccountTask','advanceMatchTask']){const response=await fetch(base+'/'+task,{method:'POST',headers:{'content-type':'application/json'},body:'{"data":{}}',signal:AbortSignal.timeout(30000)});assert.ok([401,403].includes(response.status));checks.push({name:task+'_private',status:response.status});}
  const report={checkedAt:new Date().toISOString(),checks,noUserOrGameWrites:true,limitations:'No real Google/Apple account deletion or live queue execution tested by this read-only smoke check.'};
  fs.writeFileSync(path.join(root,'output/store-live-verification.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error.message);process.exitCode=1;});
