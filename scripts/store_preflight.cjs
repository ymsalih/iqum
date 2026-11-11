const fs=require('node:fs');const path=require('node:path');
const root=path.resolve(__dirname,'..');
const checks=[];const add=(id,ok,detail)=>checks.push({id,ok,detail});
// Legal pages are published by the publisher (e.g. Google Sites); the app
// only links to them from lib/data/legal_links.dart.
const links=fs.readFileSync(path.join(root,'lib/data/legal_links.dart'),'utf8');
const flat=links.replace(/\s+/g,' ');
const value=(name)=>(new RegExp('static const '+name+" = '([^']*)'").exec(flat)||[])[1]??'';
const server=fs.readFileSync(path.join(root,'functions/src/index.js'),'utf8');
add('legal_version',server.includes(`CURRENT_LEGAL_VERSION='${value('version')}'`),'Uygulama ve sunucu koşul sürümleri eşleşmeli.');
for(const name of ['privacy','terms','gameInfo','deletion']){let ok=false;try{ok=new URL(value(name)).protocol==='https:';}catch{}add('link_'+name,ok,'Yayınlanmış HTTPS sayfa linki gerekli (lib/data/legal_links.dart).');}
add('support_email',/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value('supportEmail')),'Geçerli destek e-postası gerekli (lib/data/legal_links.dart).');
const gradle=fs.readFileSync(path.join(root,'android/app/build.gradle.kts'),'utf8');
add('release_signing',!gradle.includes('signingConfig = signingConfigs.getByName("debug")'),'Android release imzası debug anahtarı olamaz.');
const keyFile=path.join(root,'android/key.properties');
let signingConfigured=false;
if(fs.existsSync(keyFile)){
  const props=Object.fromEntries(fs.readFileSync(keyFile,'utf8').split(/\r?\n/).filter(l=>l.trim()&&!l.trim().startsWith('#')).map(l=>{const i=l.indexOf('=');return [l.slice(0,i).trim(),l.slice(i+1).trim()];}));
  signingConfigured=['storeFile','storePassword','keyAlias','keyPassword'].every(k=>Boolean(props[k]))&&fs.existsSync(path.resolve(root,'android',props.storeFile??'__missing__'));
}
add('release_key_configured',signingConfigured,'Gerçek upload anahtarı ve özel key.properties gerekli; sırlar rapora yazılmaz.');
for(const file of ['android/app/google-services.json','ios/Runner/GoogleService-Info.plist','ios/Runner/PrivacyInfo.xcprivacy'])add(file,fs.existsSync(path.join(root,file)),'Platform yapılandırması gerekli.');
const report={checkedAt:new Date().toISOString(),scope:'configuration only; published URLs, archive privacy report, store forms and real device tests require final verification',checks,ready:checks.every(c=>c.ok)};
fs.mkdirSync(path.join(root,'output'),{recursive:true});fs.writeFileSync(path.join(root,'output/store-preflight.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
if(!report.ready)process.exitCode=1;
