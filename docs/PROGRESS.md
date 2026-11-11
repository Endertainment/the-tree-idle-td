# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.

**Spec:** 1.0 (`docs/AI_BUILD_PROMPT.md`) · **Milestone:** M8 done, tagged
`v1.0.0-m8` → launch hardening next
**Branch:** `main` · **Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2)
**Verification (M8):** check_project exit 0 · tests **74/74** · smoke **25/25
scenes, zero ERROR/WARNING** · battle_smoke **PASS** · balance_probe median **9**
· simulate_run medians **new 9 / mid 29 / max 55** over 10 seeds · lint_locale
**653 keys, 0 missing, 0 unused** · release AAB **73.2 MB** + release APK
**166.3 MB**, installed and launched on LDPlayer 14 (`docs/preview/m8_release.png`)
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
| M7 | Backend (FastAPI + Neon), live features | done (Neon/Docker runtime unverified) | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | done (tagged; launch gaps listed below) | `v1.0.0-m8` |

## Enemy roster port (2026-11-11, no tag)

- 6 enemies from the 20.10.2026 build are now in the project — the full table,
  the conversion rules and the attack model live in `docs/ENEMY_ROSTER.md`.
- Spawning: `raider` (8+), `thrower` (9+), `wyvern` (12+), `mage` (16+),
  `ram` (20+), `trebuchet` (24+). Each specialist is carved out of the grunt or
  runner pool (a tank for the ram), so the per-wave count is untouched, at least
  two mass units stay in every wave, and the diff against `HEAD` starts at wave 8.
- **Ranged attack implemented**: an enemy inside `attack_range` stops, fires every
  `attack_interval` for `attack_damage_pct` of the Tree's max HP, and never leaks.
  The controller owns the projectile pool, the battle-clock-scaled flight and the
  damage, which reuses `TreeEntity.receive_leak` so the meta reduction and the
  `tree_hurt` SFX apply once.
- Towers, units and the 5 launch enemies are untouched.
- Verification: import/parse clean · tests **76/76** · smoke **25/25 scenes** ·
  battle_smoke **PASS** · `ranged_probe` **PASS** (shot fired, landed, Tree HP
  dropped) · `simulate_run --profile=mid --runs=3` median **9** (HEAD baseline
  **8**) · `balance_probe two seed=1` **5** (HEAD baseline **5**).
- Both balance gates also miss at `HEAD` (probe 5 < 7; mid 9 vs target 25–35),
  and the mid profile scores like `new`, which points at the simulator's meta
  setup being inert in this environment. Treat the numbers as an A/B, not a
  pass — worth a separate session.

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

## M7 delivered (tagged `v0.8.0-m7`)

- **Server** `server/`: FastAPI + Pydantic v2 + SQLAlchemy 2 async with the full
  §8.5 endpoint table (`/healthz` unauthenticated, everything else `/v1` with
  bearer auth except guest/refresh and the signed SSV callback). Tables:
  `players`, `saves`, `runs`, `leaderboard_entries`, `tournaments`,
  `tournament_entries`, `purchases`, `events`, `missions_state`, plus
  `idempotency_keys`. JSON→JSONB variant means SQLite locally and Neon in
  production with only `DATABASE_URL` changed (`?ssl=require` supported).
  Alembic baseline + `create_all` bootstrap, seed script, `api.http`, Dockerfile
  and compose file (Docker unavailable here), `.env.example`, `README.md`, and
  `SPEC.md` matching the implementation.
- **Auth**: guest device account, HS256 access (15 min) + rotating refresh
  (30 days, SHA-256 stored), `hashlib`/`secrets` only. No token ever logged.
- **Cloud save**: revision-checked PUT (409 with the server copy), `Idempotency-Key`
  replay, profile mirror (nickname/avatar/level/xp) on save.
- **Leaderboard**: weekly/all-time/tournament scopes, deterministic tie-break
  (wave desc → earlier submission → lower play time), cursor pagination, own rank
  computed against the full board.
- **Tournaments**: lazy weekly tournament (same Kyiv 04:00 reset), cohorts of 50,
  eligibility level 12, standings with percentile + §6.7 reward tiers, validated
  submission. Anti-cheat rejects duration < waves × 20 s, >2.5 waves/min,
  >250 k DPS and oversized cash; every attempt (accepted or not) is stored with
  its reason. Optional HMAC run signature via `RUN_HMAC_SECRET`.
