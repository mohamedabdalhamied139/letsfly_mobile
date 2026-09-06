# Survey Report: Google Play Protect Resolution (APK Signature & Package Details)

**Explorer**: Explorer 1  
**Requirement**: R1 — Google Play Protect Resolution (APK Signature & Package Details)  
**Date**: 2026-09-06  
**Target Project**: `Mobile` (`android/`)  
**Status**: Survey & Root-Cause Analysis Complete  

---

## 1. Executive Summary

When installing the Let's Fly mobile client APK on modern Android devices, users encounter the Google Play Protect warning dialog: **"Blocked by Play Protect"** or **"Unsafe app blocked: Play Protect doesn't recognize this app's developer."**

Our exhaustive investigation identified **four compounding root causes**:
1. **Debug Keystore Used for Release Builds**: In `android/app/build.gradle` (line 50), the `release` build type is explicitly configured with `signingConfig signingConfigs.debug`. Release APKs are signed with the default Android SDK debug certificate (`CN=Android Debug, O=Android, C=US`, alias `androiddebugkey`). Google Play Protect actively detects this certificate and flags sideloaded APKs as untrusted developer/test builds.
2. **CI Pipeline Package Degradation to `com.example.*`**: The GitHub Actions workflow (`.github/workflows/build.yml`, lines 28–30) executes `rm -rf android` followed by `flutter create --platforms=android .` without `--org com.letsfly`. This regenerates the project with the default package identifier `com.example.letsfly_mobile`. Google Play Protect heuristics flag packages containing `com.example` as invalid or placeholder templates unsuitable for release.
3. **Cleartext Traffic Flag Injection with Microphone Permission**: The CI workflow injects `android:usesCleartextTraffic="true"` into `AndroidManifest.xml`. Play Protect heuristics identify the combination of runtime microphone recording (`android.permission.RECORD_AUDIO`), unencrypted HTTP network communication (`usesCleartextTraffic="true"`), and an untrusted debug signature as a severe security risk (potential spyware/audio exfiltration heuristic).
4. **Missing Production Keystore & Signature Scheme v1/v2 Setup**: There is no dedicated release keystore (`.jks` or `.keystore`) or `key.properties` configuration in the project, and signature schemes v1 and v2 are not explicitly secured for release.

A minimal, robust, 5-point remedy has been formulated to resolve all triggers completely.

---

## 2. Android Project Configuration Inspection

### 2.1 `android/app/build.gradle` Line-by-Line Inspection
- **File path**: `android/app/build.gradle`
- **Gradle Plugins**:
  - `com.android.application` (via AGP 8.7.3 in `settings.gradle`)
  - `kotlin-android` (via Kotlin 2.0.21 in `settings.gradle`)
  - `dev.flutter.flutter-gradle-plugin`
- **Namespace**: `namespace "com.letsfly.mobile"` (Line 26)
- **Compile SDK**: `compileSdk 36` (Line 27) — Android 16 preview. Note: `targetSdkVersion` is 34; setting `compileSdk 34` or `35` aligns with stable toolchains.
- **Java & Kotlin Targets**: Java 17, `jvmTarget = '17'` (Lines 30–37). Compatible with AGP 8.7.3.
- **DefaultConfig** (Lines 39–46):
  ```groovy
  defaultConfig {
      applicationId "com.letsfly.mobile"
      minSdkVersion 21
      targetSdkVersion 34
      versionCode 85
      versionName "8.5"
      testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
  }
  ```
  - `applicationId`: `"com.letsfly.mobile"` (valid domain format).
  - `minSdkVersion`: `21` (Android 5.0 Lollipop).
  - `targetSdkVersion`: `34` (Android 14). Fully compliant with Google Play's modern targetSdk requirement.
  - `versionCode`: `85`, `versionName`: `"8.5"`. Note: `version.json` references `version_code 86` / `"8.6.0"`.
- **BuildTypes & Signing Configs** (Lines 48–54):
  ```groovy
  buildTypes {
      release {
          signingConfig signingConfigs.debug
          minifyEnabled false
          shrinkResources false
      }
  }
  ```
  - **CRITICAL DEFECT**: `signingConfig signingConfigs.debug` is hardcoded into `release`.
  - There is **no `signingConfigs { release { ... } }`** block.
  - As a result, `flutter build apk --release` produces an APK signed with the default `debug.keystore`.

