import {createHash,randomUUID,timingSafeEqual} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {GameError,leave} from './engine.js';

export const RECEIPT_LIFETIME=24*60*60*1000;
export function requireRecentAuthentication(authTime,now){
  if(!Number.isFinite(authTime)||authTime>now+30000||now-authTime>5*60*1000){
    throw new GameError('failed-precondition','Hesabını silmek için kimliğini yeniden doğrula.');
  }
}
export function receiptHash(value){
  if(typeof value!=='string'||!/^[a-zA-Z0-9_-]{32,128}$/.test(value))throw new GameError('invalid-argument','Silme işlem kimliği geçersiz.');
  return createHash('sha256').update(value).digest('hex');
}
export function anonymousMatch(match,uid){
  const m=structuredClone(match);
  m.members=m.members.map(value=>value===uid?'deleted:'+randomUUID():value);
  m.players=m.players.map((player,index)=>player.uid===uid?{uid:m.members[index],name:'Silinmiş oyuncu',ready:false,deleted:true}:player);
  m.code=null;
  return m;
}

export function createAccountDeletion({db,auth,transaction,accounts,stage,enqueueCleanup,clock=Date.now}){
  const marker=uid=>db.collection('accountDeletions').doc(uid);
  async function request(actor,data){
    const hash=receiptHash(data.requestId);
    return transaction(async tx=>{
      const existing=await tx.get(marker(actor.uid));
      if(existing.exists){
        if(existing.data().receiptHash!==hash)throw new GameError('already-exists','Bu hesap için silme işlemi zaten başlatıldı.');
        return {state:existing.data().state};
      }
      requireRecentAuthentication(actor.authTime,clock());
      tx.create(marker(actor.uid),{state:'pending',receiptHash:hash,requestedAt:clock(),expiresAt:null});
      return {state:'pending'};
    });
  }
  async function status(uid,requestId){
    if(typeof uid!=='string'||!uid||uid.length>128||uid.includes('/'))throw new GameError('invalid-argument','Silme işlem kimliği geçersiz.');
    const hash=receiptHash(requestId),snapshot=await marker(uid).get();
    if(!snapshot.exists)return {state:'unknown'};
    const stored=snapshot.data();
    if(typeof stored.receiptHash!=='string'||stored.receiptHash.length!==hash.length||!timingSafeEqual(Buffer.from(hash),Buffer.from(stored.receiptHash)))return {state:'unknown'};
    return {state:stored.state,requestedAt:stored.requestedAt,...(stored.completedAt?{completedAt:stored.completedAt}:{})};
  }
  async function unlinkMatch(uid,matchRef){
    await transaction(async tx=>{
      const [ms,ss]=await Promise.all([tx.get(matchRef),tx.get(db.collection('matchSecrets').doc(matchRef.id))]);
      if(!ms.exists||!ms.data().members?.includes(uid))return;
      const m=ms.data(),s=ss.data();
      let context;
      if(s&&['waiting','active'].includes(m.status)){
        leave(m,uid);context=await accounts(tx,m);
      }
      if(context)stage(tx,m,s,context,clock());
      tx.set(marker(uid).collection('matches').doc(matchRef.id),{pending:true});
      const anonymized=anonymousMatch(m,uid);
      if(anonymized.players.every(p=>p.deleted))tx.delete(matchRef);
      else tx.set(matchRef,anonymized);
    });
    // The final public state is retained for the other participant, without this
    // player's name/uid. Hidden boards, actions, room codes and outbox jobs go.
    await db.recursiveDelete(db.collection('matchSecrets').doc(matchRef.id));
    for(const collection of ['rooms','matchJobs']){
      while(true){
        const rows=await db.collection(collection).where('matchId','==',matchRef.id).limit(100).get();
        if(rows.empty)break;
        const batch=db.batch();rows.docs.forEach(doc=>batch.delete(doc.ref));await batch.commit();
      }
    }
    for(const game of ['matching','sequence']){
      const queue=db.collection('queues').doc(game);
      await db.runTransaction(async tx=>{if((await tx.get(queue)).exists)tx.update(queue,{matches:FieldValue.arrayRemove(matchRef.id)});});
    }
    await marker(uid).collection('matches').doc(matchRef.id).delete();
  }
  async function run({uid,cleanup=false}){
    if(typeof uid!=='string'||!uid||uid.includes('/'))throw new Error('Invalid account deletion job.');
    const ref=marker(uid),snapshot=await ref.get();
    if(!snapshot.exists)return;
    const data=snapshot.data();
    if(cleanup){
      if(data.state==='complete'&&data.expiresAt<=clock())await ref.delete();
      return;
    }
    if(data.state==='complete'){
      if(!data.cleanupScheduled){await enqueueCleanup(uid,data.expiresAt);await ref.update({cleanupScheduled:true});}
      return;
    }
    await ref.update({state:'processing'});
    while(true){
      const pending=await ref.collection('matches').limit(50).get();
      if(pending.empty)break;
      for(const item of pending.docs)await unlinkMatch(uid,db.collection('matches').doc(item.id));
    }
    // Every page removes the uid from the query. Retries are safe after a crash.
    while(true){
      const matches=await db.collection('matches').where('members','array-contains',uid).limit(50).get();
      if(matches.empty)break;
      for(const match of matches.docs)await unlinkMatch(uid,match.ref);
    }
    await db.recursiveDelete(db.collection('users').doc(uid));
    await db.collection('activePlayers').doc(uid).delete();
    try{await auth.deleteUser(uid);}catch(error){if(error.code!=='auth/user-not-found')throw error;}
    const completedAt=clock(),expiresAt=completedAt+RECEIPT_LIFETIME;
    await ref.update({state:'complete',completedAt,expiresAt});
    await enqueueCleanup(uid,expiresAt);
    await ref.update({cleanupScheduled:true});
  }
  return {request,status,run};
}
