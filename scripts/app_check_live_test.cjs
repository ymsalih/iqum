// Host-only management helper. Never prints tokens, secrets, or CLI credentials.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const stateFile=path.join(root,'output/app-check-live-state.json');
const definesFile=path.join(root,'output/app-check-live-defines.json');
const base=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/');
(async()=>{
  const settings=JSON.parse(fs.readFileSync(path.join(root,'config/firebase.json'),'utf8').replace(/^\uFEFF/,''));
  if(settings.FIREBASE_PROJECT_ID!=='iqum-4734b')throw Error('Refusing an unexpected Firebase project.');
  const auth=require(base+'auth');
  const options={project:settings.FIREBASE_PROJECT_ID,nonInteractive:true};
  auth.setActiveAccount(options,auth.getGlobalDefaultAccount());
  await require(base+'requireAuth').requireAuth(options);
  const Client=require(base+'apiv2').Client;
  const client=new Client({urlPrefix:'https://firebaseappcheck.googleapis.com',auth:true});
  const app='projects/'+settings.FIREBASE_MESSAGING_SENDER_ID+'/apps/'+settings.FIREBASE_ANDROID_APP_ID;
  const mode=process.argv[2];
  if(mode==='prepare'){
    if(fs.existsSync(stateFile))throw Error('An earlier test identity must be cleaned up first.');
    const secret=crypto.randomUUID();
    const response=await client.post('/v1/'+app+'/debugTokens',{displayName:'IQUM emulator '+new Date().toISOString(),token:secret});
    const name=response.body.name;
    if(typeof name!=='string'||!name.startsWith(app+'/debugTokens/'))throw Error('Unexpected debug identity resource.');
    fs.mkdirSync(path.dirname(stateFile),{recursive:true});
    fs.writeFileSync(stateFile,JSON.stringify({name,startedAt:new Date().toISOString(),app}));
    fs.writeFileSync(definesFile,JSON.stringify({...settings,APP_CHECK_DEBUG:'true',USE_FIREBASE_EMULATORS:'false',IQUM_LIVE_APP_CHECK_TEST:'true',IQUM_TEST_DEBUG_SECRET:secret}));
    console.log(JSON.stringify({temporaryDebugIdentityCreated:true,project:settings.FIREBASE_PROJECT_ID}));
  }else if(mode==='verify'){
    const state=JSON.parse(fs.readFileSync(stateFile,'utf8'));
    const logging=new Client({urlPrefix:'https://logging.googleapis.com',auth:true});
    const response=await logging.post('/v2/entries:list',{resourceNames:['projects/'+settings.FIREBASE_PROJECT_ID],filter:'resource.type="cloud_run_revision" AND resource.labels.service_name="api" AND jsonPayload.verifications.app="VALID" AND timestamp>="'+state.startedAt+'"',orderBy:'timestamp desc',pageSize:10});
    const entries=response.body.entries??[];
    if(!entries.length)throw Error('No verified native App Check request is visible in live logs yet.');
    const result={liveServerAppCheckVerified:true,verifiedRequestCount:entries.length,latestVerifiedAt:entries[0].timestamp};
    fs.writeFileSync(path.join(root,'output/app-check-native-server-result.json'),JSON.stringify(result));
    console.log(JSON.stringify(result));
  }else if(mode==='log-build'||mode==='log-drive'){
    const filename=mode==='log-build'?'app-check-live-build.log':'app-check-live-drive.log';
    let text=fs.readFileSync(path.join(root,'output',filename),'utf8');
    if(fs.existsSync(definesFile)){
      const secret=JSON.parse(fs.readFileSync(definesFile,'utf8')).IQUM_TEST_DEBUG_SECRET;
      if(secret)text=text.replaceAll(secret,'[REDACTED]').replaceAll(Buffer.from('IQUM_TEST_DEBUG_SECRET='+secret).toString('base64'),'[REDACTED]');
    }
    console.log(text.split(/\r?\n/).slice(-25).join('\n'));
  }else if(mode==='cleanup'){
    const secret=fs.existsSync(definesFile)?JSON.parse(fs.readFileSync(definesFile,'utf8')).IQUM_TEST_DEBUG_SECRET:null;
    if(fs.existsSync(stateFile)){
      const state=JSON.parse(fs.readFileSync(stateFile,'utf8'));
      if(state.app!==app||!state.name.startsWith(app+'/debugTokens/'))throw Error('Refusing to delete an unrelated debug identity.');
      await client.delete('/v1/'+state.name);
      fs.unlinkSync(stateFile);
    }
    if(secret){
      for(const filename of ['app-check-live-build.log','app-check-live-drive.log']){
        const logFile=path.join(root,'output',filename);
        if(fs.existsSync(logFile)){
          const text=fs.readFileSync(logFile,'utf8').replaceAll(secret,'[REDACTED]').replaceAll(Buffer.from('IQUM_TEST_DEBUG_SECRET='+secret).toString('base64'),'[REDACTED]');
          fs.writeFileSync(logFile,text);
        }
      }
    }
    if(fs.existsSync(definesFile))fs.unlinkSync(definesFile);
    console.log(JSON.stringify({temporaryDebugIdentityRemoved:true,privateTestDefinesRemoved:true}));
  }else throw Error('Use prepare, verify, or cleanup.');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
