# Changelog

All notable changes are recorded per milestone. The project follows semantic
versioning for tags; unreleased work stays under `[Unreleased]`.

## [Unreleased]

### Added

- **Enemy ranged attack.** `EnemyData` gained `attack_range`, `attack_interval`,
  `attack_damage_pct`, `attack_projectile`, `attack_projectile_speed` and
  `attack_sfx`. An enemy inside its range stops, fires every interval and never
  leaks — it wins by chipping the Tree. `BattleController` owns an 8-sprite
  projectile pool, the flight (battle-clock scaled, so pause and 2× behave), the
  impact FX and the damage, which goes through `TreeEntity.receive_leak()` so the
  meta damage-reduction modifiers and the `tree_hurt` SFX apply once, as for a
  leak. `ranged_shots_fired()` / `ranged_hits_landed()` counters feed the tools.
- `thrower` (320 px, 1.5 %/2.4 s), `mage` (340 px, 2.0 %/3.0 s) and `trebuchet`
  (520 px, 3.0 %/4.5 s) now spawn — waves 9, 16 and 24. The wave generator takes
  each specialist from a grunt, then a runner, keeping ≥2 mass units per wave and
  the tuned `5 + floor(0.8 × wave)` count.
- `tools/ranged_probe.gd`: boots the real battle at wave 9 and proves the shot is
  fired, lands and costs the Tree HP. `test_ranged_attack_window` covers the
  geometry; `test_ported_enemy_roster` now asserts all six ports spawn.
- **Ported enemy roster from the 20.10.2026 build** (`docs/ENEMY_ROSTER.md`):
  `raider`, `wyvern` and `ram` now spawn from waves 8 / 12 / 20 — one specialist
  per wave, carved out of the existing grunt/tank pool, so the tuned
  `5 + floor(0.8 × wave)` count is unchanged and waves 1–8 stay byte-identical.
  `thrower`, `mage` and `trebuchet` are data- and art-complete but deliberately
  stay out of the table until the enemy ranged attack exists (the new combat
  model only walks and leaks).
- 36 placeholder walk frames (`enemy_*_walk_00..05.png`), `enemy.<id>` en/uk
  strings, and `test_ported_enemy_roster` — it fails if a ranged port ever
  spawns early or if a ported stat drifts from the port table.
- HP/speed/armor are ported unchanged; the old flat `damage` became
  `leak_damage_pct`, `coins` became `cash_reward` and `radius` became `scale`,
  re-expressed for the 1200 HP Tree and the new cash economy.

## [1.0.0] — 2026-10-31 — M8 balance, polish, release readiness

### Added

- **Balance simulator** `tools/simulate_run.gd`: headless, seeded, real battle
  scene, the same competent bot across three meta profiles (`new` level 1, `mid`
  level 12 + 8 workshop levels + 2 rare cards, `max` level 20 + all workshop 30
  + four maxed cards + Fourth Branch), per-seed output and median/p10/p90
  summary. `tools/tutorial_probe.gd` proves the three first-run hints fire and
  persist.
- **First-run tutorial hints** (3, non-blocking, dismissible): "Tap a pedestal
  to build" at wave 1, "Spend cash to grow stronger" on the first upgrade panel,
  "Coins are permanent — upgrade the Workshop" on the first run summary. Shown
  flags persist in the save's additive `tutorial` section; en + uk copy.
- **Release build**: `Android Release` export preset (AAB), signed release
  keystore workflow (`tools/export_release.ps1`, keystore + password never in
  git), `build/the-tree.aab` (73.2 MB) and `build/the-tree-release.apk`
  (166.3 MB QA artifact), installed and launched on LDPlayer 14.
- **Release docs/assets**: `docs/RELEASE.md`, `docs/QA_CHECKLIST.md` (M8),
  `docs/PERF.md`, `docs/store/` (icon 512, feature graphic 1024×500, three
  1080×1920 screenshots), `docs/ANDROID.md` release-signing section.

### Changed

- **Balance (data only)**: 60-wave table; HP growth `1.06^(w-1)` with a ×4 step
  at the wave-10 boss and ×1.20 per wave after 40; in-run Regen capped at
  0.5 %/s, 10 levels with a higher cost. Measured medians over 10 seeds: new 9,
  mid 29, max 55 (`docs/BALANCE.md`, ADR-042).
- **Version**: project and app `1.0.0`; export version code 8.
- **Tests**: **74/74** (M8 adds four: tutorial one-shot/persistence, tutorial
  locale catalogue, hint control, release wave curve); `balance_probe` stays at
  median 9.
