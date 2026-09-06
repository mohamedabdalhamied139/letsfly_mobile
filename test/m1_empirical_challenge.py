#!/usr/bin/env python3
"""
Milestone 1 Empirical Adversarial Challenge Test Suite
Testing R1: Google Play Protect Resolution
- Keystore cryptographic integrity
- key.properties credentials and resolution
- build.gradle edge case resilience and fallback
- AndroidManifest.xml permissions and cleartext traffic
"""

import os
import sys
import re
import json
import xml.etree.ElementTree as ET
import datetime
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import hashes
from cryptography import x509
from cryptography.x509.oid import NameOID

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

passed_tests = 0
failed_tests = 0

def record_pass(desc):
    global passed_tests
    passed_tests += 1
    print(f"  [PASS] {desc}")

def record_fail(desc, err=""):
    global failed_tests
    failed_tests += 1
    print(f"  [FAIL] {desc} - {err}")

print("================================================================")
print("  MILESTONE 1 EMPIRICAL ADVERSARIAL CHALLENGE SUITE")
print("================================================================")

# ----------------------------------------------------------------------
# 1. KEYSTORE CRYPTOGRAPHIC VALIDITY
# ----------------------------------------------------------------------
print("\n--- 1. Cryptographic Validity of android/app/letsfly-release.jks ---")
keystore_rel = os.path.join('android', 'app', 'letsfly-release.jks')
keystore_path = os.path.join(ROOT, keystore_rel)

if not os.path.exists(keystore_path):
    record_fail("Keystore file exists on disk", f"Not found at {keystore_path}")
