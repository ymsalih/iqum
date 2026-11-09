const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.join(__dirname,'..');
const out=(p)=>{const full=path.join(root,p);fs.mkdirSync(path.dirname(full),{recursive:true});return full;};
function tone(name,notes,duration){
  const rate=22050,count=Math.floor(rate*duration),data=Buffer.alloc(count*2);
  for(let i=0;i<count;i++){const t=i/rate,envelope=Math.exp(-t*12)*(Math.min(1,t*90));let signal=0;for(const [frequency,gain] of notes)signal+=Math.sin(2*Math.PI*frequency*t)*gain;data.writeInt16LE(Math.round(Math.max(-1,Math.min(1,signal*envelope))*.32*32767),i*2);}
  const header=Buffer.alloc(44);header.write('RIFF');header.writeUInt32LE(36+data.length,4);header.write('WAVEfmt ',8);header.writeUInt32LE(16,16);header.writeUInt16LE(1,20);header.writeUInt16LE(1,22);header.writeUInt32LE(rate,24);header.writeUInt32LE(rate*2,28);header.writeUInt16LE(2,32);header.writeUInt16LE(16,34);header.write('data',36);header.writeUInt32LE(data.length,40);fs.writeFileSync(out('assets/sounds/'+name+'.wav'),Buffer.concat([header,data]));
}
(async()=>{
  const source=path.join(root,'design/assets');
  for(const filename of fs.readdirSync(source).filter(n=>n.endsWith('.svg')&&!n.startsWith('iqum-'))){await sharp(path.join(source,filename)).resize(256,256).png().toFile(out('assets/art/'+filename.replace('.svg','.png')));}
  await sharp(path.join(source,'iqum-mark.svg')).resize(256,256).png().toFile(out('assets/brand/mark.png'));
  await sharp(path.join(source,'iqum-mark-light.svg')).resize(256,256).png().toFile(out('assets/brand/mark-light.png'));
  fs.copyFileSync(path.join(source,'iqum-app-icon-1024.png'),out('assets/brand/app-icon.png'));
  for(const [density,size] of Object.entries({mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192}))await sharp(path.join(source,'iqum-app-icon-1024.png')).resize(size,size).png().toFile(out(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`));
  const icons=path.join(root,'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  for(const icon of JSON.parse(fs.readFileSync(path.join(icons,'Contents.json'))).images){if(icon.filename){const size=Math.round(parseFloat(icon.size)*parseFloat(icon.scale));await sharp(path.join(source,'iqum-app-icon-1024.png')).resize(size,size).removeAlpha().png().toFile(path.join(icons,icon.filename));}}
  tone('flip',[[280,.8],[700,.15]],.12);tone('success',[[660,.5],[880,.4],[1320,.15]],.45);tone('error',[[140,.7],[190,.25]],.3);
  console.log('Prepared 12 animal artworks, brand assets, native launcher icons and three short sound cues.');
})().catch(e=>{console.error(e);process.exitCode=1;});
