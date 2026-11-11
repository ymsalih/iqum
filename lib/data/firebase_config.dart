/// Firebase connection settings of the live IQUM project (iqum-4734b).
///
/// These are identifiers, not secrets: every installed app carries them.
/// Data is protected by Firestore rules, the Cloud Functions checks,
/// Firebase Authentication and App Check. A `--dart-define` (or
/// `--dart-define-from-file`) with the same name still overrides a value,
/// e.g. to point a test build somewhere else.
abstract final class FirebaseConfig {
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'iqum-4734b',
  );
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBD_hTi0-0IkMo7EW7dgX0CTSOYm3rt6NE',
  );
  static const iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
    defaultValue: 'AIzaSyDmQ1q5TRaU05jdmqXU0hwlrW7D_Ep6GZE',
  );
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '688320483908',
  );
  static const androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:688320483908:android:4b49fc0dd471652ea2a211',
  );
  static const iosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:688320483908:ios:b619e42ef29c3b39a2a211',
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '688320483908-dhu2uav2ju8qkr0qjv19ta4l154235mr.apps.googleusercontent.com',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '688320483908-movbq81rcgl6dst4ppl4lgeb2ingdgom.apps.googleusercontent.com',
  );
}