- **Quality**: corrupt-save recovery no longer logs an engine JSON parse error,
  headless tools release audio resources before exit (no leaked AudioStreamWAV
  or "resources still in use"), and `battle_smoke` adapts its tower levels to
  the harder wave 10.

### Known issues

- 543 draw calls at the 120-enemy desktop stress (guideline <120); atlas pass
  deferred to post-launch (ADR-043).
- Universal QA APK is 166 MB; AAB is 73.2 MB and Play's per-device split size
  was not measured with `bundletool` (not installed here).
- Ads/billing cannot complete a real transaction in this environment; SQLite is
  the verified backend runtime; no crash-reporting SDK; store art is
  placeholder. See `docs/RELEASE.md` for the full list.

## [0.8.0-m7] — 2026-10-31 — M7 backend, cloud saves, live leaderboard

### Added

- **Server (`server/`)**: FastAPI app with Pydantic v2 and SQLAlchemy 2 async,
  JWT access/refresh auth, guest accounts, cloud saves with revision conflicts
  (409 + server copy) and Idempotency-Key replay, remote config, weekly
  leaderboard with cursor pagination and own rank, tournaments with 50-player
  cohorts/standings/submission, run telemetry, purchase verification stub,
  signed AdMob SSV callback and batched analytics. SQLite (`aiosqlite`) is the
  default; PostgreSQL/Neon works through `DATABASE_URL` with no code changes.
- **Server operations**: `Dockerfile`, `docker-compose.yml`, `.env.example`,
  `alembic.ini` + async Alembic baseline, `create_all` bootstrap, seed script
  (`python -m app.seed`), `api.http` collection, OpenAPI at `/docs`,
  `server/README.md` and an implementation contract in `server/SPEC.md`.
- **Client `ApiClient`** (`scripts/platform/api_client.gd`): the project's only
  `HTTPRequest` owner. Await-able typed `ApiResult`, 10 s timeout (15 s saves),
  1/2/4/8/16 s retry backoff with jitter, one refresh-token rotation on 401,
  Idempotency-Key on every mutation, tokens in `user://auth.json` and a persisted
  offline queue in `user://api_queue.json` flushed on reconnect.
- **`LoginService`**: guest login on the first online boot using the save's UUID
  as `device_id`, refresh when expiring, periodic recovery after an offline
  period, and no login while the onboarding wizard has not created the player.
- **Cloud save sync (`SaveSyncService`)**: local-first autosave push (2 s
  debounce), pull on boot when the server is newer, three-way merge with the last
  synced payload as base — real conflicts resolve to the server, local-only
  changes are pushed as a patch. Persisted sync state and a live status row with
  "Sync now" in Settings.
- **Live leaderboard**: `LeaderboardService` now fetches `/leaderboard` and
  `/tournaments/current`, maps server rows through `LeaderboardBackend`, keeps
  own rank/live tournament info, caches to `user://leaderboard_cache.json`, and
  falls back to `LocalBackendStub` offline or on any error. The screen refreshes
  when a live response arrives.
- **Remote config**: `RemoteConfigService` merges `GET /config` over
  `config/remote_defaults.tres`, caches it in `user://remote_config.json` for one
  hour and exposes feature flags/ad frequency. `config/env.tres` holds the
  debug/Android-debug/release base URLs.
- **Analytics**: batched events now go through `ApiClient` to `POST /events`;
  the last `HTTPRequest` outside `ApiClient` was removed.
- **Tests**: server **31 pytest** (auth/refresh, save 409 + idempotency,
  leaderboard ordering/own rank/pagination, tournament accept/reject with a
  stored rejection reason, DST week boundaries, events validation, SSV
  signatures, purchases, URL normalisation). Client **+10 (70 total)**:
  backoff schedule, URL building, typed result, queue persistence/retry/drop,
  sync policy, three-way merge, remote-config merge/TTL, server-row mapping,
  env resources, and a guard that `ApiClient` is the only `HTTPRequest` owner.
- **Proof**: `tools/api_e2e.ps1` starts uvicorn on 127.0.0.1:8000, runs
  `server/e2e_client.py` (guest login → save PUT → leaderboard GET → tournament
  submit → standings), prints PASS and always stops the server.

### Changed

- Project version is now **0.8.0** (`project.godot`, `App.VERSION`).
- `SaveService` emits `saved(payload)` so cloud sync can react to local writes.
- The app boot sequence adds api → login → remote config → save sync →
  leaderboard after the existing services; all of them degrade offline.

### Known limits

- Neon, Docker and a real device were not available in this environment: the
  PostgreSQL path is URL-normalisation-tested and documented, the Docker files
  are provided but unverified, and all runtime proofs use SQLite.