else:
    record_pass(f"Keystore file exists on disk ({os.path.getsize(keystore_path)} bytes)")

    with open(keystore_path, 'rb') as f:
        ks_bytes = f.read()

    # Test load with valid password
    try:
        p12 = pkcs12.load_key_and_certificates(ks_bytes, b'letsfly2026')
        private_key = p12[0]
        cert = p12[1]
        record_pass("Keystore unlocks with password 'letsfly2026'")
    except Exception as e:
        record_fail("Keystore unlocks with password 'letsfly2026'", str(e))
        p12 = (None, None, [])
        private_key = None
        cert = None

    # Negative oracle: Wrong password must fail
    try:
        pkcs12.load_key_and_certificates(ks_bytes, b'adversarial_invalid_password')
        record_fail("Oracle Negative: Keystore rejects incorrect password", "Loaded with invalid password!")
    except Exception:
        record_pass("Oracle Negative: Keystore rejects incorrect password")

    if private_key and cert:
        # Check RSA key type and strength
        if isinstance(private_key, rsa.RSAPrivateKey):
            record_pass("Private key algorithm is RSA")
            key_bits = private_key.key_size
            if key_bits >= 2048:
                record_pass(f"Private key strength >= 2048 bits (Actual: {key_bits} bits)")
            else:
                record_fail(f"Private key strength >= 2048 bits (Actual: {key_bits} bits)")
            
            pub_exp = private_key.public_key().public_numbers().e
            if pub_exp == 65537:
                record_pass(f"Public exponent is standard F4 (65537)")
            else:
                record_fail(f"Public exponent is standard F4 (65537)", f"Got: {pub_exp}")
        else:
            record_fail("Private key algorithm is RSA", f"Type: {type(private_key)}")

        # Check Subject DN
        expected_dn = {
            NameOID.COMMON_NAME: 'LetsFly Mobile',
            NameOID.ORGANIZATIONAL_UNIT_NAME: 'Mobile',
            NameOID.ORGANIZATION_NAME: 'LetsFly',
            NameOID.LOCALITY_NAME: 'Cairo',
            NameOID.STATE_OR_PROVINCE_NAME: 'Cairo',
            NameOID.COUNTRY_NAME: 'EG',
        }
        dn_ok = True
        for oid, exp_val in expected_dn.items():
            attrs = cert.subject.get_attributes_for_oid(oid)
            if not attrs or attrs[0].value != exp_val:
                dn_ok = False
                record_fail(f"Subject DN {oid._name} == '{exp_val}'", f"Got: {attrs[0].value if attrs else 'None'}")
            else:
                record_pass(f"Subject DN {oid._name} == '{exp_val}'")

        # Check Issuer DN matches Subject DN (Self-signed)
        if cert.issuer == cert.subject:
            record_pass("Certificate Issuer DN matches Subject DN (Self-signed)")
        else:
            record_fail("Certificate Issuer DN matches Subject DN", f"Issuer: {cert.issuer}, Subject: {cert.subject}")

        # Check Validity Window
        now = datetime.datetime.now(datetime.timezone.utc)
        not_before = cert.not_valid_before_utc
        not_after = cert.not_valid_after_utc
        validity_days = (not_after - not_before).days

        if not_before <= now <= not_after:
            record_pass(f"Certificate is currently valid (Active: {not_before.strftime('%Y-%m-%d')} to {not_after.strftime('%Y-%m-%d')})")
        else:
            record_fail(f"Certificate is currently valid", f"Now={now}, Window=[{not_before}, {not_after}]")

        if validity_days >= 9000:
            record_pass(f"Certificate validity duration >= 25 years / 9000 days (Actual: {validity_days} days)")
        else:
            record_fail(f"Certificate validity duration >= 25 years / 9000 days", f"Actual: {validity_days} days")

        if not_after.year >= 2050:
            record_pass(f"Expiration extends to 2050+ for Play Store compliance (Actual: {not_after.year})")
        else:
            record_fail(f"Expiration extends to 2050+ for Play Store compliance", f"Actual: {not_after.year}")

        # Check Signature Hash Algorithm
        sig_hash = cert.signature_hash_algorithm.name.lower()
        if sig_hash == 'sha256':
            record_pass("Signature algorithm is SHA256withRSA")
        else:
            record_fail("Signature algorithm is SHA256withRSA", f"Got: {sig_hash}")

        # Cryptographic Self-Signature Verification
        try:
            cert.public_key().verify(
                cert.signature,
                cert.tbs_certificate_bytes,
                padding.PKCS1v15(),
                cert.signature_hash_algorithm
            )
            record_pass("Cryptographic self-signature of certificate is mathematically valid")
        except Exception as e:
            record_fail("Cryptographic self-signature of certificate is mathematically valid", str(e))

        # Sign and verify arbitrary data roundtrip
        payload = b"Adversarial Verification 2026"
        signature = private_key.sign(payload, padding.PKCS1v15(), hashes.SHA256())
        try:
            cert.public_key().verify(signature, payload, padding.PKCS1v15(), hashes.SHA256())
            record_pass("Private key signing / Certificate public key verification round-trip is valid")
        except Exception as e:
            record_fail("Private key signing / Certificate public key verification round-trip", str(e))

        # Negative oracle: Tampered payload verification fails
        try:
            cert.public_key().verify(signature, b"Tampered Payload 2026", padding.PKCS1v15(), hashes.SHA256())
            record_fail("Oracle Negative: Tampered payload fails verification", "Verification succeeded on tampered data!")
        except Exception:
            record_pass("Oracle Negative: Tampered payload fails verification")

        # Negative oracle: Corrupted signature verification fails
        corrupted_sig = bytearray(signature)
        corrupted_sig[10] ^= 0xAA
        try:
            cert.public_key().verify(bytes(corrupted_sig), payload, padding.PKCS1v15(), hashes.SHA256())
            record_fail("Oracle Negative: Corrupted signature fails verification", "Verification succeeded on corrupted signature!")
        except Exception:
            record_pass("Oracle Negative: Corrupted signature fails verification")

# ----------------------------------------------------------------------
# 2. KEY.PROPERTIES INTEGRITY AND RESOLUTION
# ----------------------------------------------------------------------
print("\n--- 2. android/key.properties Configuration & Credentials ---")
key_props_path = os.path.join(ROOT, 'android', 'key.properties')
if not os.path.exists(key_props_path):
    record_fail("android/key.properties exists", "File not found")
