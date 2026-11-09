const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root=__dirname;
const screens=path.join(root,'screens');
const labels={home:'Ana sayfa',levels:'Leveller',sequence:'Sıra Hafızası',matching:'Kart Eşleştirme',path:'Hafıza Yolu',duel:'Düello lobisi',result:'Sonuç',account:'Hesap ve ayarlar'};
function header(height,title,subtitle){return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="${height}"><style>text{font-family:Segoe UI,Arial,sans-serif;fill:#292722}</style><text x="55" y="68" font-family="Georgia,serif" font-size="40" letter-spacing="5">IQUM</text><text x="1744" y="61" text-anchor="end" font-size="14" letter-spacing="3">${title}</text><text x="55" y="110" font-size="17" fill="#777168">${subtitle}</text></svg>`);}
async function sheet(names,filename){
  const rows=Math.ceil(names.length/4),height=rows===1?1200:2330;
  const layers=[{input:header(height,rows===1?'İLK TASARIM · 0.1':'EKRAN AİLESİ · 0.1','Fildişi arayüz · koyu fiziksel tahtalar · mat altın detaylar'),left:0,top:0}];
  for(let i=0;i<names.length;i++){
    const name=names[i],x=55+(i%4)*435,y=155+Math.floor(i/4)*1100;
    const input=await sharp(path.join(screens,name+'.png')).resize({width:390,height:935,fit:'inside',withoutEnlargement:true}).toBuffer();
    layers.push({input,left:x,top:y});
    layers.push({input:Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="400" height="40"><text x="195" y="26" text-anchor="middle" font-family="Segoe UI,Arial,sans-serif" font-size="17" fill="#4f4b40">${labels[name]}</text></svg>`),left:x-5,top:y+954});
  }
  await sharp({create:{width:1800,height,channels:3,background:'#ece8df'}}).composite(layers).png().toFile(path.join(screens,filename));
}
(async()=>{
  await sharp(path.join(root,'assets','iqum-app-icon.svg')).resize(1024,1024).png().toFile(path.join(root,'assets','iqum-app-icon-1024.png'));
  await sheet(['home','sequence','matching','path'],'design-overview.png');
  await sheet(['home','levels','sequence','matching','path','duel','result','account'],'all-screens.png');
  console.log('Exported app icon and two design sheets.');
})().catch(error=>{console.error(error);process.exitCode=1;});
