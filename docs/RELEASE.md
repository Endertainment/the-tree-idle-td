# RELEASE — Godot 4.7.2 / Android

Release checklist for *The Tree: Idle Tower Defense*. The gates below are run for
every milestone; store-specific fields stay unchecked until M7/M8.

## 0. Versions

- [ ] `project.godot` `config/version` matches the tag (`0.7.0` for `v0.7.0-m6`).
- [ ] `export_presets.cfg` `version/name`, `version/code` bumped.
- [ ] `CHANGELOG.md` has the milestone section.
- [ ] `docs/PROGRESS.md` status and next tasks updated.

## 1. Automated gates (must be green)

```powershell
pwsh -NoProfile -File tools/check_project.ps1
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tools/smoke_test.gd
godot --headless --path . --script res://tools/battle_smoke.gd
godot --headless --path . --script res://tools/ads_flow_smoke.gd
godot --headless --path . --script res://tools/lint_locale.gd
```

- [ ] check_project exit 0
- [ ] tests 60/60 (or higher)
- [ ] smoke_test `== OK ==`
- [ ] battle_smoke `== PASS ==`
- [ ] ads_flow_smoke `[ads] PASS`
- [ ] lint_locale `missing: 0, unused: 0`

## 2. Android build

- [ ] JDK 17 (`C:\Tools\jdk-17`) and SDK (`C:\Android\Sdk`) present.
- [ ] Debug keystore exists locally (never committed).
- [ ] `pwsh -NoProfile -File tools/export_android.ps1` → `build/the-tree.apk`.
- [ ] `pwsh -NoProfile -File tools/install_ldplayer.ps1 -Screenshot ...` installs
      and launches without a crash on LDPlayer.
- [ ] `adb logcat` shows `[AdsService] GMA initialized` and no
      `FATAL EXCEPTION`.
- [ ] Back button: closes modals first, then opens battle pause, never exits a run
      without confirmation (`docs/QA_CHECKLIST.md`).

## 3. Debug vs release

- [ ] Debug APK keeps test ad IDs (`config/monetization.tres`) and Google test
      app ID; no production IDs in the repository.
- [ ] Release build must set `consent_granted` default false (it follows
      `OS.is_debug_build()`), so the consent step appears before any ad.
- [ ] `SettingsService.fake_monetization` is a debug-only flag; desktop release
      ads stay unavailable.
- [ ] Analytics endpoint empty + `analytics_enabled=false` in the committed
      config.

## 4. Signing / Play Console (M7/M8)

- [ ] Upload keystore (not the debug one) created offline; passwords in a
      password manager, never in git.
- [ ] Play Console app created with package `com.endertainment.thetree`.
- [ ] Products from §7.3 created as in-app products (IDs exact); No Ads, Starter
      Pack and Speed Pack as one-time products.
- [ ] Google Play Billing receipt verification endpoint implemented
      (`IapService._verify_receipt` hook) and tested with licence testers.
- [ ] UMP/EEA consent message published in AdMob; test device list configured.
- [ ] Data safety form and privacy policy URL fill the §13.12 placeholders.
- [ ] Version code never reused; AAB export
      (`gradle_build/export_format=1`) verified.

## 5. Device QA (see `docs/QA_CHECKLIST.md`)

- [ ] Cold start ≤ 5 s on LDPlayer.
- [ ] Battle 60 FPS target with the M2 stress scene.
- [ ] Offline: all screens usable, store/ad states graceful.
- [ ] App background/foreground during battle pauses simulation, audio resumes.
- [ ] Language switch mid-screen: no missing glyphs or overflow.
- [ ] No keystore, `.env`, production IDs or `build/` staged (`git status`).

## Rollback

- Tag the release commit; keep the previous APK/AAB artifact and its version code.
- Revert `project.godot` version and `export_presets.cfg` together; the save
  schema is unchanged by M6 (additive `shop`/`ads` keys only).
