"""Read-only archive manifest inventory. Run on Codemagic macOS after signing.

This validates plist structure, not all compiled required-reason API usage.
"""
import json
import plistlib
import sys
from pathlib import Path


def inspect(archive):
    apps = list((archive / "Products" / "Applications").glob("*.app"))
    if len(apps) != 1:
        raise ValueError("Archive must contain exactly one main application")
    app = apps[0]
    own_manifest = app / "PrivacyInfo.xcprivacy"
    if not own_manifest.is_file():
        raise ValueError("Main app PrivacyInfo.xcprivacy is missing")
    entries = []
    for file in sorted(app.rglob("PrivacyInfo.xcprivacy")):
        with file.open("rb") as handle:
            data = plistlib.load(handle)
        reasons = data.get("NSPrivacyAccessedAPITypes", [])
        for item in reasons:
            if not item.get("NSPrivacyAccessedAPIType") or not item.get("NSPrivacyAccessedAPITypeReasons"):
                raise ValueError(f"Incomplete required-reason declaration: {file.relative_to(app)}")
        entries.append({
            "path": str(file.relative_to(app)),
            "tracking": bool(data.get("NSPrivacyTracking", False)),
            "trackingDomains": data.get("NSPrivacyTrackingDomains", []),
            "requiredReasonAPIs": reasons,
            "collectedData": data.get("NSPrivacyCollectedDataTypes", []),
        })
    own = next(item for item in entries if item["path"] == "PrivacyInfo.xcprivacy")
    if own["tracking"] or own["trackingDomains"]:
        raise ValueError("IQUM first release declares no cross-app tracking")
    expected = {"Name", "EmailAddress", "UserID", "GameplayContent", "ProductInteraction"}
    declared = {item["NSPrivacyCollectedDataType"].removeprefix("NSPrivacyCollectedDataType") for item in own["collectedData"]}
    if not expected.issubset(declared):
        raise ValueError("Main app's account/gameplay declarations are incomplete")
    return {
        "mainApplication": app.name,
        "manifests": entries,
        "frameworks": sorted(p.name for p in (app / "Frameworks").glob("*.framework")),
        "needsManualReview": "Compare SDK manifests, Xcode privacy report, required-reason API calls and App Privacy form; this inventory alone does not certify compliance.",
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/audit_ios_archive.py PATH.xcarchive")
    try:
        archive_path = Path(sys.argv[1]).resolve(strict=True)
        result = inspect(archive_path)
        destination = Path("output") / "store-ios-archive-audit.json"
        destination.parent.mkdir(exist_ok=True)
        destination.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Manifest inventory written: {destination}; {len(result['manifests'])} files")
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        raise SystemExit(str(error))
