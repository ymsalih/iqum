import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth} from 'firebase-admin/auth';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';

process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099';
const admin=initializeApp({projectId:'demo-iqum'},'iqum-integration');
const db=getFirestore(admin);let rules;
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
// Local Functions cold starts share this machine with the IDE. This wait budget
// does not change the game's server-side 15-second turn/presence deadlines.
async function waitFor(read,accept,timeout=30000){const end=Date.now()+timeout;let value;while(Date.now()<end){value=await read();if(accept(value))return value;await delay(150);}throw new Error('Timed out waiting for state: '+JSON.stringify(value));}
async function account(name){const response=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:`${randomUUID()}@iqum.invalid`,password:'local-test-password',displayName:name,returnSecureToken:true})});const result=await response.json();assert.ok(result.idToken,JSON.stringify(result));return {uid:result.localId,token:result.idToken,name};}
// Unsigned test identities are accepted ONLY by the Firebase local emulator.
// Never register these as debug secrets or send them to a live project.
const testAppCheck=process.env.IQUM_TEST_APP_CHECK==='1';
const emulatorAppToken=appId=>[Buffer.from('{"alg":"none"}').toString('base64url'),Buffer.from(JSON.stringify({sub:appId})).toString('base64url'),''].join('.');
async function call(actor,name,data={}){const response=await fetch(`http://127.0.0.1:5001/demo-iqum/europe-west1/api`,{method:'POST',headers:{'content-type':'application/json',...(testAppCheck?{'X-Firebase-AppCheck':emulatorAppToken('demo-android')}:{}),...(actor?{authorization:`Bearer ${actor.token}`}:{})},body:JSON.stringify({data:{action:name,payload:data}})});const body=await response.json();if(body.error){const error=new Error(body.error.message);error.code=body.error.status;throw error;}return body.result;}
const match=id=>db.collection('matches').doc(id).get().then(s=>s.data());
function keepAlive(players,id){let stopped=false;const timer=setInterval(()=>{if(!stopped)Promise.all(players.map(a=>call(a,'heartbeat',{matchId:id}))).catch(()=>{});},3500);return ()=>{stopped=true;clearInterval(timer);};}
async function room(a,b){const {matchId}=await call(a,'createRoom',{gameType:'matching'});const m=await match(matchId);await call(b,'joinRoom',{code:m.code});await call(a,'setReady',{matchId});await call(b,'setReady',{matchId});return matchId;}

