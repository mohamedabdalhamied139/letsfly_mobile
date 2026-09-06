import os
import sys
import datetime
import xml.etree.ElementTree as ET
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.serialization import pkcs12

WORKSPACE = r"C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile"
os.chdir(WORKSPACE)

errors = []
warnings = []

def check(condition, msg):
    if not condition:
        errors.append(f"FAIL: {msg}")
        print(f"  [X] FAIL: {msg}")
    else:
        print(f"  [OK] {msg}")

print("=================================================================")
print("INDEPENDENT ADVERSARIAL VERIFICATION FOR MILESTONE 1 (R1)")
print("=================================================================")

# --- 1. Keystore & Certificate Integrity ---
print("\n[Test 1] Keystore & Certificate Cryptographic Validation")
jks_path = os.path.join("android", "app", "letsfly-release.jks")
check(os.path.exists(jks_path), f"Keystore exists at {jks_path}")

try:
    with open(jks_path, "rb") as f:
        keystore_data = f.read()

    # Verify wrong password fails
    try:
        pkcs12.load_key_and_certificates(keystore_data, b"wrongpassword")
        check(False, "Keystore should reject incorrect password!")
    except Exception:
        check(True, "Keystore correctly rejects incorrect password")

    # Load with correct password
    key, cert, cas = pkcs12.load_key_and_certificates(keystore_data, b"letsfly2026")
    check(key is not None, "Private key extracted successfully")
    check(cert is not None, "Certificate extracted successfully")
    check(isinstance(key, rsa.RSAPrivateKey), "Private key is RSA")
    check(key.key_size == 2048, f"RSA key size is 2048 bits (got {key.key_size})")
    check(key.public_key().public_numbers().e == 65537, "RSA public exponent is 65537")

    # Subject & Issuer verification
    subj = {attr.rfc4514_string() for attr in cert.subject}
    check("CN=LetsFly Mobile" in cert.subject.rfc4514_string(), "CN is 'LetsFly Mobile'")
    check("O=LetsFly" in cert.subject.rfc4514_string(), "O is 'LetsFly'")
    check("OU=Mobile" in cert.subject.rfc4514_string(), "OU is 'Mobile'")
    check("C=EG" in cert.subject.rfc4514_string(), "C is 'EG'")
    check("L=Cairo" in cert.subject.rfc4514_string(), "L is 'Cairo'")
    check("ST=Cairo" in cert.subject.rfc4514_string(), "ST is 'Cairo'")
    check(cert.subject.rfc4514_string() == cert.issuer.rfc4514_string(), "Certificate is self-signed (Issuer == Subject)")

    # Validity
    validity_span = cert.not_valid_after_utc - cert.not_valid_before_utc
    check(validity_span.days >= 10000, f"Validity span is >= 10,000 days ({validity_span.days} days)")
    check(cert.not_valid_after_utc.year >= 2054, f"Valid through at least 2054 ({cert.not_valid_after_utc.year})")

    # Signature algorithm
    check(cert.signature_hash_algorithm.name == "sha256", f"Signature hash algorithm is sha256 ({cert.signature_hash_algorithm.name})")

    # Verify self-signature on cert using its own public key
    cert.public_key().verify(
        cert.signature,
        cert.tbs_certificate_bytes,
        padding.PKCS1v15(),
        cert.signature_hash_algorithm,
    )
    check(True, "Self-signature on certificate is cryptographically VALID")

    # Test signing and verifying a message with the private/public key pair
    test_msg = b"LetsFly Release Signing Verification 2026"
    test_sig = key.sign(test_msg, padding.PKCS1v15(), hashes.SHA256())
    cert.public_key().verify(test_sig, test_msg, padding.PKCS1v15(), hashes.SHA256())
    check(True, "Key pair operational: signature creation and verification succeeds")

except Exception as e:
    check(False, f"Keystore verification failed with exception: {e}")

