import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/models.dart';
import '../domain/game_clock.dart';
import 'app_check.dart';
import 'firebase_config.dart';

class Account {
  const Account(this.uid, this.name);
  final String uid, name;
}

abstract class Backend {
  bool get available;
  Account? get account;
  Future<bool> signIn(bool apple);
  Future<void> signOut();
  Future<bool> reauthenticateForDeletion();
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]);
  Stream<Map<String, dynamic>> watchMatch(String id);
  Stream<Map<String, dynamic>> watchProfile();
  Future<void> heartbeat(String matchId);
  int get serverOffset;
  int get now;
  bool get hasServerTime;
}

class OfflineBackend implements Backend {
  final GameClock clock = GameClock();
  @override
  int get now => clock.now;
  @override
  bool get hasServerTime => false;
  @override
  bool get available => false;
  @override
  Account? get account => null;
  @override
  int get serverOffset => 0;
  @override
  Future<bool> signIn(bool apple) async => throw StateError(
    'Çevrimiçi oyunlar şu an kullanılamıyor. Antrenmanlara devam edebilirsin.',
  );
  @override
  Future<void> signOut() async {}
  @override
  Future<bool> reauthenticateForDeletion() async =>
      throw StateError('Hesabını silmek için internet bağlantısı gerekir.');
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async => throw StateError('Bağlantı kurulamadı. Lütfen tekrar dene.');
  @override
  Stream<Map<String, dynamic>> watchMatch(String id) => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> watchProfile() => const Stream.empty();
  @override
  Future<void> heartbeat(String matchId) async {}
}

