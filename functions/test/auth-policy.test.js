import test from 'node:test';
import assert from 'node:assert/strict';
import {accountProblem} from '../src/auth-policy.js';

test('unverified e-mail accounts are refused; providers and verified e-mail pass',()=>{
  assert.equal(accountProblem({firebase:{sign_in_provider:'password'},email_verified:false}).code,'permission-denied');
  assert.equal(accountProblem({firebase:{sign_in_provider:'password'}}).code,'permission-denied');
  assert.equal(accountProblem({firebase:{sign_in_provider:'password'},email_verified:true}),null);
  assert.equal(accountProblem({firebase:{sign_in_provider:'google.com'},email_verified:true}),null);
  assert.equal(accountProblem({firebase:{sign_in_provider:'apple.com'}}),null);
  assert.equal(accountProblem({firebase:{sign_in_provider:'anonymous'}}).code,'unauthenticated');
  assert.equal(accountProblem(undefined).code,'unauthenticated');
});