- Purchase validation and AdMob SSV use explicit shared-secret stubs; a real
  Play/App Store verifier and Google's ECDSA keys are M8 work.
- The leaderboard still falls back to deterministic stub rows until the first
  successful authenticated fetch (online: real data and own rank).

## [0.7.0-m6] — 2026-10-31 — M6 Android, ads, billing, telemetry

### Added

- **Android export**: `export_presets.cfg` (debug preset `Android`, package
  `com.endertainment.thetree`, portrait/immersive, min SDK 24, target 35,
  x86_64 + arm64), `tools/export_android.ps1` (JDK 17 + SDK env, generated debug
  keystore, build-template install, Gradle export to `build/the-tree.apk`) and
  `tools/install_ldplayer.ps1` (adb connect/install/launch/screenshot).
  `docs/ANDROID.md` lists the verified toolchain and exact commands.
- **Ads**: Poing Studios AdMob **5.1.0** (`addons/admob`, verified on Godot
  4.7.2), `AndroidAdsAdapter` with GMA initialization, UMP consent, rewarded and
  interstitial loads, plus a desktop `DebugAdOverlay` fake ad. `AdsService` owns
  placements from §7.2 (`run_double_coins`, `free_cash`, `tree_blessing`,
  `speed_unlock_24h`, `research_speedup`, `run_end_interstitial`), per-run/day
  caps, the every-3rd-run/120 s/wave-5 interstitial rule, one reward per view,
  the consent gate, failure reasons and the "No Ads disables interstitials" rule.
  Speed Trial now grants a real 24 h 1.5x boost (or the next locked speed), and
  the battle pause menu offers Free Cash and Tree Blessing.
- **IAP**: godot-google-play-billing **3.3.0** (`addons/GodotGooglePlayBilling`),
  `IapService` with the seven §7.3 products in `config/shop.tres`, store prices,
  purchase/restore/pending/cancelled/already-owned states, purchase-token
  idempotency, `RewardBundle` grants, consume/acknowledge and a documented M7
  receipt-verification hook. Shop buttons enable only when `is_available()`.
- **Telemetry**: `AnalyticsService` with the §8.6 events (`app_open`, `run_start`,
  `wave_cleared`, `run_end`, `purchase`, `ad_shown`, `ad_rewarded`, `screen_view`,
  `error`), debug prints and optional batched HTTP disabled by default.
- **Device polish**: safe-area insets applied by `SceneRouter`, haptics on boss
  spawn/leaks/ad rewards respecting the settings toggle, app pause/resume
  freezing the battle clock while audio and save services handle their own hooks,
  and `docs/RELEASE.md` + `docs/QA_CHECKLIST.md` skeletons.
- **Tests**: **+9 (60 total)** — ad placement caps and daily rollover,
  interstitial cadence, reward-once guard, IAP catalogue resource, monetization
  config (test IDs/caps), billing reason mapping, speed-boost persistence,
  M6 locale keys, analytics privacy sanitization.

### Changed

- `SettingsService` gained persisted `consent_granted` (false in release, true in
  editor/debug) and a debug `fake_monetization` switch.
- Android uses the Compatibility (GLES3) renderer (`rendering_method.mobile`).
- `locale_lint.gd` treats `shop.purchase_*` as runtime-assembled keys.

### Fixed

- AdMob rewarded loads now wait for the asynchronous GMA initialization callback
  (loading earlier crashed the native SDK).
- Android back no longer quits while leaving Shop/entering battle: `Quit On Go
  Back` is disabled and `SceneRouter` debounces the notification/key pair; it
  only quits from the main menu and opens the battle pause menu otherwise.

## [0.6.0-m5] — 2026-10-31 — M5 shell, UX, localization, audio

### Added

- **Localization**: `localization/strings.csv` with **607 keys** in English and
  Ukrainian (Godot CSV import, both catalogues registered in Project Settings).
  Every `.tscn` label now stores a translation key; code strings go through
  `LocaleService.t()`. Data resources (`tower`, `unit`, `enemy`, `workshop`,
  `card`, `magica`, `tree_upgrade`, `mission`) render their `*_key` fields through
  the active locale. `LocaleService` gained live `set_language()`,
  `format_number()` (`12 480` / `12,480`), `format_percent()`,
  `format_duration()` (`2г 15хв` / `2h 15m`), `format_countdown()`,
  `plural()`/`plural_count()` with Ukrainian one/few/many (11–14 exception) and a
  debug `pseudo` transform (+~60 % length). `tools/lint_locale.gd` fails on
  missing keys, unused keys, bad key format, empty cells or placeholder mismatch.
