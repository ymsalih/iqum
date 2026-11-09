const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{pathToFileURL}=require('node:url');
// Use a normal local Playwright install, or the Codex bundled runtime.
const {chromium}=require(process.env.IQUM_PLAYWRIGHT||'playwright');
const root=path.resolve(__dirname,'..'),site=path.join(root,'legal_site'),checks=[];
(async()=>{
  const executablePath=process.env.IQUM_BROWSER||['C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p=>fs.existsSync(p));
  const browser=await chromium.launch({headless:true,executablePath});
  try{
    for(const width of [320,390,820]){
      const page=await browser.newPage({viewport:{width,height:850}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
      for(const slug of ['','gizlilik','kullanim-kosullari','hesap-silme','oyun-bilgileri']){
        await page.goto(pathToFileURL(path.join(site,slug,'index.html')).href);
        assert.equal(await page.locator('h1').count(),1);
        assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,`${slug} overflow ${width}`);
        for(const href of await page.locator('a[href]').evaluateAll(nodes=>nodes.map(n=>n.getAttribute('href')))){
          if(!/^(https:|mailto:)/.test(href)){const p=path.resolve(site,slug,href);assert.ok(fs.existsSync(p),`Broken link ${p}`);}
        }
        if(width===390)await page.screenshot({path:path.join(root,'output',`legal-${slug||'index'}.png`),fullPage:false});
        checks.push({width,page:slug||'index',passed:true});
      }
      assert.deepEqual(errors,[]);await page.close();
    }
  }finally{await browser.close();}
  fs.writeFileSync(path.join(root,'output/legal-visual-verification.json'),JSON.stringify({checks},null,2));console.log(`PASS ${checks.length} web layout/link checks`);
})().catch(error=>{console.error(error);process.exitCode=1;});
