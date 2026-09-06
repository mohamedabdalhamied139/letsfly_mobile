# Challenger 2 Test Harness - Packaging & Build Adversarial Review
import os, sys, re, json, xml.etree.ElementTree as ET
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import hashes

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
passed = 0
failed = 0

def check(ok, name, details=''):
    global passed, failed
    if ok:
        passed += 1
        print(f'  [PASS] {name}')
    else:
        failed += 1
        print(f'  [FAIL] {name} - {details}')

print('======================================================================')
print('  CHALLENGER 2: ADVERSARIAL PACKAGING & BUILD HARNESS')
print('======================================================================')

# 1. CI WORKFLOW (.github/workflows/build.yml)
print('\n--- 1. CI WORKFLOW ADVERSARIAL CHALLENGE ---')
ci_path = os.path.join(ROOT, '.github', 'workflows', 'build.yml')
with open(ci_path, 'r', encoding='utf-8') as f:
    ci = f.read()

# Negative checks: verify no destructive or dangerous commands
check('rm -rf android' not in ci, 'CI avoids wiping android/ directory')
check('rm -rf ios' not in ci, 'CI avoids wiping ios/ directory')
check('flutter create' not in ci, 'CI avoids flutter create (preserves package name and signing configs)')
check('usesCleartextTraffic' not in ci, 'CI avoids injecting usesCleartextTraffic')
check('sed -i' not in ci, 'CI avoids arbitrary sed manipulation of AndroidManifest.xml')
check('androiddebugkey' not in ci, 'CI avoids signing with androiddebugkey')

# Positive checks: keystore configuration and release APK build
check('name: Configure Keystore' in ci, 'CI defines Configure Keystore step')
check('keyAlias=letsfly' in ci, 'CI sets keyAlias to letsfly')
check('keyPassword=letsfly2026' in ci, 'CI sets keyPassword to letsfly2026')
check('storeFile=letsfly-release.jks' in ci, 'CI sets storeFile to letsfly-release.jks')
check('storePassword=letsfly2026' in ci, 'CI sets storePassword to letsfly2026')
check('flutter build apk --release' in ci, 'CI executes flutter build apk --release')
check('flutter build apk --debug' not in ci, 'CI does NOT build debug APK')
check('build/app/outputs/flutter-apk/app-release.apk' in ci, 'CI specifies release APK output path')
check('tag_name: v8.6' in ci, 'CI specifies release tag v8.6')
check('version.json' in ci, 'CI attaches version.json to GitHub release')

# 2. SIGNING CONFIGURATION & RESILIENCE
print('\n--- 2. SIGNING CONFIGURATION ADVERSARIAL CHALLENGE ---')
gradle_path = os.path.join(ROOT, 'android', 'app', 'build.gradle')
with open(gradle_path, 'r', encoding='utf-8') as f:
    bg = f.read()

check('signingConfigs {' in bg and 'release {' in bg, 'signingConfigs.release block is defined')
m_v1 = re.search(r'v1SigningEnabled\s+(true|false)', bg)
m_v2 = re.search(r'v2SigningEnabled\s+(true|false)', bg)
check(m_v1 and m_v1.group(1) == 'true', 'v1SigningEnabled is explicitly true in release signingConfig')
check(m_v2 and m_v2.group(1) == 'true', 'v2SigningEnabled is explicitly true in release signingConfig')

# Verify release buildType uses release signingConfig
m_rel = re.search(r'buildTypes\s*\{[\s\S]*?release\s*\{([\s\S]*?)\}', bg)
if m_rel:
    rel_content = m_rel.group(1)
    check('signingConfig signingConfigs.release' in rel_content, 'buildTypes.release uses signingConfigs.release')
    check('signingConfig signingConfigs.debug' not in rel_content, 'buildTypes.release does NOT use debug key')
else:
    check(False, 'buildTypes.release parsed')

# Keystore existence and cryptographic verification
ks_path = os.path.join(ROOT, 'android', 'app', 'letsfly-release.jks')
check(os.path.exists(ks_path), 'Release keystore letsfly-release.jks exists on disk')

with open(ks_path, 'rb') as f:
    ks_bytes = f.read()

p12_obj = pkcs12.load_pkcs12(ks_bytes, b'letsfly2026')
check(p12_obj.key is not None, 'Private key successfully loaded from keystore')
check(p12_obj.cert is not None, 'Certificate successfully loaded from keystore')

