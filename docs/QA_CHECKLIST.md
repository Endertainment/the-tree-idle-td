# QA_CHECKLIST — manual checks per milestone

Run after `docs/RELEASE.md` automated gates are green. Mark a line only when it
was actually observed; write **not verified** with a reason otherwise.

Device: LDPlayer 14 (1080×1920 @ 480 dpi), Android 9 image, package
`com.endertainment.thetree`.

## M8 — release readiness (2026-10-31, `v1.0.0-m8`)

### Automated gates (verified in this session)

- [x] `tools/check_project.ps1` exit 0.
- [x] `tests/run_tests.gd` **74/74**, zero ERROR/WARNING lines.
- [x] `tools/smoke_test.gd` 25 scenes, `== OK ==`, zero ERROR/WARNING lines.
- [x] `tools/battle_smoke.gd` `== PASS ==`, zero ERROR/WARNING lines.
- [x] `tools/balance_probe.gd` zero-meta median **9** (9 policies/seeds).
- [x] `tools/simulate_run.gd` new **9**, mid **29**, max **55** medians over
      10 seeds (`docs/BALANCE.md`).
- [x] `tools/lint_locale.gd` 653 keys, 0 missing, 0 unused.
- [x] `tools/perf_probe.gd` 120 enemies + 8 towers + 4 units: 1036.5 FPS,
      543 draw calls (`docs/PERF.md`).
- [x] `tools/tutorial_probe.gd` shows the build hint at wave 1, text resolves
      from the catalogue and the flag persists.
- [x] `tools/export_release.ps1` signed AAB **73.2 MB** + release APK **166.3 MB**.

### Release build on LDPlayer

- [x] `adb install -r build/the-tree-release.apk` succeeded (one-time uninstall
      needed because the old install used the debug key).
- [x] App launches; `[App] boot complete, version 1.0.0` in logcat.
- [x] No `FATAL EXCEPTION` or `SCRIPT ERROR` after boot and battle.
- [x] Onboarding completes with nickname `Release`; main menu reachable
      (`docs/preview/m8_release.png`).
- [x] Battle starts at wave 1/60 on the release build; enemies, towers, units
      and the upgrade button render (`docs/preview/m8_battle_hint.png`).
- [x] Force-stop → relaunch keeps the profile (no onboarding repeat) and shows
      the offline-income modal (save persistence).
- [x] Android back: battle → pause, pause → battle (M6 behaviour, re-checked in
      the release build).
- [x] Release build shows **no debug overlay / free-reward UI**
      (`OS.is_debug_build()` gate).
- [ ] Cold start ≤ 5 s: measured ~5 s to the language step on this emulator;
      exact stopwatch value not recorded.
- [x] Frame pacing on LDPlayer: **~117 FPS** at wave 1
      (`dumpsys SurfaceFlinger --latency`, 124 frames, 8.53 ms average). The
      120-enemy stress profile has no device-friendly overlay in a release
      build and was not measured on LDPlayer.
- [ ] 30-minute continuous session without crash or memory growth: **not run**
      (emulator session was shorter; the 74-test + battle smoke + 10-seed
      simulations cover long-run logic, not device memory).
- [ ] Airplane-mode run: **not verified**. `svc wifi disable` wedged the
      emulator's shell and the instance had to be restarted; the offline path is
      covered by M7 unit/API tests and the desktop local-first logic, but not on
      this device.
- [ ] 130 % text scale and +60 % pseudo-locale on the M8 release build:
      **not verified on device** (covered by M5 automated layout captures).

### Monetization / network

- [x] Ads fail gracefully in this environment
      (`ERR_ADDRESS_UNREACHABLE`, no crash, buttons reset).
- [x] Billing shows "Store unavailable" without a Play listing.
- [ ] Real rewarded-ad fill: blocked by environment network.
- [ ] Real sandbox purchase / restore: blocked without a Play Console listing.
- [ ] Cloud save against the live backend on the release build: not run
      (SQLite-only backend proof from M7; release build has no debug hooks).

### Store / release paperwork

- [x] Placeholder icon, feature graphic and three screenshots in `docs/store/`.
- [x] `docs/RELEASE.md` versions, gates, signing, build, privacy/data-safety and
      known issues.
- [ ] Privacy policy URL submitted in Play Console.
- [ ] Data safety form submitted.
- [ ] Final store art (not placeholders).
- [ ] AAB uploaded to an internal testing track and downloaded via Play
      (requires a Play Console account).

## M6 — Android, ads, billing, telemetry (2026-10-31, `v0.7.0-m6`)

### Boot / lifecycle

- [x] Cold start reaches the main menu on LDPlayer (GLES3 renderer).
- [x] No `FATAL EXCEPTION` in `adb logcat` during boot.
- [ ] Cold start ≤ 5 s (measured: ___ s; M6 build is a 179 MB debug APK).
- [x] App background/foreground during battle: simulation freezes/resumes,
      music pauses/resumes (AudioService + BattleClock).
- [x] Back button: Shop → main menu, main menu → exits, battle → pause,
      pause → battle (verified on LDPlayer).
- [ ] 60 FPS on LDPlayer during a wave (not measured in M6; M8 measured ~117).
- [x] Safe-area inset applied by `SceneRouter` (no jump between scenes).

### Ads

- [x] `[AdsService] GMA initialized` in logcat (Poing 5.1.0, platform 1.4.0).
- [x] Rewarded request reaches the SDK and fails gracefully
      (`ERR_ADDRESS_UNREACHABLE`) without crashing.
- [x] Failure toast/button reset on the main menu (device check).
- [x] Desktop fake ad (`DebugAdOverlay`) grants exactly one reward
      (`tools/ads_flow_smoke.gd`).
- [x] Daily cap blocks the second `speed_unlock_24h` request.
- [x] No ad request before consent (release default false; editor true).
- [ ] Interstitial cadence on a real device (needs fill; unit-tested only).
- [ ] No Ads purchase disables interstitials but keeps rewarded ads.
- [ ] App kill mid-ad: no double reward, cap persisted (unit-tested only).

### Billing

- [x] Shop shows "Store unavailable" and disabled buy buttons when
      `IapService.is_available()` is false.
- [x] Restore reports the local ownership list on desktop.
- [x] Debug simulate purchase grants through `RewardBundle` once.
- [ ] Real sandbox purchase (blocked: local build, no Play listing).
- [ ] Reinstall + restore recovers non-consumables (needs Play listing).
- [ ] Pending/cancelled/already-owned sheets (needs Play listing).

### Telemetry / privacy

- [x] Debug console prints `app_open`, `screen_view`, `ad_shown`, `ad_rewarded`.
- [x] Analytics disabled by default (no HTTP without endpoint).
- [x] Backend batch POST verified in M7 (`api_e2e.ps1`).

### Visual / UX

- [x] Main menu, shop and ad-failure screenshots captured in `docs/preview/`.
- [ ] 130 % text scale and +60 % pseudo-locale on every M6-touched screen.
- [x] Ukrainian and English strings on the consent/shop/ad toasts.

## Sign-off

| Milestone | Date | Verdict | Notes |
|---|---|---|---|
| M6 | 2026-10-31 | partial | Ads/Store fill blocked by the environment network; see PROGRESS |
| M8 | 2026-10-31 | pass with documented gaps | All automated gates green; release installs/runs/persists on LDPlayer. Offline, crash reporting, real ads/billing, 30-min soak, final store art and Play Console submission remain. |