- **Monetization/telemetry stubs**: idempotent purchase verify (`verified_by=stub`,
  `PURCHASES_MODE=disabled` returns 503), signed AdMob SSV (HMAC stopgap,
  transaction-id idempotency, timestamp skew check), batched events (≤100,
  scalar props, 90-day prune).
- **Client**:
  - `ApiClient` autoload is the only `HTTPRequest` owner (test-enforced): typed
    `ApiResult`, 10 s/15 s timeouts, 1/2/4/8/16 s jittered retries, 401 refresh,
    Idempotency-Key on mutations, tokens in `user://auth.json`, persisted queue
    in `user://api_queue.json` flushed on reconnect, offline cooldown + recovery.
  - `LoginService` guest login on first online boot (device id = save UUID),
    refresh, retry loop; waits for onboarding so the first account is stable.
  - `SaveSyncService` local-first sync with 2 s debounce, boot pull when the
    server is newer, three-way merge (server wins conflicts, local-only changes
    pushed as a patch), persisted state, Settings status row + "Sync now".
  - `LeaderboardService` fetches real weekly/all-time/tournament boards and
    `/tournaments/current`, maps rows, keeps own rank, caches to
    `user://leaderboard_cache.json`, falls back to `LocalBackendStub` offline or
    on error; the screen rebuilds when live data arrives.
  - `RemoteConfigService` merges `GET /config` over `config/remote_defaults.tres`
    with a 1 h `user://remote_config.json` cache; `config/env.tres` holds base
    URLs. `AnalyticsService` now posts through `ApiClient`.
- **Tests**: server **31 pytest**; client **+10 → 70/70**, all green, including a
  guard that no script other than `ApiClient` creates an `HTTPRequest`.
- **Proof**: `tools/api_e2e.ps1` (uvicorn on 127.0.0.1:8000 → guest login → save
  PUT + idempotent replay → profile → leaderboard → tournament submit →
  standings → leaderboard own rank) prints **PASS** and stops the server.
- **Not verified (environment):** Neon/PostgreSQL runtime, Docker build/compose,
  Android device run of the live API. The PostgreSQL URL path, TLS normalisation
  and shared metadata are unit-tested; the runtime proofs all use SQLite.

## M8 delivered (tagged `v1.0.0-m8`) — release 1.0.0

- **Balance simulation** `tools/simulate_run.gd`: headless, seeded, real battle
  scene, one competent bot, three meta profiles (`new` level 1; `mid` level 12
  with 8 levels on 13 combat/utility workshop tracks + 2 rare cards; `max` level
  20 with all 24 workshop tracks at 30 + 4 maxed cards + Fourth Branch), per-run
  lines and median/min/max/p10/p90 with a non-zero exit when the band misses.
  `tools/tutorial_probe.gd` proves the hint flow.
- **Balance (data only, ADR-042):** 60-wave table; HP `1.06^(w-1)` with a ×4
  step at the wave-10 boss and ×1.20/wave after 40; in-run Regen capped at
  0.5 %/s / 10 levels with a higher cost. Measured over seeds 1–10: **new 9**
  (all seeds), **mid 29** (bimodal 29/43, median 29), **max 55** (all seeds).
  Independent `balance_probe.gd` zero-meta median **9**. Before the pass every
  profile cleared the 30-wave table end and Regen healed 500+ leaks.
- **Tutorial hints (3, non-blocking, dismissible, persisted):** "Tap a pedestal
  to build" on wave 1, "Spend cash to grow stronger" on the first upgrade panel,
  "Coins are permanent — upgrade the Workshop" on the first run summary.
  `TutorialService` + `TutorialHint` (code-built panel, z-index above sheets),
  `GameState.tutorial.shown` in the save, en + uk copy, 4 new tests.
- **Release build:** `Android Release` export preset (AAB, version code 8 /
  1.0.0), local release keystore (gitignored) and a placeholder password that
  lives only in `tools/keystore/README.md`, `tools/export_release.ps1` patches a
  temporary preset copy and restores it; `build/the-tree.aab` **73.2 MB** and
  `build/the-tree-release.apk` **166.3 MB**. `adb install -r` + launch on
  LDPlayer 14, onboarding → menu → battle at wave **1/60**, force-stop/relaunch
  keeps the profile, ~117 FPS at wave 1.
- **Performance:** `tools/perf_probe.gd` at 120 enemies + 8 towers + 4 units:
  **1036.5 FPS / 543 draw calls** (desktop RTX 3050). Draw-call guideline
  (<120) not met → ADR-043 atlas pass deferred; recorded in `docs/PERF.md`.
