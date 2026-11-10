const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),sharp=require('sharp'),{pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'..'),out=path.join(root,'store_assets');
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const source=path.join(root,'design/assets/iqum-app-icon.svg'),folder=path.join(root,'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const records=[];
  for(const icon of JSON.parse(fs.readFileSync(path.join(folder,'Contents.json'))).images){
    if(!icon.filename)continue;const size=Math.round(parseFloat(icon.size)*parseFloat(icon.scale));
    const file=path.join(folder,icon.filename);await sharp(source).resize(size,size).removeAlpha().png().toFile(file);
    const meta=await sharp(file).metadata();assert.equal(meta.hasAlpha,false);assert.equal(meta.width,size);assert.equal(meta.height,size);records.push({file:icon.filename,size,alpha:false});
  }
  for(const [filename,size] of [['google-play-icon.png',512],['app-store-icon.png',1024]])await sharp(source).resize(size,size).removeAlpha().png().toFile(path.join(out,filename));
  const {chromium}=require(process.env.IQUM_PLAYWRIGHT||'playwright');
  const executablePath=process.env.IQUM_BROWSER||['C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p=>fs.existsSync(p));
  const browser=await chromium.launch({headless:true,executablePath});
  try{
    const page=await browser.newPage({viewport:{width:1024,height:500},deviceScaleFactor:1});await page.goto(pathToFileURL(path.join(out,'feature-graphic.html')).href);await page.evaluate(()=>document.fonts.ready);
    await sharp(await page.screenshot()).removeAlpha().png().toFile(path.join(out,'google-play-feature-graphic.png'));
  }finally{await browser.close();}
  for(const [file,width,height] of [['google-play-icon.png',512,512],['app-store-icon.png',1024,1024],['google-play-feature-graphic.png',1024,500]]){
    const meta=await sharp(path.join(out,file)).metadata();assert.equal(meta.width,width);assert.equal(meta.height,height);assert.equal(meta.hasAlpha,false);records.push({file,width,height,alpha:false});
  }
  fs.writeFileSync(path.join(root,'output/store-asset-verification.json'),JSON.stringify({checks:records},null,2));console.log(`PASS ${records.length} icon/graphic size and opacity checks`);
})().catch(error=>{console.error(error);process.exitCode=1;});