- **Audio**: `tools/generate_audio_placeholders.py` generates 3×20 s music loops
  and 30 short SFX (16-bit mono 44.1 kHz) into `assets/audio/{music,ui,battle,meta}/`.
  `AudioService` now has one persistent music player with an 0.8 s crossfade
  (menu/battle/boss themes), a 16-voice SFX pool with a 40 ms per-sound cooldown
  and ±5 % pitch, master/music/SFX/UI bus volumes from SettingsService, a −6 dB
  duck while a modal is visible, focus resume, and EventBus hooks for wave
  start/clear, boss spawn/remove, hit/crit/kill/leak, shots, build/upgrade/sell,
  research start/complete, card flip/drop, level-up, purchases and UI buttons.
- **Settings** (`scenes/menu/settings.tscn`): live music/SFX/UI sliders, instant
  language switch (uk/en), text scale 100/115/130 % applied to the live theme,
  screen shake, haptics, damage numbers, debug FPS counter and pseudo-locale,
  read-only nickname, player ID with copy, privacy/terms placeholders, version,
  and a debug-only reset profile. Reached from the main-menu gear; opened as a
  modal overlay from the battle pause menu without losing the run.
- **Onboarding** (`scenes/onboarding/first_launch.tscn`): language → nickname
  (3–16 chars, Unicode-letters validation, inline errors) + 6 avatars → Play.
  Creates a UUID v4 `player.id`, nickname and `avatar_id`, sets `is_onboarded`
  and flushes the save; Boot routes here when the profile is not onboarded.
- **Navigation**: `SceneRouter` history/back stack, `open_overlay()` modal
  screens, fade transitions, Android back / `ui_cancel` handling that closes
  modals first, steps back inside onboarding, and opens the pause menu (never a
  silent exit) while a battle is running.
- Tests: **+8 (47 total)** for locale lint, catalogues, Ukrainian plurals,
  number/duration/countdown formatting, pseudo-locale, settings persistence,
  nickname validation + UUID v4 and audio dB mapping.

### Added (M5b — menu, shop, leaderboard, profile, polish)

- **Reference main menu** (`scenes/menu/main_menu.tscn`): coin/gem pills with
  shop shortcuts, gear, centered logotype, clickable stats card (best wave,
  avatar frame, nickname, level + XP bar), Battle CTA, Speed Trial rewarded-ad
  offer, daily missions `n/3` card, Magica entry and the five-tab nav with
  notification dots. A ScrollContainer keeps it usable at 130 % text and pseudo
  locale.
- **Shop** (`scenes/menu/shop.tscn`): `Gems` / `Coins` / `Special` tabs,
  2-column offer cards, the 7 spec §7.3 products with bonus/best-value badges,
  `—` prices, disabled "Store unavailable" buy buttons, restore link and the
  `No Ads` / `Starter Pack` offers. `IapCatalog` + `IapService` stub; a
  debug-only simulate purchase grants through `RewardBundle`.
- **Leaderboard** (`scenes/menu/leaderboard.tscn`): weekly / all-time /
  tournament tabs, 50 deterministic `LocalBackendStub` entries, top-3 medals,
  own rank pinned at the bottom, refresh with loading state, offline banner with
  last-updated, empty state, cohort header and percentile reward tiers. All via
  `LeaderboardService` (single M7 swap point).
- **Profile** (`scenes/menu/profile.tscn`): avatar frame, read-only nickname +
  Settings hint, player ID with copy, level + XP bar, lifetime stats and
  Leaderboard/Settings actions. Linked from the menu stats card and Settings.
- **Polish**: global `ToastService` FIFO queue, notification dots in `MenuNav`,
  card rarity frame skins, coin-fly animation on mission claims, shop and
  leaderboard SFX hooks, leaderboard/empty/loading states, modal scrim dismiss.
- **Tests +4 (51 total)**: shop catalog integrity, leaderboard sort/own-rank,
  profile stats aggregation, toast queue.
- **Screenshots**: `docs/preview/m5b_menu_en.png`, `m5b_menu_uk.png`,
  `m5b_menu_pseudo.png`, `m5b_shop.png`, `m5b_leaderboard.png`,
  `m5b_profile.png`.

### Changed

- Main menu gear now opens Settings instead of a "coming soon" toast.
- Battle pause "Settings" now opens the real settings overlay.
- `SettingsService` persists `damage_numbers`, `show_fps` and `pseudo_locale`.
- Locale-aware formatting replaces per-screen number/duration strings.
- Shop tab now opens the real shop screen on every meta screen; the "coming
  soon" toast path is gone.
