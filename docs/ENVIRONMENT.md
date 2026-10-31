# ENVIRONMENT — local toolchain

Checked: 2026-10-31 on the developer machine.

| Tool | Status | Path / version | Needed for |
|---|---|---|---|
| Godot | ✅ installed | `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2.stable.official) | everything |
| Godot CLI config | ✅ done | `tools/godot_path.txt`, honouring `$env:GODOT_BIN` | headless checks |
| `check_project.ps1` | ✅ done | `tools/check_project.ps1` — green on the current scaffold | gate for every batch |
| Export templates | ✅ installed | `%APPDATA%\Godot\export_templates\4.7.2.stable` (android_debug/release present) | Android export (M6) |
| JDK | ✅ installed | `C:\Tools\jdk-17` (Temurin 17.0.20.1) — set `JAVA_HOME` to it for Android export | Android export (M6) |
| Android SDK | ❌ missing | no `ANDROID_HOME`, no `sdkmanager` | Android export (M6) |
| `adb` | ❌ missing | not on PATH | install/debug on LDPlayer (M6) |
| LDPlayer | ❓ unknown | not in `C:\LDPlayer`, `D:\LDPlayer`, Program Files | test device (M6) |
| git / gh | ✅ | git 2.51.2, gh 0.20+ (account `Endertainment`) | version control |
| AdMob plugin | — not yet | `poing-studios/godot-admob-plugin` (verify 4.7 compat) | rewarded/interstitial ads (M6) |
| Play Billing plugin | — not yet | `godot-google-play-billing` (verify 4.7 compat) | IAP (M6) |
| Fonts | — not yet | `assets/fonts/display.otf`, `body.otf` (Cyrillic required) | UI text quality (M5) |
| Real art | — not yet | 240 placeholders generated in M0 | art swap (after M5) |

## How the agent verifies work

```powershell
pwsh -File tools/check_project.ps1           # import + parse check, exit 0 = green
pwsh -File tools/check_project.ps1 -VerboseLog   # same, full Godot output
```

M0–M5 need only Godot. The Android toolchain is a **M6 prerequisite** and can be installed later; nothing before M6 depends on it.

## Installing the missing Android pieces (M6)

1. Godot → Editor → Manage Export Templates → Download and Install (standard 4.7.2, not .NET).
2. JDK 17 (Temurin) and set `JAVA_HOME`.
3. Android SDK command-line tools → install `platform-tools`, `build-tools;35.0.0`, `platforms;android-35`.
4. Set `ANDROID_HOME`, add `platform-tools` to PATH.
5. LDPlayer: enable ADB debugging, note the install path for `adb connect 127.0.0.1:5555`.
