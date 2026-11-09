const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');
const root = __dirname;
const records = [];
const report = {kind:'design-prototype',checks:records,errors:[]};
const screens = path.join(root,'screens');
fs.mkdirSync(screens,{recursive:true});
const executablePath = process.env.IQUM_BROWSER || ['C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p=>fs.existsSync(p));
const check = async (name, fn) => {await fn();records.push({name,status:'passed'});console.log('PASS '+name);};
(async()=>{
  const context=await chromium.launchPersistentContext(path.join(root,'.cache','verification-profile'),{headless:true,executablePath,viewport:{width:900,height:1150}});
  const page=context.pages()[0]||await context.newPage();
  page.on('pageerror',e=>report.errors.push(e.message));
  try {
    await page.clock.install({time:new Date('2026-11-08T12:00:00Z')});
    await page.goto(pathToFileURL(path.join(root,'index.html')).href);
    const choose=async value=>page.selectOption('#iq-screen',value);
    const card=i=>page.locator(`#iq-pair-grid [data-card="${i}"]`);
    const advance=async ms=>page.clock.fastForward(ms);
    await check('Nine screens render without broken images or horizontal overflow',async()=>{
      for(const width of [900,320]){
        await page.setViewportSize({width,height:1150});
        for(const name of ['home','levels','sequence','matching','path','duel','result','account','brand']){
          await choose(name);
          await page.locator('.iq-device').screenshot({path:path.join(screens,`${width===320?'small-':''}${name}.png`),animations:'disabled'});
          const geometry=await page.evaluate(()=>({viewport:innerWidth,scroll:document.documentElement.scrollWidth,device:document.querySelector('.iq-device').clientWidth,inside:document.querySelector('.iq-device').scrollWidth,broken:[...document.querySelectorAll('img')].filter(n=>!n.complete||!n.naturalWidth).length}));
          assert.equal(geometry.broken,0,name+' image');
          assert.ok(geometry.scroll<=geometry.viewport+1,name+' document overflow');
          assert.ok(geometry.inside<=geometry.device+1,name+' device overflow');
        }
      }
      await page.setViewportSize({width:900,height:1150});
    });
    await check('Level road ascends from below and opens at the current unlocked stop',async()=>{
      await choose('levels');
      const layout=await page.evaluate(()=>{
        const road=document.querySelector('.iq-road-scroll').getBoundingClientRect();
        const active=document.querySelector('.iq-level-road .iq-current').getBoundingClientRect();
        const first=document.querySelector('[data-level="1"]').getBoundingClientRect();
        const second=document.querySelector('[data-level="2"]').getBoundingClientRect();
        return {ascends:second.top<first.top,visible:active.top>=road.top&&active.bottom<=road.bottom,locked:document.querySelector('[data-level="30"]').disabled};
      });
      assert.deepEqual(layout,{ascends:true,visible:true,locked:true});
    });
    await check('A pair scores once, stays visible and retains the turn',async()=>{
      await choose('matching');await card(0).click();await advance(5000);
      const remaining=await page.locator('#iq-pair-clock').innerText();assert.ok(remaining==='00:10'||remaining==='00:09',remaining);
      await card(9).click();assert.equal(await page.locator('#iq-pair-score').innerText(),'1:0');
      assert.equal(await page.locator('#iq-pair-grid .iq-matched').count(),2);
      assert.equal(await page.locator('#iq-pair-grid button:not(:disabled)').count(),0);
      await advance(800);assert.equal(await page.locator('#iq-turn-text').innerText(),'Sıra sende');
      assert.equal(await page.locator('#iq-pair-grid .iq-open').count(),2);
      assert.equal(await page.locator('#iq-pair-score').innerText(),'1:0');
    });
    await check('Mismatch closes both cards, switches player and deducts no points',async()=>{
      await card(1).click();await card(2).click();assert.equal(await page.locator('#iq-pair-grid button:not(:disabled)').count(),0);
      await advance(1000);assert.equal(await card(1).getAttribute('class').then(c=>c.includes('iq-open')),false);
      assert.equal(await card(2).getAttribute('class').then(c=>c.includes('iq-open')),false);
      assert.equal(await page.locator('#iq-turn-text').innerText(),'Deniz oynuyor');
      assert.equal(await page.locator('#iq-pair-score').innerText(),'1:0');assert.equal(await page.locator('#iq-pair-grid button:not(:disabled)').count(),0);
      await page.selectOption('#iq-viewer','1');assert.equal(await page.locator('#iq-pair-grid .iq-matched').count(),2);
      assert.equal(await page.locator('#iq-turn-text').innerText(),'Sıra sende');
    });
    await check('The first card does not reset the 15-second deadline; timeout closes it',async()=>{
      await advance(4000);const before=await page.locator('#iq-pair-clock').innerText();await card(3).click();
      const after=await page.locator('#iq-pair-clock').innerText();assert.equal(before,after);
      await advance(12000);assert.equal(await card(3).getAttribute('class').then(c=>c.includes('iq-open')),false);
      assert.equal(await page.locator('#iq-turn-text').innerText(),'Sen oynuyor');assert.equal(await page.locator('#iq-pair-score').innerText(),'1:0');
    });
    await check('All eight pairs end the duel with the correct reward',async()=>{
      await choose('matching');
      for(const [a,b] of [[0,9],[1,12],[2,8],[3,13],[4,14],[5,11],[6,15],[7,10]]){await card(a).click();await card(b).click();await advance(800);}
      assert.equal(await page.locator('#iq-screen').inputValue(),'result');assert.ok((await page.locator('.iq-reward').innerText()).includes('+100'));
      assert.equal(await page.locator('.iq-result-score').innerText(),'8:0');
    });
    await check('Draw and loss sample states use consistent scores and rewards',async()=>{
      await choose('result');await page.selectOption('#iq-state','draw');assert.equal(await page.locator('.iq-result-score').innerText(),'4:4');assert.ok((await page.locator('.iq-reward').innerText()).includes('+50'));
      await page.selectOption('#iq-state','loss');assert.equal(await page.locator('.iq-result-score').innerText(),'3:5');assert.ok((await page.locator('.iq-reward').innerText()).includes('+0'));
    });
    await check('Sequence preview hides and a wrong answer ends the current round',async()=>{
      await choose('sequence');await page.locator('[data-action="start-sequence"]').click();assert.equal(await page.locator('.iq-memory-card.iq-open').count(),6);
      await advance(6200);assert.equal(await page.locator('.iq-memory-card.iq-open').count(),0);
      await page.locator('[data-answer="kus"]').click();assert.equal(await page.locator('.iq-memory-card.iq-matched').count(),1);
      await page.locator('[data-answer="fil"]').click();assert.equal(await page.locator('[data-answer]').count(),0);
      assert.ok((await page.locator('#iq-seq-message').innerText()).includes('Turun burada bitti'));
    });
    await check('Wrong path step consumes one heart and restarts the same level',async()=>{
      await choose('path');await page.locator('[data-action="start-path"]').click();await advance(8000);
      assert.equal(await page.locator('.iq-path-tile:not(:disabled)').count(),3);await page.locator('[data-tile="0:0"]').click();
      assert.equal(await page.locator('.iq-hearts').getAttribute('aria-label'),'3 can');assert.equal(await page.locator('.iq-path-tile:not(:disabled)').count(),0);
      await advance(1000);assert.equal(await page.locator('[data-action="start-path"]').count(),1);assert.equal(await page.locator('.iq-path-head h1').innerText(),'Level 07');
      await page.locator('[data-action="start-path"]').click();await advance(8000);
      for(const [r,c] of [[0,1],[1,0],[2,1],[3,1],[4,0]])await page.locator(`[data-tile="${r}:${c}"]`).click();
      assert.equal(await page.locator('#iq-screen').inputValue(),'result');assert.ok((await page.locator('.iq-display').innerText()).includes('Bir adım daha ileri'));
    });
    await check('Zero hearts block play and a heart refills after 30 minutes',async()=>{
      await choose('path');await page.selectOption('#iq-state','no-hearts');assert.equal(await page.locator('[aria-modal="true"]').count(),1);
      assert.equal(await page.locator('.iq-content').evaluate(e=>e.inert),true);
      await advance(1800200);assert.equal(await page.locator('[aria-modal="true"]').count(),0);assert.equal(await page.locator('.iq-hearts').getAttribute('aria-label'),'1 can');
    });
    await check('Android offers only Google; iOS additionally offers Apple',async()=>{
      await choose('account');await page.selectOption('#iq-state','normal');
      await page.selectOption('#iq-platform','android');
      assert.equal(await page.locator('[data-action="sign-google"]').count(),1);
      assert.equal(await page.locator('[data-action="sign-apple"]').count(),0);
      await page.selectOption('#iq-platform','ios');
      assert.equal(await page.locator('[data-action="sign-google"]').count(),1);
      assert.equal(await page.locator('[data-action="sign-apple"]').count(),1);
      await page.selectOption('#iq-platform','android');
    });
    await check('Room code validation and guest login route are explicit demo flows',async()=>{
      await choose('duel');await page.locator('[data-action="join-room"]').click();assert.ok((await page.locator('#iq-room-error').innerText()).includes('altı'));
      await page.locator('#iq-room-input').fill('abc123');await page.locator('[data-action="join-room"]').click();assert.equal(await page.locator('#iq-screen').inputValue(),'account');
      await page.locator('[data-action="sign-google"]').click();assert.equal(await page.locator('.iq-room-code strong').innerText(),'ABC123');
      assert.ok((await page.locator('#iq-preview-note').innerText()).includes('gerçek Google/Apple bağlantısı henüz kurulmadı'));
    });
    await check('Disconnected and expired room states render as blocking sheets',async()=>{
      await choose('matching');await page.selectOption('#iq-state','disconnected');assert.equal(await page.locator('[aria-modal="true"]').count(),1);
      await choose('duel');await page.selectOption('#iq-state','expired');assert.ok((await page.locator('[role="dialog"]').innerText()).includes('Odanın süresi doldu'));
    });
    await check('Reduced motion removes card transitions',async()=>{
      await page.emulateMedia({reducedMotion:'reduce'});await choose('matching');assert.equal(await page.locator('.iq-card-inner').first().evaluate(e=>getComputedStyle(e).transitionDuration),'0s');await page.emulateMedia({reducedMotion:'no-preference'});
    });
    // Final reference shots show both artwork and stateful materials.
    await choose('path');await page.selectOption('#iq-state','normal');await choose('account');await page.selectOption('#iq-state','normal');
    await choose('home');await page.locator('.iq-device').screenshot({path:path.join(screens,'home.png'),animations:'disabled'});
    await choose('sequence');await page.locator('[data-action="start-sequence"]').click();await page.locator('.iq-device').screenshot({path:path.join(screens,'sequence.png'),animations:'disabled'});
    await choose('matching');await card(0).click();await card(9).click();await advance(800);await card(1).click();await page.locator('.iq-device').screenshot({path:path.join(screens,'matching.png'),animations:'disabled'});
    await choose('path');await page.selectOption('#iq-state','normal');await page.locator('[data-action="start-path"]').click();await advance(8000);await page.locator('[data-tile="0:1"]').click();await page.locator('[data-tile="1:0"]').click();await page.locator('.iq-device').screenshot({path:path.join(screens,'path.png'),animations:'disabled'});
    await page.selectOption('#iq-state','no-hearts');await page.locator('.iq-device').screenshot({path:path.join(screens,'no-hearts.png'),animations:'disabled'});
    assert.deepEqual(report.errors,[]);report.passed=true;console.log('PASS No runtime errors');
  } catch(error){report.passed=false;report.failure=error.stack;throw error;}
  finally {fs.writeFileSync(path.join(root,'verification.json'),JSON.stringify(report,null,2));await context.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