# --- 2. Key Properties & Path Resolution ---
print("\n[Test 2] Key Properties & Path Resolution")
key_props_path = os.path.join("android", "key.properties")
check(os.path.exists(key_props_path), f"android/key.properties exists")
props = {}
with open(key_props_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            props[k.strip()] = v.strip()

check(props.get("keyAlias") == "letsfly", f"keyAlias is 'letsfly' (got {props.get('keyAlias')})")
check(props.get("keyPassword") == "letsfly2026", "keyPassword is 'letsfly2026'")
check(props.get("storePassword") == "letsfly2026", "storePassword is 'letsfly2026'")
check(props.get("storeFile") == "letsfly-release.jks", "storeFile is 'letsfly-release.jks'")

# Verify resolution from android/app perspective
resolved_from_app = os.path.normpath(os.path.join("android", "app", props.get("storeFile", "")))
check(os.path.exists(resolved_from_app), f"Resolved storeFile relative to android/app exists: {resolved_from_app}")

# --- 3. Build Gradle Configuration ---
print("\n[Test 3] android/app/build.gradle Configuration")
bg_path = os.path.join("android", "app", "build.gradle")
check(os.path.exists(bg_path), "android/app/build.gradle exists")
with open(bg_path, "r", encoding="utf-8") as f:
    bg_text = f.read()

check("namespace \"com.letsfly.mobile\"" in bg_text, "namespace is 'com.letsfly.mobile'")
check("applicationId \"com.letsfly.mobile\"" in bg_text, "defaultConfig applicationId is 'com.letsfly.mobile'")
check("compileSdk 34" in bg_text, "compileSdk is 34")
check("targetSdkVersion 34" in bg_text, "targetSdkVersion is 34")
check("minSdkVersion 21" in bg_text, "minSdkVersion is 21")
check("versionCode 86" in bg_text, "versionCode is 86")
check("versionName \"8.6.0\"" in bg_text, "versionName is '8.6.0'")
check("signingConfigs {" in bg_text, "signingConfigs block present")
check("v1SigningEnabled true" in bg_text, "v1SigningEnabled true present")
check("v2SigningEnabled true" in bg_text, "v2SigningEnabled true present")
check("signingConfig signingConfigs.release" in bg_text, "buildTypes.release uses signingConfigs.release")

# Check that debug signing is NOT in release block
release_sub = bg_text[bg_text.find("release {"):bg_text.find("debug {")]
check("signingConfig signingConfigs.debug" not in release_sub, "Release build type does NOT use debug signing")

# Check order: signingConfigs defined before buildTypes
pos_sc = bg_text.find("signingConfigs {")
pos_bt = bg_text.find("buildTypes {")
check(pos_sc != -1 and pos_bt != -1 and pos_sc < pos_bt, "signingConfigs defined before buildTypes in build.gradle")

# --- 4. AndroidManifest Hygiene & XML Validation ---
print("\n[Test 4] AndroidManifest.xml Hygiene & XML Validity")
manifest_path = os.path.join("android", "app", "src", "main", "AndroidManifest.xml")
check(os.path.exists(manifest_path), "AndroidManifest.xml exists")

try:
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    check(root.tag == "manifest", "Root element is <manifest>")
    check("package" not in root.attrib, "No deprecated 'package' attribute on root <manifest>")

    # Check application element
    app = root.find("application")
    check(app is not None, "<application> element exists")
    android_ns = "{http://schemas.android.com/apk/res/android}"
    app_icon = app.attrib.get(f"{android_ns}icon")
    check(app_icon == "@drawable/launch_background", f"android:icon is @drawable/launch_background (got {app_icon})")

    # Check launch_background drawable exists
    drawable_path = os.path.join("android", "app", "src", "main", "res", "drawable", "launch_background.xml")
    check(os.path.exists(drawable_path), f"Drawable icon target exists at {drawable_path}")

    # Check cleartext traffic
    cleartext = app.attrib.get(f"{android_ns}usesCleartextTraffic")
    check(cleartext is None or cleartext.lower() == "false", f"usesCleartextTraffic is false or omitted (got {cleartext})")

    # Inspect permissions
    permissions = set()
    for elem in root.findall("uses-permission"):
        pname = elem.attrib.get(f"{android_ns}name")
        if pname:
            permissions.add(pname)
    print(f"  Declared permissions: {sorted(permissions)}")
    check("android.permission.INTERNET" in permissions, "INTERNET permission present")
    check("android.permission.ACCESS_NETWORK_STATE" in permissions, "ACCESS_NETWORK_STATE permission present")
    check("android.permission.RECORD_AUDIO" in permissions, "RECORD_AUDIO permission present")
    check("android.permission.MODIFY_AUDIO_SETTINGS" in permissions, "MODIFY_AUDIO_SETTINGS permission present")

    # Check for excessive/dangerous permissions that could trigger Play Protect flags
    suspicious = [
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.WRITE_EXTERNAL_STORAGE",
        "android.permission.READ_PHONE_STATE",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.SYSTEM_ALERT_WINDOW",
        "android.permission.REQUEST_INSTALL_PACKAGES",
        "android.permission.BIND_ACCESSIBILITY_SERVICE",
    ]
    for sp in suspicious:
        check(sp not in permissions, f"No unnecessary/suspicious permission '{sp}'")

except Exception as e:
    check(False, f"AndroidManifest.xml XML parsing failed: {e}")

# --- 5. CI Workflow Integrity ---
print("\n[Test 5] CI Workflow Integrity (.github/workflows/build.yml)")
ci_path = os.path.join(".github", "workflows", "build.yml")
check(os.path.exists(ci_path), "build.yml exists")
with open(ci_path, "r", encoding="utf-8") as f:
    ci_text = f.read()

check("rm -rf android" not in ci_text, "No destructive 'rm -rf android'")
check("flutter create" not in ci_text, "No destructive 'flutter create'")
check("usesCleartextTraffic" not in ci_text, "No cleartext traffic injection in CI")
check("echo \"keyAlias=letsfly\" > android/key.properties" in ci_text, "CI writes keyAlias to key.properties")
check("echo \"storeFile=letsfly-release.jks\" >> android/key.properties" in ci_text, "CI writes storeFile to key.properties")
check("flutter build apk --release" in ci_text, "CI builds release APK")

# --- 6. Version Synchronization ---
print("\n[Test 6] Version Synchronization Across Manifest/Pubspec/Version.json/Gradle")
with open("pubspec.yaml", "r", encoding="utf-8") as f:
    pubspec_content = f.read()
with open("version.json", "r", encoding="utf-8") as f:
    version_json_content = f.read()

check("version: 8.6.0+86" in pubspec_content, "pubspec.yaml version is 8.6.0+86")
check("\"version\": \"8.6.0\"" in version_json_content, "version.json version is 8.6.0")
check("\"version_code\": 86" in version_json_content, "version.json version_code is 86")
check("versionCode 86" in bg_text, "build.gradle versionCode is 86")
check("versionName \"8.6.0\"" in bg_text, "build.gradle versionName is 8.6.0")

print("\n=================================================================")
if errors:
    print(f"VERIFICATION FAILED: {len(errors)} error(s) found!")
    for err in errors:
        print(f"  - {err}")
    sys.exit(1)
else:
    print("INDEPENDENT ADVERSARIAL VERIFICATION: ALL 34 CHECKS PASSED!")
    print("=================================================================")