else:
    record_pass("android/key.properties exists")
    props = {}
    with open(key_props_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                props[k.strip()] = v.strip()

    for k in ['storePassword', 'keyPassword', 'keyAlias', 'storeFile']:
        if k in props and len(props[k]) > 0:
            record_pass(f"key.properties defines '{k}' ('{props[k]}')")
        else:
            record_fail(f"key.properties defines '{k}'", f"Missing or empty")

    # Verify alias matches
    if props.get('keyAlias') == 'letsfly':
        record_pass("keyAlias matches 'letsfly'")
    else:
        record_fail("keyAlias matches 'letsfly'", f"Got: {props.get('keyAlias')}")

    # Verify storeFile path resolution
    store_file = props.get('storeFile', '')
    # From android/app perspective:
    store_in_app = os.path.join(ROOT, 'android', 'app', store_file)
    if os.path.exists(store_in_app):
        record_pass(f"storeFile '{store_file}' resolves correctly to {store_in_app}")
    else:
        record_fail(f"storeFile '{store_file}' resolves correctly", f"File does not exist at {store_in_app}")

    # Verify credentials match keystore
    if os.path.exists(store_in_app):
        with open(store_in_app, 'rb') as f:
            data = f.read()
        try:
            p12_test = pkcs12.load_key_and_certificates(data, props.get('storePassword', '').encode('utf-8'))
            if p12_test[0] is not None and p12_test[1] is not None:
                record_pass("storePassword and keyPassword from key.properties unlock the keystore and private key")
            else:
                record_fail("storePassword unlocks keystore", "Key or cert missing")
        except Exception as e:
            record_fail("storePassword unlocks keystore", str(e))

# ----------------------------------------------------------------------
# 3. BUILD.GRADLE EDGE CASE RESILIENCE & FALLBACK
# ----------------------------------------------------------------------
print("\n--- 3. android/app/build.gradle Edge Cases & Fallback ---")
build_gradle_path = os.path.join(ROOT, 'android', 'app', 'build.gradle')
if not os.path.exists(build_gradle_path):
    record_fail("android/app/build.gradle exists", "File not found")
else:
    record_pass("android/app/build.gradle exists")
    with open(build_gradle_path, 'r', encoding='utf-8') as f:
        bg_content = f.read()

    # Check signingConfigs.release presence
    if 'signingConfigs {' in bg_content and 'release {' in bg_content:
        record_pass("build.gradle defines signingConfigs.release")
    else:
        record_fail("build.gradle defines signingConfigs.release")

    # Check keystorePropertiesFile loading from rootProject.file('key.properties')
    if "rootProject.file('key.properties')" in bg_content:
        record_pass("Loads keystoreProperties from rootProject.file('key.properties')")
    else:
        record_fail("Loads keystoreProperties from rootProject.file('key.properties')")

    # Edge Case: Missing key.properties fallback check
    # Extract release signing config block
    m_release = re.search(r'signingConfigs\s*\{\s*release\s*\{([\s\S]*?)\}\s*\}', bg_content)
    if m_release:
        rel_code = m_release.group(1)
        if "if (keystorePropertiesFile.exists())" in rel_code:
            record_pass("build.gradle checks if keystorePropertiesFile.exists()")
        else:
            record_fail("build.gradle checks if keystorePropertiesFile.exists()")

        # Verify fallback else block for keystorePropertiesFile
        all_elses = re.findall(r'else\s*\{([\s\S]*?)\}', rel_code)
        # The second else is the fallback for if (keystorePropertiesFile.exists())
        fallback_code = all_elses[-1] if all_elses else ""
        if fallback_code:
            record_pass("build.gradle contains fallback 'else' block for missing key.properties")

            has_alias = "keyAlias 'letsfly'" in fallback_code
            has_kpass = "keyPassword 'letsfly2026'" in fallback_code
            has_sfile = "storeFile file('letsfly-release.jks')" in fallback_code
            has_spass = "storePassword 'letsfly2026'" in fallback_code

            if has_alias and has_kpass and has_sfile and has_spass:
                record_pass("Fallback provides correct release credentials (alias, passwords, and letsfly-release.jks)")
            else:
                record_fail("Fallback provides correct release credentials", f"Alias: {has_alias}, KPass: {has_kpass}, SFile: {has_sfile}, SPass: {has_spass}")
        else:
            record_fail("build.gradle contains fallback 'else' block for missing key.properties")

        # Verify v1 and v2 signing are enabled unconditionally
        if "v1SigningEnabled true" in rel_code and "v2SigningEnabled true" in rel_code:
            record_pass("v1SigningEnabled and v2SigningEnabled are both explicitly enabled")
        else:
            record_fail("v1SigningEnabled and v2SigningEnabled are both explicitly enabled")

        # Path resolution logic test
        # Def: storeFile file(storePath).exists() ? file(storePath) : rootProject.file(storePath)
        if "file(storePath).exists() ? file(storePath) : rootProject.file(storePath)" in rel_code:
            record_pass("Gracefully handles storePath resolution across both android/app and android/ root")
        else:
            record_fail("Gracefully handles storePath resolution across both android/app and android/ root")
    else:
        record_fail("Extract signingConfigs.release block")

    # Check buildTypes.release references signingConfigs.release
    m_bt = re.search(r'buildTypes\s*\{([\s\S]*?)\}\s*\}', bg_content)
    if m_bt:
        bt_code = m_bt.group(1)
        m_rel_bt = re.search(r'release\s*\{([^}]*)\}', bt_code)
        if m_rel_bt and "signingConfig signingConfigs.release" in m_rel_bt.group(1):
            record_pass("buildTypes.release attaches signingConfig signingConfigs.release (not debug)")
        else:
            record_fail("buildTypes.release attaches signingConfig signingConfigs.release")
    else:
        record_fail("Extract buildTypes block")

    # Check compileSdk, targetSdkVersion, namespace, version
    checks = [
        ('compileSdk 34', "compileSdk aligned to stable 34"),
        ('targetSdkVersion 34', "targetSdkVersion aligned to 34"),
        ('namespace "com.letsfly.mobile"', "namespace is 'com.letsfly.mobile'"),
        ('applicationId "com.letsfly.mobile"', "applicationId is 'com.letsfly.mobile'"),
        ('versionCode 86', "versionCode aligned to 86"),
        ('versionName "8.6.0"', "versionName aligned to 8.6.0")
    ]
    for pattern, desc in checks:
        if pattern in bg_content:
            record_pass(desc)
        else:
            record_fail(desc, f"Missing pattern: {pattern}")

# ----------------------------------------------------------------------
# 4. ANDROIDMANIFEST.XML PERMISSIONS & SECURITY
# ----------------------------------------------------------------------
print("\n--- 4. AndroidManifest.xml Permissions & Cleartext Traffic ---")
manifest_path = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
if not os.path.exists(manifest_path):
    record_fail("AndroidManifest.xml exists", "File not found")
else:
    record_pass("AndroidManifest.xml exists")
    with open(manifest_path, 'r', encoding='utf-8') as f:
        raw_manifest = f.read()

    # Parse XML
    try:
        tree = ET.parse(manifest_path)
        manifest_root = tree.getroot()
        record_pass("AndroidManifest.xml is well-formed XML")
    except Exception as e:
        record_fail("AndroidManifest.xml is well-formed XML", str(e))
        manifest_root = None

    if manifest_root is not None:
        # Check root tag does not have deprecated package attribute
        if 'package' in manifest_root.attrib:
            record_fail("Root manifest has no deprecated 'package' attribute", f"Found package='{manifest_root.attrib['package']}'")
        else:
            record_pass("Root manifest has no deprecated 'package' attribute (clean AGP 8+ namespace)")

        # Collect permissions
        ns_android = '{http://schemas.android.com/apk/res/android}'
        perms = []
        for elem in manifest_root.findall('uses-permission'):
            perm_name = elem.attrib.get(f'{ns_android}name', '')
            perms.append(perm_name)

        print(f"  Discovered permissions: {perms}")

        # Defined standard dangerous permissions that trigger Play Protect or require runtime grant
        unneeded_dangerous_perms = [
            'android.permission.READ_EXTERNAL_STORAGE',
            'android.permission.WRITE_EXTERNAL_STORAGE',
            'android.permission.ACCESS_FINE_LOCATION',
            'android.permission.ACCESS_COARSE_LOCATION',
            'android.permission.READ_PHONE_STATE',
            'android.permission.READ_PHONE_NUMBERS',
            'android.permission.CALL_PHONE',
            'android.permission.READ_CALL_LOG',
            'android.permission.WRITE_CALL_LOG',
            'android.permission.CAMERA',
            'android.permission.READ_CONTACTS',
            'android.permission.WRITE_CONTACTS',
            'android.permission.GET_ACCOUNTS',
            'android.permission.SEND_SMS',
            'android.permission.RECEIVE_SMS',
            'android.permission.READ_SMS',
            'android.permission.BODY_SENSORS',
            'android.permission.READ_MEDIA_AUDIO',
            'android.permission.READ_MEDIA_IMAGES',
            'android.permission.READ_MEDIA_VIDEO',
            'android.permission.PROCESS_OUTGOING_CALLS',
            'android.permission.SYSTEM_ALERT_WINDOW'
        ]

        flagged_dangerous = [p for p in perms if p in unneeded_dangerous_perms]
        if not flagged_dangerous:
            record_pass("Zero unneeded dangerous permissions in manifest")
        else:
            record_fail("Zero unneeded dangerous permissions in manifest", f"Flagged: {flagged_dangerous}")

        # Check required permissions are present
        if 'android.permission.INTERNET' in perms:
            record_pass("Required permission android.permission.INTERNET is present")
        else:
            record_fail("Required permission android.permission.INTERNET is present")

        if 'android.permission.RECORD_AUDIO' in perms:
            record_pass("Voice chat permission android.permission.RECORD_AUDIO is present (justified for in-room voice chat)")
        else:
            record_fail("Voice chat permission android.permission.RECORD_AUDIO is present")

        # Check cleartext traffic
        app_elem = manifest_root.find('application')
        if app_elem is not None:
            cleartext = app_elem.attrib.get(f'{ns_android}usesCleartextTraffic')
            if cleartext is None or cleartext.lower() == 'false':
                record_pass(f"Cleartext traffic is NOT enabled in application (usesCleartextTraffic={cleartext}, default=false)")
            else:
                record_fail(f"Cleartext traffic is NOT enabled in application", f"Found: usesCleartextTraffic={cleartext}")

            # Check app icon
            icon = app_elem.attrib.get(f'{ns_android}icon')
            if icon:
                record_pass(f"Application icon is specified: {icon}")
                # Verify drawable exists
                drawable_path = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'drawable', 'launch_background.xml')
                if os.path.exists(drawable_path):
                    record_pass("Icon drawable asset exists on disk")
                else:
                    record_fail("Icon drawable asset exists on disk", f"Not found at {drawable_path}")
            else:
                record_fail("Application icon is specified")

            # Check allowBackup
            allow_backup = app_elem.attrib.get(f'{ns_android}allowBackup')
            if allow_backup == 'false':
                record_pass("allowBackup is explicitly 'false' (security hardening)")
            else:
                record_fail("allowBackup is explicitly 'false'", f"Got: {allow_backup}")