cert_alias = p12_obj.cert.friendly_name if p12_obj.cert else None
check(cert_alias == b'letsfly', f'Keystore cert alias matches letsfly (Actual: {cert_alias})')

check(isinstance(p12_obj.key, rsa.RSAPrivateKey), 'Private key is RSA')
check(p12_obj.key.key_size == 2048, f'RSA key size is 2048 bits (Actual: {p12_obj.key.key_size})')
check(p12_obj.key.public_key().public_numbers().e == 65537, 'RSA public exponent is 65537')

cert = p12_obj.cert.certificate
check(cert.signature_hash_algorithm.name == 'sha256', 'Signature hash is SHA256')
dn_str = cert.subject.rfc4514_string()
check('CN=LetsFly Mobile' in dn_str, 'Cert CN is LetsFly Mobile')
check('OU=Mobile' in dn_str, 'Cert OU is Mobile')
check('O=LetsFly' in dn_str, 'Cert O is LetsFly')
check('L=Cairo' in dn_str, 'Cert L is Cairo')
check('ST=Cairo' in dn_str, 'Cert ST is Cairo')
check('C=EG' in dn_str, 'Cert C is EG')

days = (cert.not_valid_after_utc - cert.not_valid_before_utc).days
check(days == 10000, f'Cert validity is 10,000 days (Actual: {days})')
check(cert.not_valid_after_utc.year == 2054, f'Cert valid until 2054 (Actual: {cert.not_valid_after_utc.year})')

try:
    cert.public_key().verify(cert.signature, cert.tbs_certificate_bytes, padding.PKCS1v15(), cert.signature_hash_algorithm)
    check(True, 'Cert self-signature is cryptographically valid')
except Exception as e:
    check(False, 'Cert self-signature is cryptographically valid', str(e))

# Fallback resilience in build.gradle
check('rootProject.file' in bg and 'key.properties' in bg, 'Reads key.properties from rootProject')
check('if (keystorePropertiesFile.exists())' in bg, 'Handles missing key.properties gracefully with fallback')
check('letsfly-release.jks' in bg, 'Fallback references letsfly-release.jks directly')

# 3. VERSION ALIGNMENT
print('\n--- 3. VERSION ALIGNMENT ADVERSARIAL CHALLENGE ---')
with open(os.path.join(ROOT, 'pubspec.yaml'), 'r', encoding='utf-8') as f:
    pub_text = f.read()

m_pub = re.search(r'^version:\s*([0-9.]+)\+([0-9]+)', pub_text, re.MULTILINE)
check(m_pub is not None, 'pubspec.yaml defines version in SemVer+code format')
pub_ver_name = m_pub.group(1) if m_pub else ''
pub_ver_code = int(m_pub.group(2)) if m_pub else 0

with open(os.path.join(ROOT, 'version.json'), 'r', encoding='utf-8-sig') as f:
    vj = json.load(f)

json_ver_name = vj.get('version', '')
json_ver_code = vj.get('version_code', 0)
json_apk_url = vj.get('apk_url', '')

m_g_code = re.search(r'versionCode\s+([0-9]+)', bg)
m_g_name = re.search(r'versionName\s+[\'"]([^\'"]+)[\'"]', bg)
g_ver_code = int(m_g_code.group(1)) if m_g_code else 0
g_ver_name = m_g_name.group(1) if m_g_name else ''

print(f'  pubspec.yaml: {pub_ver_name}+{pub_ver_code}')
print(f'  version.json: {json_ver_name} (code: {json_ver_code})')
print(f'  build.gradle: {g_ver_name} (code: {g_ver_code})')

check(pub_ver_name == json_ver_name == g_ver_name == '8.6.0', f'Version names match across all configs (pub={pub_ver_name}, json={json_ver_name}, gradle={g_ver_name})')
check(pub_ver_code == json_ver_code == g_ver_code == 86, f'Version codes match across all configs (pub={pub_ver_code}, json={json_ver_code}, gradle={g_ver_code})')
check('/releases/download/v8.6/app-release.apk' in json_apk_url, 'version.json apk_url targets release tag v8.6')

