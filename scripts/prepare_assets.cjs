const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.join(__dirname,'..');
const out=(p)=>{const full=path.join(root,p);fs.mkdirSync(path.dirname(full),{recursive:true});return full;};
(async()=>{
  const source=path.join(root,'design/assets');
  for(const filename of fs.readdirSync(source).filter(n=>n.endsWith('.svg')&&!n.startsWith('iqum-'))){await sharp(path.join(source,filename)).resize(256,256).png().toFile(out('assets/art/'+filename.replace('.svg','.png')));}
  console.log('Prepared 12 animal artworks. Sounds: node design/sound/build_sounds.cjs; brand/icons: node design/brand/build_brand.cjs; Rive animals: node design/rive/build_animals.cjs');
})().catch(e=>{console.error(e);process.exitCode=1;});
