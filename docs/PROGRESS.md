# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.
Keep it under 90 lines — it is read at the start of every session.

**Spec:** 1.0 (`docs/AI_BUILD_PROMPT.md`) · **Milestone:** M4 done → M5 next
**Branch:** `main` · **Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2)
**Verification (M4b, green):** check_project exit 0 · tests 39/39 · smoke 20/20 scenes ·
battle_smoke PASS · m4b_acceptance PASS · balance_probe exit 0 (default 9 waves;
`-- fill 1 10` clears 11) · previews `m4_magica.png`, `m4_cards.png`,
`m4_cards_detail.png`, `m4_missions.png`
**Toolchain gaps (M6):** Android SDK/adb; LDPlayer `E:\LDPlayer\LDPlayer14`; SDK `C:\Android\Sdk`

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | done | `v0.2.0-m1` |
| M2 | Combat depth | done | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | done (M3.1 balance pass) | `v0.4.1-m3` |
| M4 | Meta progression and persistence | **done (M4a + M4b)** | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | not started | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

## M4b delivered (finishes M4, tags v0.5.0-m4)

- **Magica**: `MagicaNode` + **14 `.tres`** in `data/magica/` (all named §6.4 rows:
  Quickened Roots I–III, Flow of Ages, Auto-Restart, Golden Sap I–III, Night Harvest,
  Merchant's Favor, Fourth Branch, Deep Roots, Ancient Memory, Second Wind).
  `MagicaModel` + `MagicaService`: one active research, UTC `started_at`/`ends_at`,
  offline completion on boot/focus into a claimable badge, 50 % cancel refund,
  research-speed modifier at start, one `magica:<id>` ModifierService source per
  completed node. `scenes/menu/magica.tscn`: 3 branch columns, node states
  (locked/available/active/done), radial timer, Speed up (AD) stub, Cancel confirm.
- **Cards**: `CardData` + **12 `.tres`** in `data/cards/` (rarity, 5 levels, shard
  curve 20/40/80/160, effect lists), `CardCollection` + `CardService` (owned/levels/
  shards, duplicates→shards with auto-upgrade, equip 1–5 slots gated by
  `card_slot_1..4` + Deep Roots, 8 % + `card_drop_chance` drops on wave clear, one
  `&"cards"` source applied on equip and removed on unequip). `scenes/menu/cards.tscn`:
  loadout slots, filters/sort collection grid, detail modal with live effect numbers,
  Upgrade, Equip/Unequip, where-to-get.
- **Missions**: `MissionTemplate` pool in `data/missions/templates.tres`, `MissionSchedule`
  (pure 04:00 / Monday-04:00 local maths), `MissionModel` + `MissionService`
  (3 daily + 5 weekly, level-scaled targets/rewards, battle-event progress,
  claim-once, all-3/all-5 bonuses incl. weekly card pack, persisted + rerolled).
  `scenes/menu/missions.tscn`: countdowns, progress bars, reward chips, Claim,
  Claim all (≥2), reset footer.
- **Offline income**: `OfflineModel` + `OfflineService` (`last_seen_at` UTC in the
  save, 0.01 coins/s base, 8 h cap + workshop `offline_cap_minutes`, Night Harvest
  multiplier), claim through `WalletService`, Welcome back modal on the main menu.
- **Nav + environment**: Cards/Missions/Shop tabs wired (Shop shows "arrives with M6"),
  shared `MenuNav` with correct active state, Magica entry on the home screen with a
  completion badge; new `EventBus` signals (`enemy_killed`, `enemy_leaked`,
  `tower_built`, `card_dropped`, `second_wind_used`); Ancient Memory grants a free
  Archer, Second Wind saves the Tree once, Greed scales spawner counts, Overgrowth
  scales tower range.
- Tests: **+10 (39 total)** — magica prerequisites/timer/cancel/offline restart,
  card equip/unequip aggregation, duplicate shards, slot limits, mission 04:00
  boundary, claim-once/reroll, completion bonus, offline caps.
  `tools/m4b_acceptance.gd` proves the five M4 acceptance criteria end-to-end;
  `tools/balance_probe.gd` now isolates cards/magica/missions and accepts a min-wave.

## M4a delivered (tagged as part of v0.5.0-m4)

- **Save v2** (`SaveService`): spec §8.2 document + local extras, SHA-256 checksum,
  atomic temp+rename, `.bak` fallback, pure `migrate_v1_to_v2()`, event-driven
  autosave + immediate pause/close flush. ADR-022.
- **`WalletService`/`MetaWallet`** (only currency mutation path, typed
  `SpendResult`, 50-entry log) and **`LevelService`/`UnlockService`**
  (XP `round(120*1.18^(level-1))`, §6.2 gates at 3/4/10/12).
- **Workshop**: 24 `WorkshopTrack` `.tres` (cost `base*1.18^level` rounded to 5,
  max 50), `WorkshopModel`/`WorkshopService`, `scenes/menu/workshop.tscn`.
- **One modifier pipeline**: workshop, Tree, cards, magica and offline bonuses
  aggregate in `ModifierService`; entities only call `get_stat()`. ADR-023.

## Deviations / open items

- §6.4's table names **14** nodes; the M4 brief's "12" was a pre-table count. All 14
  are data-driven and tested by id.
- Flow of Ages publishes `battle_speed_extra` but the battle HUD still exposes the
  three M3 speed buttons; the fourth step is an M5 UI task. Auto-Restart publishes a
  flag but the run-summary toggle is M5.
- Merchant's Favor `shop_discount` is stored for M6; its in-run discount is live.
- Ads speed-up/card pack are stubs until M6 (`AdsService`); the mission "watch ads"
  template stays at 0 until the ad bridge calls `MissionService.record_rewarded_ad()`.
- Card art is the placeholder square; per-rarity 9-slice frames and M5 polish remain.
- Save schema stays v2; the M4b extras default on load (no v3 migration needed).
- `battle_controller.gd`/`battle_hud.gd` still exceed the 400-line guideline.
- 532 draw calls > M2 target 120 (placeholder art, atlas pass M5/M8).

## Next tasks — M5 (first 3)

1. **Main menu per reference** (`docs/reference/ui_main_menu.png`): top bar with
   currency `+` buttons, stats card (best wave/level/XP/avatar), Battle CTA, speed
   trial bar, daily card, 5-tab nav; keep the Magica entry.
2. **SceneRouter + navigation**: fade transitions on every screen, back stack,
   Android back-button behaviour, no dead ends.
3. **Settings screen**: audio sliders, language switch, text scale, haptics, shake,
   debug FPS counter; persist via `SettingsService`.