class FirebaseBackend implements Backend {
  FirebaseBackend(
    this.auth,
    this.firestore,
    this.functions, {
    GoogleSignIn? googleSignIn,
    TargetPlatform? platform,
  }) : _google = googleSignIn,
       _platform = platform ?? defaultTargetPlatform;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final TargetPlatform _platform;
  GoogleSignIn? _google;
  GoogleSignIn get google => _google ??= GoogleSignIn(
    clientId:
        _platform == TargetPlatform.iOS &&
            FirebaseConfig.googleIosClientId.isNotEmpty
        ? FirebaseConfig.googleIosClientId
        : null,
    serverClientId: FirebaseConfig.googleWebClientId.isEmpty
        ? null
        : FirebaseConfig.googleWebClientId,
    scopes: const ['email'],
  );
  final GameClock clock = GameClock();
  static const emulator = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static Future<Backend> initialize() async {
    try {
      const project = FirebaseConfig.projectId;
      if (project.isNotEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: Platform.isIOS && FirebaseConfig.iosApiKey.isNotEmpty
                ? FirebaseConfig.iosApiKey
                : FirebaseConfig.apiKey,
            appId: Platform.isIOS
                ? FirebaseConfig.iosAppId
                : FirebaseConfig.androidAppId,
            messagingSenderId: FirebaseConfig.messagingSenderId,
            projectId: project,
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      if (!emulator) {
        await const AppCheckSetup().activate(FirebaseAppCheck.instance);
      }
      final backend = FirebaseBackend(
        FirebaseAuth.instance,
        FirebaseFirestore.instance,
        FirebaseFunctions.instanceFor(
          region: const String.fromEnvironment(
            'FUNCTIONS_REGION',
            defaultValue: 'europe-west1',
          ),
        ),
      );
      // SQLite owns offline game data. Do not leave a second persistent copy
      // of cloud profiles/matches behind when an account is removed locally.
      backend.firestore.settings = const Settings(persistenceEnabled: false);
      await backend.firestore.clearPersistence();
      if (emulator) {
        const host = String.fromEnvironment(
          'EMULATOR_HOST',
          defaultValue: '10.0.2.2',
        );
        await backend.auth.useAuthEmulator(host, 9099);
        backend.firestore.useFirestoreEmulator(host, 8080);
        backend.functions.useFunctionsEmulator(host, 5001);
      }
      return backend;
    } catch (_) {
      return OfflineBackend();
    }
  }

  @override
  bool get available => true;
  @override
  Account? get account {
    final u = auth.currentUser;
    return u == null
        ? null
        : Account(u.uid, u.displayName?.split(' ').first ?? 'Oyuncu');
  }

  @override
  int get serverOffset => now - DateTime.now().millisecondsSinceEpoch;
  @override
  int get now => clock.now;
  @override
  bool get hasServerTime => clock.synchronized;
  @override
  Future<bool> signIn(bool apple) async {
    if (apple && _platform != TargetPlatform.iOS) {
      throw StateError('Bu cihazda Google ile devam edebilirsin.');
    }
    try {
      if (apple) {
        await auth.signInWithProvider(AppleAuthProvider());
        return true;
      }
      final user = await google.signIn();
      if (user == null) return false;
      final tokens = await user.authentication;
      if (tokens.idToken == null || tokens.idToken!.isEmpty) {
        throw StateError(
          'Google giriş ayarları doğrulanamadı. Lütfen daha sonra tekrar dene.',
        );
      }
      await auth.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: tokens.idToken,
          accessToken: tokens.accessToken,
        ),
      );
      return true;
    } on PlatformException catch (error) {
      if ([
        'sign_in_canceled',
        'sign_in_cancelled',
        'canceled',
        'cancelled',
      ].contains(error.code)) {
        return false;
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      if ([
        'canceled',
        'web-context-canceled',
        'popup-closed-by-user',
      ].contains(error.code)) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await auth.signOut();
    try {
      await google.signOut();
    } catch (_) {
      // A provider cleanup failure must not keep the Firebase account signed in.
    }
  }

  @override
  Future<bool> reauthenticateForDeletion() async {
    final current = auth.currentUser;
    if (current == null) throw StateError('Önce hesabına giriş yap.');
    final providers = current.providerData.map((p) => p.providerId).toSet();
    try {
      if (_platform == TargetPlatform.iOS && providers.contains('apple.com')) {
        final credential = await current.reauthenticateWithProvider(
          AppleAuthProvider(),
        );
        final code = credential.additionalUserInfo?.authorizationCode;
        if (code == null || code.isEmpty) {
          throw StateError(
            'Apple erişimi iptal edilemedi. Yeniden doğrulayıp tekrar dene.',
          );
        }
        await auth.revokeTokenWithAuthorizationCode(code);
      } else {
        if (!providers.contains('google.com')) {
          throw StateError(
            'Hesabının giriş sağlayıcısı bu cihazda doğrulanamıyor. Destek bölümünden silme talebi gönderebilirsin.',
          );
        }
        final selected = await google.signIn();
        if (selected == null) return false;
        final tokens = await selected.authentication;
        if (tokens.idToken == null || tokens.idToken!.isEmpty) {
          throw StateError('Google kimliği doğrulanamadı.');
        }
        await current.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            idToken: tokens.idToken,
            accessToken: tokens.accessToken,
          ),
        );
      }
      await current.getIdToken(true);
      return true;
    } on FirebaseAuthException catch (error) {
      if ([
        'canceled',
        'web-context-canceled',
        'popup-closed-by-user',
      ].contains(error.code)) {
        return false;
      }
      rethrow;
    } on PlatformException catch (error) {
      if ([
        'sign_in_canceled',
        'sign_in_cancelled',
        'canceled',
        'cancelled',
      ].contains(error.code)) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final start = clock.tick;
    final dynamic resultData;
    if (name == 'getDeletionStatus') {
      // A deletion receipt must remain usable after its Firebase user has been
      // removed. Send App Check, but never attach a stale Firebase Auth token.
      final project = auth.app.options.projectId;
      const region = String.fromEnvironment(
        'FUNCTIONS_REGION',
        defaultValue: 'europe-west1',
      );
      const host = String.fromEnvironment(
        'EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      final uri = Uri.parse(
        emulator
            ? 'http://$host:5001/$project/$region/api'
            : 'https://$region-$project.cloudfunctions.net/api',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        try {
          final token = await FirebaseAppCheck.instance.getToken().timeout(
            const Duration(seconds: 3),
          );
          if (token != null) request.headers.set('X-Firebase-AppCheck', token);
        } catch (_) {
          /* Server policy decides whether an absent token is allowed. */
        }
        request.write(
          jsonEncode({
            'data': {'action': name, 'payload': data},
          }),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        final body = Map<String, dynamic>.from(
          jsonDecode(
                await utf8.decoder
                    .bind(response)
                    .join()
                    .timeout(const Duration(seconds: 10)),
              )
              as Map,
        );
        if (response.statusCode != 200 || body['error'] != null) {
          throw StateError(
            'Silme durumu şu anda alınamadı. Yeniden deneyebilirsin.',
          );
        }
        resultData = body['result'];
      } finally {
        client.close(force: true);
      }
    } else {
      final result = await functions
          .httpsCallable(
            'api',
            options: HttpsCallableOptions(
              timeout: Duration(seconds: name == 'getServerTime' ? 3 : 20),
            ),
          )
          .call<dynamic>({'action': name, 'payload': data});
      resultData = result.data;
    }
    final map = Map<String, dynamic>.from(resultData as Map);
    if (map['serverNow'] is num) {
      clock.synchronize(intValue(map['serverNow']), start);
    }
    return map;
  }

  @override
  Stream<Map<String, dynamic>> watchMatch(String id) => firestore
      .collection('matches')
      .doc(id)
      .snapshots()
      .where((s) => s.exists)
      .map((s) => {'id': s.id, ...s.data()!});
  @override
  Stream<Map<String, dynamic>> watchProfile() {
    final uid = account?.uid;
    if (uid == null) return const Stream.empty();
    return firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .where((s) => s.exists)
        .map((s) => s.data()!);
  }

  @override
  Future<void> heartbeat(String matchId) async {
    await call('heartbeat', {'matchId': matchId});
  }
}

String friendlyError(Object error) {
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    if (details is Map && details['userMessage'] is String) {
      return details['userMessage'] as String;
    }
    return switch (error.code) {
      'unauthenticated' => 'Devam etmek için giriş yapmalısın.',
      'not-found' => 'Oda bulunamadı veya süresi doldu.',
      'resource-exhausted' =>
        'Biraz hızlı ilerledin. Kısa bir süre sonra tekrar dene.',
      'deadline-exceeded' ||
      'unavailable' => 'Bağlantı kurulamadı. Lütfen tekrar dene.',
      _ => error.message ?? 'İşlem tamamlanamadı. Tekrar deneyebilirsin.',
    };
  }
  if (error is FirebaseAuthException) {
    if ([
      'canceled',
      'web-context-canceled',
      'popup-closed-by-user',
    ].contains(error.code)) {
      return '';
    }
    return switch (error.code) {
      'network-request-failed' =>
        'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
      'account-exists-with-different-credential' =>
        'Bu hesap için daha önce kullandığın giriş yöntemini seç.',
      'user-disabled' => 'Bu hesabın erişimi kapatılmış.',
      'operation-not-allowed' => 'Bu giriş yöntemi şu an kullanılamıyor.',
      'user-mismatch' =>
        'Silmek istediğin hesaba ait giriş yöntemini ve aynı hesabı seç.',
      'requires-recent-login' => 'Bu işlem için kimliğini yeniden doğrula.',
      _ => 'Giriş tamamlanamadı. Lütfen tekrar dene.',
    };
  }
  if (error is PlatformException) {
    if ([
      'sign_in_canceled',
      'sign_in_cancelled',
      'canceled',
      'cancelled',
    ].contains(error.code)) {
      return '';
    }
    if (error.code == 'network_error') {
      return 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.';
    }
    return 'Google girişi tamamlanamadı. Lütfen tekrar dene.';
  }
  if (error is StateError) return error.message.toString();
  return 'İşlem tamamlanamadı. Lütfen tekrar dene.';
}