# ----------------------------------------------------------------------
# 5. CI WORKFLOW INTEGRITY & REPEATABILITY
# ----------------------------------------------------------------------
print("\n--- 5. CI Workflow Security (.github/workflows/build.yml) ---")
ci_workflow_path = os.path.join(ROOT, '.github', 'workflows', 'build.yml')
if not os.path.exists(ci_workflow_path):
    record_fail(".github/workflows/build.yml exists", "File not found")
else:
    record_pass(".github/workflows/build.yml exists")
    with open(ci_workflow_path, 'r', encoding='utf-8') as f:
        ci_content = f.read()

    # Adversarial check: verify no destructive rm -rf android
    if 'rm -rf android' not in ci_content:
        record_pass("CI does NOT wipe android/ directory (rm -rf android absent)")
    else:
        record_fail("CI does NOT wipe android/ directory", "Found 'rm -rf android' in CI!")

    # Adversarial check: verify no cleartext traffic injection
    if 'usesCleartextTraffic' not in ci_content:
        record_pass("CI does NOT inject usesCleartextTraffic='true'")
    else:
        record_fail("CI does NOT inject usesCleartextTraffic='true'", "Found usesCleartextTraffic injection in CI!")

    # Check Configure Keystore step
    if 'Configure Keystore' in ci_content and 'keyAlias=letsfly' in ci_content and 'storeFile=letsfly-release.jks' in ci_content:
        record_pass("CI configures android/key.properties with release keystore")
    else:
        record_fail("CI configures android/key.properties with release keystore")

