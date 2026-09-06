import os
import re
import datetime
from cryptography import x509
from cryptography.hazmat.primitives.serialization import pkcs12

print("=== 1. VERIFY KEYSTORE (android/app/letsfly-release.jks) ===")
jks_path = os.path.join("android", "app", "letsfly-release.jks")
assert os.path.exists(jks_path), f"Keystore does not exist at {jks_path}!"
size = os.path.getsize(jks_path)
print(f"File exists: {jks_path} (size: {size} bytes)")
assert size > 0, "Keystore file is empty!"

with open(jks_path, "rb") as f:
    jks_bytes = f.read()

key, cert, cas = pkcs12.load_key_and_certificates(jks_bytes, b"letsfly2026")
assert key is not None, "Failed to extract private key!"
assert cert is not None, "Failed to extract certificate!"
print(f"Private Key Type: RSA {key.key_size}-bit")
assert key.key_size == 2048, f"Expected 2048-bit key, got {key.key_size}"

subject_dn = cert.subject.rfc4514_string()
issuer_dn = cert.issuer.rfc4514_string()
print(f"Certificate Subject: {subject_dn}")
print(f"Certificate Issuer:  {issuer_dn}")
assert "CN=LetsFly Mobile" in subject_dn, "CN mismatch"
assert "O=LetsFly" in subject_dn, "O mismatch"
assert "OU=Mobile" in subject_dn, "OU mismatch"
assert "L=Cairo" in subject_dn, "L mismatch"
assert "ST=Cairo" in subject_dn, "ST mismatch"
assert "C=EG" in subject_dn, "C mismatch"

val_days = (cert.not_valid_after_utc - cert.not_valid_before_utc).days
print(f"Validity: {cert.not_valid_before_utc} to {cert.not_valid_after_utc} ({val_days} days)")
assert val_days >= 10000, f"Expected at least 10000 days validity, got {val_days}"
print(f"Signature Hash Algorithm: {cert.signature_hash_algorithm.name}")
assert cert.signature_hash_algorithm.name == "sha256", "Expected sha256"

print("\n=== 2. VERIFY KEY.PROPERTIES (android/key.properties) ===")
props_path = os.path.join("android", "key.properties")
assert os.path.exists(props_path), "key.properties missing!"
with open(props_path, "r", encoding="utf-8") as f:
    props_text = f.read()
print(props_text.strip())
assert "storePassword=letsfly2026" in props_text
assert "keyPassword=letsfly2026" in props_text
assert "keyAlias=letsfly" in props_text
assert "storeFile=letsfly-release.jks" in props_text

# Check path resolution relative to android/app
resolved_store = os.path.normpath(os.path.join("android", "app", "letsfly-release.jks"))
assert os.path.exists(resolved_store), f"Relative storeFile does not resolve: {resolved_store}"
print(f"Resolved storeFile path: {resolved_store} (EXISTS)")

print("\n=== 3. VERIFY BUILD.GRADLE (android/app/build.gradle) ===")
gradle_path = os.path.join("android", "app", "build.gradle")
with open(gradle_path, "r", encoding="utf-8") as f:
    gradle_text = f.read()

assert 'compileSdk 34' in gradle_text, "compileSdk 34 missing"
assert 'versionCode 86' in gradle_text, "versionCode 86 missing"
assert 'versionName "8.6.0"' in gradle_text, 'versionName "8.6.0" missing'
assert 'signingConfigs {' in gradle_text, "signingConfigs missing"
assert 'v1SigningEnabled true' in gradle_text, "v1SigningEnabled missing"
assert 'v2SigningEnabled true' in gradle_text, "v2SigningEnabled missing"
assert 'signingConfig signingConfigs.release' in gradle_text, "signingConfig signingConfigs.release missing"
release_block = gradle_text.split("buildTypes {")[1].split("release {")[1].split("}")[0]
assert 'signingConfig signingConfigs.debug' not in release_block, "debug signing still in release buildType!"
print("build.gradle syntax and signing config: PASSED")

print("\n=== 4. VERIFY ANDROIDMANIFEST.XML (android/app/src/main/AndroidManifest.xml) ===")
manifest_path = os.path.join("android", "app", "src", "main", "AndroidManifest.xml")
with open(manifest_path, "r", encoding="utf-8") as f:
    manifest_text = f.read()

assert "package=" not in manifest_text, "Deprecated package attribute still present!"
assert 'android:icon="@drawable/launch_background"' in manifest_text, "android:icon missing!"
assert 'usesCleartextTraffic="true"' not in manifest_text, "usesCleartextTraffic=true found!"
assert "android.permission.INTERNET" in manifest_text
assert "android.permission.RECORD_AUDIO" in manifest_text
print("AndroidManifest.xml hygiene checks: PASSED")

print("\n=== 5. VERIFY CI WORKFLOW (.github/workflows/build.yml) ===")
ci_path = os.path.join(".github", "workflows", "build.yml")
with open(ci_path, "r", encoding="utf-8") as f:
    ci_text = f.read()

assert "rm -rf android" not in ci_text, "Destructive rm -rf android still present!"
assert "flutter create" not in ci_text, "Destructive flutter create still present!"
assert "usesCleartextTraffic" not in ci_text, "Cleartext injection still present!"
assert "Configure Keystore" in ci_text, "Configure Keystore step missing!"
print("CI workflow verification: PASSED")

print("\n=== 6. VERIFY VERSION SYNCHRONIZATION ===")
with open("pubspec.yaml", "r", encoding="utf-8") as f:
    pubspec_text = f.read()
with open("version.json", "r", encoding="utf-8") as f:
    version_json_text = f.read()

assert "version: 8.6.0+86" in pubspec_text, "pubspec version mismatch"
assert '"version": "8.6.0"' in version_json_text, "version.json version mismatch"
assert '"version_code": 86' in version_json_text, "version.json version_code mismatch"
print("Version synchronization (8.6.0+86): PASSED")

print("\n>>> ALL MILESTONE 1 VERIFICATION CHECKS PASSED SUCCESSFULLY! <<<")
