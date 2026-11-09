// Private operator tool for an already VERIFIED outside-app request.
// Default is read-only. No account lookup by guessed email and no secret output.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{createRequire}=require('node:module');
const root=path.resolve(__dirname,'..'),req=createRequire(path.join(root,'functions/package.json'));
const arg=name=>{const i=process.argv.indexOf(name);return i<0?null:process.argv[i+1];};
(async()=>{
  const uid=arg('--uid'),project=arg('--project')||'iqum-4734b',execute=process.argv.includes('--execute');
  if(!uid||uid.length>128||uid.includes('/'))throw Error('Geçerli --uid gerekli. Varsayılan işlem salt okunur.');
  if(!['iqum-4734b','demo-iqum'].includes(project))throw Error('Beklenmeyen proje.');
  if((process.env.FIREBASE_AUTH_EMULATOR_HOST||process.env.FIRESTORE_EMULATOR_HOST)&&project!=='demo-iqum')throw Error('Emülatör için açıkça --project demo-iqum kullan.');
  if(execute&&!process.argv.includes('--verified-request'))throw Error('Silme için sahipliği doğrulanmış talep ve --verified-request gerekli.');
  const {initializeApp,applicationDefault,deleteApp}=req('firebase-admin/app'),{getAuth}=req('firebase-admin/auth'),{getFirestore}=req('firebase-admin/firestore');
  const app=initializeApp({projectId:project,...(project==='demo-iqum'?{}:{credential:applicationDefault()})});
  try{
    const auth=getAuth(app),db=getFirestore(app);const user=await auth.getUser(uid);
    if(!execute){console.log(JSON.stringify({mode:'dry-run',accountFound:true,providers:user.providerData.map(p=>p.providerId),note:'Hiçbir veri değiştirilmedi. Sahiplik doğrulaması operatörün sorumluluğundadır.'}));return;}
    const secret=crypto.randomBytes(16).toString('hex'),ref=db.collection('accountDeletions').doc(uid);
    const created=await db.runTransaction(async tx=>{
      if((await tx.get(ref)).exists)return false;
      tx.create(ref,{state:'pending',receiptHash:crypto.createHash('sha256').update(secret).digest('hex'),requestedAt:Date.now(),expiresAt:null,source:'verified-support-request'});return true;
    });
    if(!created){console.log('Bu hesap için silme işlemi zaten mevcut; işaret değiştirilmedi. Yönetici durumunu kontrol et.');return;}
    const directory=path.join(root,'output/private-deletion-receipts');fs.mkdirSync(directory,{recursive:true});
    const output=path.join(directory,crypto.randomUUID()+'.json');fs.writeFileSync(output,JSON.stringify({project,uid,requestId:secret,createdAt:new Date().toISOString()},null,2),{flag:'wx',mode:0o600});
    console.log('Doğrulanmış talep kuyruğa alındı. Özel durum makbuzu output/private-deletion-receipts içinde saklandı; tamamlanma ayrıca kontrol edilmeli.');
  }finally{await deleteApp(app);}
})().catch(error=>{console.error('İşlem tamamlanamadı:',error.message);process.exitCode=1;});
