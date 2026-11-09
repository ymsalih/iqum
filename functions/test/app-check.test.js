import test from 'node:test';
import assert from 'node:assert/strict';
import {appCheckPolicy,assertAppIdentity} from '../src/app-check.js';

test('only server configuration controls enforcement, invalid settings fail closed',()=>{
  assert.equal(appCheckPolicy({}).enforced,false);
  assert.doesNotThrow(()=>assertAppIdentity(undefined,appCheckPolicy({})));
  assert.throws(()=>appCheckPolicy({APP_CHECK_ENFORCED:'TRUE'}),/true or false/);
  assert.throws(()=>appCheckPolicy({APP_CHECK_ENFORCED:'true'}),/app IDs/);
});
test('enforced requests require a verified IQUM Android or iOS identity',()=>{
  const policy=appCheckPolicy({APP_CHECK_ENFORCED:'true',APP_CHECK_ALLOWED_APP_IDS:' android-app, ios-app '});
  for(const app of [undefined,{}, {appId:'other-project-app'},{data:{appId:'android-app'}}]){
    assert.throws(()=>assertAppIdentity(app,policy),error=>error.code==='permission-denied');
  }
  assert.doesNotThrow(()=>assertAppIdentity({appId:'android-app'},policy));
  assert.doesNotThrow(()=>assertAppIdentity({appId:'ios-app'},policy));
});
