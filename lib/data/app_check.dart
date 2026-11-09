import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Debug attestation is an explicit development-only choice. A release/profile
/// package always uses the real device provider, even if a debug flag is passed.
class AppCheckSetup {
  const AppCheckSetup({
    this.debugBuild = kDebugMode,
    this.debugRequested = const bool.fromEnvironment('APP_CHECK_DEBUG'),
    this.emulator = const bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
  });

  final bool debugBuild, debugRequested, emulator;
  bool get useDebug => debugBuild && debugRequested;
  AndroidAppCheckProvider get android => useDebug
      ? const AndroidDebugProvider()
      : const AndroidPlayIntegrityProvider();
  AppleAppCheckProvider get apple =>
      useDebug ? const AppleDebugProvider() : const AppleAppAttestProvider();

  Future<void> activate(FirebaseAppCheck service) async {
    if (emulator) return;
    await service.activate(providerAndroid: android, providerApple: apple);
    // The SDK caches and refreshes tokens; do not attest on every move.
    await service.setTokenAutoRefreshEnabled(true);
  }
}
