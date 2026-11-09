"""Add the configured Google iOS URL scheme without embedding credentials."""
import json
import plistlib
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'config/firebase.json'
config = json.loads(config_path.read_text(encoding='utf-8'))
client_id = config.get('GOOGLE_IOS_CLIENT_ID', '')
if not client_id.endswith('.apps.googleusercontent.com'):
    raise SystemExit('GOOGLE_IOS_CLIENT_ID alanına Firebase projenizin iOS OAuth istemci kimliğini yazın.')
target = root / 'ios/Runner/Info.plist'
info = plistlib.loads(target.read_bytes())
info['GIDClientID'] = client_id
scheme = '.'.join(reversed(client_id.split('.')))
types = [entry for entry in info.get('CFBundleURLTypes', []) if entry.get('CFBundleURLName') != 'google-sign-in']
types.append({'CFBundleURLName': 'google-sign-in', 'CFBundleURLSchemes': [scheme]})
info['CFBundleURLTypes'] = types
target.write_bytes(plistlib.dumps(info, sort_keys=False))
print('Google iOS giriş yönlendirmesi Info.plist dosyasına eklendi.')
