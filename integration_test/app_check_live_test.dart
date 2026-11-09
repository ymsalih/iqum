import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in native SDK test. Uses a short-lived, host-registered debug identity.
/// Creates no Firebase users, profiles, game records, rooms, or point changes.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android debug App Check exchanges a token and calls the live IQUM clock',
    (tester) async {
      const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
      const appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
      const secret = String.fromEnvironment('IQUM_TEST_DEBUG_SECRET');
      expect(project, 'iqum-4734b');
      expect(
        secret.isNotEmpty,
        true,
        reason: 'Prepare the temporary host debug identity first.',
      );
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          projectId: project,
          appId: appId,
          apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
          messagingSenderId: String.fromEnvironment(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
        ),
      );
      final appCheck = FirebaseAppCheck.instance;
      await appCheck.activate(
        providerAndroid: const AndroidDebugProvider(debugToken: secret),
      );
      await appCheck.setTokenAutoRefreshEnabled(true);
      final token = await appCheck
          .getToken(true)
          .timeout(const Duration(seconds: 60));
      expect(token != null && token.isNotEmpty, true);
      // Inspect identity without printing/exporting the token or debug secret.
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token!.split('.')[1])),
                ),
              )
              as Map;
      expect(claims['sub'], appId);
      final response =
          await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable(
                'api',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 30),
                ),
              )
              .call<dynamic>({
                'action': 'getServerTime',
                'payload': <String, dynamic>{},
              });
      final result = Map<String, dynamic>.from(response.data as Map);
      expect(result['serverNow'], isA<num>());
      expect((result['serverNow'] as num) > 0, true);
      binding.reportData = {
        'nativeAppCheckTokenReceived': true,
        'tokenIdentityMatchesAndroidApp': true,
        'liveClockCallSucceeded': true,
        'serverNow': result['serverNow'],
        'projectId': project,
      };
    },
    skip: !const bool.fromEnvironment('IQUM_LIVE_APP_CHECK_TEST'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
