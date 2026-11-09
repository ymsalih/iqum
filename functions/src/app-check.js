import {GameError} from './engine.js';

export function appCheckPolicy(env=process.env){
  const setting=env.APP_CHECK_ENFORCED??'false';
  if(!['true','false'].includes(setting))throw new Error('APP_CHECK_ENFORCED must be true or false.');
  const enforced=setting==='true';
  const allowedAppIds=(env.APP_CHECK_ALLOWED_APP_IDS??'').split(',').map(s=>s.trim()).filter(Boolean);
  if(enforced&&!allowedAppIds.length)throw new Error('Enforcement requires the IQUM Android/iOS Firebase app IDs.');
  return {enforced,allowedAppIds};
}

export function assertAppIdentity(app,policy){
  if(policy.enforced&&!policy.allowedAppIds.includes(app?.appId)){
    throw new GameError('permission-denied','Uygulama doğrulanamadı. Resmî IQUM uygulamasını güncelle ve tekrar dene.');
  }
}