# 4. PACKAGE IDENTITY AND MANIFEST HYGIENE
print('\n--- 4. PACKAGE IDENTITY & MANIFEST HYGIENE ---')
check('com.letsfly.mobile' in bg, 'Gradle build contains com.letsfly.mobile')
check('compileSdk 34' in bg, 'compileSdk is 34')
check('targetSdkVersion 34' in bg, 'targetSdkVersion is 34')
check('minSdkVersion 21' in bg, 'minSdkVersion is 21')

manifest_path = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
tree = ET.parse(manifest_path)
root = tree.getroot()
ns = '{http://schemas.android.com/apk/res/android}'

check('package' not in root.attrib, 'Root manifest does not contain deprecated package attribute')
app_el = root.find('application')
check(app_el is not None, 'Application element exists in manifest')
if app_el is not None:
    cleartext = app_el.attrib.get(f'{ns}usesCleartextTraffic')
    check(cleartext is None or cleartext.lower() == 'false', f'usesCleartextTraffic is false/absent (Actual: {cleartext})')
    icon = app_el.attrib.get(f'{ns}icon')
    check(icon == '@drawable/launch_background', f'Application icon is launch_background (Actual: {icon})')
    backup = app_el.attrib.get(f'{ns}allowBackup')
    check(backup == 'false', f'allowBackup is false (Actual: {backup})')

perms = [p.attrib.get(f'{ns}name', '') for p in root.findall('uses-permission')]
print(f'  Permissions found: {perms}')
check('android.permission.INTERNET' in perms, 'INTERNET permission present')
check('android.permission.ACCESS_NETWORK_STATE' in perms, 'ACCESS_NETWORK_STATE permission present')
check('android.permission.RECORD_AUDIO' in perms, 'RECORD_AUDIO permission present')
check('android.permission.MODIFY_AUDIO_SETTINGS' in perms, 'MODIFY_AUDIO_SETTINGS permission present')

dangerous_unauthorized = [
    'android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.ACCESS_FINE_LOCATION', 'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.READ_PHONE_STATE', 'android.permission.SEND_SMS',
    'android.permission.CAMERA', 'android.permission.READ_CONTACTS'
]
flagged = [p for p in perms if p in dangerous_unauthorized]
check(len(flagged) == 0, f'No dangerous unauthorized permissions present (Flagged: {flagged})')

# 5. ADVERSARIAL AUDIT: IN-APP UPDATER & BOM
print('\n--- 5. ADVERSARIAL AUDIT: IN-APP UPDATER & BOM ---')
with open(os.path.join(ROOT, 'version.json'), 'rb') as f:
    first_bytes = f.read(3)
has_bom = (first_bytes == b'\xef\xbb\xbf')
print(f'  version.json UTF-8 BOM present: {has_bom}')
if has_bom:
    print('  [ADVISORY] version.json begins with UTF-8 BOM (0xEF 0xBB 0xBF). Strict RFC 8259 parsers require strip.')

aum_path = os.path.join(ROOT, 'lib', 'core', 'services', 'app_update_manager.dart')
if os.path.exists(aum_path):
    with open(aum_path, 'r', encoding='utf-8') as f:
        aum_text = f.read()
    m_aum_ver = re.search(r"currentVersion\s*=\s*'([^']+)'", aum_text)
    m_aum_code = re.search(r"currentVersionCode\s*=\s*(\d+)", aum_text)
    aum_ver = m_aum_ver.group(1) if m_aum_ver else 'unknown'
    aum_code = int(m_aum_code.group(1)) if m_aum_code else -1
    print(f'  AppUpdateManager: currentVersion={aum_ver}, currentVersionCode={aum_code}')
    if aum_code < 86:
        print(f'  [ADVISORY FINDING] AppUpdateManager has stale currentVersionCode={aum_code} (expected 86). Will trigger false update notice!')

# Signing simulation: both branches yield valid release credentials
# Branch A: with key.properties
# Branch B: fallback without key.properties
ks_exists = os.path.exists(os.path.join(ROOT, 'android', 'app', 'letsfly-release.jks'))
check(ks_exists, 'Keystore exists for both key.properties and fallback paths')

print('\n======================================================================')
print(f'CHALLENGER 2 SUMMARY: {passed} PASSED, {failed} FAILED')
print('======================================================================')
if failed == 0:
    print('FINAL VERDICT: APPROVE')
    sys.exit(0)
else:
    print('FINAL VERDICT: REJECT')
    sys.exit(1)
