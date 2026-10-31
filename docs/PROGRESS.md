# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.

**Spec:** 1.0 (`docs/AI_BUILD_PROMPT.md`) · **Milestone:** M5a done → M5b next
**Branch:** `main` · **Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2)
**Verification (M5a, green):** check_project exit 0 · tests **47/47** ·
smoke **22/22 scenes** · battle_smoke PASS · m4b_acceptance PASS ·
lint_locale 530 keys, 0 missing, 0 unused · previews `m5_settings_uk.png`,
`m5_settings_pseudo.png`, `m5_onboarding.png`, `m5_onboarding_profile.png`,
`m5_battle_uk.png`, `m5_battle_pseudo.png`
**Toolchain gaps (M6):** Android SDK/adb; LDPlayer `E:\LDPlayer\LDPlayer14`; SDK `C:\Android\Sdk`

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | done | `v0.2.0-m1` |
| M2 | Combat depth | done | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | done (M3.1 balance pass) | `v0.4.1-m3` |
| M4 | Meta progression and persistence | done | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | **M5a done, M5b next** | `v0.6.0-m5` (M5b) |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
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
- 532 draw calls > M2 target 120 (placeholder art, atlas pass M5b/M8).

## Next tasks — M5b (owns tag `v0.6.0-m5`)

1. **Main menu per reference** (`docs/reference/ui_main_menu.png`): top bar with
   `+` buttons, stats card (best wave/level/XP/avatar), speed-trial bar, daily
   card, 5-tab nav; keep the Magica entry and the gear → Settings.
2. **Shop UI** with stub products (`Gems`, `Coins`, `Special`, restore, disabled
   "Store unavailable"), **Leaderboard** against `LocalBackendStub` (weekly /
   all-time / tournament, offline banner, empty state), **Profile** screen.
3. **Toasts/modals/loading/empty states/notification dots** polish; card rarity
   frames; audio for shop/leaderboard stubs.
4. Tag `v0.6.0-m5` after all M5 acceptance checks, update CHANGELOG/PROGRESS.
