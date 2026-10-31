# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.

**Spec:** 1.0 (`docs/AI_BUILD_PROMPT.md`) · **Milestone:** M6 done (tagged) → M7 next
**Branch:** `main` · **Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2)
**Verification (M6, green except device ad fill):** check_project exit 0 · tests
**60/60** · smoke **25/25 scenes** · battle_smoke PASS · ads_flow_smoke PASS ·
lint_locale **640 keys, 0 missing, 0 unused** · debug APK **179 MB**, installed
and launched on LDPlayer · previews `m6_device.png`, `m6_shop_device.png`,
`m6_ads_failure.png`
**Toolchain:** Android SDK `C:\Android\Sdk`, JDK 17 `C:\Tools\jdk-17`, LDPlayer
`E:\LDPlayer\LDPlayer14`, adb `127.0.0.1:5555` (see `docs/ANDROID.md`)

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | done | `v0.2.0-m1` |
| M2 | Combat depth | done | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | done (M3.1 balance pass) | `v0.4.1-m3` |
| M4 | Meta progression and persistence | done | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | done | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | done, tagged (ad fill blocked by env network) | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

## M5a delivered (first half of M5, no tag)

- **Localization**: `localization/strings.csv` (`keys,en,uk`, **530 keys**, real
  English + Ukrainian, registered in Project Settings). All scene labels now hold
  keys (engine `tr()`); all code strings go through `LocaleService.t(key)`. No
  literals left in `.tscn` labels except symbols. `LocaleService`: live
  `set_language`, `format_number` (`12 480` NBSP / `12,480`), `format_percent`,
  `format_duration` (`2г 15хв` / `2h 15m`), `format_countdown`, `plural(n, base)`
  with Ukrainian one/few/many incl. 11–14, `.one/.few/.many/.other` CSV rows and
  `pseudo` (+~60 %). Data resources keep `name_key`/`description_key`/
  `label_key`; card stats, magica effects, mission titles and unlock names are
  localized at render time. `tools/lint_locale.gd` audits `.tscn/.gd/.tres` vs CSV,
  key format, empty cells and placeholder parity; non-zero on failure.
- **Audio**: `tools/generate_audio_placeholders.py` (numpy) writes 3×20 s music
  loops + 30 SFX WAVs into `assets/audio/{music,ui,battle,meta}/` (16-bit mono
  44.1 kHz). `AudioService` owns one music player (0.8 s crossfade, no restart on
  scene change), a 16-voice SFX pool (40 ms per-sound cooldown, ±5 % pitch),
  master/music/SFX/UI buses driven by `SettingsService`, −6 dB modal duck and
  focus resume. EventBus hooks: wave start/clear, boss spawn/remove, kills,
  leaks, crits, tower hits/shots, build/upgrade/sell, research start/complete,
  card flip/drop, level-up, purchases, and every Button (global UI click).
- **Settings** `scenes/menu/settings.tscn`: audio sliders (live), language uk/en
  (instant), text scale 100/115/130 % through a runtime theme duplicate, screen
  shake, haptics, damage numbers, debug FPS/pseudo-locale, read-only nickname,
  player ID + copy, legal placeholders, version, debug reset profile. The main
  menu gear routes here; the battle pause menu opens it as a modal overlay (run
  stays alive).
- **Onboarding** `scenes/onboarding/first_launch.tscn`: language → nickname
  (3–16, Unicode letters/digits/underscore, inline errors) + 6 avatars → Play;
  creates UUID v4 `player.id`, nickname, avatar, `is_onboarded`, flushes save.
  Boot routes to it when the save is not onboarded.
- **Navigation**: `SceneRouter` fade + history + `open_overlay()`, Android
  `NOTIFICATION_WM_GO_BACK_REQUEST`/`ui_cancel`, modals closed first, settings
  overlay closed before leaving, onboarding back steps inside the wizard, and
  battle back opens pause (abandon still needs confirm).
- Tests: **+8 (47 total)** — locale lint, en/uk catalogues, Ukrainian plurals,
  number/duration/countdown formatting, pseudo-locale, settings persistence,
  nickname validation + UUID v4, audio dB mapping.

## M5b delivered (completes M5, tagged `v0.6.0-m5`)

- **Main menu** rebuilt to `docs/reference/ui_main_menu.png`: coin/gem pills with
  `+` shortcuts (route to the shop tab), gear, centered logotype, clickable stats
  card (best wave, avatar frame, nickname, player level + XP bar), Battle CTA,
  Speed Trial rewarded offer (M6 toast, no fake grant), daily missions `n/3` card
  with View, compact Magica entry, and the five-tab nav with active state +
  notification dots (missions claimable, cards upgradable, Magica claim on Home).
  A ScrollContainer keeps the layout alive at 130 % text and +60 % pseudo text.