before(async()=>{rules=await initializeTestEnvironment({projectId:'demo-iqum',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
after(async()=>{await rules?.cleanup();await deleteApp(admin);});

test('enforced App Check rejects missing, malformed and unrelated app identities',{skip:!testAppCheck},async()=>{
  async function probe(token,payload={}){
    return fetch('http://127.0.0.1:5001/demo-iqum/europe-west1/api',{method:'POST',headers:{'content-type':'application/json',...(token?{'X-Firebase-AppCheck':token}:{})},body:JSON.stringify({data:{action:'getServerTime',payload}})});
  }
  assert.equal((await probe(null,{appId:'demo-android',enforceAppCheck:false})).status,401);
  // The local SDK skips cryptographic verification; the app allowlist must still
  // reject malformed tokens (403), while the real verifier returns 401.
  assert.ok([401,403].includes((await probe('malformed')).status));
  assert.equal((await probe(emulatorAppToken('unrelated-app'))).status,403);
  for(const appId of ['demo-android','demo-ios'])assert.equal((await probe(emulatorAppToken(appId))).status,200);
});

test('guest imports are atomic, repeatable, private and cannot mint duel points',async()=>{
  const a=await account('A');
  const now=Date.now(),runId=randomUUID().replaceAll('-',''),importId=randomUUID();
  const payload={importId,progress:{level:7,completedLevels:6,points:999999,sequenceBest:12,life:{count:2,nextAt:now+1800000,observedAt:now}},records:[{id:runId,game:'path',finishedAt:now,data:{level:6}}]};
  const first=await call(a,'importProgress',payload);assert.equal(first.profile.points,0);assert.equal(first.profile.level,7);assert.equal(first.profile.life.count,2);
  const second=await call(a,'importProgress',{...payload,progress:{...payload.progress,life:{count:0,nextAt:now+1800000,observedAt:now}}});assert.equal(second.profile.life.count,2);
  await call(a,'importProgress',{...payload,importId:randomUUID()});assert.equal((await db.collection('users').doc(a.uid).collection('runs').get()).size,1);
  const owner=rules.authenticatedContext(a.uid).firestore(),stranger=rules.authenticatedContext('stranger').firestore();
  await assertSucceeds(getDoc(doc(owner,'users',a.uid)));
  await assertFails(setDoc(doc(owner,'users',a.uid),{points:1000000}));
  await assertFails(getDoc(doc(stranger,'users',a.uid)));
  await assert.rejects(()=>call(null,'createRoom',{gameType:'matching'}));
});

test('server ignores forged client dates and points; only clock bootstrap is public',async()=>{
  const a=await account('Clock');
  const before=Date.now();
  const clock=await call(null,'getServerTime',{serverNow:9999999999999,now:0});
  assert.ok(clock.serverNow>=before&&clock.serverNow<=Date.now());
  assert.deepEqual(Object.keys(clock),['serverNow']);
  await assert.rejects(()=>call(null,'getProfile'));
  const imported=await call(a,'importProgress',{importId:randomUUID(),progress:{points:999999,life:{count:0,nextAt:-1,observedAt:9999999999999}},records:[]});
  assert.equal(imported.profile.points,0);assert.equal(imported.profile.life.count,0);
  const next=imported.profile.life.nextAt;
  assert.ok(next>=before+1800000&&next<=Date.now()+1800000);
  const again=await call(a,'importProgress',{importId:randomUUID(),progress:{points:999999,life:{count:4,nextAt:-1,observedAt:-999999999}},records:[]});
  assert.equal(again.profile.life.count,0);assert.equal(again.profile.life.nextAt,next);
  const {matchId}=await call(a,'createRoom',{gameType:'matching',now:-999999999,expiresAt:9999999999999});
  const m=await match(matchId);assert.ok(m.createdAt>=before&&m.createdAt<=Date.now());
  assert.equal(m.expiresAt-m.createdAt,600000);
  await call(a,'leaveMatch',{matchId});
});

test('shared matching board, 15-second timeout, access control and one-time settlement',{timeout:180000},async()=>{
  const a=await account('A'),b=await account('B'),c=await account('C');
  const {matchId}=await call(a,'createRoom',{gameType:'matching'});let m=await match(matchId);
  await call(b,'joinRoom',{code:m.code});await assert.rejects(()=>call(c,'joinRoom',{code:m.code}),/dolu/);
  const owner=rules.authenticatedContext(a.uid).firestore(),stranger=rules.authenticatedContext(c.uid).firestore();
  await assertSucceeds(getDoc(doc(owner,'matches',matchId)));
  await assertFails(getDoc(doc(stranger,'matches',matchId)));
  await assertFails(getDoc(doc(owner,'matchSecrets',matchId)));
  await assertFails(setDoc(doc(owner,'matches',matchId),{scores:[8,0]}));
  await call(a,'setReady',{matchId});await call(b,'setReady',{matchId});
  const stop=keepAlive([a,b],matchId);
  try{
    m=await waitFor(()=>match(matchId),m=>m.phase==='playing');
    const players=[a,b],board=(await db.collection('matchSecrets').doc(matchId).get()).data().board;
    let actor=players[m.turn],other=players[1-m.turn];
    await assert.rejects(()=>call(other,'submitMove',{matchId,actionId:randomUUID(),move:{index:0}}),/Sıra rakibinde/);
    const pair=board.findIndex((v,i)=>i!==0&&v===board[0]),firstId=randomUUID();
    const opened=await call(actor,'submitMove',{matchId,actionId:firstId,now:0,turnDeadline:9999999999999,scores:[9999,9999],move:{index:0}}),deadline=opened.match.turnDeadline;
    assert.ok(deadline>Date.now()&&deadline<Date.now()+15001);assert.deepEqual(opened.match.scores,[0,0]);
    await call(actor,'submitMove',{matchId,actionId:firstId,move:{index:0}});
    m=await match(matchId);assert.equal(m.turnDeadline,deadline);assert.deepEqual(m.opened,[0]);
    const secondId=randomUUID();await call(actor,'submitMove',{matchId,actionId:secondId,move:{index:pair}});await call(actor,'submitMove',{matchId,actionId:secondId,move:{index:pair}});
    m=await waitFor(()=>match(matchId),m=>m.phase==='playing');assert.equal(m.scores[m.turn],1);assert.equal(m.matched.length,2);
    const x=board.findIndex((_,i)=>!m.matched.includes(i)),y=board.findIndex((v,i)=>!m.matched.includes(i)&&v!==board[x]);
    await call(actor,'submitMove',{matchId,actionId:randomUUID(),move:{index:x}});await call(actor,'submitMove',{matchId,actionId:randomUUID(),move:{index:y}});
    m=await waitFor(()=>match(matchId),m=>m.phase==='playing'&&m.members[m.turn]===other.uid);assert.equal(Object.keys(m.revealed).length,2);
    actor=other;const previousTurn=m.turn;
    await call(actor,'submitMove',{matchId,actionId:randomUUID(),move:{index:x}});
    m=await waitFor(()=>match(matchId),m=>m.lastEvent==='timeout'&&m.turn!==previousTurn,23000);assert.deepEqual(m.opened,[]);assert.equal(m.scores.reduce((a,b)=>a+b),1);
    for(const animal of new Set(board)){
      m=await match(matchId);const indexes=board.map((v,i)=>v===animal&&!m.matched.includes(i)?i:-1).filter(i=>i>=0);if(!indexes.length)continue;
      actor=players[m.turn];await call(actor,'submitMove',{matchId,actionId:randomUUID(),move:{index:indexes[0]}});await call(actor,'submitMove',{matchId,actionId:randomUUID(),move:{index:indexes[1]}});
      m=await waitFor(()=>match(matchId),m=>m.phase==='playing'||m.status==='finished');
    }
    assert.equal(m.status,'finished');assert.deepEqual(m.rewards.sort((a,b)=>a-b),[0,100]);
    const before=(await call(a,'getProfile')).profile.points;
    await call(a,'resumeMatch',{matchId});await call(a,'heartbeat',{matchId});await call(a,'resumeMatch',{matchId});
    assert.equal((await call(a,'getProfile')).profile.points,before);
    assert.equal((await db.collection('users').doc(a.uid).get()).data().played,1);
  }finally{stop();}
});

test('random matching is transactional and never pairs a player with themselves',async()=>{
  const a=await account('A'),b=await account('B');
  const [first,repeated]=await Promise.all([call(a,'findMatch',{gameType:'sequence'}),call(a,'findMatch',{gameType:'sequence'})]);assert.equal(first.matchId,repeated.matchId);
  const joined=await call(b,'findMatch',{gameType:'sequence'});assert.equal(first.matchId,joined.matchId);assert.equal((await match(first.matchId)).members.length,2);
  await call(a,'leaveMatch',{matchId:first.matchId});assert.equal((await match(first.matchId)).status,'cancelled');
});

test('expired presence cannot be renewed to undo a forfeit',{timeout:60000},async()=>{
  const a=await account('A'),b=await account('B'),matchId=await room(a,b),stop=keepAlive([a,b],matchId);
  try{await waitFor(()=>match(matchId),m=>m.phase==='playing');stop();await db.collection('matchSecrets').doc(matchId).update({[`lastSeen.${b.uid}`]:Date.now()-16000,[`lastSeen.${a.uid}`]:Date.now()});await call(b,'resumeMatch',{matchId});const m=await match(matchId);assert.equal(m.status,'finished');assert.equal(m.winner,0);assert.equal((await call(a,'getProfile')).profile.points,100);}
  finally{stop();}
});

test('legal consent uses a version and a server timestamp without damaging progress',async()=>{
  const a=await account('Legal');const before=Date.now();
  await assert.rejects(()=>call(a,'acceptLegalTerms',{version:'old'}));
  await call(a,'acceptLegalTerms',{version:'2026-11-10',acceptedAt:0});
  const {profile}=await call(a,'getProfile');
  assert.equal(profile.legal.termsVersion,'2026-11-10');assert.ok(profile.legal.acceptedAt>=before);
  assert.equal(profile.points,0);assert.equal(profile.life.count,4);
});

test('account deletion removes Auth, private trees and room secrets; old tokens cannot recreate data',{timeout:90000},async()=>{
  const a=await account('Delete Me'),b=await account('Retained Opponent');
  const requestId=randomUUID().replaceAll('-',''),matchId=await room(a,b),stop=keepAlive([b],matchId);
  try{
    await waitFor(()=>match(matchId),m=>m.phase==='playing');
    await call(a,'importProgress',{importId:randomUUID(),progress:{level:9},records:[{id:'run-private',game:'path',finishedAt:Date.now(),data:{level:8}}]});
    await db.collection('matchSecrets').doc(matchId).collection('actions').doc('private').set({uid:a.uid});
    const [one,two]=await Promise.all([call(a,'requestAccountDeletion',{requestId}),call(a,'requestAccountDeletion',{requestId})]);
    assert.ok(['pending','processing','complete'].includes(one.state));assert.ok(['pending','processing','complete'].includes(two.state));
    await assert.rejects(()=>call(a,'getProfile'));
    await assert.rejects(()=>call(a,'createRoom',{gameType:'matching'}));
    await assert.rejects(()=>call(a,'importProgress',{importId:randomUUID(),progress:{},records:[]}));
    await assert.rejects(()=>call(a,'acceptLegalTerms',{version:'2026-11-10'}));
    const owner=rules.authenticatedContext(a.uid).firestore();
    await assertFails(getDoc(doc(owner,'users',a.uid)));
    await assertFails(getDoc(doc(owner,'matches',matchId)));
    const status=await waitFor(()=>call(null,'getDeletionStatus',{uid:a.uid,requestId}),s=>s.state==='complete',60000);
    assert.ok(status.completedAt>=status.requestedAt);assert.equal(status.uid,undefined);
    assert.equal((await call(null,'getDeletionStatus',{uid:a.uid,requestId:'f'.repeat(32)})).state,'unknown');
    assert.equal((await db.collection('users').doc(a.uid).get()).exists,false);
    assert.equal((await db.collection('users').doc(a.uid).collection('runs').get()).size,0);
    assert.equal((await db.collection('users').doc(a.uid).collection('imports').get()).size,0);
    assert.equal((await db.collection('activePlayers').doc(a.uid).get()).exists,false);
    await assert.rejects(()=>getAuth(admin).getUser(a.uid),e=>e.code==='auth/user-not-found');
    const retained=await match(matchId);assert.equal(retained.status,'finished');
    assert.equal(JSON.stringify(retained).includes(a.uid),false);assert.equal(retained.players[0].name,'Silinmiş oyuncu');
    assert.equal((await db.collection('matchSecrets').doc(matchId).get()).exists,false);
    assert.equal((await db.collection('matchSecrets').doc(matchId).collection('actions').get()).empty,true);
    for(const collection of ['rooms','matchJobs'])assert.equal((await db.collection(collection).where('matchId','==',matchId).get()).empty,true);
    assert.equal((await call(b,'getProfile')).profile.points,100);
    assert.equal((await call(b,'resumeMatch',{matchId})).match.status,'finished');
    assert.equal((await call(a,'requestAccountDeletion',{requestId})).state,'complete');
    await delay(800);assert.equal((await call(b,'getProfile')).profile.points,100);
    await assert.rejects(()=>call(a,'requestAccountDeletion',{requestId:randomUUID().replaceAll('-','')}));
  }finally{stop();}
});

test('deletion retry resumes secret cleanup after public match was already anonymized',{timeout:60000},async()=>{
  const a=await account('Recover Delete'),matchId=randomUUID().replaceAll('-',''),requestId='a'.repeat(32);
  const {receiptHash}=await import('../src/account-deletion.js');
  await db.collection('matches').doc(matchId).set({id:matchId,members:['deleted:earlier','retained'],players:[{uid:'deleted:earlier',name:'Silinmiş oyuncu',deleted:true},{uid:'retained',name:'B'}],status:'finished',code:null});
  await db.collection('matchSecrets').doc(matchId).set({privateUid:a.uid});
  await db.collection('rooms').doc('RECOVR').set({matchId});
  const marker=db.collection('accountDeletions').doc(a.uid),batch=db.batch();
  batch.set(marker,{state:'processing',receiptHash:receiptHash(requestId),requestedAt:Date.now()});
  batch.set(marker.collection('matches').doc(matchId),{pending:true});await batch.commit();
  await waitFor(()=>call(null,'getDeletionStatus',{uid:a.uid,requestId}),s=>s.state==='complete',45000);
  assert.equal((await db.collection('matchSecrets').doc(matchId).get()).exists,false);
  assert.equal((await db.collection('rooms').doc('RECOVR').get()).exists,false);
  assert.equal((await marker.collection('matches').get()).empty,true);
  assert.equal((await match(matchId)).players[1].uid,'retained');
});
