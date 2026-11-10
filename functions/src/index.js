import {randomInt,randomUUID,createHash} from 'node:crypto';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getFunctions} from 'firebase-admin/functions';
import {getAuth} from 'firebase-admin/auth';
import {onCall,HttpsError} from 'firebase-functions/v2/https';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {onTaskDispatched} from 'firebase-functions/v2/tasks';
import {createMatch,join,ready,advance,move,leave,heartbeat as touch,nextEvent,GameError,defaultProfile,mergeProfile,lifeAt} from './engine.js';
import {appCheckPolicy,assertAppIdentity} from './app-check.js';
import {createAccountDeletion} from './account-deletion.js';

initializeApp();
const db=getFirestore();
const REGION='europe-west1';
const options={region:REGION,maxInstances:20};
const appCheck=appCheckPolicy();
const ref=(collection,id)=>db.collection(collection).doc(id);
async function transaction(update){
  for(let attempt=0;attempt<3;attempt++){
    try{return await db.runTransaction(update);}
    catch(error){
      const transient=error.code===10||(error.code===3&&/transaction is invalid or closed/i.test(error.message));
      if(!transient||attempt===2)throw error;
      await new Promise(resolve=>setTimeout(resolve,100*(attempt+1)+randomInt(100)));
    }
  }
}
function user(request){
  if(!request.auth||request.auth.token.firebase?.sign_in_provider==='anonymous')throw new HttpsError('unauthenticated','Devam etmek için hesabına giriş yap.');
  return {uid:request.auth.uid,name:String(request.auth.token.name??'Oyuncu').trim().slice(0,24)||'Oyuncu',authTime:Number(request.auth.token.auth_time)*1000};
}
async function actorTransaction(uid,update){
  return transaction(async tx=>{
    if((await tx.get(ref('accountDeletions',uid))).exists)throw new GameError('failed-precondition','Hesabın siliniyor. Bu hesaba yeni kayıt eklenemez.');
    return update(tx);
  });
}
function id(value){if(typeof value!=='string'||!/^[a-zA-Z0-9_-]{1,120}$/.test(value))throw new HttpsError('invalid-argument','Geçersiz işlem kimliği.');return value;}
function callable(handler){return onCall(options,async request=>{
  try{const actor=user(request),result=await handler(actor,request.data??{});if(result.error)throw new GameError(result.error.code,result.error.message);return {...result,serverNow:Date.now()};}
  catch(error){if(error instanceof HttpsError)throw error;if(error instanceof GameError)throw new HttpsError(error.code,error.message,{userMessage:error.message});console.error('IQUM operation failed',error.message);throw new HttpsError('internal','İşlem tamamlanamadı. Tekrar deneyebilirsin.');}
});}
async function accounts(tx,m){
  const profiles=[],locks=[],deletions=[];
  for(const uid of m.members)profiles.push(await tx.get(ref('users',uid)));
  for(const uid of m.members)locks.push(await tx.get(ref('activePlayers',uid)));
  for(const uid of m.members)deletions.push(await tx.get(ref('accountDeletions',uid)));
  return {profiles,locks,deletions};
}
// State, point settlement and the next durable outbox job commit together.
function stage(tx,m,s,context,now){
  const terminal=m.status==='finished'||m.status==='cancelled';
  if(terminal&&!s.awarded){
    m.finishedAt=now;s.awarded=true;
    m.members.forEach((uid,i)=>{
      if(context.deletions?.[i]?.exists){if(context.locks[i].data()?.matchId===m.id)tx.delete(ref('activePlayers',uid));return;}
      const profile={...defaultProfile(now),...(context.profiles[i].data()??{})};
      profile.life=lifeAt(profile.life,now);
      if(m.status==='finished'){
        profile.points+=(m.rewards[i]??0);profile.played++;
        if(m.rewards[i]===100)profile.won++;else if(m.rewards[i]===50)profile.drawn++;
      }
      tx.set(ref('users',uid),profile);
      if(context.locks[i].data()?.matchId===m.id)tx.delete(ref('activePlayers',uid));
    });
  }
  m.revision=(m.revision??0)+1;
  m.nextAt=nextEvent(m,s);
  tx.set(ref('matches',m.id),m);tx.set(ref('matchSecrets',m.id),s);
  if(m.nextAt!=null)tx.create(ref('matchJobs',`${m.id}_${m.revision}`),{matchId:m.id,revision:m.revision,runAt:m.nextAt});
}

