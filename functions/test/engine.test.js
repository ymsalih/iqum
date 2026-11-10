import test from 'node:test';
import assert from 'node:assert/strict';
import {createMatch,join,ready,advance,move,heartbeat,nextEvent,mergeProfile,lifeAt} from '../src/engine.js';
function duel(type='matching'){const {match:m,secret:s}=createMatch({id:'test',uid:'a',name:'A',gameType:type,mode:'private',now:0,first:0});join(m,s,'b','B',0);ready(m,s,'a',0);ready(m,s,'b',0);advance(m,s,3000);return {m,s};}
test('matching preserves deadline after the first card and rejects the other player',()=>{const {m,s}=duel();assert.throws(()=>move(m,s,'b',{index:0},4000),/Sıra rakibinde/);move(m,s,'a',{index:0},4000);assert.equal(m.turnDeadline,18000);assert.equal(m.opened.length,1);});
test('matching score, open pair and extra turn; feedback blocks input',()=>{const {m,s}=duel();const a=0,b=s.board.findIndex((v,i)=>i>0&&v===s.board[0]);move(m,s,'a',{index:a},4000);move(m,s,'a',{index:b},5000);assert.equal(m.scores[0],1);assert.equal(m.matched.length,2);assert.throws(()=>move(m,s,'a',{index:3},5100),/bekle/);advance(m,s,5600);assert.equal(m.turn,0);assert.equal(m.turnDeadline,20600);assert.equal(Object.keys(m.revealed).length,2);});
test('mismatch closes both cards and deducts no score',()=>{const {m,s}=duel();const b=s.board.findIndex(v=>v!==s.board[0]);move(m,s,'a',{index:0},4000);move(m,s,'a',{index:b},5000);advance(m,s,5900);assert.deepEqual(m.scores,[0,0]);assert.equal(m.turn,1);assert.deepEqual(m.revealed,{});});
test('deadline closes one card and passes turn, provided both peers remain online',()=>{const {m,s}=duel();move(m,s,'a',{index:0},4000);heartbeat(m,s,'a',10000);heartbeat(m,s,'b',10000);advance(m,s,18000);assert.equal(m.turn,1);assert.deepEqual(m.opened,[]);assert.deepEqual(m.scores,[0,0]);});
test('finished shared board rewards a winner only after final feedback',()=>{const {m,s}=duel();let now=3100;for(const animal of new Set(s.board)){const indexes=s.board.map((v,i)=>v===animal?i:-1).filter(i=>i>=0);heartbeat(m,s,'a',now);heartbeat(m,s,'b',now);move(m,s,'a',{index:indexes[0]},now);move(m,s,'a',{index:indexes[1]},now+20);now+=700;advance(m,s,now);}assert.equal(m.status,'finished');assert.deepEqual(m.scores,[8,0]);assert.deepEqual(m.rewards,[100,0]);assert.equal(nextEvent(m,s),null);});
test('late reconnect cannot refresh presence to escape a forfeit',()=>{const {m,s}=duel();heartbeat(m,s,'b',10000);heartbeat(m,s,'a',16000);assert.equal(m.status,'finished');assert.equal(m.winner,1);assert.deepEqual(m.rewards,[0,100]);});
test('both disconnected cancels without awarding points',()=>{const {m,s}=duel();advance(m,s,15000);assert.equal(m.status,'cancelled');assert.deepEqual(m.rewards,[0,0]);});
test('private rooms are two-player, expire, and require both players ready',()=>{const {match:m,secret:s}=createMatch({id:'r',uid:'a',name:'A',gameType:'matching',mode:'private',now:0});ready(m,s,'a',1);assert.equal(m.status,'waiting');join(m,s,'b','B',2);assert.throws(()=>join(m,s,'c','C',3),/dolu/);ready(m,s,'b',4);assert.equal(m.startAt,3004);const other=createMatch({id:'x',uid:'x',name:'X',gameType:'matching',mode:'private',now:0});advance(other.match,other.secret,600000);assert.equal(other.match.status,'cancelled');});
test('sequence uses equal previews, hides the pattern and ends each player on error',()=>{const {m,s}=duel('sequence');assert.equal(m.pattern.length,6);heartbeat(m,s,'a',8000);heartbeat(m,s,'b',8000);advance(m,s,9000);assert.equal(m.pattern,undefined);const correct=s.patterns[0][0];move(m,s,'a',{animal:correct},10000);const wrong=s.patterns[0].find(a=>a!==s.patterns[0][1]);move(m,s,'a',{animal:wrong},10001);assert.equal(m.roundDone[0],true);assert.equal(m.scores[0],1);assert.throws(()=>move(m,s,'a',{animal:correct},10002),/sona erdi/);});
test('three equal perfect sequence rounds finish as a draw',()=>{const {m,s}=duel('sequence');let now=9000;for(let round=0;round<3;round++){heartbeat(m,s,'a',now-1000);heartbeat(m,s,'b',now-1000);advance(m,s,now);for(const animal of s.patterns[round]){move(m,s,'a',{animal},now+100);move(m,s,'b',{animal},now+100);}if(round<2){now+=2200;heartbeat(m,s,'a',now);heartbeat(m,s,'b',now);advance(m,s,now);now+=[6000,8000,10000][round+1];}}assert.equal(m.status,'finished');assert.deepEqual(m.scores,[27,27]);assert.deepEqual(m.rewards,[50,50]);});
test('life renewal is capped, preserves partial interval and imported points are ignored',()=>{assert.equal(lifeAt({count:0,nextAt:100,observedAt:0},100+10*1800000).count,4);const p=mergeProfile({points:200,level:10,life:{count:2,nextAt:1800000,observedAt:0}},{points:999999,level:5,life:{count:3,nextAt:1900000,observedAt:0}},1000);assert.equal(p.points,200);assert.equal(p.level,10);assert.equal(p.life.count,2);assert.equal(p.life.nextAt,1800000);});