- All screen toasts route through one global queue instead of per-screen tweens.
- `GameState.stats.coins_earned` is tracked by `WalletService` for the profile
  stat (old saves fall back to the current coin balance).

### Fixed

- `tools/smoke_test.gd` no longer leaks the battle music stream: it stops music
  and frees scene instances before quitting, so the run has no ERROR lines.
- `tools/capture_scene.gd` boots services before applying the capture locale, so
  UK/pseudo screenshots are real and staged previews are no longer overwritten.

## [0.5.0-m4] — 2026-10-31

### Added (M4a)

- `SaveService` schema **v2**: full spec 8.2 document (player, wallet, stats,
  workshop, magica, cards, missions, unlocks, settings, shop, ads) plus local
  `is_onboarded`/`applied_rewards` extras, a canonical SHA-256 checksum, atomic
  temp write + rename, `.bak` fallback on parse/checksum failure, a pure
  `migrate_v1_to_v2()` (tested) and a one-time `save_migrated` log. Autosave is
  event-driven: run start/end, wave cleared (<=1/s debounce), meta purchase,
  scene change, app pause and `WM_CLOSE_REQUEST` (immediate flush).
- `WalletService` (`scripts/economy/wallet_service.gd`, after `GameState`) and
  the pure `MetaWallet`: the only coin/gem/stones mutation path, `add(bundle)`,
  `try_spend(kind, amount, reason) -> SpendResult`, a bounded 50-entry transaction
  log, `currency_changed`/`meta_purchased` events and debounced save-on-mutation.
  Run summary, "Double coins" and the debug grant now go through it; no direct
  `GameState.wallet[...]` writes remain.
- `LevelService` + `UnlockService`: XP curve `round(120 * 1.18^(level-1))`,
  multi-level grants, `level_up` event, the spec 6.2 unlock table in
  `data/progression/levels.tres` (levels 1–20) and `is_unlocked(id)`. The menu
  shows a combined unlock toast on the next visit. Speed 1.5x/2x gates now read
  `UnlockService`; debug grants still require a debug build.
- Workshop: `WorkshopTrack` resource + **24 `.tres`** in `data/workshop/`
  (4 categories × 6, spec 6.3 effects/caps/base costs, cost `base * 1.18^level`
  rounded to 5, max 50), `WorkshopModel` (pure) and `WorkshopService`
  (level_of/cost_of/try_buy, ModifierService aggregation by declared add/mul).
  New `scenes/menu/workshop.tscn`: header coin balance, 4 category tabs,
  scrollable generated rows (icon, name, `Lv x/50`, current → next, cost, Buy),
  insufficient-funds shake + "Need N more coins" toast, purchase flash and an
  optional SFX hook. The `Upgrades` nav tab routes to it (`SceneRouter.workshop`).
- One modifier pipeline: workshop, in-run Tree tracks and future cards/magica all
  register sources in `ModifierService`; Tree/Tower/Unit read `get_stat()` for
  damage, attack speed, crit, regen, range, max HP, starting cash, shield,
  damage reduction, cash/coin/XP gain and in-run discount. Run-scoped sources are
  removed when the battle scene exits.
- Tests: **+7** (29 total) — v1→v2 migration, checksum-corrupt → `.bak` fallback,
  wallet never negative + 50-entry log, workshop 24-track cost curve/caps, unlock
  gates at levels 3/4/10/12, modifier stacking/caps, and a `tree_damage` 10
  profile showing +40 % starting DPS. New `tools/persistence_proof.gd` buys a
  workshop level, reloads with a fresh SaveService and asserts it survived.
- Preview: `docs/preview/m4_workshop.png`.

### Added (M4b)

- **Magica** (`MagicaNode`, `MagicaModel`, `MagicaService`): 14 data nodes in
  `data/magica/` covering every named §6.4 row (Time/Wealth/Knowledge), one
  active research, UTC `started_at`/`ends_at`, offline completion on boot/focus
  into a claimable badge, 50 % cancel refund, research-speed modifier at start and
  one `magica:<id>` ModifierService source per completed node. `scenes/menu/magica.tscn`
  has the three branch columns, locked/available/active/done node states, a radial
  timer, "Speed up (AD)" stub and a Cancel confirmation.
- **Cards** (`CardData`, `CardCollection`, `CardService`): 12 cards in
  `data/cards/` (4 rarities, levels 1–5, shards 20/40/80/160, effect lists),
  duplicate shards with auto-upgrade, 1–5 equip slots (levels 2/5/15/20 + Deep
  Roots), one aggregated `&"cards"` source on equip and removal on unequip, and an
  8 % + `card_drop_chance` wave-clear drop. `scenes/menu/cards.tscn` adds loadout
  slots, filter/sort collection grid and a detail modal with live effect numbers,
  Upgrade, Equip/Unequip and where-to-get.