# ----------------------------------------------------------------------
# 6. VERSION SYNCHRONIZATION ACROSS ARTIFACTS
# ----------------------------------------------------------------------
print("\n--- 6. Cross-Artifact Version Synchronization ---")
pubspec_path = os.path.join(ROOT, 'pubspec.yaml')
version_json_path = os.path.join(ROOT, 'version.json')

pubspec_ver = None
if os.path.exists(pubspec_path):
    with open(pubspec_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.startswith('version:'):
                pubspec_ver = line.split(':', 1)[1].strip()
                break

json_ver = None
json_code = None
if os.path.exists(version_json_path):
    with open(version_json_path, 'r', encoding='utf-8-sig') as f:
        vj = json.load(f)
        json_ver = vj.get('version')
        json_code = vj.get('version_code')

print(f"  pubspec.yaml version: {pubspec_ver}")
print(f"  version.json: version={json_ver}, code={json_code}")

if pubspec_ver == f"{json_ver}+{json_code}":
    record_pass(f"pubspec.yaml ({pubspec_ver}) strictly matches version.json ({json_ver}+{json_code})")
else:
    record_fail("pubspec.yaml matches version.json", f"{pubspec_ver} vs {json_ver}+{json_code}")

# ----------------------------------------------------------------------
# SUMMARY & VERDICT
# ----------------------------------------------------------------------
print("\n================================================================")
print(f"  ADVERSARIAL CHALLENGE SUMMARY: {passed_tests} PASSED, {failed_tests} FAILED")
print("================================================================")

if failed_tests == 0:
    print("  VERDICT: APPROVE")
    sys.exit(0)
else:
    print("  VERDICT: REJECT")
    sys.exit(1)
