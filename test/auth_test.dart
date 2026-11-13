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
  bool verified = true;
  String name = 'Test Oyuncu';
  AuthCredential? reauthCredential;
  @override
  bool get emailVerified => verified;
  @override
  String? get email => 'oyuncu@example.com';
  @override
  Future<void> reload() async => events.add('reload');
  @override
  Future<void> updateDisplayName(String? displayName) async {
    name = displayName ?? '';
    events.add('name:$displayName');
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async =>
      events.add('verify-mail');
  @override
  List<UserInfo> get providerData => providers.map(_Provider.new).toList();
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    reauthCredential = credential;
    events.add(
      credential.providerId == 'password' ? 'password-reauth' : 'google-reauth',
    );
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
  String get displayName => name;
}

class _Credential extends Fake implements UserCredential {}

class _EmailCredential extends Fake implements UserCredential {
  _EmailCredential(this.user);
  @override
  final User user;
}

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

  // E-mail accounts: one test account whose verification state is set.
  _User? emailUser;
  String? language, resetSentTo;
  int emailSignIns = 0;
  @override
  Future<void> setLanguageCode(String? languageCode) async =>
      language = languageCode;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emailUser = _User()
      ..providers = ['password']
      ..verified = false;
    signed = emailUser;
    return _EmailCredential(emailUser!);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emailSignIns++;
    if (password != 'dogru-sifre1') {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    signed = emailUser;
    return _EmailCredential(emailUser!);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async => resetSentTo = email;
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
  group('E-mail accounts', () {
    test(
      'registration names the account, mails a link and signs out',
      () async {
        await backend.registerWithEmail(
          name: ' Ada Lovelace ',
          email: ' ada@example.com ',
          password: 'dogru-sifre1',
        );
        expect(auth.language, 'tr');
        expect(auth.emailUser!.events, ['name:Ada Lovelace', 'verify-mail']);
        expect(auth.currentUser, isNull);
        expect(backend.account, isNull);
      },
    );
    test('an unverified address cannot sign in and stays signed out', () async {
      await backend.registerWithEmail(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'dogru-sifre1',
      );
      await expectLater(
        backend.signInWithEmail('ada@example.com', 'dogru-sifre1'),
        throwsA(isA<EmailNotVerified>()),
      );
      expect(auth.currentUser, isNull);
      expect(backend.account, isNull);
      // Even if Firebase still held the user, the app would not treat an
      // unverified e-mail account as signed in.
      auth.signed = auth.emailUser;
      expect(backend.account, isNull);
    });
    test('a verified address signs in with a fresh token', () async {
      await backend.registerWithEmail(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'dogru-sifre1',
      );
      auth.emailUser!.verified = true;
      expect(
        await backend.signInWithEmail('ada@example.com', 'dogru-sifre1'),
        isTrue,
      );
      expect(backend.account?.name, 'Ada');
      expect(backend.usesPassword, isTrue);
      expect(
        auth.emailUser!.events,
        containsAllInOrder(['reload', 'refresh:true']),
      );
    });
    test('a wrong password reads as a plain message', () async {
      await backend.registerWithEmail(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'dogru-sifre1',
      );
      try {
        await backend.signInWithEmail('ada@example.com', 'yanlis');
        fail('should not sign in');
      } catch (error) {
        expect(friendlyError(error), 'E-posta veya şifre hatalı.');
      }
    });
    test('verification can be re-sent and reset links are requested', () async {
      await backend.registerWithEmail(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        password: 'dogru-sifre1',
      );
      auth.emailUser!.events.clear();
      await backend.resendVerification('ada@example.com', 'dogru-sifre1');
      expect(auth.emailUser!.events, ['verify-mail']);
      expect(auth.currentUser, isNull);
      await backend.sendPasswordReset(' ada@example.com ');
      expect(auth.resetSentTo, 'ada@example.com');
    });
    test('deleting an e-mail account asks for its password', () async {
      final current = _User()..providers = ['password'];
      auth.signed = current;
      expect(await backend.reauthenticateForDeletion(), isFalse);
      expect(current.events, isEmpty);
      expect(
        await backend.reauthenticateForDeletion(password: 'dogru-sifre1'),
        isTrue,
      );
      expect(current.events, ['password-reauth', 'refresh:true']);
      expect(current.reauthCredential?.providerId, 'password');
      expect(google.logouts, 0);
    });
  });
}