- **Missions** (`MissionTemplate`, `MissionTemplateTable`, `MissionSchedule`,
  `MissionModel`, `MissionService`): 3 daily + 5 weekly generated from
  `data/missions/templates.tres`, level-scaled targets/rewards, battle-event
  progress (`waves_cleared`, `kills`, `towers_built`, `wave_reached`, `crits`,
  `clean_runs`, `cards_equipped`, `ads_watched`), claim-once, all-3/all-5 bonuses
  (weekly includes a card pack), persist/reroll at 04:00 local and Monday 04:00.
  `scenes/menu/missions.tscn`: countdowns, progress bars, reward chips, Claim,
  Claim all (≥2) and the reset footer.
- **Offline income** (`OfflineModel`, `OfflineService`): UTC `last_seen_at`,
  0.01 coins/s base, 8 h cap + workshop `offline_cap_minutes`, Night Harvest
  multiplier, claim through `WalletService`, Welcome back modal on the main menu.
- **Navigation/UI**: Cards, Missions and Shop tabs wired (Shop shows "arrives with
  M6"), shared `MenuNav` with correct active state, Magica home-screen entry with a
  completion badge, Welcome back modal. New EventBus signals for kills/leaks/tower
  builds/card drops/Second Wind; Ancient Memory, Second Wind, Greed and Overgrowth
  reach the live battle.
- Tests: **+10 (39 total)** and `tools/m4b_acceptance.gd`; previews
  `m4_magica.png`, `m4_cards.png`, `m4_cards_detail.png`, `m4_missions.png`.

### Changed (M4b)

- `GameState.player.last_seen_at`, `magica.pending_claim` and the mission bonus
  flags are local extras inside the same v2 document; older saves default them.
- `tools/balance_probe.gd` isolates cards/magica/missions between runs and accepts
  an optional minimum-wave argument; `tests/run_tests.gd` runs the M4b suite.

### Changed

- `GameState` is now the profile container only: wallet mutations through
  `WalletService`, XP through `LevelService`, workshop levels through
  `WorkshopService`. `to_dict()` returns the full v2 document; `best_wave` moves
  to `stats` (kept in sync on the runtime player for existing HUD code).
- Battle run cash/coin/XP flows apply the workshop tracks (starting cash, cash
  gain, wave-clear bonus, in-run discount, coin/XP gain) — all no-ops at level 0,
  so M3/M3.1 battle balance numbers are unchanged.

### Verification (M4)

- `check_project` exit 0 · unit tests 39/39 · scene smoke 20/20 ·
  battle smoke PASS · `m4b_acceptance` PASS (research offline/restart, workshop
  DPS, card equip/unequip + Deep Roots, mission claim-once/04:00 reroll, offline
  claim, corrupt→`.bak`, Welcome back modal) · `balance_probe` exit 0
  (fill seed 1 cleared 11 waves; the M4 acceptance run used min-wave 10).

## [0.4.1-m3] — 2026-10-31

### Changed (M3.1 balance pass)

- Starting cash **50 → 120** in `WaveTable`/`wave_table_m2.tres` and spec §4.10
  (ADR-020), so wave 1 can afford the 60-cash Archer.
- Tower coverage: Archer range 300→400, Cannon 280→370, Frost Spire 260→340
  (ADR-021). `tests/test_battle.gd` asserts the new ranges.
- Wave pressure: HP growth 1.16→1.11, counts `6+1.2w`→`5+0.8w`, boss group
  x1.6→x1.20, spawn interval `0.72/0.35`→`1.00/0.45` s. Wave clear bonus
  `20+5w`→`60+14w`, kill cash multiplier `1.09^w`→`1.12^w`.
- `tools/balance_probe.gd` now accepts a policy + run seed, reports damage share
  by source and per-wave peak enemies, isolates RunState/GameState/SaveService
  and exits 0 when the floor gate (7 cleared waves) is met.
- `tests/test_battle.gd` wave/tower assertions updated to the M3.1 data.

### Verification

- `balance_probe`: 18 runs (3 openings × 6 seeds), median 9 cleared waves, range
  9–11, peak 11 concurrent enemies, all runs end in defeat on waves 10–12.
  Before the pass: all runs cleared 4 and died on wave 5.
- `check_project` OK, 22/22 unit tests, 17/17 scene smoke, 52-check battle smoke.

## [0.4.0-m3] — 2026-10-31

### Added

- `UpgradeTrack` resource + 6 data tracks in `data/tree/upgrades/` (damage,
  attack speed, crit chance, crit damage, range, regen) and `TreeUpgrades`, which
  loads the directory, aggregates bonuses, prices levels with `CostCurve` and
  exposes the shared `tree_dps()` formula. `TreeEntity` now applies the bonuses
  (crit cap 60 %, range, regen heal over time) and plays a gold flash + ring on
  purchase.
- `RunWallet` + `SpendResult`: one mutation point for run cash with a typed
  result (OK / insufficient / max level / invalid) and a 50-entry transaction
  log. Build, unit placement, tower/unit upgrade and sell paths go through it;
  `RunState.cash` is a read-only mirror.
- Generated upgrade panel (`UpgradePanel` + `UpgradeRow`): Tree / Units / Towers
  tabs, icon + level + current → next green preview + cost + disabled reason,
  hold-to-buy at 8/s (`HoldToBuy`, stops on the first failed spend), affordability
  notification dot/pulse, unit in-place upgrades and tower rows that open the
  tower sheet.
- Speed control 1x/1.5x/2x in the battle top bar with locked segments, a lock
  popup and a debug-only unlock (`GameState.unlocks`, level 3/10 gates). The speed
  is a `BattleClock` delta multiplier only; HUD tweens and audio stay real-time.
- Pause overlay with Resume / Restart (confirm) / Abandon (confirm) / Settings
  placeholder and live stats. It freezes the clock, spawning and timers while the
  HUD stays responsive. Abandon uses the same cleared-wave rewards as defeat.
- Next-wave accidental-tap guard (`TapGuard`, first 3 skips need a 250 ms hold).
- `RunSummary` v2: best wave + NEW BEST, cash-lost note, coins `sum(8+2w)` plus
  50 per boss wave, gems `floor(w/5)` + 5 on a new best, XP `10w`, count-up rows,
  and a "Double coins" button backed by `RewardedAdStub` (debug fake grant).
  Rewards are a single `RewardBundle` granted once per run id (`RewardLedger`).
- F3 debug overlay (fps, enemies, projectiles, cash, sim speed, wave, kills) in
  debug builds, and `tools/balance_probe.gd` for the wave-15 balance gate.
- Verification: 22 unit tests (wallet, 5 s hold-to-buy over-buy guard, track
  curves, DPS delta, bundle idempotency, speed maths, tap guard), a 52-check
  battle smoke, and M3 previews in `docs/preview/m3_*.png`.

### Changed

- `GameState` gains `unlocks`, `reward_ledger`, `wallet_log`, `grant_bundle()`,
  `claim_run_reward()` and the skip counter; the save payload carries them with
  safe defaults (no schema bump needed).
- `RunRewards.compute()` accepts boss-wave and new-best bonuses; `RunSummary`
  uses it through `RewardBundle`.
- Battle HUD top bar is two rows (wave/timer/pause/cash, then speed/gems) and the
  boss bar/countdown/banner moved down to make room.
- `SceneRouter.reload()` added for the pause-menu restart.
- `tools/battle_smoke.gd` now isolates save/GameState state and covers M3.

## [0.3.0-m2] — 2026-10-31

### Added

- Enemy archetypes `runner`, `tank`, `shaman` (140 px +20 % speed aura) and
  `boss_troll` with a boss HP bar (replaces the wave bar) and a spawn banner.
  Enemies are pooled, flash through `ui/shaders/hit_flash.gdshader` and expose
  `hp_changed` so the boss bar binds without polling HP.
- Towers `cannon` (splash 70), `frost_spire` (splash 60 + 35 % slow) and `totem`
  (aura +15 % damage / +10 % attack speed, no attack), all with 10 levels, three
  data-driven art tiers (L1-4 / 5-7 / 8-10), four targeting modes and the
  `TowerBehavior` registry (Double Shot, Shrapnel, Deep Chill, Rooted Gift).
  Towers can be selected, upgraded and sold for 70 % of invested cash.
- Guardian units `unit_archer`, `unit_mage`, `unit_druid` on the four canopy
  slots, with data-authored unlock conditions (free / level 4 / Workshop /
  level 12 or 150 gems), placement and in-place L1-10 upgrades (`50*1.45^(lvl-1)`).
- `StatusEffectComponent` (slow refreshes, never stacks), splash falloff and a
  true-damage hook in `DamageResolver`, a `SpatialHash` shared by towers, units,
  the Tree and splash, pooled floating damage numbers (cap 25), pooled death and
  splash FX, and Totem/shaman aura passes.
- A 30-wave `wave_table_m2.tres` with all five enemy types, swarm waves 5/15/25
  and boss waves 10/20/30 (authored x1.6 boss HP), generated by
  `tools/generate_wave_table.gd`.
- HUD: boss bar, build sheet for all four towers, tower sheet with stat preview +
  upgrade + sell, unit placement/upgrade sheet and a disabled 1x speed
  placeholder (M3 wires the real speeds).
- Verification: 15 unit tests (status refresh, targeting modes, behavior
  registry, splash falloff, true damage, boss cadence, slot unlocking, tower/unit
  data), a 22-check battle smoke, `tools/perf_probe.gd` (120 enemies + 8 towers +
  4 units) and preview captures in `docs/preview/m2_*.png`.

### Changed

- `battle_controller.gd` (state/flow) split into `battle_hud_controller.gd`, `build_sheet.gd`,
  `tower_sheet.gd` and `unit_slots.gd`; enemy pooling, hit resolution and arena construction
  live in `enemy_manager.gd`, `combat_system.gd` and `battle_arena.gd`. The HUD stays
  presentation-only and sheets pause `BattleClock`.
- Projectiles and the Tree now pass a `shot` dictionary (damage, splash, slow,
  source id) so one controller path resolves primary hits and splash.
- `wave_table_m1.tres` is replaced by `wave_table_m2.tres`; `MapData` gains
  `unit_slot_requirements`, `SpawnGroup` gains `hp_multiplier`.

## [0.2.0-m1] — 2026-10-31

### Added

- Data-driven battle content: `MapData` with two smooth lanes, 8 pedestal
  positions and 4 unit-slot anchors (`forest_clearing.tres`); `EnemyData`
  (`enemy_grunt.tres`), `TowerData` (`tower_archer.tres`), `TreeData`
  (`tree_base.tres`) and a 10-wave `WaveTable` (`wave_table_m1.tres`, 1.16x HP
  scaling, swarm wave 5, doubled wave 10).
- `DamageResolver.resolve()` as the only damage formula (crit before flat
  armor, 10 % armor floor), `CurveBuilder` Catmull-Rom lane smoothing and a
  pooled homing `Projectile`.
- Battle entities: curve-walking `Enemy` with HP bar and leak, `TreeEntity`
  auto-attack, 8 `Pedestal` states, `Tower` with nearest-target acquisition and
  a typed `upgrade()` no-op for M3.
- Battle systems: `BattleClock` sim speed/pause, `Spawner`, `WaveManager`
  (prepare -> wave -> result, 6 s prep, skip bonus), `BattleController`
  (arena build, in-run cash, defeat, summary).
- Battle scene, battle HUD (wave/timer/cash, tree HP, prep countdown + Next
  wave, wave banner, build sheet, Upgrade placeholder modal, empty-ground
  dismiss) and `RunSummary` with grant-once coins/gems/XP and best-wave save.
- GameState gains a save-safe `best_wave` default.
- Verification: `tools/battle_smoke.gd`, `tools/validate_layout.gd`, and
  `tests/test_battle.gd` (damage, wave table, lane clearance, reward math);
  scene smoke test covers 15 scenes. Battle previews in `docs/preview/`.

### Changed

- `scenes/battle/battle.tscn` replaces the M0 placeholder; `battle_placeholder.gd`
  is removed.
- `EventBus` gains `damage_dealt` and `run_cash_changed`.

## [0.1.0-m0] — 2026-10-31

### Added

- Folder skeleton from the architecture spec, including `data/`, `config/`,
  `localization/`, `ui/theme/`, `ui/components/`, `scripts/` domains and
  future battle/entity folders.
- Twelve typed service autoloads in the fixed boot order: EventBus, App,
  SceneRouter, SettingsService, LocaleService, AudioService, SaveService,
  GameState, RunState, ModifierService, TimeService, RngService.
- `SceneRouter` as the only owner of `change_scene_to_file`, with fade overlay
  and a back stack.
- `ui/theme/main_theme.tres` generated by `ui/theme/theme_builder.gd`, with
  `PrimaryButton`, `SecondaryButton`, `GoldButton`, `IconButton`, `PanelGreen`,
  `PanelDark`, `ListRow`, `Chip`, `CurrencyPill` and menu-specific variations.
- Reusable components: `PrimaryButton`, `Panel`, `CurrencyPill`, `Modal`.
- Boot → main menu → battle placeholder → back flow; boot fades in over 0.6 s
  and initialises services.
- Main menu shell with currency pills, settings button, Battle CTA, daily
  missions card, five-tab navigation and a coming-soon toast.
- `tools/check_project.ps1` verified green; `tests/run_tests.gd` covers manifest
  paths, save round-trip and the shared cost curve.
- Architecture decision records for mobile renderer, 1080×1920 scaling and
  data-driven resources.
