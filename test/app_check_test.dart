import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqum/data/app_check.dart';

class _AppCheck extends Fake implements FirebaseAppCheck {
  final calls = <Invocation>[];
  bool failActivation = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (failActivation && invocation.memberName == #activate) {
      return Future<void>.error(StateError('provider unavailable'));
    }
    return Future<void>.value();
  }
}

void main() {
  test(
    'release cannot select debug providers, even with a debug dart-define',
    () async {
      final service = _AppCheck();
      await const AppCheckSetup(
        debugBuild: false,
        debugRequested: true,
      ).activate(service);
      final activation = service.calls.first;
      expect(activation.memberName, #activate);
      expect(
        activation.namedArguments[#providerAndroid],
        isA<AndroidPlayIntegrityProvider>(),
      );
      expect(
        activation.namedArguments[#providerApple],
        isA<AppleAppAttestProvider>(),
      );
      expect(service.calls.last.memberName, #setTokenAutoRefreshEnabled);
      expect(service.calls.last.positionalArguments, [true]);
    },
  );
  test(
    'debug attestation is explicit and never the default device provider',
    () async {
      expect(
        const AppCheckSetup(debugBuild: true, debugRequested: false).useDebug,
        false,
      );
      final service = _AppCheck();
      await const AppCheckSetup(
        debugBuild: true,
        debugRequested: true,
      ).activate(service);
      expect(
        service.calls.first.namedArguments[#providerAndroid],
        isA<AndroidDebugProvider>(),
      );
      expect(
        service.calls.first.namedArguments[#providerApple],
        isA<AppleDebugProvider>(),
      );
    },
  );
  test(
    'local service emulators do not contact real attestation providers',
    () async {
      final service = _AppCheck();
      await const AppCheckSetup(emulator: true).activate(service);
      expect(service.calls, isEmpty);
    },
  );
  test(
    'activation failure is surfaced instead of silently disabling protection',
    () async {
      final service = _AppCheck()..failActivation = true;
      await expectLater(
        const AppCheckSetup().activate(service),
        throwsStateError,
      );
      expect(service.calls.map((c) => c.memberName), [#activate]);
    },
  );
}
