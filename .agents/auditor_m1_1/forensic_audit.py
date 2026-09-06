import os
import sys
import datetime
import traceback
from pathlib import Path
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import hashes
from cryptography import x509

def main():
    root = Path(r"C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile")
    print(f"Auditing root: {root}")
    
    failures = []
    checks = []

    # -------------------------------------------------------------
    # Check 1: Genuine PKCS12 Keystore Verification
    # -------------------------------------------------------------
    print("\n--- Check 1: android/app/letsfly-release.jks Integrity ---")
    keystore_path = root / "android" / "app" / "letsfly-release.jks"
    if not keystore_path.exists():
        failures.append("Keystore file android/app/letsfly-release.jks does not exist!")
    else:
        file_size = keystore_path.stat().st_size
        print(f"Keystore file exists, size: {file_size} bytes")
        if file_size < 500:
            failures.append(f"Keystore file is suspiciously small ({file_size} bytes). Possible dummy/stub.")
        
        # Read binary
        with open(keystore_path, "rb") as f:
            keystore_data = f.read()

        # 1a. Test decryption with wrong password (must fail)
        try:
            pkcs12.load_key_and_certificates(keystore_data, b"wrong_password_intentionally")
            failures.append("Keystore decrypted with WRONG password! It might be unencrypted or a mocked dummy.")
        except Exception as e:
            print(f"Confirmed keystore rejects wrong password: {type(e).__name__}")

        # 1b. Test decryption with genuine password
        try:
            private_key, cert, additional_certs = pkcs12.load_key_and_certificates(keystore_data, b"letsfly2026")
            if private_key is None:
                failures.append("PKCS12 loaded but contained no private key!")
            if cert is None:
                failures.append("PKCS12 loaded but contained no certificate!")

            print(f"Keystore successfully decrypted with 'letsfly2026'")
            
            # Check private key properties
            if not isinstance(private_key, rsa.RSAPrivateKey):
                failures.append(f"Private key is not RSA, found: {type(private_key)}")
            else:
                key_size = private_key.key_size
                pub_exp = private_key.public_key().public_numbers().e
                print(f"RSA Private Key: {key_size}-bit, public exponent={pub_exp}")
                if key_size != 2048:
                    failures.append(f"Expected 2048-bit RSA key, found {key_size}")
                if pub_exp != 65537:
                    failures.append(f"Expected RSA public exponent 65537, found {pub_exp}")

            # Check certificate properties
            if cert is not None:
                subject_str = cert.subject.rfc4514_string()
                issuer_str = cert.issuer.rfc4514_string()
                print(f"Certificate Subject: {subject_str}")
                print(f"Certificate Issuer:  {issuer_str}")
                
                # Check DN components
                dn_dict = {attr.oid._name: attr.value for attr in cert.subject}
                print(f"Parsed Subject DN attributes: {dn_dict}")
                if dn_dict.get("commonName") != "LetsFly Mobile":
                    failures.append(f"CN mismatch: expected 'LetsFly Mobile', got '{dn_dict.get('commonName')}'")
                if dn_dict.get("organizationName") != "LetsFly":
                    failures.append(f"O mismatch: expected 'LetsFly', got '{dn_dict.get('organizationName')}'")

                # Check validity
                # Cryptography 42+ uses not_valid_before_utc / not_valid_after_utc
                try:
                    nvb = cert.not_valid_before_utc
                    nva = cert.not_valid_after_utc
                except AttributeError:
                    nvb = cert.not_valid_before
                    nva = cert.not_valid_after
                print(f"Certificate Validity: from {nvb} to {nva}")
                duration_days = (nva - nvb).days
                print(f"Validity duration: {duration_days} days")
                if duration_days < 365 * 20:
                    failures.append(f"Certificate validity duration is too short: {duration_days} days")

                # Check signature hash
                sig_hash = cert.signature_hash_algorithm.name
                print(f"Signature Hash Algorithm: {sig_hash}")
                if sig_hash.lower() != "sha256":
                    failures.append(f"Expected sha256 signature hash algorithm, got {sig_hash}")

                # Check cryptographic matching between private key and cert public key
                test_message = b"Let's Fly Android APK Release Signing Integrity Verification 2026"
                signature = private_key.sign(
                    test_message,
                    padding.PKCS1v15(),
                    hashes.SHA256()
                )
                # Verify using certificate's public key
                cert_pubkey = cert.public_key()
                try:
                    cert_pubkey.verify(
                        signature,
                        test_message,
                        padding.PKCS1v15(),
                        hashes.SHA256()
                    )
                    print("Cryptographic signature verification: MATCHED! Private key corresponds to Certificate public key.")
                except Exception as ve:
                    failures.append(f"Cryptographic signature verification failed: {ve}")

                # Test corrupted signature rejects
                bad_sig = bytearray(signature)
                bad_sig[10] ^= 0xFF
                try:
                    cert_pubkey.verify(
                        bytes(bad_sig),
                        test_message,
                        padding.PKCS1v15(),
                        hashes.SHA256()
                    )
                    failures.append("Corrupted signature was NOT rejected! Cryptographic library failure or mock.")
                except Exception:
                    print("Confirmed corrupted signature is properly rejected.")

        except Exception as e:
            traceback.print_exc()
            failures.append(f"Failed to decrypt/load keystore: {e}")

    checks.append(("Keystore Genuine PKCS12", len(failures) == 0))

    # -------------------------------------------------------------
    # Check 2: android/key.properties Configuration
    # -------------------------------------------------------------
    print("\n--- Check 2: android/key.properties Configuration ---")
    prop_failures = []
    prop_path = root / "android" / "key.properties"
    if not prop_path.exists():
        prop_failures.append("android/key.properties does not exist!")
    else:
        props = {}
        with open(prop_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    props[k.strip()] = v.strip()

        print(f"Loaded properties: {props}")
        required_keys = {"storePassword", "keyPassword", "keyAlias", "storeFile"}
        missing = required_keys - set(props.keys())
        if missing:
            prop_failures.append(f"Missing keys in key.properties: {missing}")

        if props.get("storePassword") != "letsfly2026":
            prop_failures.append(f"Incorrect storePassword: {props.get('storePassword')}")
        if props.get("keyPassword") != "letsfly2026":
            prop_failures.append(f"Incorrect keyPassword: {props.get('keyPassword')}")
        if props.get("keyAlias") != "letsfly":
            prop_failures.append(f"Incorrect keyAlias: {props.get('keyAlias')}")
        
        store_file_val = props.get("storeFile", "")
        # Resolve as Gradle does:
        # In build.gradle: file(storePath).exists() ? file(storePath) : rootProject.file(storePath)
        # Note: in Gradle, 'file(storePath)' is relative to android/app (the project dir)
        app_dir = root / "android" / "app"
        android_dir = root / "android"
        resolved_app = app_dir / store_file_val
        resolved_root = android_dir / store_file_val
        if resolved_app.exists():
            print(f"storeFile resolved relative to android/app: {resolved_app} (EXISTS)")
        elif resolved_root.exists():
            print(f"storeFile resolved relative to android (rootProject): {resolved_root} (EXISTS)")
        else:
            prop_failures.append(f"storeFile '{store_file_val}' cannot be resolved to an existing file!")

    failures.extend(prop_failures)
    checks.append(("key.properties Valid Configuration", len(prop_failures) == 0))

    # -------------------------------------------------------------
    # Check 3: android/app/build.gradle Configuration
    # -------------------------------------------------------------
    print("\n--- Check 3: android/app/build.gradle Signing Config ---")
    gradle_failures = []
    gradle_path = root / "android" / "app" / "build.gradle"
    if not gradle_path.exists():
        gradle_failures.append("android/app/build.gradle does not exist!")
    else:
        with open(gradle_path, "r", encoding="utf-8") as f:
            gradle_content = f.read()

        # Check key.properties loading
        if "rootProject.file('key.properties')" not in gradle_content and 'rootProject.file("key.properties")' not in gradle_content:
            gradle_failures.append("build.gradle does not load rootProject.file('key.properties')")
        else:
            print("Confirmed build.gradle loads key.properties")

        # Check signingConfigs block
        if "signingConfigs {" not in gradle_content:
            gradle_failures.append("signingConfigs block missing from build.gradle")
        
        if "release {" not in gradle_content:
            gradle_failures.append("release signingConfig missing from build.gradle")

        if "v1SigningEnabled true" not in gradle_content:
            gradle_failures.append("v1SigningEnabled true missing from release signingConfig")

        if "v2SigningEnabled true" not in gradle_content:
            gradle_failures.append("v2SigningEnabled true missing from release signingConfig")

        # Check buildTypes.release.signingConfig
        # Look for signingConfig signingConfigs.release inside buildTypes { release { ... } }
        import re
        build_types_match = re.search(r"buildTypes\s*\{([\s\S]*?)\}\s*\}", gradle_content)
        if not build_types_match:
            gradle_failures.append("Could not find buildTypes block in build.gradle")
        else:
            build_types_body = build_types_match.group(1)
            release_block_match = re.search(r"release\s*\{([\s\S]*?)\}", build_types_body)
            if not release_block_match:
                gradle_failures.append("Could not find release block in buildTypes")
            else:
                release_body = release_block_match.group(1)
                print(f"buildTypes.release body:\n{release_body.strip()}")
                if "signingConfig signingConfigs.release" not in release_body:
                    gradle_failures.append("buildTypes.release does NOT bind 'signingConfig signingConfigs.release'!")
                if "signingConfig signingConfigs.debug" in release_body:
                    gradle_failures.append("buildTypes.release still binds 'signingConfig signingConfigs.debug'!")

        # Check SDK and versions
        if "compileSdk 34" not in gradle_content:
            gradle_failures.append("compileSdk 34 missing or different in build.gradle")
        if "targetSdkVersion 34" not in gradle_content:
            gradle_failures.append("targetSdkVersion 34 missing or different in build.gradle")
        if "versionCode 86" not in gradle_content:
            gradle_failures.append("versionCode 86 missing in build.gradle")
        if 'versionName "8.6.0"' not in gradle_content:
            gradle_failures.append('versionName "8.6.0" missing in build.gradle')

    failures.extend(gradle_failures)
    checks.append(("build.gradle Signing Config Genuine Binding", len(gradle_failures) == 0))

    # -------------------------------------------------------------
    # Check 4: AndroidManifest.xml and CI build.yml
    # -------------------------------------------------------------
    print("\n--- Check 4: AndroidManifest.xml and CI build.yml ---")
    manifest_failures = []
    manifest_path = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest_path.exists():
        manifest_failures.append("AndroidManifest.xml does not exist")
    else:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_content = f.read()
        
        # Check no package attribute on root manifest
        root_manifest_match = re.search(r"<manifest\s+[^>]*>", manifest_content)
        if root_manifest_match and 'package=' in root_manifest_match.group(0):
            manifest_failures.append(f"Deprecated package attribute still present in <manifest>: {root_manifest_match.group(0)}")
        else:
            print("Confirmed <manifest> tag has no deprecated package attribute.")

        # Check usesCleartextTraffic is not true
        if 'android:usesCleartextTraffic="true"' in manifest_content:
            manifest_failures.append("android:usesCleartextTraffic='true' found in AndroidManifest.xml")
        else:
            print("Confirmed no android:usesCleartextTraffic='true' in manifest.")

        # Check application icon
        if 'android:icon=' not in manifest_content:
            manifest_failures.append("android:icon is missing from AndroidManifest.xml")
        else:
            print("Confirmed android:icon is specified in AndroidManifest.xml")

    # CI workflow
    ci_path = root / ".github" / "workflows" / "build.yml"
    if not ci_path.exists():
        manifest_failures.append(".github/workflows/build.yml does not exist")
    else:
        with open(ci_path, "r", encoding="utf-8") as f:
            ci_content = f.read()

        if "rm -rf android" in ci_content:
            manifest_failures.append("Destructive 'rm -rf android' still present in build.yml")
        if "flutter create" in ci_content:
            manifest_failures.append("Destructive 'flutter create' still present in build.yml")
        if "usesCleartextTraffic" in ci_content:
            manifest_failures.append("Cleartext traffic injection still present in build.yml")
        print("Confirmed CI workflow does not destroy android directory or inject cleartext traffic.")

    failures.extend(manifest_failures)
    checks.append(("Manifest Hygiene and CI Workflow Non-Destructive", len(manifest_failures) == 0))

    # -------------------------------------------------------------
    # Check 5: Anti-Cheating, Facades, Pre-populated Mock Artifacts
    # -------------------------------------------------------------
    print("\n--- Check 5: Anti-Cheating, Facades, and Pre-populated Artifacts ---")
    cheat_failures = []
    
    # Check for suspicious mock files, stub certificates, hardcoded dummy returns
    suspicious_patterns = [
        "mock_keystore", "dummy_keystore", "fake_keystore", "mock_cert", "test_cert_stub"
    ]
    for pattern in suspicious_patterns:
        matches = list(root.glob(f"**/*{pattern}*"))
        if matches:
            cheat_failures.append(f"Found suspicious file matching '{pattern}': {matches}")

    # Check worker_m1 directory for pre-populated logs or fabricated attestation
    worker_dir = root / ".agents" / "worker_m1"
    if worker_dir.exists():
        print(f"Inspecting worker_m1 folder: {[f.name for f in worker_dir.iterdir()]}")
        # Verify worker's verify_m1.py against actual files
        verify_script = worker_dir / "verify_m1.py"
        if verify_script.exists():
            with open(verify_script, "r", encoding="utf-8") as f:
                v_content = f.read()
            # Ensure it does not contain fake mocks like `return True` or bypass
            if "def verify_keystore" in v_content:
                if "return True" in v_content and "pkcs12" not in v_content:
                    cheat_failures.append("worker verify_m1.py uses fake verify_keystore mock!")
                else:
                    print("worker verify_m1.py uses genuine cryptography verification logic.")

    failures.extend(cheat_failures)
    checks.append(("Anti-Cheating and No Facades", len(cheat_failures) == 0))

    # -------------------------------------------------------------
    # SUMMARY
    # -------------------------------------------------------------
    print("\n========================================================")
    print("AUDIT SUMMARY:")
    for name, passed in checks:
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {name}")
    print("========================================================")

    if failures:
        print("\nINTEGRITY VIOLATION DETECTED! Failures:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    else:
        print("\nAUDIT VERDICT: CLEAN")
        sys.exit(0)

if __name__ == "__main__":
    main()