const getProfile=callable(async ({uid})=>{
  const profile=await actorTransaction(uid,async tx=>{const snapshot=await tx.get(ref('users',uid));const data={...defaultProfile(Date.now()),...snapshot.data()};data.life=lifeAt(data.life,Date.now());tx.set(ref('users',uid),data);return data;});return {profile};
});

const importProgress=callable(async ({uid},data)=>{
  const importId=id(data.importId),records=data.records??[];
  if(!Array.isArray(records)||records.length>100||!data.progress||typeof data.progress!=='object')throw new GameError('invalid-argument','Kayıt paketi geçersiz.');
  const clean=records.map(record=>{
    const recordId=id(record.id);
    if(!['matching','sequence','path'].includes(record.game)||!record.data||typeof record.data!=='object')throw new GameError('invalid-argument','Oyun kaydı geçersiz.');
    const details=record.data;
    const whole=(value,min,max,fallback=min)=>Math.max(min,Math.min(max,Math.floor(Number(value)||fallback)));
    const level=whole(details.level,1,30),stars=whole(details.stars,1,3);
    const normalized=record.game==='path'?{level,stars}:record.game==='sequence'?{level,stars,correct:whole(details.correct,0,27,0),elapsedMs:whole(details.elapsedMs,0,864e5,0)}:{level,stars,pairs:whole(details.pairs,3,12,8),attempts:whole(details.attempts,3,999,3),elapsedMs:whole(details.elapsedMs,0,864e5,0)};
    return {id:recordId,game:record.game,finishedAt:Math.min(Date.now(),Math.max(0,Math.floor(Number(record.finishedAt)||0))),data:normalized};
  });
  if(new Set(clean.map(r=>r.id)).size!==clean.length)throw new GameError('invalid-argument','Kayıt paketi aynı oyunu yineliyor.');
  const result=await actorTransaction(uid,async tx=>{
    const profileRef=ref('users',uid),importRef=profileRef.collection('imports').doc(importId);
    const [existing,imported]=await Promise.all([tx.get(profileRef),tx.get(importRef)]);
    if(imported.exists)return existing.data()??defaultProfile(Date.now());
    const existingRuns=await Promise.all(clean.map(record=>tx.get(profileRef.collection('runs').doc(record.id))));
    const profile=mergeProfile(existing.data(),data.progress,Date.now());
    clean.forEach((record,i)=>{if(!existingRuns[i].exists)tx.create(profileRef.collection('runs').doc(record.id),record);});
    tx.set(profileRef,profile);tx.create(importRef,{appliedAt:Date.now(),recordCount:clean.length});return profile;
  });
  return {profile:result};
});