- **Shop** `scenes/menu/shop.tscn`: `Gems` / `Coins` / `Special` tabs, 2-column
  offer cards, 7 products from spec §7.3 (`IapCatalog`), bonus/best-value badges,
  price `—` and disabled `Store unavailable` buy buttons until M6, restore link,
  `No Ads` + `Starter Pack`, and a debug-only simulate-purchase button that runs
  the RewardBundle grant path through `IapService`.
- **Leaderboard** `scenes/menu/leaderboard.tscn`: Weekly / All-time / Tournament,
  50 deterministic fake entries from `LocalBackendStub` around the player's best,
  top-3 medals, own rank pinned at the bottom, refresh with loading state,
  offline banner + last-updated time, empty state, and a tournament cohort with
  percentile reward tiers. All access goes through `LeaderboardService`, whose
  `_load()` is the single M7 swap point.
- **Profile** `scenes/menu/profile.tscn`: avatar frame, read-only nickname +
  "change in Settings" hint, player ID with copy, level + XP bar, lifetime stats
  (best wave, runs, kills, playtime, coins earned) and Leaderboard / Settings
  actions. Linked from the menu stats card and Settings → Account.
- **Polish**: one global `ToastService` FIFO (no overlapping toasts), refreshed
  modal scrim dismiss, leaderboard loading/empty states, notification dots,
  card rarity frame skins, tweened coin-fly on mission claims, shop/leaderboard
  UI SFX, and a clean smoke-test exit (no leaked audio stream / ERROR lines).
- Navigation: every bottom tab now opens its real screen; no "coming soon" path
  remains. Shop is a real tab, not a toast.
- Tests: **+4 (51 total)** — shop catalogue integrity (7 products, tabs, bundles,
  en/uk keys), leaderboard deterministic order + own-rank insertion + tiers,
  profile stats aggregation/legacy fallback, and the toast FIFO.
- Previews: `docs/preview/m5b_menu_en.png`, `m5b_menu_uk.png`,
  `m5b_menu_pseudo.png`, `m5b_shop.png`, `m5b_leaderboard.png`,
  `m5b_profile.png`.

## M6 delivered (tagged `v0.7.0-m6`)

- **Android export**: `export_presets.cfg` debug preset `Android` (package
  `com.endertainment.thetree`, portrait + immersive, min SDK 24, target 35,
  x86_64 + arm64, `use_gradle_build=true`). `tools/export_android.ps1` sets
  `JAVA_HOME`/`ANDROID_HOME`, generates the gitignored debug keystore, installs
  the Android build template and produces `build/the-tree.apk` (**~179 MB**
  debug). `tools/install_ldplayer.ps1` connects adb, installs, launches and
  optionally screenshots. `docs/ANDROID.md` documents the exact commands.
- **Ads**: Poing Studios AdMob **5.1.0** + `android-template-v4.7.2` (verified on
  Godot 4.7.2; `[AdsService] GMA initialized (plugin v5.1.0, platform 1.4.0)` on
  device). `AndroidAdsAdapter` handles async GMA init, UMP consent, rewarded and
  interstitial loads; the desktop stub plays a visible `DebugAdOverlay`.
  `AdsService` implements all §7.2 placements, per-run/day caps, the
  every-3rd-run/120 s/wave-5 interstitial rule, one-reward-per-view
  (`AdRewardGuard`), consent gate, failure reasons, `No Ads` interstitial
  disablement, and persisted caps in the save's `ads` section. Speed Trial now
  grants a real 24 h boost (or the next locked speed); the battle pause menu has
  Free Cash and Tree Blessing offers; Magica has the 30-minute research speed-up.
- **IAP**: godot-google-play-billing **3.3.0**; seven §7.3 products moved to
  `config/shop.tres`; `IapService` handles store prices, purchase/restore,
  pending/cancelled/already-owned/network reasons, purchase-token idempotency,
  consume/acknowledge and `RewardBundle` grants. Shop buttons enable only when
  `is_available()`; otherwise "Store unavailable". `_verify_receipt()` is the
  documented M7 hook.
- **Consent + telemetry**: `SettingsService.consent_granted` (false in release,
  true in editor/debug) gates every ad; UMP is tried first and a local
  `ConsentDialog` is the fallback. `AnalyticsService` emits the §8.6 events with
  debug prints and optional batched HTTP (endpoint empty + disabled by default;
  only the random player UUID is attached).
