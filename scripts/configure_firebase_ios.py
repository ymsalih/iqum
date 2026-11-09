"""Import a verified Firebase iOS file and configure the native sign-in target."""
import argparse
import json
import plistlib
import re
from pathlib import Path

FILE_ID = 'A16F0B012026110800000001'
BUILD_ID = 'A16F0B012026110800000002'


def configure(source, root, team_id=None):
    root = Path(root)
    source = Path(source)
    settings = json.loads((root / 'config/firebase.json').read_text(encoding='utf-8-sig'))
    data = plistlib.loads(source.read_bytes())
    if data.get('PROJECT_ID') != settings['FIREBASE_PROJECT_ID']:
        raise ValueError('iOS Firebase dosyası beklenen projeye ait değil.')
    if data.get('BUNDLE_ID') != 'com.iqum.iqum':
        raise ValueError('iOS Bundle ID eşleşmedi.')
    required = ['GOOGLE_APP_ID', 'API_KEY', 'GCM_SENDER_ID', 'CLIENT_ID', 'REVERSED_CLIENT_ID']
    if any(not data.get(key) for key in required):
        raise ValueError('iOS Firebase/Google alanları eksik.')
    if str(data['GCM_SENDER_ID']) != str(settings['FIREBASE_MESSAGING_SENDER_ID']):
        raise ValueError('Firebase proje numarası eşleşmedi.')
    if not data['CLIENT_ID'].endswith('.apps.googleusercontent.com'):
        raise ValueError('iOS Google istemci kimliği geçersiz.')
    if data['REVERSED_CLIENT_ID'] != '.'.join(reversed(data['CLIENT_ID'].split('.'))):
        raise ValueError('Google dönüş şeması istemci kimliğiyle eşleşmedi.')
    if not settings.get('GOOGLE_WEB_CLIENT_ID'):
        raise ValueError('Google Web OAuth kimliği önce Android dosyasından alınmalı.')
    if team_id is not None and not re.fullmatch(r'[A-Z0-9]{10}', team_id):
        raise ValueError('Apple Team ID geçersiz.')

    info_path = root / 'ios/Runner/Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info['GIDClientID'] = data['CLIENT_ID']
    info['GIDServerClientID'] = settings['GOOGLE_WEB_CLIENT_ID']
    urls = [item for item in info.get('CFBundleURLTypes', [])
            if item.get('CFBundleURLName') != 'google-sign-in']
    urls.append({'CFBundleURLName': 'google-sign-in',
                 'CFBundleURLSchemes': [data['REVERSED_CLIENT_ID']]})
    info['CFBundleURLTypes'] = urls

    project_path = root / 'ios/Runner.xcodeproj/project.pbxproj'
    project = project_path.read_text(encoding='utf-8')
    if FILE_ID not in project:
        project = project.replace('/* Begin PBXBuildFile section */',
            f'/* Begin PBXBuildFile section */\n\t\t{BUILD_ID} /* GoogleService-Info.plist in Resources */ = '
            f'{{isa = PBXBuildFile; fileRef = {FILE_ID} /* GoogleService-Info.plist */; }};', 1)
        project = project.replace('/* Begin PBXFileReference section */',
            f'/* Begin PBXFileReference section */\n\t\t{FILE_ID} /* GoogleService-Info.plist */ = '
            '{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };', 1)
        project, group_count = re.subn(
            r'(97C146F01CF9000F007C117D /\* Runner \*/ = \{\s*isa = PBXGroup;\s*children = \()',
            rf'\1\n\t\t\t\t{FILE_ID} /* GoogleService-Info.plist */,', project, count=1)
        project, resource_count = re.subn(
            r'(97C146EC1CF9000F007C117D /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;\s*buildActionMask = \d+;\s*files = \()',
            rf'\1\n\t\t\t\t{BUILD_ID} /* GoogleService-Info.plist in Resources */,', project, count=1)
        if group_count != 1 or resource_count != 1:
            raise ValueError('Runner hedefi bulunamadı; Xcode projesi değiştirilmedi.')
    if team_id:
        pattern = r'(CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;)(\s*DEVELOPMENT_TEAM = [^;]+;)?'
        project, target_count = re.subn(pattern, rf'\1\n\t\t\t\tDEVELOPMENT_TEAM = {team_id};', project)
        if target_count != 3:
            raise ValueError('Beklenen üç Runner imzalama yapılandırması bulunamadı.')
    if 'com.apple.SignInWithApple' not in project:
        project, capability_count = re.subn(
            r'(97C146ED1CF9000F007C117D = \{\s*CreatedOnToolsVersion = [^;]+;)',
            r'\1\n\t\t\t\t\t\tSystemCapabilities = { com.apple.SignInWithApple = { enabled = 1; }; };', project, count=1)
        if capability_count != 1:
            raise ValueError('Runner Apple yeteneği hedefi bulunamadı.')

    settings['FIREBASE_IOS_APP_ID'] = data['GOOGLE_APP_ID']
    settings['FIREBASE_IOS_API_KEY'] = data['API_KEY']
    settings['GOOGLE_IOS_CLIENT_ID'] = data['CLIENT_ID']
    (root / 'ios/Runner/GoogleService-Info.plist').write_bytes(source.read_bytes())
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
    project_path.write_text(project, encoding='utf-8')
    (root / 'config/firebase.json').write_text(json.dumps(settings, indent=2) + '\n', encoding='utf-8')
    return {'projectId': data['PROJECT_ID'], 'bundleId': data['BUNDLE_ID'],
            'firebaseIOSConfigured': True, 'googleRedirectConfigured': True,
            'appleCapabilityConfigured': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--team-id')
    args = parser.parse_args()
    print(json.dumps(configure(args.source, args.root, args.team_id), ensure_ascii=False))