async function openMatch(actor,data,mode){
  const gameType=data.gameType;
  if(!['matching','sequence'].includes(gameType))throw new GameError('invalid-argument','Bu oyun düello olarak oynanmıyor.');
  const matchId=randomUUID().replaceAll('-','');
  const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  for(let attempt=0;attempt<5;attempt++){
    const code=Array.from({length:6},()=>alphabet[randomInt(alphabet.length)]).join('');
    const result=await actorTransaction(actor.uid,async tx=>{
      const ownLock=await tx.get(ref('activePlayers',actor.uid));
      if(ownLock.exists){
        const current=await tx.get(ref('matches',ownLock.data().matchId));
        if(current.exists&&['waiting','active'].includes(current.data().status)&&!(current.data().status==='waiting'&&current.data().expiresAt<=Date.now()))return {matchId:current.id};
      }
      const queueRef=ref('queues',gameType);
      let queue=[],candidates=[];
      if(mode==='random'){
        const qs=await tx.get(queueRef);queue=qs.data()?.matches??[];
        candidates=await Promise.all(queue.map(value=>tx.get(ref('matches',value))));
      }
      const valid=candidates.filter(snapshot=>snapshot.exists&&snapshot.data().status==='waiting'&&snapshot.data().expiresAt>Date.now()&&snapshot.data().members.length===1&&!snapshot.data().members.includes(actor.uid));
      if(mode==='random'&&valid.length){
        const candidate=valid[0],m={...candidate.data(),id:candidate.id},secretSnap=await tx.get(ref('matchSecrets',candidate.id)),s=secretSnap.data();
        join(m,s,actor.uid,actor.name,Date.now());
        const context={profiles:[],locks:[]};
        tx.set(ref('activePlayers',actor.uid),{matchId:m.id});
        tx.set(queueRef,{matches:valid.slice(1).map(snapshot=>snapshot.id)});
        stage(tx,m,s,context,Date.now());return {matchId:m.id};
      }
      const roomRef=ref('rooms',code);
      if(mode==='private'&&(await tx.get(roomRef)).exists)return {collision:true};
      if(valid.length>=100)throw new GameError('resource-exhausted','Şu an çok sayıda oyuncu bekliyor. Birazdan tekrar dene.');
      const {match:m,secret:s}=createMatch({id:matchId,...actor,gameType,mode,code:mode==='private'?code:null,now:Date.now()});
      const context={profiles:[],locks:[]};
      tx.set(ref('activePlayers',actor.uid),{matchId});
      if(mode==='private')tx.create(roomRef,{matchId,expiresAt:m.expiresAt});
      else tx.set(queueRef,{matches:[...valid.map(snapshot=>snapshot.id),matchId]});
      stage(tx,m,s,context,Date.now());return {matchId};
    });
    if(!result.collision)return result;
  }
  throw new GameError('unavailable','Oda oluşturulamadı. Tekrar dene.');
}
const createRoom=callable((actor,data)=>openMatch(actor,data,'private'));
const findMatch=callable((actor,data)=>openMatch(actor,data,'random'));
const joinRoom=callable(async (actor,data)=>{
  const code=String(data.code??'').toUpperCase();
  if(!/^[A-Z2-9]{6}$/.test(code))throw new GameError('not-found','Oda bulunamadı veya süresi doldu.');
  return actorTransaction(actor.uid,async tx=>{
    const room=await tx.get(ref('rooms',code));
    if(!room.exists||room.data().expiresAt<=Date.now())throw new GameError('not-found','Oda bulunamadı veya süresi doldu.');
    const matchId=room.data().matchId;
    const [ms,ss,lock]=await Promise.all([tx.get(ref('matches',matchId)),tx.get(ref('matchSecrets',matchId)),tx.get(ref('activePlayers',actor.uid))]);
    if(!ms.exists||!ss.exists)throw new GameError('not-found','Oda bulunamadı.');
    if(lock.exists&&lock.data().matchId!==matchId){const active=await tx.get(ref('matches',lock.data().matchId));if(active.exists&&['waiting','active'].includes(active.data().status)&&!(active.data().status==='waiting'&&active.data().expiresAt<=Date.now()))throw new GameError('failed-precondition','Önce devam eden karşılaşmandan ayrıl.');}
    const m=ms.data(),s=ss.data();join(m,s,actor.uid,actor.name,Date.now());
    const context={profiles:[],locks:[]};
    tx.set(ref('activePlayers',actor.uid),{matchId});stage(tx,m,s,context,Date.now());return {matchId};
  });
});