- **Quality cleanup:** corrupt-save recovery now parses with `JSON.parse()`
  (no engine "Parse JSON failed" ERROR); `SaveService.quiet` suppresses the two
  expected recovery warnings in tests; `AudioService.release_all()` and tool
  cleanup remove the leaked `AudioStreamWAV`/playback and "resources still in
  use" lines. `battle_smoke.gd` levels its towers for the harder wave 10.
  Tests/smoke/battle_smoke now finish with **zero ERROR/WARNING lines**.
- **Release docs/assets:** `docs/RELEASE.md` (versions, gates, signing, sizes,
  store, privacy/data-safety, crash-reporting decision, known issues),
  `docs/QA_CHECKLIST.md` (M8, honest verified/unverified), `docs/PERF.md`,
  `docs/ANDROID.md` release section, `docs/store/` icon + feature graphic + 3
  screenshots (placeholders), `CHANGELOG.md` 1.0.0, ADR-042/043/044.
- **Previews:** `docs/preview/m8_release.png` (release main menu on LDPlayer),
  `m8_battle_hint.png` (release battle wave 1/60).

### Remaining launch gaps (honest)

1. Draw calls **543** vs the <120 M2 guideline (ADR-043; no visual regression
   was traded for it). Desktop 1036 FPS, LDPlayer ~117 FPS at wave 1.
2. Universal QA APK is **166.3 MB**; the AAB is 73.2 MB. Play's per-device split
   was not measured (`bundletool` not installed). AAB is the upload artifact.
3. Ads do not fill in this environment (Google ad hosts unreachable); billing
   cannot complete without a Play Console listing. Failure paths are tested.
4. Neon/PostgreSQL/Docker runtime and a real Android device were unavailable;
   SQLite is the verified backend runtime (M7).
5. No crash-reporting SDK (hook documented, post-launch task); analytics endpoint
   empty/disabled.
6. Store art/fonts are placeholders; Play Console privacy policy + data-safety
   forms are not submitted.
7. Device **offline airplane-mode run** and a **30-minute soak** were not
   verified (wifi disable wedged the emulator shell; session shorter than 30 min).
   The offline/local-first logic is covered by tests, not by an M8 device run.
8. Battle HUD safe area (notch) and the 130 % / pseudo-locale stress pass were
   not re-run on the M8 release build.

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
- **543 draw calls** at the 120-enemy M8 stress > M2 target 120 (placeholder
  art; atlas pass moved to post-launch, ADR-043).
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
  pass is **still deferred** (no cutout on the LDPlayer test image; M8 did not
  change it).
- **Leaderboard is live-or-local (M7):** `LeaderboardService` fetches the real
  API when authenticated and online (own rank included), caches the last
  response and falls back to the deterministic `LocalBackendStub` when offline or
  on any request error. The screen is unchanged.
- **Backend runtime gaps:** Neon/PostgreSQL, Docker and a real Android device
  were unavailable this session. SQLite is the verified runtime; the Postgres
  path is URL-normalisation-tested and the compose file is unverified. Purchase
  and SSV verification remain explicit stubs (ADR-039/040/041).
- Capture helper now finishes `App.init_services()` before applying the capture
  language/pseudo-locale and only stages the preview afterwards (ADR-033).

## Next tasks — launch hardening (post-1.0.0)

1. **Atlas/draw-call pass** (ADR-043): one atlas per family (enemies, towers,
   UI/icons), `AtlasTexture` for the HUD, `SpriteFrames` reuse; target <200
   draw calls at 120 enemies without visual change.
2. **Monetization verification:** Play Console internal testing track + licence
   testers, real rewarded fill, ECDSA AdMob SSV and Google Play Developer API
   purchase verification (replace the M7 stubs).
3. **Ship blockers outside code:** privacy policy URL, data-safety form, final
   store art/fonts, crash-reporting SDK decision, real-device QA and a 30-minute
   soak, airplane-mode run. Measure the AAB per-device download with bundletool.

## Launch command

```powershell
pwsh -NoProfile -File tools/check_project.ps1
godot --headless --path . --script res://tests/run_tests.gd
pwsh -NoProfile -File tools/export_release.ps1
pwsh -NoProfile -File tools/install_ldplayer.ps1 -ApkPath build/the-tree-release.apk -Screenshot docs/preview/m8_release.png
```

