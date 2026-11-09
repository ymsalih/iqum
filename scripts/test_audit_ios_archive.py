import importlib.util
import plistlib
import unittest
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("archive_audit", Path(__file__).with_name("audit_ios_archive.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ArchiveAuditTest(unittest.TestCase):
    def setUp(self):
        self.archive = ROOT / "output" / "ios-audit-fixtures" / str(uuid.uuid4()) / "Runner.xcarchive"
        self.app = self.archive / "Products" / "Applications" / "Runner.app"
        self.app.mkdir(parents=True)
        self.manifest = self.app / "PrivacyInfo.xcprivacy"
        self.manifest.write_bytes((ROOT / "ios/Runner/PrivacyInfo.xcprivacy").read_bytes())

    def test_collects_main_and_sdk_manifests(self):
        sdk = self.app / "Frameworks" / "Example.framework" / "PrivacyInfo.xcprivacy"
        sdk.parent.mkdir(parents=True)
        sdk.write_bytes(plistlib.dumps({"NSPrivacyTracking": False, "NSPrivacyAccessedAPITypes": []}))
        result = module.inspect(self.archive)
        self.assertEqual(len(result["manifests"]), 2)
        self.assertIn("Example.framework", result["frameworks"])

    def test_refuses_missing_main_manifest(self):
        self.manifest.unlink()
        with self.assertRaises(ValueError):
            module.inspect(self.archive)

    def test_refuses_tracking_and_empty_required_reasons(self):
        original = plistlib.loads(self.manifest.read_bytes())
        original["NSPrivacyTracking"] = True
        self.manifest.write_bytes(plistlib.dumps(original))
        with self.assertRaises(ValueError):
            module.inspect(self.archive)
        original["NSPrivacyTracking"] = False
        original["NSPrivacyAccessedAPITypes"] = [{"NSPrivacyAccessedAPIType": "test", "NSPrivacyAccessedAPITypeReasons": []}]
        self.manifest.write_bytes(plistlib.dumps(original))
        with self.assertRaises(ValueError):
            module.inspect(self.archive)


if __name__ == "__main__":
    unittest.main()
