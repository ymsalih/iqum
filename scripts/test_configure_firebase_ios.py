import importlib.util
import json
import plistlib
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('ios_setup', Path(__file__).with_name('configure_firebase_ios.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class IOSConfigTests(unittest.TestCase):
    def setUp(self):
        self.scratch = Path(__file__).resolve().parents[1] / 'output/ios-config-tests'
        self.scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=self.scratch)
        self.addCleanup(self.remove_fixture)
        self.root = Path(self.temp.name)
        for folder in ['config', 'ios/Runner', 'ios/Runner.xcodeproj']:
            (self.root / folder).mkdir(parents=True, exist_ok=True)
        self.settings = {'FIREBASE_PROJECT_ID': 'iqum-test', 'FIREBASE_MESSAGING_SENDER_ID': '123',
                         'GOOGLE_WEB_CLIENT_ID': 'web.apps.googleusercontent.com'}
        (self.root / 'config/firebase.json').write_text(json.dumps(self.settings))
        (self.root / 'ios/Runner/Info.plist').write_bytes(plistlib.dumps({
            'CFBundleURLTypes': [{'CFBundleURLName': 'other', 'CFBundleURLSchemes': ['existing']}]}))
        project = '''/* Begin PBXBuildFile section */
/* Begin PBXFileReference section */
97C146F01CF9000F007C117D /* Runner */ = { isa = PBXGroup; children = ( ); };
97C146EC1CF9000F007C117D /* Resources */ = { isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( ); };
97C146ED1CF9000F007C117D = { CreatedOnToolsVersion = 7.3.1; };
'''+('\nCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' * 3)
        (self.root / 'ios/Runner.xcodeproj/project.pbxproj').write_text(project)
        self.data = {'PROJECT_ID': 'iqum-test', 'BUNDLE_ID': 'com.iqum.iqum',
                     'GOOGLE_APP_ID': '1:123:ios:fixture', 'API_KEY': 'fixture-key', 'GCM_SENDER_ID': '123',
                     'CLIENT_ID': 'ios.apps.googleusercontent.com', 'REVERSED_CLIENT_ID': 'com.googleusercontent.apps.ios'}
        self.source = self.root / 'source.plist'
        self.save_source()

    def save_source(self):
        self.source.write_bytes(plistlib.dumps(self.data))

    def remove_fixture(self):
        if not Path(self.temp.name).resolve().is_relative_to(self.scratch.resolve()):
            raise ValueError('Test temizleme yolu çalışma alanı dışında.')
        self.temp.cleanup()

    def test_import_is_idempotent_and_preserves_other_redirects(self):
        module.configure(self.source, self.root, 'ABCDEFGHIJ')
        before = (self.root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        module.configure(self.source, self.root, 'ABCDEFGHIJ')
        after = (self.root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        self.assertEqual(before, after)
        self.assertEqual(after.count('DEVELOPMENT_TEAM = ABCDEFGHIJ;'), 3)
        info = plistlib.loads((self.root / 'ios/Runner/Info.plist').read_bytes())
        self.assertEqual(len(info['CFBundleURLTypes']), 2)
        self.assertEqual(info['CFBundleURLTypes'][0]['CFBundleURLName'], 'other')
        self.assertEqual(info['GIDServerClientID'], self.settings['GOOGLE_WEB_CLIENT_ID'])
        config = json.loads((self.root / 'config/firebase.json').read_text())
        self.assertEqual(config['FIREBASE_IOS_API_KEY'], 'fixture-key')

    def test_other_project_is_rejected_before_any_write(self):
        self.data['PROJECT_ID'] = 'different-project'
        self.save_source()
        with self.assertRaises(ValueError):
            module.configure(self.source, self.root)
        self.assertFalse((self.root / 'ios/Runner/GoogleService-Info.plist').exists())
        self.assertEqual(json.loads((self.root / 'config/firebase.json').read_text()), self.settings)

    def test_wrong_bundle_or_redirect_is_rejected(self):
        for key, value in [('BUNDLE_ID', 'another.app'), ('REVERSED_CLIENT_ID', 'invalid.scheme')]:
            original = self.data[key]
            self.data[key] = value
            self.save_source()
            with self.assertRaises(ValueError):
                module.configure(self.source, self.root)
            self.data[key] = original


if __name__ == '__main__':
    unittest.main()
