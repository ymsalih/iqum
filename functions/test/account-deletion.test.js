import test from 'node:test';
import assert from 'node:assert/strict';
import {requireRecentAuthentication,receiptHash,anonymousMatch,createAccountDeletion,RECEIPT_LIFETIME} from '../src/account-deletion.js';
test('deletion requires recent server-verified authentication, not a client clock',()=>{
  const now=900000;
  for(const authTime of [undefined,NaN,now-300001,now+30001])assert.throws(()=>requireRecentAuthentication(authTime,now),/yeniden doğrula/);
  requireRecentAuthentication(now-300000,now);requireRecentAuthentication(now,now);
});
test('receipt is a hashed high entropy secret and rejects malformed paths',()=>{
  const receipt='ab'.repeat(16);assert.equal(receiptHash(receipt).length,64);assert.notEqual(receiptHash(receipt),receipt);
  for(const value of ['short','../'+'a'.repeat(40),null,'a'.repeat(129)])assert.throws(()=>receiptHash(value));
});
test('retained opponent result has no deleted user ID or name and cannot reuse its room',()=>{
  const m={members:['private-user-id','opponent'],players:[{uid:'private-user-id',name:'Private Name',ready:true},{uid:'opponent',name:'B'}],code:'ABC234',scores:[3,5],winner:1};
  const result=anonymousMatch(m,'private-user-id');
  assert.equal(JSON.stringify(result).includes('private-user-id'),false);assert.equal(JSON.stringify(result).includes('Private Name'),false);
  assert.equal(result.code,null);assert.deepEqual(result.scores,[3,5]);assert.equal(result.winner,1);
  assert.equal(result.members[0],result.players[0].uid);assert.equal(result.players[0].deleted,true);
  assert.equal(m.players[0].name,'Private Name');
});
test('receipt cleanup never removes an unfinished deletion or an unexpired token guard',async()=>{
  let deleted=false,data={state:'processing',expiresAt:0};const ref={get:async()=>({exists:true,data:()=>data}),delete:async()=>{deleted=true;}};
  const service=createAccountDeletion({db:{collection:()=>({doc:()=>ref})},clock:()=>RECEIPT_LIFETIME});
  await service.run({uid:'test',cleanup:true});assert.equal(deleted,false);
  data={state:'complete',expiresAt:RECEIPT_LIFETIME+1};await service.run({uid:'test',cleanup:true});assert.equal(deleted,false);
  data.expiresAt=RECEIPT_LIFETIME;await service.run({uid:'test',cleanup:true});assert.equal(deleted,true);
});
