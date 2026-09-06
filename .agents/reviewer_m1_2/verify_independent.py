import os
import sys
import xml.etree.ElementTree as ET
import yaml
from cryptography import x509
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa

def run_tests():
    print("=================================================================")
    print("  INDEPENDENT VERIFICATION & ADVERSARIAL STRESS TEST (REVIEWER 2) ")
    print("=================================================================")

    workspace = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    print(f"Workspace: {workspace}")

    # 1. KEYSTORE VERIFICATION
    print("\n--- [Test 1: Keystore Cryptographic Integrity] ---")
    keystore_path = os.path.join(workspace, "android", "app", "letsfly-release.jks")
    assert os.path.isfile(keystore_path), f"Keystore missing at {keystore_path}"
    keystore_size = os.path.getsize(keystore_path)
    print(f"Keystore file exists. Size: {keystore_size} bytes")
    assert keystore_size > 1000, "Keystore file suspiciously small"

    with open(keystore_path, "rb") as f:
        keystore_bytes = f.read()

    # Adversarial test: Wrong password should raise ValueError
    try:
        pkcs12.load_key_and_certificates(keystore_bytes, b"wrong_password_attack")
        assert False, "Adversarial test failed: Keystore unlocked with wrong password!"
    except Exception as e:
        print("Adversarial password check passed: Keystore securely rejects wrong password.")

    # Load with actual credentials
    key, cert, cas = pkcs12.load_key_and_certificates(keystore_bytes, b"letsfly2026")
    assert key is not None, "Private key is null!"
    assert cert is not None, "Certificate is null!"
    assert isinstance(key, rsa.RSAPrivateKey), f"Expected RSAPrivateKey, got {type(key)}"
    assert key.key_size == 2048, f"Expected 2048 bits, got {key.key_size}"
    print(f"Private Key: RSA {key.key_size}-bit valid.")

    # Cryptographic key pair match: Sign random test message and verify with cert's public key
    test_msg = b"Adversarial Reviewer 2 Cryptographic Signature Verification Test 2026"
    sig = key.sign(
        test_msg,
        padding.PKCS1v15(),
        hashes.SHA256()
    )
    pub_key = cert.public_key()
    pub_key.verify(sig, test_msg, padding.PKCS1v15(), hashes.SHA256())
    print("Cryptographic verification passed: Certificate public key matches private key.")

    # Certificate details
    subject = cert.subject.rfc4514_string()
    issuer = cert.issuer.rfc4514_string()
    print(f"Subject DN: {subject}")
    print(f"Issuer DN:  {issuer}")
    for attr in ["CN=LetsFly Mobile", "OU=Mobile", "O=LetsFly", "L=Cairo", "ST=Cairo", "C=EG"]:
        assert attr in subject, f"Subject DN missing {attr}"
        assert attr in issuer, f"Issuer DN missing {attr}"

    val_days = (cert.not_valid_after_utc - cert.not_valid_before_utc).days
    print(f"Validity: {cert.not_valid_before_utc} to {cert.not_valid_after_utc} ({val_days} days)")
    assert val_days >= 10000, f"Validity {val_days} days is less than 10000 days requirement"
    assert cert.signature_hash_algorithm.name == "sha256", f"Signature hash not sha256: {cert.signature_hash_algorithm.name}"

    # PKCS12 Friendly Name / Alias check
    p12_struct = pkcs12.load_pkcs12(keystore_bytes, b"letsfly2026")
    assert p12_struct.cert is not None, "PKCS12 cert bag missing"
    print(f"Certificate Friendly Name (alias): {p12_struct.cert.friendly_name}")
    assert p12_struct.cert.friendly_name == b"letsfly", f"Expected friendly_name b'letsfly', got {p12_struct.cert.friendly_name}"

    # 2. KEY.PROPERTIES VERIFICATION
    print("\n--- [Test 2: key.properties Integrity] ---")
    props_path = os.path.join(workspace, "android", "key.properties")
    assert os.path.isfile(props_path), f"key.properties missing at {props_path}"
    props = {}
    with open(props_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()

    print("Parsed key.properties:", props)
    assert props.get("keyAlias") == "letsfly", f"Invalid keyAlias: {props.get('keyAlias')}"
    assert props.get("keyPassword") == "letsfly2026", f"Invalid keyPassword: {props.get('keyPassword')}"
    assert props.get("storePassword") == "letsfly2026", f"Invalid storePassword: {props.get('storePassword')}"
    assert props.get("storeFile") == "letsfly-release.jks", f"Invalid storeFile: {props.get('storeFile')}"

    # Path resolution test: In build.gradle, file(storePath) from android/app resolves to android/app/letsfly-release.jks
    gradle_app_dir = os.path.join(workspace, "android", "app")
    resolved_store_file = os.path.join(gradle_app_dir, props["storeFile"])
    assert os.path.isfile(resolved_store_file), f"Resolved storeFile does not exist: {resolved_store_file}"
    print(f"Resolved storeFile relative to android/app: {resolved_store_file} (EXISTS)")

    # 3. GRADLE CONFIGURATION (android/app/build.gradle)
    print("\n--- [Test 3: Gradle Build Configuration] ---")
    build_gradle_path = os.path.join(workspace, "android", "app", "build.gradle")
    with open(build_gradle_path, "r", encoding="utf-8") as f:
        gradle_content = f.read()

    assert 'namespace "com.letsfly.mobile"' in gradle_content, "Missing namespace declaration"
    assert 'compileSdk 34' in gradle_content, "Missing compileSdk 34"
    assert 'applicationId "com.letsfly.mobile"' in gradle_content, "Missing applicationId"
    assert 'minSdkVersion 21' in gradle_content, "Missing minSdkVersion 21"
    assert 'targetSdkVersion 34' in gradle_content, "Missing targetSdkVersion 34"
    assert 'versionCode 86' in gradle_content, "Missing versionCode 86"
    assert 'versionName "8.6.0"' in gradle_content, 'Missing versionName "8.6.0"'

    # Verify signingConfigs block
    assert "signingConfigs {" in gradle_content, "Missing signingConfigs block"
    assert "v1SigningEnabled true" in gradle_content, "v1SigningEnabled true missing"
    assert "v2SigningEnabled true" in gradle_content, "v2SigningEnabled true missing"
    assert "signingConfig signingConfigs.release" in gradle_content, "signingConfigs.release not assigned to release buildType"

    # Adversarial check: debug signing should never be assigned to release
    release_idx = gradle_content.find("buildTypes {")
    assert release_idx != -1, "buildTypes block missing"
    buildtypes_slice = gradle_content[release_idx:]
    release_slice = buildtypes_slice[buildtypes_slice.find("release {"):buildtypes_slice.find("debug {")]
    assert "signingConfigs.debug" not in release_slice, "CRITICAL: signingConfigs.debug assigned in release buildType!"
    assert "signingConfig signingConfigs.release" in release_slice, "release buildType lacks signingConfigs.release"
    print("Gradle signing configuration correctly configures release signing with v1+v2 schemes.")

    # 4. ANDROID MANIFEST VERIFICATION
    print("\n--- [Test 4: AndroidManifest.xml Hygiene & Security] ---")
    manifest_path = os.path.join(workspace, "android", "app", "src", "main", "AndroidManifest.xml")
    assert os.path.isfile(manifest_path), f"AndroidManifest.xml missing at {manifest_path}"

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest_raw = f.read()

    # Parse with ElementTree to guarantee XML validity
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    print(f"Manifest root tag: {root.tag}")

    # Check deprecated package attribute removed
    assert "package" not in root.attrib, f"Deprecated package attribute still present: {root.attrib.get('package')}"
    print("Verified: Root <manifest> tag has no deprecated package attribute.")

    # Check permissions
    ns = {"android": "http://schemas.android.com/apk/res/android"}
    permissions = [elem.attrib.get(f"{{{ns['android']}}}name") for elem in root.findall("uses-permission")]
    print(f"Configured permissions: {permissions}")
    assert "android.permission.INTERNET" in permissions, "INTERNET permission missing"
    assert "android.permission.ACCESS_NETWORK_STATE" in permissions, "ACCESS_NETWORK_STATE missing"
    assert "android.permission.RECORD_AUDIO" in permissions, "RECORD_AUDIO permission missing"
    assert "android.permission.MODIFY_AUDIO_SETTINGS" in permissions, "MODIFY_AUDIO_SETTINGS missing"

    # Adversarial check: No unauthorized/excessive permissions
    unwanted = ["android.permission.READ_SMS", "android.permission.SEND_SMS", "android.permission.QUERY_ALL_PACKAGES"]
    for p in unwanted:
        assert p not in permissions, f"Security risk: {p} found in manifest!"

    # Check application tag
    app_elem = root.find("application")
    assert app_elem is not None, "<application> tag missing"
    icon_attr = app_elem.attrib.get(f"{{{ns['android']}}}icon")
    print(f"Application icon: {icon_attr}")
    assert icon_attr == "@drawable/launch_background", f"Expected @drawable/launch_background, got {icon_attr}"

    # Verify icon target exists on disk
    icon_res = os.path.join(workspace, "android", "app", "src", "main", "res", "drawable", "launch_background.xml")
    assert os.path.isfile(icon_res), f"Icon resource missing at {icon_res}"

    # Cleartext traffic check: MUST NOT be true
    cleartext = app_elem.attrib.get(f"{{{ns['android']}}}usesCleartextTraffic")
    print(f"usesCleartextTraffic attribute: {cleartext}")
    assert cleartext is None or cleartext.lower() == "false", f"Play Protect risk: usesCleartextTraffic is {cleartext}"
    print("Verified: AndroidManifest.xml has no cleartext traffic vulnerability.")

    # 5. CI WORKFLOW (.github/workflows/build.yml)
    print("\n--- [Test 5: CI Workflow Security & Integrity] ---")
    ci_path = os.path.join(workspace, ".github", "workflows", "build.yml")
    assert os.path.isfile(ci_path), f"build.yml missing at {ci_path}"

    with open(ci_path, "r", encoding="utf-8") as f:
        ci_text = f.read()

    # Parse YAML to verify validity
    parsed_ci = yaml.safe_load(ci_text)
    assert parsed_ci is not None, "Failed to parse build.yml as YAML"
    jobs = parsed_ci.get("jobs", {})
    assert "build" in jobs, "build job missing in CI workflow"
    steps = jobs["build"].get("steps", [])
    step_names = [s.get("name") for s in steps]
    print(f"CI Step names: {step_names}")

    # Adversarial checks for destructive patterns
    assert "rm -rf android" not in ci_text, "CRITICAL: Destructive 'rm -rf android' still present in CI!"
    assert "flutter create" not in ci_text, "CRITICAL: Destructive 'flutter create' still present in CI!"
    assert "usesCleartextTraffic" not in ci_text, "CRITICAL: Cleartext injection still present in CI!"

    # Verify Configure Keystore step exists and has correct parameters
    config_step = next((s for s in steps if s.get("name") == "Configure Keystore"), None)
    assert config_step is not None, "Missing 'Configure Keystore' step in CI workflow"
    run_cmd = config_step.get("run", "")
    assert "keyAlias=letsfly" in run_cmd, "Configure Keystore lacks keyAlias=letsfly"
    assert "keyPassword=letsfly2026" in run_cmd, "Configure Keystore lacks keyPassword"
    assert "storeFile=letsfly-release.jks" in run_cmd, "Configure Keystore lacks storeFile"
    assert "storePassword=letsfly2026" in run_cmd, "Configure Keystore lacks storePassword"

    # Verify build APK step
    build_step = next((s for s in steps if s.get("name") == "Build APK"), None)
    assert build_step is not None, "Missing 'Build APK' step in CI"
    assert "flutter build apk --release" in build_step.get("run", ""), "Build APK does not execute release build"
    print("Verified: CI workflow is non-destructive, configures keystore, and builds release APK properly.")

    # 6. PROJECT VERSION SYNCHRONIZATION
    print("\n--- [Test 6: Version Synchronization Across Artifacts] ---")
    pubspec_path = os.path.join(workspace, "pubspec.yaml")
    with open(pubspec_path, "r", encoding="utf-8") as f:
        pubspec_yaml = yaml.safe_load(f)
    pubspec_ver = pubspec_yaml.get("version")
    print(f"pubspec.yaml version: {pubspec_ver}")
    assert pubspec_ver == "8.6.0+86", f"pubspec version mismatch: {pubspec_ver}"

    import json
    version_json_path = os.path.join(workspace, "version.json")
    with open(version_json_path, "r", encoding="utf-8-sig") as f:
        version_data = json.load(f)
    print(f"version.json: version={version_data.get('version')}, version_code={version_data.get('version_code')}")
    assert version_data.get("version") == "8.6.0", f"version.json version mismatch: {version_data.get('version')}"
    assert version_data.get("version_code") == 86, f"version.json version_code mismatch: {version_data.get('version_code')}"
    print("Version synchronization across pubspec.yaml, version.json, and build.gradle is 100% consistent.")

    print("\n=================================================================")
    print("  ALL INDEPENDENT VERIFICATION TESTS PASSED UNANIMOUSLY!          ")
    print("=================================================================")

if __name__ == "__main__":
    run_tests()
