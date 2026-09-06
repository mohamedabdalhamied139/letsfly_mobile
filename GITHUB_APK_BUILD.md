# Let's Fly — GitHub + Android APK

## 1. Create the repository
Create an empty GitHub repository, then push this project to its `main` branch.

## 2. Add the four repository secrets
GitHub → Settings → Secrets and variables → Actions → New repository secret:

- `LETSFLY_KEYSTORE_BASE64`: Base64 contents of the release keystore.
- `LETSFLY_KEYSTORE_PASSWORD`: keystore password.
- `LETSFLY_KEY_ALIAS`: release key alias.
- `LETSFLY_KEY_PASSWORD`: key password.

Do **not** commit `android/key.properties` or any `.jks`/`.keystore` file.

### Generate the Base64 value on Windows PowerShell
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("letsfly-release.jks"))
```
Copy the resulting single line into `LETSFLY_KEYSTORE_BASE64`.

## 3. Build
Push to `main`/`master`, or manually run:
GitHub → Actions → Android Release APK → Run workflow.

The workflow performs:
- Flutter dependency installation
- `flutter analyze`
- `flutter test`
- signed release APK build
- APK artifact upload
- GitHub Release creation on `main`

The workflow intentionally fails on analysis/test/build errors; it does not hide failures with `|| true`.