test('past or future client dates cannot renew imported hearts or change the server timer',()=>{
  const server={points:200,life:{count:2,nextAt:1801000,observedAt:1000}};
  for(const date of [-999999999,9999999999999]){
    const p=mergeProfile(server,{points:999999,life:{count:1,nextAt:date,observedAt:date}},2000);
    assert.equal(p.life.count,1);assert.equal(p.life.nextAt,1801000);assert.equal(p.life.observedAt,2000);assert.equal(p.points,200);
  }
  const first=mergeProfile(undefined,{life:{count:0,nextAt:-1,observedAt:-999999999}},2000);
  assert.equal(first.life.count,0);assert.equal(first.life.nextAt,1802000);
  const repeated=mergeProfile(first,{life:{count:0,nextAt:9999999999999,observedAt:9999999999999}},3000);
  assert.equal(repeated.life.nextAt,1802000);
  assert.equal(lifeAt(repeated.life,1801999).count,0);assert.equal(lifeAt(repeated.life,1802000).count,1);
});

test('solo levels, stars and statistics merge upward and are validated',()=>{
  const server=mergeProfile({sequenceLevel:4,stars:{sequence:'321'},stats:{sequence:{played:5,cleared:3,failed:2,timeMs:9000,perfect:1}}},{},1000);
  assert.equal(server.sequenceLevel,4);assert.equal(server.matchingLevel,1);
  assert.equal(server.stars.sequence,'321'+'0'.repeat(27));
  const p=mergeProfile(server,{sequenceLevel:99,matchingLevel:3,stars:{sequence:'139x',path:'2'},stats:{sequence:{played:4,cleared:9,failed:-5,timeMs:'x'},matching:{played:2}}},2000);
  assert.equal(p.sequenceLevel,30);assert.equal(p.matchingLevel,3);
  assert.equal(p.stars.sequence.slice(0,4),'3310');assert.equal(p.stars.path[0],'2');assert.equal(p.stars.sequence.length,30);
  assert.deepEqual(p.stats.sequence,{played:5,cleared:9,failed:2,timeMs:9000,perfect:1});
  assert.equal(p.stats.matching.played,2);assert.equal(p.stats.path,undefined);
  const lower=mergeProfile(p,{sequenceLevel:2,stars:{sequence:'000'}},3000);
  assert.equal(lower.sequenceLevel,30);assert.equal(lower.stars.sequence.slice(0,3),'331');
});
