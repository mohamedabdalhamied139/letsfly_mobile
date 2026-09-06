# Building the Android app

This archive is the repaired Flutter mobile source. The Windows `LetsFly_v2_fixed` project is the authoritative functional baseline.

1. Install Flutter (stable) and Android SDK.
2. From this directory run `flutter create .` only if your Flutter installation needs to regenerate missing platform wrapper files. Do not overwrite `lib/`.
3. Run `flutter pub get`.
4. Run `flutter analyze` and `flutter test`.
5. Build with `flutter build apk --release`.

The mobile client targets the same production REST/WebSocket contract as Windows. The gesture controller is intentionally protected and was not modified.
