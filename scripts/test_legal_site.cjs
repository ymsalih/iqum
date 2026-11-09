const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),tmp=path.join(root,'output/legal-fixture');fs.mkdirSync(tmp,{recursive:true});
const publisher=JSON.parse(fs.readFileSync(path.join(root,'assets/legal/publisher.json'),'utf8'));
function generate(args=[]){return spawnSync(process.execPath,['scripts/build_legal_site.cjs',...args],{cwd:root,encoding:'utf8'});}
test('release generation refuses incomplete publisher identity and contact',()=>{
  assert.notEqual(generate(['--release']).status,0);
});
test('release pages are static, readable and escape publisher-supplied text',()=>{
  const file=path.join(tmp,'publisher.json'),out=path.join(tmp,'site');
  fs.writeFileSync(file,JSON.stringify({...publisher,legalName:'Test <script>alert(1)</script>',supportEmail:'support@iqum-test.org',contactAddress:'Test address',publicOrigin:'https://iqum-test.org',targetAudience:'13+',status:'published'}));
  const result=generate(['--release','--publisher',file,'--out',out]);assert.equal(result.status,0,result.stderr);
  const privacy=fs.readFileSync(path.join(out,'gizlilik/index.html'),'utf8');assert.ok(privacy.includes('&lt;script&gt;'));assert.ok(!privacy.includes('<script>alert'));
  for(const slug of ['gizlilik','kullanim-kosullari','hesap-silme','oyun-bilgileri']){
    const page=fs.readFileSync(path.join(out,slug,'index.html'),'utf8');assert.ok(page.includes('lang="tr"'));assert.ok(!page.includes('{{'));assert.ok(!page.includes('TASLAK'));assert.ok(!page.includes('noindex'));assert.ok(!page.includes('type="password"'));
  }
  assert.equal(JSON.parse(fs.readFileSync(path.join(out,'publication-status.json'))).draft,false);
});
test('outside-app request prepares a correctly encoded email and never pretends a request was submitted',()=>{
  let listener;const status={textContent:''},window={location:{href:''}},form={dataset:{support:'support@iqum-test.org'},reportValidity:()=>true,addEventListener:(_,fn)=>listener=fn};
  const nodes={'deletion-form':form,'account-email':{value:'private@privaterelay.appleid.com'},'request-note':{value:'Remove all data & records.'},'request-status':status};
  vm.runInNewContext(fs.readFileSync(path.join(root,'legal_site/request.js'),'utf8'),{document:{getElementById:id=>nodes[id]},window});
  listener.call(form,{preventDefault(){}});
  const uri=new URL(window.location.href);assert.equal(uri.protocol,'mailto:');assert.ok(uri.searchParams.get('body').includes('\nGiriş'));
  assert.ok(uri.searchParams.get('body').includes('Remove all data & records.'));assert.ok(status.textContent.includes('henüz talep gönderilmiş sayılmaz'));
  form.reportValidity=()=>false;window.location.href='';listener.call(form,{preventDefault(){}});assert.equal(window.location.href,'');
});
