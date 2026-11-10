import {randomInt} from 'node:crypto';
export const ANIMALS=['kus','tavsan','balik','kelebek','kaplumbaga','kedi','tilki','fil','at','baykus','salyangoz','denizati'];
export class GameError extends Error {constructor(code,message){super(message);this.code=code;}}
const fail=(code,message)=>{throw new GameError(code,message);};
export function shuffle(items,rng=randomInt){const a=[...items];for(let i=a.length-1;i>0;i--){const j=rng(i+1);[a[i],a[j]]=[a[j],a[i]];}return a;}
export function createMatch({id,uid,name,gameType,mode,code=null,now,first=randomInt(2)}){
  if(!['matching','sequence'].includes(gameType))fail('invalid-argument','Bu oyun düello olarak oynanmıyor.');
  const match={id,gameType,mode,code,members:[uid],players:[{uid,name,ready:false}],status:'waiting',phase:'waiting',createdAt:now,expiresAt:now+(mode==='private'?600000:30000),scores:[0,0],rewards:[0,0],revision:0,turn:first,lastEvent:'waiting',matched:[],opened:[],revealed:{}};
  const secret={board:shuffle([...ANIMALS.slice(0,8),...ANIMALS.slice(0,8)]),patterns:Object.fromEntries([6,9,12].map((n,i)=>[String(i),shuffle(ANIMALS).slice(0,n)])),lastSeen:{[uid]:now},elapsed:[0,0],awarded:false};
  return {match,secret};
}
export function join(match,secret,uid,name,now){
  if(match.members.includes(uid))return;
  if(match.status!=='waiting'||now>=match.expiresAt)fail('not-found','Oda bulunamadı veya süresi doldu.');
  if(match.members.length>=2)fail('failed-precondition','Bu oda dolu.');
  match.members.push(uid);match.players.push({uid,name,ready:false});secret.lastSeen[uid]=now;
  if(match.mode==='random')match.expiresAt=now+60000;
}
export function ready(match,secret,uid,now){
  const i=match.members.indexOf(uid);if(i<0)fail('permission-denied','Bu maçta oyuncu değilsin.');
  if(match.status!=='waiting')return;
  if(now>=match.expiresAt)fail('not-found','Odanın süresi doldu.');
  match.players[i].ready=true;secret.lastSeen[uid]=now;
  if(match.members.length===2&&match.players.every(p=>p.ready)){
    match.status='active';match.phase='countdown';match.startAt=now+3000;match.lastEvent='starting';
    for(const member of match.members)secret.lastSeen[member]=now;
  }
}
function finish(m,winner,reason='complete'){m.status='finished';m.phase='finished';m.winner=winner;m.reason=reason;m.rewards=winner===null?[50,50]:winner===0?[100,0]:[0,100];delete m.pattern;}
function cancel(m,reason){m.status='cancelled';m.phase='cancelled';m.reason=reason;m.rewards=[0,0];delete m.pattern;}
function beginSequence(m,s,now){m.phase='preview';m.pattern=s.patterns[m.round];m.phaseDeadline=now+[6000,8000,10000][m.round];m.roundCorrect=[0,0];m.roundDone=[false,false];m.lastEvent='preview';}
function endRound(m,s,now){
  if(m.round===2){const score=m.scores[0]-m.scores[1],time=s.elapsed[0]-s.elapsed[1];finish(m,score===0?(time===0?null:time<0?0:1):score>0?0:1);}
  else{m.phase='intermission';m.phaseDeadline=now+2000;delete m.pattern;m.lastEvent='round-over';}
}
export function advance(m,s,now){
  if(m.status==='finished'||m.status==='cancelled')return false;
  if(m.status==='waiting'){if(now>=m.expiresAt){cancel(m,'expired');return true;}return false;}
  const missing=m.members.map(uid=>now-(s.lastSeen[uid]??m.startAt)>=15000);
  if(missing.every(Boolean)){cancel(m,'both-disconnected');return true;}
  if(missing.some(Boolean)){finish(m,missing[0]?1:0,'disconnect');return true;}
  if(m.phase==='countdown'&&now>=m.startAt){
    if(m.gameType==='matching'){m.phase='playing';m.turnDeadline=now+15000;m.lastEvent='start';}
    else{m.round=0;beginSequence(m,s,now);}
    return true;
  }
  if(m.gameType==='matching'){
    if(m.phase==='feedback'&&now>=m.feedbackUntil){
      for(const index of m.opened)if(!m.matched.includes(index))delete m.revealed[index];
      m.opened=[];
      if(m.matched.length===16){finish(m,m.scores[0]===m.scores[1]?null:m.scores[0]>m.scores[1]?0:1);return true;}
      m.turn=m.nextTurn;m.phase='playing';m.turnDeadline=now+15000;return true;
    }
    if(m.phase==='playing'&&now>=m.turnDeadline){for(const index of m.opened)delete m.revealed[index];m.opened=[];m.turn=1-m.turn;m.turnDeadline=now+15000;m.lastEvent='timeout';return true;}
  }else{
    if(m.phase==='preview'&&now>=m.phaseDeadline){m.phase='answer';delete m.pattern;m.answerStartedAt=now;m.phaseDeadline=now+[30000,45000,60000][m.round];m.lastEvent='answer';return true;}
    if(m.phase==='answer'&&now>=m.phaseDeadline){for(let i=0;i<2;i++)if(!m.roundDone[i]){s.elapsed[i]+=m.phaseDeadline-m.answerStartedAt;m.roundDone[i]=true;}endRound(m,s,now);return true;}
    if(m.phase==='intermission'&&now>=m.phaseDeadline){m.round++;beginSequence(m,s,now);return true;}
  }
  return false;
}
export function move(m,s,uid,action,now){
  advance(m,s,now);
  const player=m.members.indexOf(uid);
  if(player<0)fail('permission-denied','Bu maçta oyuncu değilsin.');
  if(m.status!=='active')fail('failed-precondition','Karşılaşma şu an hamle kabul etmiyor.');
  if(m.gameType==='matching'){
    if(m.phase!=='playing')fail('failed-precondition','Kartlar kapanana kadar bekle.');
    if(m.turn!==player)fail('failed-precondition','Sıra rakibinde.');
    const index=action.index;
    if(!Number.isInteger(index)||index<0||index>=16)fail('invalid-argument','Geçersiz kart.');
    if(m.matched.includes(index)||m.opened.includes(index))fail('failed-precondition','Bu kart zaten açık.');
    m.opened.push(index);m.revealed[index]=s.board[index];m.lastEvent='opened';
    if(m.opened.length===2){
      const [a,b]=m.opened,found=s.board[a]===s.board[b];
      if(found){m.matched.push(a,b);m.scores[player]++;}
      m.phase='feedback';m.nextTurn=found?player:1-player;m.feedbackUntil=now+(found?600:900);m.lastEvent=found?'matched':'mismatch';
    }
  }else{
    if(m.phase!=='answer'||m.roundDone[player])fail('failed-precondition','Bu turdaki denemen sona erdi.');
    if(!ANIMALS.includes(action.animal))fail('invalid-argument','Geçersiz hayvan.');
    if(s.patterns[m.round][m.roundCorrect[player]]===action.animal){m.scores[player]++;m.roundCorrect[player]++;if(m.roundCorrect[player]===s.patterns[m.round].length)m.roundDone[player]=true;}
    else m.roundDone[player]=true;
    if(m.roundDone[player])s.elapsed[player]+=Math.min(now,m.phaseDeadline)-m.answerStartedAt;
    if(m.roundDone.every(Boolean))endRound(m,s,now);
    m.lastEvent='answer';
  }
  s.lastSeen[uid]=now;
}
export function leave(m,uid){const index=m.members.indexOf(uid);if(index<0)fail('permission-denied','Bu maçta oyuncu değilsin.');if(m.status==='waiting')cancel(m,'left');else if(m.status==='active')finish(m,1-index,'left');}
export function nextEvent(m,s){
  if(m.status==='waiting')return m.expiresAt;
  if(m.status!=='active')return null;
  const phase=m.phase==='countdown'?m.startAt:m.gameType==='matching'?(m.phase==='feedback'?m.feedbackUntil:m.turnDeadline):m.phaseDeadline;
  return Math.min(phase,...m.members.map(uid=>(s.lastSeen[uid]??m.startAt)+15000));
}
export function heartbeat(m,s,uid,now){advance(m,s,now);if(m.members.includes(uid)&&(m.status==='active'||m.status==='waiting'))s.lastSeen[uid]=now;}

