# RELEASE — The Tree: Idle Tower Defense 1.0.0 (M8)

Target: Godot 4.7.2 / Android (package `com.endertainment.thetree`).
Release tag: **`v1.0.0-m8`** · version code **8** · version name **1.0.0**.

## 1. Versions and docs

- [x] `project.godot` `config/version="1.0.0"`.
- [x] `scripts/autoload/app.gd` `VERSION = "1.0.0"`.
- [x] `export_presets.cfg` `version/code=8`, `version/name="1.0.0"` (debug and
      release presets).
- [x] `CHANGELOG.md` has the 1.0.0 section.
- [x] `docs/PROGRESS.md`, `docs/BALANCE.md`, `docs/PERF.md` updated.

## 2. Automated gates (all run on the release commit)

```powershell
pwsh -NoProfile -File tools/check_project.ps1
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tools/smoke_test.gd
godot --headless --path . --script res://tools/battle_smoke.gd
godot --headless --path . --script res://tools/balance_probe.gd
godot --headless --path . --script res://tools/simulate_run.gd --profile=new --runs=10
godot --headless --path . --script res://tools/lint_locale.gd
```

| Gate | Result |
|---|---|
| `check_project.ps1` | exit 0, all scripts parse |
| `run_tests.gd` | **74/74** passed, no ERROR/WARNING lines |
| `smoke_test.gd` | 25 scenes, `== OK ==`, no ERROR/WARNING |
| `battle_smoke.gd` | `== PASS ==`, no ERROR/WARNING |
| `balance_probe.gd` | zero-meta median **9** (M3.1 openings) |
| `simulate_run.gd` | new **9**, mid **29**, max **55** medians over 10 seeds |
| `lint_locale.gd` | 653 keys, 0 missing, 0 unused |

## 3. Signing (local only)

- [x] Release keystore generated at `tools/keystore/release.keystore`
      (**gitignored**, alias `thetree`, 10 000 days).
- [x] Placeholder password documented only in `tools/keystore/README.md`.
- [x] `export_presets.cfg` committed with **no keystore path and no password**.
- [x] `tools/export_release.ps1` injects the local keystore path/password into a
      temporary preset copy, exports, and restores the committed file in
      `finally`.

> The README password is a **placeholder for QA**. Regenerate the keystore with
> a production password before the first Play Console upload and back it up
> offline (losing it blocks every future update).

## 4. Build

```powershell
pwsh -NoProfile -File tools/export_release.ps1
```

| Artifact | Size | Use |
|---|---|---|
| `build/the-tree.aab` | **73.2 MB** | Play Console upload (signed release) |
| `build/the-tree-release.apk` | **166.3 MB** | LDPlayer/device QA only (fat APK, arm64 + x86_64, uncompressed native libs) |
| `build/the-tree.apk` | 179 MB | debug build from M6, not shipped |

Install/run proof:

```powershell
pwsh -NoProfile -File tools/install_ldplayer.ps1 `
  -ApkPath build/the-tree-release.apk -Screenshot docs/preview/m8_release.png
```

- [x] `adb install -r` succeeded (signature mismatch with the old debug install
      was handled by the script's one-time uninstall).
- [x] `apksigner verify --print-certs build/the-tree-release.apk` reports
      `CN=The Tree, OU=Games, O=Entertainment, L=Kyiv, C=UA` (release key);
      `jarsigner -verify build/the-tree.aab` prints `jar verified`.
- [x] App launches to the release build (`[App] boot complete, version 1.0.0`).
- [x] Onboarding → nickname `Release` → main menu; screenshot
      `docs/preview/m8_release.png`.
- [x] Force-stop + relaunch keeps the profile (no onboarding repeat, offline
      income modal shown); screenshot `docs/preview/m8_battle_hint.png` shows
      the battle at wave 1/60 on the release build.
- [x] No `FATAL EXCEPTION` / `SCRIPT ERROR` in `adb logcat`.

### APK size note

The spec's "APK < 60 MB" applies to the **Play delivery**, not the universal QA
APK. The AAB contains both arm64-v8a and x86_64; Play splits by ABI, so the
per-device download is expected to be well under 60 MB, but this was **not
measured with `bundletool`** in this environment (bundletool is not installed).
The 166 MB universal APK is a QA artifact and is not uploaded. Recorded as a
known issue rather than silently claimed.

## 5. Store listing assets

- [x] Placeholder set in `docs/store/`: `icon_512.png`,
      `feature_graphic_1024x500.png`, three 1080×1920 screenshots.
- [x] Specs and replacement notes in `docs/store/README.md`.
- [ ] Final painted icon / key art / device screenshots (post-M8 art pass).
- [ ] Short + full description, privacy policy URL, data-safety answers entered
      in Play Console.

## 6. Privacy and data safety

- [x] No real player name is required: onboarding accepts a nickname only.
- [x] Player id is a random UUID; no email, phone or location collected.
- [x] Analytics endpoint is empty and disabled in the committed config
      (`config/monetization.tres` + `AnalyticsService` no-op).
- [x] Ads: Google AdMob (Poing Studios 5.1.0), UMP consent first, test IDs only
      in the repository; no production ad unit IDs committed.
- [x] Billing: Google Play Billing via `godot-google-play-billing 3.3.0`;
      purchase tokens are sent only to the configured backend when enabled.
- [x] Cloud save/leaderboard are opt-in-by-service availability; the game is
      fully playable offline and local-first.
- [x] Data safety form must declare: app activity (game progress) if cloud save
      is on, purchase history (billing), and device identifiers (advertising ID
      via AdMob). No location, contacts, photos, files.
- [ ] Privacy policy URL and Data safety form submitted in Play Console.

## 7. Crash reporting hook

Not shipped as an SDK in 1.0.0 (no new third-party dependency in the release
milestone). The hook is `AnalyticsService.track()` plus `adb logcat` for QA;
a crash reporter (Firebase Crashlytics or Sentry) is a post-launch task with a
`DECISIONS.md` entry. The release build has no debug overlay or test-grant UI
(`App.is_debug_build()` gates them).

## 8. Known issues (launch)

1. **Draw calls 543 > 120 guideline** (120-enemy desktop stress). Deferred with
   ADR-043; desktop 1036 FPS and LDPlayer ~117 FPS at wave 1.
2. **Universal APK is 166 MB**; Play per-device split size not measured with
   `bundletool`. Upload target remains the AAB.
3. **Ads do not fill in this environment** (`ERR_ADDRESS_UNREACHABLE` to Google
   ad hosts). The failure path is graceful and unit-tested; a real fill test
   needs a device with Google Play services and network access.
4. **Billing cannot complete a purchase** without a Play Console listing and
   licence testers. The restore/pending/canceled paths are unit-tested.
5. **Neon/PostgreSQL and Docker runtime** were unavailable; the backend was
   verified on SQLite, with the Postgres URL path unit-tested (M7).
6. **No crash reporting SDK** and no real-device (non-emulator) QA in this
   environment. LDPlayer 14 is the only device used.
7. **Store art is placeholder**; fonts remain Godot's default (Cyrillic-capable)
   until the art/font pass.
8. Battle HUD safe-area support is a notch pass deferred from M6; LDPlayer has
   no cutout.

## 9. Rollback

- Tag the release commit; keep `build/the-tree.aab` and its version code.
- Revert `project.godot`, `App.VERSION` and `export_presets.cfg` together.
- The save schema is unchanged in M8 (additive `tutorial` section only; older
  saves load with the three hints unseen).