async function updateMatch(actor,data,operation){
  let matchId=data.matchId;
  if(!matchId){const active=await ref('activePlayers',actor.uid).get();if(!active.exists)throw new GameError('not-found','Devam eden karşılaşma bulunamadı.');matchId=active.data().matchId;}
  id(matchId);
  return actorTransaction(actor.uid,async tx=>{
    const ms=await tx.get(ref('matches',matchId));
    const ss=await tx.get(ref('matchSecrets',matchId));
    if(!ms.exists)throw new GameError('not-found','Karşılaşma bulunamadı.');
    const m=ms.data(),s=ss.data(),now=Date.now();
    if(!m.members.includes(actor.uid))throw new GameError('permission-denied','Bu maçta oyuncu değilsin.');
    // Deleting an opponent removes the hidden board/action history while its
    // final public result remains available to the surviving participant.
    if(!ss.exists){if(['finished','cancelled'].includes(m.status))return {match:m};throw new GameError('not-found','Karşılaşma bulunamadı.');}
    let context={profiles:[],locks:[]};
    let actionRef,previousAction,hash;
    if(operation==='move'){
      actionRef=ref('matchSecrets',matchId).collection('actions').doc(id(data.actionId));
      previousAction=await tx.get(actionRef);hash=createHash('sha256').update(JSON.stringify(data.move??{})).digest('hex');
      if(previousAction.exists&&previousAction.data().hash!==hash)throw new GameError('invalid-argument','İşlem kimliği başka bir hamlede kullanılmış.');
    }
    const before=JSON.stringify(m);advance(m,s,now);
    let error=null,actionAccepted=false;
    try{
      if(operation==='ready')ready(m,s,actor.uid,now);
      else if(operation==='leave')leave(m,actor.uid);
      else if(operation==='move'&&!previousAction.exists){move(m,s,actor.uid,data.move??{},now);actionAccepted=true;}
      else if(operation==='resume'||operation==='heartbeat')touch(m,s,actor.uid,now);
    }catch(e){if(e instanceof GameError)error={code:e.code,message:e.message};else throw e;}
    if(['finished','cancelled'].includes(m.status)&&!s.awarded)context=await accounts(tx,m);
    if(actionAccepted)tx.create(actionRef,{hash,at:now});
    if(JSON.stringify(m)!==before||(['finished','cancelled'].includes(m.status)&&!s.awarded))stage(tx,m,s,context,now);
    else if(operation==='resume'||operation==='heartbeat')tx.set(ref('matchSecrets',matchId),s);
    return {match:m,...(error?{error}:{})};
  });
}
const setReady=callable((actor,data)=>updateMatch(actor,data,'ready'));
const submitMove=callable((actor,data)=>updateMatch(actor,data,'move'));
const resumeMatch=callable((actor,data)=>updateMatch(actor,data,'resume'));
const heartbeat=callable(async (actor,data)=>{
  const matchId=id(data.matchId);
  const [ms,ss,deletion]=await db.getAll(ref('matches',matchId),ref('matchSecrets',matchId),ref('accountDeletions',actor.uid));
  if(deletion.exists)throw new GameError('failed-precondition','Hesabın siliniyor.');
  if(!ms.exists)throw new GameError('not-found','Karşılaşma bulunamadı.');
  const m=ms.data(),s=ss.data(),now=Date.now();
  if(!m.members.includes(actor.uid))throw new GameError('permission-denied','Bu maçta oyuncu değilsin.');
  if(!ss.exists){if(['finished','cancelled'].includes(m.status))return {match:m};throw new GameError('not-found','Karşılaşma bulunamadı.');}
  if(m.status==='active'&&(now-(s.lastSeen[actor.uid]??0)>=15000||nextEvent(m,s)<=now))return updateMatch(actor,data,'heartbeat');
  if(m.status==='active'||m.status==='waiting')await ref('matchSecrets',matchId).update({[`lastSeen.${actor.uid}`]:now});
  return {match:m};
});
const leaveMatch=callable((actor,data)=>updateMatch(actor,data,'leave'));

