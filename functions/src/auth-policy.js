// Which Firebase Auth tokens may use the game's server functions.
// E-mail/password accounts must have confirmed their address; Google and
// Apple accounts are verified by their provider. Anonymous use is refused.
export const UNVERIFIED_EMAIL = 'E-posta adresini doğruladıktan sonra devam edebilirsin.';
export const SIGN_IN_REQUIRED = 'Devam etmek için hesabına giriş yap.';

/** Returns null when the token may proceed, or the reason it may not. */
export function accountProblem(token) {
  const provider = token?.firebase?.sign_in_provider;
  if (!token || !provider || provider === 'anonymous') return {code: 'unauthenticated', message: SIGN_IN_REQUIRED};
  if (provider === 'password' && token.email_verified !== true) return {code: 'permission-denied', message: UNVERIFIED_EMAIL};
  return null;
}
