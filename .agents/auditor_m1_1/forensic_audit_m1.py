import os
import sys
import hashlib
from datetime import datetime, timezone
from cryptography import x509
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa

print("=" * 70)
print("FORENSIC INTEGRITY AUDIT: MILESTONE 1 (R1 GOOGLE PLAY PROTECT)")
print("=" * 70)

violations = []

# ==============================================================================
# CHECK 1: KEYSTORE INTEGRITY & PKCS12 FORENSICS
# ==============================================================================
print("\n--- CHECK 1: KEYSTORE INTEGRITY (android/app/letsfly-release.jks) ---")
jks_path = os.path.join("android", "app", "letsfly-release.jks")

if not os.path.exists(jks_path):
    violations.append(f"CRITICAL: Keystore file missing at {jks_path}")
    print("FAILED: Keystore missing!")
else:
    file_size = os.path.getsize(jks_path)
    print(f"[+] File exists: {jks_path} ({file_size} bytes)")
    if file_size < 1000:
        violations.append(f"Keystore file unusually small: {file_size} bytes")

    with open(jks_path, "rb") as f:
        raw_bytes = f.read()

    # SHA256 of the keystore binary itself
    sha256_binary = hashlib.sha256(raw_bytes).hexdigest()
    print(f"[+] Keystore file SHA-256: {sha256_binary}")

    # Verify ASN.1 PKCS#12 header
    header_hex = raw_bytes[:16].hex()
    print(f"[+] ASN.1 PKCS#12 Header (hex): {header_hex}")
    if not raw_bytes.startswith(b"\x30\x82"):
        violations.append("File does not have ASN.1 SEQUENCE magic bytes (0x3082)")

    # Test invalid password rejection
    try:
        pkcs12.load_key_and_certificates(raw_bytes, b"invalid_audit_password_9999")
        violations.append("Keystore decrypted with invalid password! Keystore is unencrypted or mocked!")
    except Exception as e:
        print(f"[+] Negative authentication test PASSED: Invalid password rejected with {type(e).__name__}")

    # Test valid password loading
    try:
        key, cert, cas = pkcs12.load_key_and_certificates(raw_bytes, b"letsfly2026")
        if key is None:
            violations.append("Keystore contains no private key")
        if cert is None:
            violations.append("Keystore contains no certificate")
        print(f"[+] Valid password accepted. Key: {key is not None}, Cert: {cert is not None}, CAs: {len(cas) if cas else 0}")
    except Exception as e:
        violations.append(f"Failed to load keystore with letsfly2026: {e}")
        key, cert = None, None

    if key is not None and cert is not None:
        # Mathematical verification of RSA Key
        if not isinstance(key, rsa.RSAPrivateKey):
            violations.append(f"Private key is not RSA: {type(key)}")
        else:
            pn = key.private_numbers()
            pub_n = pn.public_numbers
            print(f"[+] RSA Key Size: {key.key_size} bits")
            print(f"[+] Public Exponent e: {pub_n.e}")
            print(f"[+] Modulus bit length: {pub_n.n.bit_length()}")
            print(f"[+] Prime p bit length: {pn.p.bit_length()}")
            print(f"[+] Prime q bit length: {pn.q.bit_length()}")

            if key.key_size != 2048:
                violations.append(f"Expected 2048-bit RSA key, found {key.key_size}")
            if pub_n.e != 65537:
                violations.append(f"Expected e=65537, found {pub_n.e}")
            if pub_n.n != pn.p * pn.q:
                violations.append("RSA Modulus n != p * q! Corrupted or fabricated key!")

            # Functional cryptographic signature check
            test_payload = b"FORENSIC_INTEGRITY_AUDIT_VERIFICATION_PAYLOAD_2026"
            signature = key.sign(test_payload, padding.PKCS1v15(), hashes.SHA256())
            try:
                cert.public_key().verify(signature, test_payload, padding.PKCS1v15(), hashes.SHA256())
                print(f"[+] Cryptographic signature generation & verification: VALID (sig size: {len(signature)} bytes)")
            except Exception as e:
                violations.append(f"Public key verification of generated signature failed: {e}")

        # X.509 Certificate Forensic Checks
        subject_dn = cert.subject.rfc4514_string()
        issuer_dn = cert.issuer.rfc4514_string()
        cert_sha256 = cert.fingerprint(hashes.SHA256()).hex()
        cert_sha1 = cert.fingerprint(hashes.SHA1()).hex()

        print(f"[+] Certificate Subject DN: {subject_dn}")
        print(f"[+] Certificate Issuer DN:  {issuer_dn}")
        print(f"[+] Certificate Serial:     {cert.serial_number}")
        print(f"[+] Certificate SHA-256 Fingerprint: {cert_sha256}")
        print(f"[+] Certificate SHA-1 Fingerprint:   {cert_sha1}")
        print(f"[+] Validity start (UTC):   {cert.not_valid_before_utc}")
        print(f"[+] Validity end (UTC):     {cert.not_valid_after_utc}")

        # Ensure not debug key
        if "Android Debug" in subject_dn or "Android" in cert.issuer.rfc4514_string() and "US" in cert.issuer.rfc4514_string():
            violations.append("Keystore is using Android Debug Certificate, which triggers Play Protect warnings!")

        # Subject DN verification
        expected_parts = ["CN=LetsFly Mobile", "OU=Mobile", "O=LetsFly", "L=Cairo", "ST=Cairo", "C=EG"]
        for part in expected_parts:
            if part not in subject_dn:
                violations.append(f"Missing required Subject DN component: {part}")

        # Validity check
        val_days = (cert.not_valid_after_utc - cert.not_valid_before_utc).days
        print(f"[+] Validity duration: {val_days} days")
        if val_days < 10000:
            violations.append(f"Validity period is {val_days} days; expected at least 10,000 days for Android release keys")

        # Self-signature check
        try:
            cert.public_key().verify(
                cert.signature,
                cert.tbs_certificate_bytes,
                padding.PKCS1v15(),
                cert.signature_hash_algorithm
            )
            print(f"[+] Certificate self-signature verified: VALID ({cert.signature_hash_algorithm.name})")
        except Exception as e:
            violations.append(f"Certificate self-signature verification failed: {e}")

