# Flutter Android development on Windows

The current dependency constraints require Dart `^3.13.3`. Use the stable Flutter
channel and Java 21. Flutter can select Android Studio's bundled Java instead of
the Java on `PATH`; check `flutter doctor -v` and select an installed JDK explicitly:

```powershell
flutter config --jdk-dir="C:\Program Files\Java\jdk-21"
flutter upgrade
flutter pub get
flutter doctor -v
flutter devices
# From the repository root after configuring the isolated profile.
pnpm run:android:device <android-device-id>
```

Replace the JDK path and device ID with local values. Configure the repository-root
`.env.device` and the matching Android debug Firebase registration. From the root,
build a debug APK or a signed production release after its target is confirmed:

```powershell
pnpm build:apk:device
pnpm build:apk:production
```

If Gradle reports `No such host is known (dl.google.com)`, restore DNS/network
access before rebuilding. Subsequent repository-disabled, Kotlin-plugin and
project-evaluation errors can be consequences of that failed download. Check
the actual artifact endpoint, not just general internet access:

```powershell
Resolve-DnsName dl.google.com
Invoke-WebRequest -Method Head -TimeoutSec 30 -Uri "https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/9.1.0/gradle-9.1.0.pom"
```

Flutter upgrades also require working GitHub Git transfers. An RPC connection
reset, timeout or `early EOF` means the upgrade has not completed; confirm the
installed version with `flutter --version`. Preserve SDK edits and retry once
connectivity recovers. Do not use `flutter upgrade --force` or delete dependency
caches to repair a DNS/download failure.

The existing `android.builtInKotlin=false` and `android.newDsl=false` flags
support legacy Android plugins under AGP 9. Keep them until the application and
all plugins have been verified with built-in Kotlin and the new Android DSL.


See the [environment reference](ENVIRONMENT_CONFIGURATION.md) for release signing, profile selection and the Dart define allowlist.

## Previous SDK and Gradle verification on 2026-11-22

Flutter remains at 3.47.4 (Dart 3.13.3). Upgrade attempts failed with GitHub
connection resets/timeouts and early EOF. Flutter's local JDK selection was
changed to the installed Java 21. Dart analysis passed with 37 informational
lints and no errors or warnings. No Android device was connected. Android
release builds stalled on dependency downloads; an offline configuration check
confirmed missing Kotlin 2.4.10 artifacts required by MapLibre. A fresh APK build
and Android launch remain unverified. No application flows or diagrams changed.
