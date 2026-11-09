const fs=require('node:fs');const path=require('node:path');const {createHash}=require('node:crypto');
const root=path.resolve(__dirname,'..');
const checks=[];const add=(id,ok,detail)=>checks.push({id,ok,detail});
const legal=JSON.parse(fs.readFileSync(path.join(root,'assets/legal/tr.json'),'utf8'));
const server=fs.readFileSync(path.join(root,'functions/src/index.js'),'utf8');
add('legal_version',server.includes(`CURRENT_LEGAL_VERSION='${legal.version}'`),'Uygulama/web/sunucu koşul sürümleri eşleşmeli.');
const publisher=JSON.parse(fs.readFileSync(path.join(root,'assets/legal/publisher.json'),'utf8'));
for(const field of ['legalName','supportEmail','contactAddress','publicOrigin','targetAudience'])add('publisher_'+field,Boolean(publisher[field]?.trim()),'Gerçek yayıncı bilgisi gerekli.');
add('legal_published',publisher.status==='published','Taslak metinlerle mağazaya çıkılmaz.');
add('publisher_version',publisher.version===legal.version,'Yayıncı ve metin sürümü aynı olmalı.');
add('support_email_format',/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(publisher.supportEmail??''),'Geçerli destek adresi gerekli.');
let validOrigin=false;try{const u=new URL(publisher.publicOrigin);validOrigin=u.protocol==='https:'&&u.pathname==='/'&&!u.search&&!u.hash&&!/localhost|\.invalid$|\.example$/.test(u.hostname);}catch{}
add('public_https_origin',validOrigin,'Gerçek HTTPS kök alan adı gerekli.');
const gradle=fs.readFileSync(path.join(root,'android/app/build.gradle.kts'),'utf8');
add('release_signing',!gradle.includes('signingConfig = signingConfigs.getByName("debug")'),'Android release imzası debug anahtarı olamaz.');
const keyFile=path.join(root,'android/key.properties');
let signingConfigured=false;
if(fs.existsSync(keyFile)){
  const props=Object.fromEntries(fs.readFileSync(keyFile,'utf8').split(/\r?\n/).filter(l=>l.trim()&&!l.trim().startsWith('#')).map(l=>{const i=l.indexOf('=');return [l.slice(0,i).trim(),l.slice(i+1).trim()];}));
  signingConfigured=['storeFile','storePassword','keyAlias','keyPassword'].every(k=>Boolean(props[k]))&&fs.existsSync(path.resolve(root,'android',props.storeFile??'__missing__'));
}
add('release_key_configured',signingConfigured,'Gerçek upload anahtarı ve özel key.properties gerekli; sırlar rapora yazılmaz.');
const metadataFile=path.join(root,'legal_site/publication-status.json');
add('public_legal_build',fs.existsSync(metadataFile)&&!JSON.parse(fs.readFileSync(metadataFile,'utf8')).draft,'Yayın web sayfaları --release ile üretilmeli.');
add('web_matches_app',fs.existsSync(metadataFile)&&JSON.parse(fs.readFileSync(metadataFile,'utf8')).sourceDigest===createHash('sha256').update(JSON.stringify({publisher,legal})).digest('hex'),'Web sayfaları güncel uygulama metinlerinden üretilmeli.');
for(const file of ['android/app/google-services.json','ios/Runner/GoogleService-Info.plist','ios/Runner/PrivacyInfo.xcprivacy'])add(file,fs.existsSync(path.join(root,file)),'Platform yapılandırması gerekli.');
const report={checkedAt:new Date().toISOString(),scope:'configuration only; published URLs, archive privacy report, store forms and real device tests require final verification',checks,ready:checks.every(c=>c.ok)};
fs.mkdirSync(path.join(root,'output'),{recursive:true});fs.writeFileSync(path.join(root,'output/store-preflight.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
if(!report.ready)process.exitCode=1;