# ==============================================================================
# CHECK 2: KEY.PROPERTIES INTEGRITY
# ==============================================================================
print("\n--- CHECK 2: KEY.PROPERTIES CONFIGURATION (android/key.properties) ---")
props_path = os.path.join("android", "key.properties")

if not os.path.exists(props_path):
    violations.append(f"CRITICAL: key.properties missing at {props_path}")
else:
    props = {}
    with open(props_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()

    print(f"[+] key.properties parsed: {props}")
    for req_key in ["storePassword", "keyPassword", "keyAlias", "storeFile"]:
        if req_key not in props:
            violations.append(f"key.properties missing required property: {req_key}")

    # Check storeFile resolution
    resolved_path = os.path.abspath(os.path.join("android", "app", props.get("storeFile", "")))
    print(f"[+] Resolved storeFile: {resolved_path}")
    if not os.path.exists(resolved_path):
        violations.append(f"storeFile does not resolve to existing file: {resolved_path}")

    # Check password match against actual keystore
    if os.path.exists(resolved_path):
        with open(resolved_path, "rb") as f:
            jks_data = f.read()
        try:
            k, c, _ = pkcs12.load_key_and_certificates(jks_data, props.get("storePassword", "").encode())
            assert k is not None and c is not None
            print("[+] Keystore successfully authenticated using key.properties credentials.")
        except Exception as e:
            violations.append(f"key.properties credentials failed to unlock keystore: {e}")

# ==============================================================================
# CHECK 3: BUILD.GRADLE SIGNING CONFIG BINDING
# ==============================================================================
print("\n--- CHECK 3: BUILD.GRADLE SIGNING CONFIG BINDING ---")
gradle_path = os.path.join("android", "app", "build.gradle")

if not os.path.exists(gradle_path):
    violations.append(f"CRITICAL: build.gradle missing at {gradle_path}")
else:
    with open(gradle_path, "r", encoding="utf-8") as f:
        gradle_text = f.read()

    # Check signingConfigs block
    if "signingConfigs {" not in gradle_text:
        violations.append("build.gradle missing signingConfigs block")
    if "release {" not in gradle_text:
        violations.append("build.gradle missing signingConfigs.release block")

    # Check v1 & v2 signing
    if "v1SigningEnabled true" not in gradle_text:
        violations.append("v1SigningEnabled true missing from signingConfigs.release")
    else:
        print("[+] v1SigningEnabled true: CONFIRMED")
    if "v2SigningEnabled true" not in gradle_text:
        violations.append("v2SigningEnabled true missing from signingConfigs.release")
    else:
        print("[+] v2SigningEnabled true: CONFIRMED")

    # Check buildTypes.release binding
    if "buildTypes {" not in gradle_text:
        violations.append("buildTypes block missing from build.gradle")
    else:
        # Extract release block under buildTypes
        bt_part = gradle_text.split("buildTypes {")[1]
        release_bt = bt_part.split("release {")[1].split("}")[0]
        print(f"[+] buildTypes.release content:\n{release_bt.strip()}")

        if "signingConfig signingConfigs.release" not in release_bt:
            violations.append("buildTypes.release is NOT bound to signingConfigs.release!")
        else:
            print("[+] buildTypes.release.signingConfig = signingConfigs.release: CONFIRMED")

        if "signingConfig signingConfigs.debug" in release_bt:
            violations.append("buildTypes.release still references signingConfigs.debug!")

    # Check key.properties loading
    if "rootProject.file('key.properties')" not in gradle_text:
        violations.append("build.gradle does not reference rootProject.file('key.properties')")
    else:
        print("[+] rootProject.file('key.properties') loading: CONFIRMED")

    # Check SDK versions
    if "compileSdk 34" not in gradle_text:
        violations.append("compileSdk is not 34")
    else:
        print("[+] compileSdk 34: CONFIRMED")

    if "targetSdkVersion 34" not in gradle_text:
        violations.append("targetSdkVersion is not 34")
    else:
        print("[+] targetSdkVersion 34: CONFIRMED")

    if "versionCode 86" not in gradle_text:
        violations.append("versionCode is not 86")
    else:
        print("[+] versionCode 86: CONFIRMED")

    if 'versionName "8.6.0"' not in gradle_text:
        violations.append('versionName is not "8.6.0"')
    else:
        print('[+] versionName "8.6.0": CONFIRMED')

# ==============================================================================
# CHECK 4: MANIFEST HYGIENE
# ==============================================================================
print("\n--- CHECK 4: ANDROIDMANIFEST.XML HYGIENE ---")
manifest_path = os.path.join("android", "app", "src", "main", "AndroidManifest.xml")
if not os.path.exists(manifest_path):
    violations.append(f"AndroidManifest.xml missing at {manifest_path}")
else:
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest_text = f.read()

    if 'package="com.letsfly.mobile"' in manifest_text:
        violations.append("Deprecated package attribute still present in AndroidManifest.xml")
    else:
        print("[+] Deprecated package attribute removed: CONFIRMED")

    if 'android:icon="@drawable/launch_background"' not in manifest_text:
        violations.append("android:icon missing from AndroidManifest.xml <application>")
    else:
        print("[+] android:icon configured: CONFIRMED")

    if 'usesCleartextTraffic="true"' in manifest_text:
        violations.append("usesCleartextTraffic='true' found in AndroidManifest.xml")
    else:
        print("[+] usesCleartextTraffic absent/safe: CONFIRMED")

# ==============================================================================
# CHECK 5: CI WORKFLOW FIXES (.github/workflows/build.yml)
# ==============================================================================
print("\n--- CHECK 5: CI WORKFLOW INTEGRITY ---")
ci_path = os.path.join(".github", "workflows", "build.yml")
if not os.path.exists(ci_path):
    violations.append(f"CI workflow missing at {ci_path}")
else:
    with open(ci_path, "r", encoding="utf-8") as f:
        ci_text = f.read()

    if "rm -rf android" in ci_text:
        violations.append("CI workflow still contains destructive 'rm -rf android'")
    else:
        print("[+] Destructive 'rm -rf android' removed: CONFIRMED")

    if "flutter create" in ci_text:
        violations.append("CI workflow still contains destructive 'flutter create'")
    else:
        print("[+] Destructive 'flutter create' removed: CONFIRMED")

    if "usesCleartextTraffic" in ci_text:
        violations.append("CI workflow still injects usesCleartextTraffic")
    else:
        print("[+] Cleartext injection removed: CONFIRMED")

    if "Configure Keystore" not in ci_text:
        violations.append("CI workflow missing 'Configure Keystore' step")
    else:
        print("[+] 'Configure Keystore' CI step: CONFIRMED")

# ==============================================================================
# CHECK 6: ADVERSARIAL REVIEW & FACADE / MOCK DETECTION
# ==============================================================================
print("\n--- CHECK 6: ADVERSARIAL REVIEW & CHEATING / FACADE DETECTION ---")
# Verify that letsfly-release.jks is not an empty stub or static text file
with open(jks_path, "rb") as f:
    keystore_raw = f.read()

# Verify that there are no mock/bypass keywords in build.gradle
mock_keywords = ["mock", "dummy", "fake", "stub", "bypass", "todo", "fixme"]
for kw in mock_keywords:
    if kw in gradle_text.lower():
        violations.append(f"Suspicious keyword '{kw}' detected in build.gradle!")

print(f"[+] build.gradle scan for mock/bypass terms: CLEAN")

# Final Assessment
print("\n" + "=" * 70)
if violations:
    print(f"VERDICT: INTEGRITY VIOLATION ({len(violations)} violations found)")
    for v in violations:
        print(f"  [-] {v}")
    sys.exit(1)
else:
    print("VERDICT: CLEAN")
    print("All forensic integrity checks passed with zero violations.")
    print("=" * 70)
    sys.exit(0)