- **Device polish**: safe-area margins via `SceneRouter`, haptics on boss
  spawn/leaks/ad rewards, app pause/resume freezes the battle clock (Audio and
  Save services keep their own hooks), Android back already routed through
  `SceneRouter`, and `docs/RELEASE.md` + `docs/QA_CHECKLIST.md` added.
- **Tests**: **+9 (60 total)** — ad caps + daily rollover, interstitial cadence,
  reward-once guard, IAP catalogue resource, monetization config/test IDs,
  billing reason mapping, speed-boost persistence, M6 locale keys, analytics
  privacy sanitization. New `tools/ads_flow_smoke.gd` proves the real
  AdsService→stub flow grants once, blocks the second daily request and fails
  gracefully when the SDK is disabled.
- **Previews**: `docs/preview/m6_device.png` (main menu on LDPlayer),
  `m6_shop_device.png` (Store unavailable state), `m6_ads_failure.png`,
  `m6_pause_ads.png` (battle pause with rewarded offers).
- **Android back**: `config/quit_on_go_back=false` + a SceneRouter debounce;
  verified Shop → menu, menu → exit, battle → pause, pause → battle on LDPlayer.

## Earlier milestones (summary)

- **M4**: save v2 (checksum/atomic/.bak/migration), WalletService, Level/Unlock,
  Workshop (24 tracks), Magica (14 nodes), Cards (12 + slots), Missions
  (3 daily / 5 weekly, 04:00), OfflineService, modifier pipeline. Tag
  `v0.5.0-m4`, 39 tests.
- **M0–M3**: boot/menu shell, battle vertical slice, combat depth, run economy,
  upgrades and speed. Tags `v0.1.0-m0` … `v0.4.1-m3`.

## Deviations / open items

- Placeholder music is **20 s WAV** (brief) rather than the final 60/90 s OGG
  from §9.9; the path/API is already OGG-compatible (ADR-028).
- Pseudo-locale is applied to `LocaleService.t()` at runtime and the +60 %
  layout stress is captured with a scene-wide transform in
  `tools/capture_scene.gd` (ADR-027). Normal language switching is engine-live.
- Text scale is a duplicated runtime theme; battle HUD `theme_override_font_sizes`
  stay authored (HUD numbers must not grow).
- `battle_controller.gd`/`battle_hud.gd` still exceed the 400-line guideline.
- 532 draw calls > M2 target 120 (placeholder art; atlas pass moved to M8).
- **Ads/Billing are wired but cannot complete a real transaction in this
  environment:** Google ad hosts (`googleads.g.doubleclick.net`,
  `pagead2.googlesyndication.com`) are unreachable from both the host and the
  emulator, so test rewarded ads fail with `ERR_ADDRESS_UNREACHABLE` (handled as
  `ad_unavailable`, no crash). Play Billing reports "In-app billing API version 3
  is not supported on this device"; a real purchase needs a Play Console listing
  and licence testers (M7/M8). All cap/one-reward/state logic is unit-tested and
  the debug overlay flow is verified headlessly.
- AdMob native AARs live in `addons/admob/android/bin`, which the addon's
  `.gitignore` excludes; `docs/ANDROID.md` documents the pinned install step. The
  Android build template (`android/`) is also gitignored.
- Safe-area insets apply to every Control screen's `SafeArea` MarginContainer.
  The battle HUD is a CanvasLayer without that container, so a notch-aware HUD
  pass is deferred to M8 (no cutout on the LDPlayer test image).
- **Leaderboard is local (M5b/M7):** `LeaderboardService` always serves the
  deterministic `LocalBackendStub` cohort and reports `is_offline() == true`.
  M7 replaces one `_load()` call with the HTTP client; the UI is unchanged.
- Capture helper now finishes `App.init_services()` before applying the capture
  language/pseudo-locale and only stages the preview afterwards (ADR-033).

## Next tasks — M7 (Backend, live features)

1. **ApiClient + backend**: stand up the FastAPI + Neon skeleton from §8.3,
   wire `ApiClient` (auth, retries, offline queue) and point
   `LeaderboardService._load()` at it; keep `LocalBackendStub` for editor/offline.
2. **Server-side commerce**: replace `IapService._verify_receipt()` with Google
   Play receipt validation, add AdMob SSV callback validation for
   `rewarded_earned` (server confirms a placement before the client grants), and
   move `AnalyticsService` to the real `POST /events` endpoint.
3. **Live-ops**: missions/tournament refresh from the backend, remote config for
   `config/monetization.tres` ad IDs and caps, and an admin-less migration path
   for save v3 if the profile gains server IDs.
