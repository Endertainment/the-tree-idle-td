# ANDROID — build, install and test on LDPlayer

Target: Godot **4.7.2** (non-.NET), package `com.endertainment.thetree`, portrait,
immersive, min SDK 24, target SDK 35, x86_64 + arm64. Debug builds only for M6.

## Verified toolchain

| Tool | Path | Notes |
|---|---|---|
| Godot | `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` | standard build (not .NET) |
| Export templates | `%APPDATA%\Godot\export_templates\4.7.2.stable` | `android_debug.apk`, `android_release.apk`, `android_source.zip` |
| JDK | `C:\Tools\jdk-17` (Temurin 17.0.20.1) | the JDK 8 on PATH must **not** be used |
| Android SDK | `C:\Android\Sdk` | `build-tools;36.1.0`, `platforms;android-36`, `platform-tools` |
| adb | `E:\LDPlayer\LDPlayer14\adb.exe` (1.0.41) | LDPlayer ships its own adb |
| Emulator | `E:\LDPlayer\LDPlayer14\dnplayer.exe` | instance 0, 1080×1920 @ 480 dpi |

The Android build template (`android/`) is gitignored and installed by
`tools/export_android.ps1` from `android_source.zip` on the first export.

## One-time setup

1. **Debug keystore** — generated once by the export script, never committed
   (`.gitignore` covers `*.keystore`):

   ```powershell
   & C:\Tools\jdk-17\bin\keytool.exe -genkeypair -v `
       -keystore tools\keystore\debug.keystore `
       -storepass android -keypass android -alias androiddebugkey `
       -keyalg RSA -keysize 2048 -validity 10000 `
       -dname "CN=Android Debug,O=Android,C=US"
   ```

   The export script injects the absolute keystore path into `export_presets.cfg`
   for the duration of the export and restores the committed (empty) path
   afterwards, so no machine-specific secret is committed.

2. **LDPlayer ADB** — `Settings → Other settings → ADB debugging → Open local
   connection`. With the emulator stopped, `basicSettings.adbDebug` must be `1` in
   `E:\LDPlayer\LDPlayer14\vms\config\leidian0.config`. Then:

   ```powershell
   & E:\LDPlayer\LDPlayer14\dnplayer.exe
   & E:\LDPlayer\LDPlayer14\adb.exe connect 127.0.0.1:5555
   & E:\LDPlayer\LDPlayer14\adb.exe devices
   ```

3. **AdMob native binaries** — the Poing addon ships its Android AARs outside git
   (`addons/admob/android/bin` is ignored by the addon). Install them once:

   ```powershell
   # pinned release, must match addons/admob/plugin.cfg (5.1.0)
   # android-template-v4.7.2.zip from
   # https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0
   Expand-Archive android-template-v4.7.2.zip addons\admob\android\bin -Force
   Set-Content addons\admob\android\bin\package.gd 'const VERSION := "v5.1.0"'
   ```

   On a normal editor start the addon can also download them itself
   (`Project → Tools → AdMob Manager → Android → Download & Install`).

## Build

```powershell
pwsh -NoProfile -File tools/export_android.ps1
# -> build/the-tree.apk
```

The script sets `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, creates the
keystore when missing, installs the Android build template when missing, and runs:

```text
godot --headless --path . --export-debug "Android" build/the-tree.apk
```

`gradle/use_gradle_build` is **on** because all Android plugins (AdMob, Play
Billing) require a Gradle build. The first build downloads Gradle + Maven
dependencies; expect several minutes.

## Install / launch / screenshot

```powershell
pwsh -NoProfile -File tools/install_ldplayer.ps1
# optional screenshot after launch:
pwsh -NoProfile -File tools/install_ldplayer.ps1 -Screenshot docs/preview/m6_device.png
```

The script retries `adb connect 127.0.0.1:5555`, handles the
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` signature mismatch by uninstalling once, and
launches `com.endertainment.thetree/com.godot.game.GodotAppLauncher`.

## Manual checks on device

```powershell
# FPS / activity
adb -s 127.0.0.1:5555 shell dumpsys gfxinfo com.endertainment.thetree
# logcat (Godot + plugins)
adb -s 127.0.0.1:5555 logcat -s godot:V Godot:V
# back button behaviour
adb -s 127.0.0.1:5555 shell input keyevent KEYCODE_BACK
```

- Back closes modals first, then opens the battle pause menu; it must never exit a
  run without the abandon confirmation.
- Play Services are present on this LDPlayer image (GMS 26.23.34, Play Store), so
  UMP/rewarded test ads can load. Billing still reports "Store unavailable"
  because the package is a local debug build, not a Play Console release.
- The emulator's Vulkan driver fails to present on this image, so the Android
  rendering method override is `gl_compatibility` (`project.godot`). A real device
  may use the Mobile (Vulkan) renderer by removing that override.

## Version pins

| Plugin | Version | Source |
|---|---|---|
| Poing Studios AdMob | **5.1.0** (+ `android-template-v4.7.2`) | `addons/admob` |
| GodotGooglePlayBilling | **3.3.0** | `addons/GodotGooglePlayBilling` |

Both were checked against Godot 4.7.2 (headless import + full Gradle APK + launch on
LDPlayer). See `docs/DECISIONS.md`.