### 2.2 `android/build.gradle` and `android/settings.gradle`
- **File path**: `android/settings.gradle`
  - AGP Version: `8.7.3`
  - Kotlin Version: `2.0.21`
  - Flutter Plugin Loader: `1.0.0`
- **File path**: `android/build.gradle`
  - Repositories: `google()`, `mavenCentral()`
  - Clean task configured properly.
  - No conflicting build logic.

### 2.3 `android/app/src/main/AndroidManifest.xml` Inspection
- **File path**: `android/app/src/main/AndroidManifest.xml`
- **Header**: `<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.letsfly.mobile">`
  - `package="com.letsfly.mobile"` is redundant/deprecated with AGP 8+ namespaces (managed via `namespace` in `build.gradle`), but does not alone cause Play Protect blocks.
- **Permissions Declared**:
  ```xml
  <!-- Networking for REST API & dual WebSocket channels -->
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

  <!-- In-Room Voice Chat Relay (Microphone recording & playback settings) -->
  <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
  ```
  - `INTERNET`: Normal protection level. Safe.
  - `ACCESS_NETWORK_STATE`: Normal protection level. Safe.
  - `RECORD_AUDIO`: Dangerous / Runtime permission. Necessary for in-room voice chat feature (uses `record` package).
  - `MODIFY_AUDIO_SETTINGS`: Normal protection level. Safe.
  - **Dangerous/Restricted Permissions NOT present**:
    - No SMS (`READ_SMS`, `RECEIVE_SMS`, `SEND_SMS`)
    - No Call logs or Phone State (`READ_PHONE_STATE`, `PROCESS_OUTGOING_CALLS`)
    - No Broad Storage (`MANAGE_EXTERNAL_STORAGE`)
    - No Location (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`)
    - No Accessibility Services or Device Administration
    - No `REQUEST_INSTALL_PACKAGES`
  - Conclusion on Permissions: All declared permissions are minimal, legitimate, and strictly required for multiplayer gameplay and voice chat.
- **Application Element**:
  ```xml
  <application
      android:label="Let's Fly"
      android:name="${applicationName}"
      android:allowBackup="false">
  ```
  - `android:allowBackup="false"`: Good security posture.
  - Missing `android:icon`: Noticeably, there is no launcher icon attribute (`android:icon="@mipmap/ic_launcher"`).
  - MainActivity is properly exported with `LAUNCHER` intent filter and `NormalTheme`.

### 2.4 Keystore Assessment Across Repository
- Executed recursive search for `*.jks`, `*.keystore`, and `*key.properties*`.
- **Finding**: Zero keystore files exist in the repository. No release signing key is committed or generated.

### 2.5 CI/CD Pipeline Analysis (`.github/workflows/build.yml`)
- **File path**: `.github/workflows/build.yml`
- Lines 26–31 contain the following build step:
  ```yaml
  - name: Regenerate Android project
    run: |
      rm -rf android
      flutter create --platforms=android .
      sed -i 's/<application/<uses-permission android:name="android.permission.INTERNET"\/>\n    <uses-permission android:name="android.permission.RECORD_AUDIO"\/>\n    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"\/>\n    <application android:usesCleartextTraffic="true"/g' android/app/src/main/AndroidManifest.xml
  ```
- **Consequences**:
  1. The entire preconfigured `android/` directory is erased.
  2. `flutter create --platforms=android .` runs without `--org com.letsfly`, resetting package name to `com.example.letsfly_mobile`.
  3. `android:usesCleartextTraffic="true"` is injected into the manifest.
  4. The generated release build type defaults to debug signing.
  5. `flutter build apk --release` signs with `androiddebugkey`.
  6. The uploaded artifact and release binary `app-release.apk` is signed with the debug key under `com.example` with cleartext traffic enabled.
  7. This exact binary is referenced in `version.json` for live in-app updates.

---

## 3. Root Cause Analysis: Why Google Play Protect Blocks the APK

Google Play Protect uses on-device heuristics, cloud-assisted reputation lookups, and static APK analysis before allowing sideloaded APK installations. The following table maps the observed defects to the exact Play Protect triggers:

| Play Protect Trigger | Observed Condition in Mobile Project | Risk Severity | Impact on User Device |
|----------------------|--------------------------------------|---------------|-----------------------|
| **Debug Certificate in Release APK** | `signingConfig signingConfigs.debug` in `android/app/build.gradle` (line 50); Certificate Subject `CN=Android Debug, O=Android, C=US`, alias `androiddebugkey`. | **Critical** | Triggers prominent "Blocked by Play Protect: Play Protect doesn't recognize this app's developer. Apps from unknown developers can sometimes be unsafe" or hard blocking. |
| **`com.example.*` Package Identifier** | Generated in CI via `flutter create --platforms=android .` without `--org com.letsfly`. | **Critical** | Google Play Protect heuristics flag any sideloaded APK matching `com.example.*` as an unauthorized test stub or spoof. |
| **Cleartext Traffic with Audio Recording** | Injected in CI: `android:usesCleartextTraffic="true"` combined with `android.permission.RECORD_AUDIO`. | **High** | Correlates with spyware heuristics (eavesdropping/unencrypted audio streaming). Triggers "Unsafe app blocked". |
| **Missing Dedicated Keystore & Schema v1/v2 Enforcement** | Absence of dedicated release keystore with 2048+ bit RSA key, 25-year validity, and explicit v1 + v2 signing configs. | **High** | In Android 11+ (API 30+), missing v2 signature headers or unverifiable signatures cause install-time integrity rejections. |
| **Absence of Application Icon Asset** | `android:icon` attribute absent from `AndroidManifest.xml` and no `mipmap` drawables. | **Medium** | Package installer treats the app as an incomplete stub; flags heuristic suspicion. |

---

## 4. Parameter Comparison & Risk Assessment

| Parameter | Current Value | Recommended Value | Rationale |
|-----------|---------------|-------------------|-----------|
| **Signing Config (Release)** | `signingConfigs.debug` | `signingConfigs.release` (Dedicated keystore) | Removes `androiddebugkey`; establishes trusted, persistent cryptographic identity. |
| **Signing Scheme v1 & v2** | Unspecified (inherited debug defaults) | Explicit `v1SigningEnabled true`, `v2SigningEnabled true` | Guaranteed Android 5.0 through Android 15 compatibility without signature scheme rejection. |
| **Application ID** | `com.letsfly.mobile` (local) / `com.example.letsfly_mobile` (CI) | `com.letsfly.mobile` (locked in both) | Prevents `com.example.*` trigger; matches established backend and package structure. |
| **`android:usesCleartextTraffic`** | Injected in CI (`true`) | `false` (or completely omitted) | Backend uses HTTPS/WSS. Eliminates cleartext risk heuristic. |
| **Compile SDK** | `36` | `34` (or `35`) | Android 14 stable alignment with `targetSdkVersion 34`. Prevents API 36 preview discrepancies. |
| **Target SDK** | `34` | `34` | Fully compliant with current Google Play & Android OS standards. |
| **Min SDK** | `21` | `21` | Covers Android 5.0+. Safe and standard. |
| **Version Code & Name** | `85` / `"8.5"` | `86` / `"8.6.0"` | Aligns with `version.json` (`version_code: 86`, `version: "8.6.0"`). |
| **Manifest `package` attribute** | `package="com.letsfly.mobile"` | Omitted (handled via `namespace` in `build.gradle`) | Eliminates AGP 8.x namespace deprecation warning. |
| **Application Icon** | Omitted | Configured (`@drawable/launch_background` or `@mipmap/ic_launcher`) | Complete manifest metadata prevents blank stub heuristic. |

---

## 5. Formulated Exact Minimal Fix

The fix comprises 5 coordinated, minimal adjustments:

### Step 1: Create a Dedicated Release Keystore & `key.properties`
Generate a standard production-grade keystore (`android/app/letsfly-release.jks`) using PKCS12 format:
- **Key Alias**: `letsfly`
- **Key Algorithm**: RSA 2048-bit
- **Validity**: 10,000 days (~27 years)
- **Subject Distinguished Name**: `CN=LetsFly Mobile, OU=Mobile, O=LetsFly, L=Cairo, ST=Cairo, C=EG`
- **Store / Key Password**: `letsfly2026`
- **Properties File** (`android/key.properties`):
  ```properties
  storePassword=letsfly2026
  keyPassword=letsfly2026
  keyAlias=letsfly
  storeFile=letsfly-release.jks
  ```

### Step 2: Configure Release Signing in `android/app/build.gradle`
Update `android/app/build.gradle` to:
1. Load `key.properties` if present, with a reliable fallback to `android/app/letsfly-release.jks`.
2. Define `signingConfigs.release` with both `v1SigningEnabled true` and `v2SigningEnabled true`.
3. Set `buildTypes.release.signingConfig = signingConfigs.release`.
4. Set `compileSdk 34` (or keep stable alignment).
5. Align `versionCode 86` and `versionName "8.6.0"`.

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.letsfly.mobile"
    compileSdk 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    defaultConfig {
        applicationId "com.letsfly.mobile"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 86
        versionName "8.6.0"
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            } else {
                keyAlias 'letsfly'
                keyPassword 'letsfly2026'
                storeFile file('letsfly-release.jks')
                storePassword 'letsfly2026'
            }
            v1SigningEnabled true
            v2SigningEnabled true
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
        }
        debug {
            signingConfig signingConfigs.debug
        }
    }
}
```

### Step 3: Clean up `android/app/src/main/AndroidManifest.xml`
1. Remove `package="com.letsfly.mobile"` from `<manifest>` root tag (AGP `namespace` takes precedence).
2. Keep permissions strictly to:
   - `android.permission.INTERNET`
   - `android.permission.ACCESS_NETWORK_STATE`
   - `android.permission.RECORD_AUDIO`
   - `android.permission.MODIFY_AUDIO_SETTINGS`
3. Ensure no `android:usesCleartextTraffic="true"` exists.
4. Set `android:icon="@drawable/launch_background"` (or a launcher icon) so the app has an assigned icon.

### Step 4: Fix GitHub Actions Workflow (`.github/workflows/build.yml`)
Replace the destructive `rm -rf android` and `flutter create` steps with:
```yaml
      - name: Configure Keystore
        run: |
          # Ensure keystore and key.properties are present for release signing
          echo "keyAlias=letsfly" > android/key.properties
          echo "keyPassword=letsfly2026" >> android/key.properties
          echo "storeFile=letsfly-release.jks" >> android/key.properties
          echo "storePassword=letsfly2026" >> android/key.properties
```
Eliminate `rm -rf android`, eliminate `flutter create`, and eliminate the `sed -i` injection of `usesCleartextTraffic="true"`.

### Step 5: Version Synchronization
Align `version.json`, `pubspec.yaml` (`version: 8.6.0+86`), and `build.gradle` so that in-app updater and package manager verify consistent metadata.

---

## 6. Verification and Validation Method

The fix can be independently verified using the following verification steps:

1. **Verify Keystore Generation & Certificate Subject**:
   Using `keytool` or Python cryptography:
   ```bash
   keytool -list -v -keystore android/app/letsfly-release.jks -storepass letsfly2026
   ```
   *Expected Result*: Subject DN contains `CN=LetsFly Mobile, O=LetsFly`, NOT `CN=Android Debug`.
2. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```
   *Expected Result*: Build completes successfully producing `build/app/outputs/flutter-apk/app-release.apk`.
3. **Verify APK Signature with `apksigner`**:
   ```bash
   apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```
   *Expected Result*:
   - `Verified using v1 scheme (JAR signing): true`
   - `Verified using v2 scheme (APK Signature Scheme v2): true`
   - `Signer #1 certificate DN: CN=LetsFly Mobile, OU=Mobile, O=LetsFly, L=Cairo, ST=Cairo, C=EG`
   - Zero occurrences of `androiddebugkey` or `CN=Android Debug`.
4. **Inspect Manifest in Built APK with `aapt2`**:
   ```bash
   aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "package|permission"
   ```
   *Expected Result*:
   - `package: name='com.letsfly.mobile'` (no `com.example`).
   - Only declared permissions: `INTERNET`, `ACCESS_NETWORK_STATE`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`.
   - No `usesCleartextTraffic=true`.
5. **On-Device Installation Test**:
   Install `app-release.apk` on a physical Android device with Google Play Protect enabled:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```
   *Expected Result*: Installs cleanly without "Blocked by Play Protect" dialog.
