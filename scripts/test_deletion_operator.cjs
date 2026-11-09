const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
test('operator deletion refuses incomplete or unsafe commands before contacting any service',()=>{
  const cases=[
    {args:[],message:'--uid'},
    {args:['--uid','../user'],message:'--uid'},
    {args:['--uid','example-user','--execute'],message:'--verified-request'},
    {args:['--uid','example-user','--project','unrelated-project'],message:'Beklenmeyen proje'},
    {args:['--uid','example-user'],env:{FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9099'},message:'--project demo-iqum'},
  ];
  for(const item of cases){const result=spawnSync(process.execPath,['scripts/request_account_deletion.cjs',...item.args],{cwd:root,encoding:'utf8',env:{...process.env,FIREBASE_AUTH_EMULATOR_HOST:'',FIRESTORE_EMULATOR_HOST:'',...item.env}});assert.equal(result.status,1);assert.ok(result.stderr.includes(item.message),result.stderr);}
});
