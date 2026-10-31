# ENVIRONMENT — local toolchain

Checked: 2026-10-31 on the developer machine.

| Tool | Status | Path / version | Needed for |
|---|---|---|---|
| Godot | ✅ installed | `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2.stable.official) | everything |
| Godot CLI config | ✅ done | `tools/godot_path.txt`, honouring `$env:GODOT_BIN` | headless checks |
| `check_project.ps1` | ✅ done | `tools/check_project.ps1` — green on the current scaffold | gate for every batch |
| Export templates | ✅ installed | `%APPDATA%\Godot\export_templates\4.7.2.stable` (`android_debug.apk`, `android_release.apk`, `android_source.zip`) | Android export |
| JDK | ✅ installed | `C:\Tools\jdk-17` (Temurin 17.0.20.1) — set `JAVA_HOME` (the JDK 8 on PATH is not used) | Android export |
| Android SDK | ✅ installed | `C:\Android\Sdk` — `build-tools;36.1.0`, `platforms;android-36`, `platform-tools`; set `ANDROID_HOME`/`ANDROID_SDK_ROOT` | Android export |
| `adb` | ✅ installed | `E:\LDPlayer\LDPlayer14\adb.exe` (1.0.41, Android 34 platform-tools) | install/debug on LDPlayer |
| LDPlayer | ✅ installed | `E:\LDPlayer\LDPlayer14` (LDPlayer 14), instance 0, 1080×1920 @ 480 dpi; ADB debugging enabled in `vms/config/leidian0.config` (`basicSettings.adbDebug=1`) | test device |
| Android build template | ✅ installed locally (gitignored) | `android/build` extracted from `android_source.zip`; `.build_version` = `4.7.2.stable` | Gradle export |
| AdMob plugin | ✅ integrated | Poing Studios **5.1.0** + `android-template-v4.7.2` AARs (`addons/admob`; `android/bin` gitignored) | rewarded/interstitial ads |
| Play Billing plugin | ✅ integrated | godot-google-play-billing **3.3.0** (`addons/GodotGooglePlayBilling`) | IAP |
| git / gh | ✅ | git 2.51.2, gh 0.20+ (account `Endertainment`) | version control |
| Fonts | — not yet | `assets/fonts/display.otf`, `body.otf` (Cyrillic required) | UI text quality (M5 polish) |
| Real art | — not yet | 240 placeholders generated in M0 | art swap (M8) |

## How the agent verifies work

```powershell
pwsh -File tools/check_project.ps1           # import + parse check, exit 0 = green
pwsh -File tools/check_project.ps1 -VerboseLog   # same, full Godot output
pwsh -File tools/export_android.ps1          # debug APK (JDK 17 + SDK env set inside)
pwsh -File tools/install_ldplayer.ps1 -Screenshot docs/preview/m6_device.png
```

M0–M5 need only Godot. M6 adds the Android toolchain; the exact setup, plugin
pins and LDPlayer ADB steps are in `docs/ANDROID.md`.

## Android toolchain notes (M6)

1. Export templates: `Editor → Manage Export Templates → Download and Install`
   (standard 4.7.2, **not** .NET). Present.
2. JDK 17 (Temurin) at `C:\Tools\jdk-17`; `tools/export_android.ps1` sets
   `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT` and PATH for the export.
3. SDK: `build-tools;36.1.0`, `platforms;android-36`, `platform-tools` (the
   4.7.2 Android template compiles against SDK 36 and targets 35).
4. LDPlayer ADB: enable `Settings → Other settings → ADB debugging`, then
   `adb connect 127.0.0.1:5555`. The emulator must be running; the install script
   retries the connection while it boots.
5. Gradle build is mandatory for the AdMob and Billing plugins; the first export
   downloads Gradle/Maven dependencies (several minutes).
6. The AdMob addon ships its native AARs outside git (`addons/admob/android/bin`);
   install them from the pinned `android-template-v4.7.2.zip` (see
   `docs/ANDROID.md`).
7. Network limitation observed in this environment: Google ad hosts
   (`googleads.g.doubleclick.net`, `pagead2.googlesyndication.com`) are
   unreachable, so test ads cannot fill; the SDK initialization and failure paths
   are verified. Billing also requires an uploaded Play listing.