const number=(v,fallback=0)=>Number.isFinite(v)?Math.floor(v):fallback;
const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
export function lifeAt(raw,now){
  let count=clamp(number(raw?.count,4),0,4);
  const observed=clamp(number(raw?.observedAt,now),0,now);
  let next=raw?.nextAt==null?observed+1800000:Math.min(number(raw.nextAt,now+1800000),now+1800000);
  if(count<4&&now>=next){const n=1+Math.floor((now-next)/1800000);count=Math.min(4,count+n);next+=n*1800000;}
  return {count,nextAt:count===4?null:next,observedAt:now};
}
export const SOLO_GAMES=['path','sequence','matching'];
const STAT_KEYS=['played','cleared','failed','timeMs','perfect'];
// Best stars per level: 30 digits 0-3. Merges keep the higher digit.
export function cleanStars(value){const raw=typeof value==='string'?value:'';return Array.from({length:30},(_,i)=>{const d=raw.charCodeAt(i)-48;return d>=0&&d<=3?d:0;}).join('');}
export function mergeStars(a,b){const x=cleanStars(a),y=cleanStars(b);return Array.from({length:30},(_,i)=>Math.max(+x[i],+y[i])).join('');}
// Lifetime counters only grow; two devices merge by the larger value.
function mergeStats(a,b){const out={};for(const key of STAT_KEYS)out[key]=Math.max(clamp(number(a?.[key]),0,1e13),clamp(number(b?.[key]),0,1e13));return out;}
export function defaultProfile(now){return {level:1,completedLevels:0,sequenceLevel:1,matchingLevel:1,stars:Object.fromEntries(SOLO_GAMES.map(g=>[g,cleanStars('')])),stats:{},points:0,sequenceBest:0,matchingBestMs:null,matchingBestAttempts:null,life:lifeAt({},now),played:0,won:0,drawn:0};}
export function mergeProfile(existing,incoming,now){
  const profile={...defaultProfile(now),...existing};
  // Offline imports may lower lives but their timestamps cannot grant recovery.
  // Once recovery has started, later mistakes/imports never restart its timer.
  const a=lifeAt(profile.life,now),b=clamp(number(incoming?.life?.count,4),0,4),count=Math.min(a.count,b);
  profile.life={count,nextAt:count===4?null:(a.nextAt??now+1800000),observedAt:now};
  profile.level=Math.max(profile.level,clamp(number(incoming?.level,1),1,30));
  profile.completedLevels=Math.max(profile.completedLevels??0,clamp(number(incoming?.completedLevels),0,30));
  profile.sequenceBest=Math.max(profile.sequenceBest,clamp(number(incoming?.sequenceBest),0,27));
  for(const field of ['sequenceLevel','matchingLevel'])profile[field]=Math.max(clamp(number(profile[field],1),1,30),clamp(number(incoming?.[field],1),1,30));
  profile.stars=Object.fromEntries(SOLO_GAMES.map(g=>[g,mergeStars(profile.stars?.[g],incoming?.stars?.[g])]));
  const stats={};for(const g of SOLO_GAMES){if(profile.stats?.[g]||incoming?.stats?.[g])stats[g]=mergeStats(profile.stats?.[g],incoming?.stats?.[g]);}
  profile.stats=stats;
  for(const field of ['matchingBestMs','matchingBestAttempts']){const value=incoming?.[field];if(Number.isFinite(value)&&value>= (field==='matchingBestAttempts'?8:0))profile[field]=profile[field]==null?Math.floor(value):Math.min(profile[field],Math.floor(value));}
  return profile;
}
