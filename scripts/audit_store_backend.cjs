// Read-only infrastructure audit. Never reads user records or prints credentials.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),project='iqum-4734b';
(async()=>{
  const base=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/');
  const auth=require(base+'auth'),options={project,nonInteractive:true};
  auth.setActiveAccount(options,auth.getGlobalDefaultAccount());await require(base+'requireAuth').requireAuth(options);
  const Client=require(base+'apiv2').Client;
  const logging=new Client({urlPrefix:'https://logging.googleapis.com',auth:true}),firestore=new Client({urlPrefix:'https://firestore.googleapis.com',auth:true});
  const entries=await Promise.allSettled([
    logging.get(`/v2/projects/${project}/locations/global/buckets`),
    logging.get(`/v2/projects/${project}/sinks`),
    firestore.get(`/v1/projects/${project}/databases/(default)`),
    firestore.get(`/v1/projects/${project}/databases/(default)/backupSchedules`),
  ]);
  const value=i=>entries[i].status==='fulfilled'?entries[i].value.body:null;
  const report={checkedAt:new Date().toISOString(),project,
    logBuckets:(value(0)?.buckets??[]).map(b=>({name:b.name.split('/').at(-1),retentionDays:b.retentionDays,locked:b.locked??false})),
    logSinks:(value(1)?.sinks??[]).map(s=>({name:s.name,destination:s.destination,disabled:s.disabled??false})),
    firestore:{region:value(2)?.locationId,pointInTimeRecovery:value(2)?.pointInTimeRecoveryEnablement,backupSchedules:(value(3)?.backupSchedules??[]).map(s=>({retention:s.retention}))},
    readFailures:entries.map((e,i)=>e.status==='rejected'?i:null).filter(i=>i!==null)};
  fs.mkdirSync(path.join(root,'output'),{recursive:true});fs.writeFileSync(path.join(root,'output/store-backend-audit.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error('Infrastructure audit failed:',error.message);process.exitCode=1;});
