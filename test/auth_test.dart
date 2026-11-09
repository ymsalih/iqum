import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iqum/data/backend.dart';

class _User extends Fake implements User {
  List<String> providers = ['google.com'];
  final events = <String>[];
  FirebaseAuthException? reauthError;
  @override
  List<UserInfo> get providerData => providers.map(_Provider.new).toList();
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    events.add('google-reauth');
    if (reauthError != null) throw reauthError!;
    return _Credential();
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    events.add('apple-reauth');
    if (reauthError != null) throw reauthError!;
    return _AppleCredential();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    events.add('refresh:$forceRefresh');
    return 'refreshed-token';
  }

  @override
  String get uid => 'google-user';
  @override
  String get displayName => 'Test Oyuncu';
}

class _Credential extends Fake implements UserCredential {}

class _Provider extends Fake implements UserInfo {
  _Provider(this.providerId);
  @override
  final String providerId;
}

class _AppleInfo extends Fake implements AdditionalUserInfo {
  @override
  String? get authorizationCode => 'one-time-authorization-code';
}

class _AppleCredential extends _Credential {
  @override
  AdditionalUserInfo? get additionalUserInfo => _AppleInfo();
}

class _Auth extends Fake implements FirebaseAuth {
  User? signed;
  int requests = 0;
  int providerRequests = 0;
  AuthCredential? credential;
  FirebaseAuthException? appleError;
  String? revokedCode;
  @override
  Future<void> revokeTokenWithAuthorizationCode(String code) async {
    revokedCode = code;
    (signed as _User).events.add('apple-revoke');
  }

  @override
  User? get currentUser => signed;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    requests++;
    this.credential = credential;
    signed = _User();
    return _Credential();
  }

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) async {
    providerRequests++;
    if (appleError != null) throw appleError!;
    signed = _User();
    return _Credential();
  }

  @override
  Future<void> signOut() async {
    signed = null;
  }
}

class _Tokens extends Fake implements GoogleSignInAuthentication {
  _Tokens(this.idToken);
  @override
  final String? idToken;
  @override
  String get accessToken => 'test-access-token';
}

class _GoogleUser extends Fake implements GoogleSignInAccount {
  _GoogleUser(this.token);
  final String? token;
  @override
  Future<GoogleSignInAuthentication> get authentication async => _Tokens(token);
}

class _Google extends Fake implements GoogleSignIn {
  GoogleSignInAccount? selected = _GoogleUser('test-id-token');
  PlatformException? error;
  bool failLogout = false;
  int logouts = 0;
  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (error != null) throw error!;
    return selected;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    logouts++;
    if (failLogout) throw StateError('provider unavailable');
    return null;
  }
}

class _Store extends Fake implements FirebaseFirestore {}

class _Functions extends Fake implements FirebaseFunctions {}

void main() {
  late _Auth auth;
  late _Google google;
  late FirebaseBackend backend;
  setUp(() {
    auth = _Auth();
    google = _Google();
    backend = FirebaseBackend(
      auth,
      _Store(),
      _Functions(),
      googleSignIn: google,
      platform: TargetPlatform.iOS,
    );
  });
  test(
    'Google deletion reauthenticates the same user without signing into a different account',
    () async {
      final current = _User();
      auth.signed = current;
      expect(await backend.reauthenticateForDeletion(), true);
      expect(auth.requests, 0);
      expect(identical(auth.currentUser, current), true);
      expect(current.events, ['google-reauth', 'refresh:true']);
      current.reauthError = FirebaseAuthException(code: 'user-mismatch');
      await expectLater(
        backend.reauthenticateForDeletion(),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(auth.requests, 0);
    },
  );
  test(
    'iOS Apple deletion revokes Apple authorization before forcing a fresh Firebase token',
    () async {
      final current = _User()..providers = ['apple.com'];
      auth.signed = current;
      expect(await backend.reauthenticateForDeletion(), true);
      expect(current.events, ['apple-reauth', 'apple-revoke', 'refresh:true']);
      expect(auth.revokedCode, 'one-time-authorization-code');
      expect(auth.providerRequests, 0);
    },
  );
  test(
    'cancelled deletion authentication never refreshes a token or signs in',
    () async {
      final current = _User();
      auth.signed = current;
      google.selected = null;
      expect(await backend.reauthenticateForDeletion(), false);
      expect(current.events, isEmpty);
      expect(auth.requests, 0);
    },
  );
  test(
    'Android rejects Apple before requesting provider authentication',
    () async {
      final android = FirebaseBackend(
        auth,
        _Store(),
        _Functions(),
        googleSignIn: google,
        platform: TargetPlatform.android,
      );
      await expectLater(android.signIn(true), throwsStateError);
      expect(auth.providerRequests, 0);
      expect(android.account, isNull);
    },
  );
  test(
    'Google token becomes a Firebase credential and exposes the Firebase UID',
    () async {
      expect(await backend.signIn(false), isTrue);
      expect(auth.requests, 1);
      final credential = auth.credential! as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, 'test-id-token');
      expect(backend.account?.uid, 'google-user');
      expect(backend.account?.name, 'Test');
    },
  );
  test(
    'Account picker cancellation does not call Firebase or create an account',
    () async {
      google.selected = null;
      expect(await backend.signIn(false), isFalse);
      expect(auth.requests, 0);
      expect(backend.account, isNull);
    },
  );
  test('Native cancellation is handled as cancellation', () async {
    google.error = PlatformException(code: 'sign_in_canceled');
    expect(await backend.signIn(false), isFalse);
    expect(auth.requests, 0);
  });
  test(
    'Missing ID token never submits an invalid Firebase credential',
    () async {
      google.selected = _GoogleUser(null);
      await expectLater(backend.signIn(false), throwsStateError);
      expect(auth.requests, 0);
    },
  );
  test('Sign-out clears Firebase and Google account selection', () async {
    await backend.signIn(false);
    await backend.signOut();
    expect(backend.account, isNull);
    expect(google.logouts, 1);
  });
  test('Google logout failure cannot retain a Firebase account', () async {
    await backend.signIn(false);
    google.failLogout = true;
    await backend.signOut();
    expect(backend.account, isNull);
  });
  test(
    'Apple cancellation preserves the unsigned state and errors are readable',
    () async {
      auth.appleError = FirebaseAuthException(code: 'web-context-canceled');
      expect(await backend.signIn(true), isFalse);
      expect(backend.account, isNull);
      expect(
        friendlyError(PlatformException(code: 'sign_in_canceled')),
        isEmpty,
      );
      expect(
        friendlyError(FirebaseAuthException(code: 'network-request-failed')),
        contains('İnternetini'),
      );
    },
  );
}