async function runDueJob(data){
  const matchId=id(data.matchId);
  await transaction(async tx=>{
    const ms=await tx.get(ref('matches',matchId));
    const ss=await tx.get(ref('matchSecrets',matchId));
    if(!ms.exists||!ss.exists)return;
    const m=ms.data(),s=ss.data();
    if(m.revision!==data.revision||!['waiting','active'].includes(m.status))return;
    const now=Date.now();
    advance(m,s,now);
    const context=['finished','cancelled'].includes(m.status)&&!s.awarded?await accounts(tx,m):{profiles:[],locks:[]};
    stage(tx,m,s,context,now);
  });
}
export const advanceMatchTask=onTaskDispatched({region:REGION,retryConfig:{maxAttempts:5,minBackoffSeconds:1},rateLimits:{maxConcurrentDispatches:50}},async request=>runDueJob(request.data));
export const enqueueMatchJob=onDocumentCreated({document:'matchJobs/{jobId}',region:REGION,retry:true},async event=>{
  const job=event.data?.data();if(!job)return;
  const queue=getFunctions().taskQueue(`locations/${REGION}/functions/advanceMatchTask`);
  await queue.enqueue(job,{scheduleTime:new Date(Math.max(Date.now(),job.runAt)),dispatchDeadlineSeconds:60});
});

// One warm RPC entry point avoids separate cold starts during a timed duel.
const deletionService=createAccountDeletion({db,auth:getAuth(),transaction,accounts,stage,enqueueCleanup:async(uid,expiresAt)=>{
  await getFunctions().taskQueue(`locations/${REGION}/functions/eraseAccountTask`).enqueue({uid,cleanup:true},{scheduleTime:new Date(expiresAt),dispatchDeadlineSeconds:300});
}});
const requestAccountDeletion=callable((actor,data)=>deletionService.request(actor,data));
export const eraseAccountTask=onTaskDispatched({region:REGION,memory:'512MiB',timeoutSeconds:540,maxInstances:5,retryConfig:{maxAttempts:30,minBackoffSeconds:30,maxBackoffSeconds:3600},rateLimits:{maxConcurrentDispatches:5}},async request=>deletionService.run(request.data));
export const enqueueAccountDeletion=onDocumentCreated({document:'accountDeletions/{uid}',region:REGION,retry:true},async event=>{
  if(!event.data?.exists)return;
  await getFunctions().taskQueue(`locations/${REGION}/functions/eraseAccountTask`).enqueue({uid:event.params.uid},{dispatchDeadlineSeconds:540});
});
const CURRENT_LEGAL_VERSION='2026-11-09';
const acceptLegalTerms=callable(async(actor,data)=>{
  if(data.version!==CURRENT_LEGAL_VERSION)throw new GameError('failed-precondition','Güncel kullanım koşullarını açıp yeniden kabul et.');
  await actorTransaction(actor.uid,async tx=>{tx.set(ref('users',actor.uid),{legal:{termsVersion:CURRENT_LEGAL_VERSION,acceptedAt:Date.now()}},{merge:true});});
  return {accepted:true};
});
const handlers=Object.freeze({getProfile,importProgress,createRoom,findMatch,joinRoom,setReady,submitMove,resumeMatch,heartbeat,leaveMatch,requestAccountDeletion,acceptLegalTerms});
export const api=onCall({...options,enforceAppCheck:appCheck.enforced},async request=>{
  // request.app is populated only after the SDK verifies X-Firebase-AppCheck.
  // A client body field or dart-define cannot disable server enforcement.
  try{assertAppIdentity(request.app,appCheck);}
  catch(error){if(error instanceof GameError)throw new HttpsError(error.code,error.message);throw error;}
  const action=request.data?.action;
  // Public, read-only clock bootstrap also supports guests. No client time input.
  if(action==='getServerTime')return {serverNow:Date.now()};
  if(action==='getDeletionStatus'){
    try{return {...await deletionService.status(request.data?.payload?.uid,request.data?.payload?.requestId),serverNow:Date.now()};}
    catch(error){if(error instanceof GameError)throw new HttpsError(error.code,error.message);throw error;}
  }
  if(typeof action!=='string'||!Object.hasOwn(handlers,action))throw new HttpsError('invalid-argument','Geçersiz işlem.');
  return handlers[action].run({...request,data:request.data?.payload??{}});
});
