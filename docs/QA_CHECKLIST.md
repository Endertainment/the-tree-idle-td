# QA_CHECKLIST — manual checks per milestone

Run after `docs/RELEASE.md` automated gates are green. Mark a line only when it
was actually observed; write "not verified" with a reason otherwise.

Device: LDPlayer 14 (1080×1920 @ 480 dpi), package
`com.endertainment.thetree`, debug APK.

## M6 — Android, ads, billing, telemetry (2026-10-31)

### Boot / lifecycle

- [x] Cold start reaches the main menu on LDPlayer (GLES3 renderer).
- [x] No `FATAL EXCEPTION` in `adb logcat` during boot.
- [ ] Cold start ≤ 5 s (measured: ___ s; M6 build is a 179 MB debug APK).
- [x] App background/foreground during battle: simulation freezes/resumes,
      music pauses/resumes (AudioService + BattleClock).
- [x] Back button: Shop → main menu, main menu → exits, battle → pause,
      pause → battle (verified on LDPlayer; `Quit On Go Back` disabled so the
      native back no longer kills the activity before `SceneRouter` runs).
- [ ] 60 FPS on LDPlayer during a wave (not measured; no FPS overlay on device).
- [x] Safe-area inset applied by `SceneRouter` (no jump between scenes).

### Ads

- [x] `[AdsService] GMA initialized` in logcat (Poing 5.1.0, platform 1.4.0).
- [x] Rewarded request reaches the SDK and fails gracefully
      (`ERR_ADDRESS_UNREACHABLE`, see PROGRESS) without crashing.
- [x] Failure toast/button reset on the main menu (device check).
- [x] Desktop fake ad (`DebugAdOverlay`) grants exactly one reward
      (`tools/ads_flow_smoke.gd`).
- [x] Daily cap blocks the second `speed_unlock_24h` request
      (`tools/ads_flow_smoke.gd` + unit tests).
- [x] No ad request before consent (release default false; editor true).
- [ ] Interstitial cadence on a real device (needs fill; unit-tested only).
- [ ] No Ads purchase disables interstitials but keeps rewarded ads.
- [ ] App kill mid-ad: no double reward, cap persisted (unit-tested only).

### Billing

- [x] Shop shows "Store unavailable" and disabled buy buttons when
      `IapService.is_available()` is false.
- [x] Restore reports the local ownership list on desktop.
- [x] Debug simulate purchase grants through `RewardBundle` once.
- [ ] Real sandbox purchase (blocked: local debug build, no Play listing).
- [ ] Reinstall + restore recovers non-consumables (needs Play listing).
- [ ] Pending/cancelled/already-owned sheets (needs Play listing).

### Telemetry / privacy

- [x] Debug console prints `app_open`, `screen_view`, `ad_shown`, `ad_rewarded`
      (seen in device logcat).
- [x] Analytics disabled by default (no HTTP without endpoint).
- [ ] Backend batch POST (M7).

### Visual / UX

- [x] Main menu, shop and ad-failure screenshots captured in `docs/preview/`.
- [ ] 130 % text scale and +60 % pseudo-locale on every M6-touched screen.
- [ ] Ukrainian and English strings on the consent/shop/ad toasts.

## Sign-off

| Milestone | Date | Verdict | Notes |
|---|---|---|---|
| M6 | 2026-10-31 | partial | Ads/Store fill blocked by the environment network; see PROGRESS |
