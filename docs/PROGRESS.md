# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.
Keep it under 90 lines — it is read at the start of every session.

**Spec:** 1.0 (`docs/AI_BUILD_PROMPT.md`) · **Milestone:** M4a done, M4b next
**Branch:** `main` · **Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2)
**Verification (M4a, green):** check_project exit 0 · tests 29/29 · smoke 18/18 scenes ·
battle_smoke PASS (53 checks) · persistence_proof PASS (16 checks) · preview `docs/preview/m4_workshop.png`
**Toolchain gaps (M6):** Android SDK/adb; LDPlayer `E:\LDPlayer\LDPlayer14`; SDK `C:\Android\Sdk`

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | done | `v0.2.0-m1` |
| M2 | Combat depth | done | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | done (M3.1 balance pass) | `v0.4.1-m3` |
| M4 | Meta progression and persistence | M4a done, M4b next | `v0.5.0-m4` (after M4b) |
| M5 | Shell, UX, localization, audio | not started | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

## M4a delivered (tagged by M4b as part of v0.5.0-m4)

- **Save schema v2** (`SaveService`): full spec §8.2 document + local
  `is_onboarded`/`applied_rewards`, canonical SHA-256 checksum, atomic temp+rename,
  `.bak` fallback on parse/checksum failure, pure `migrate_v1_to_v2()` + one-time
  `save_migrated` log, immediate v2 write after migration. Autosave: run start/end,
  wave cleared (≤1/s), meta purchase, scene change, app pause, `WM_CLOSE_REQUEST`.
  ADR-022.
- **`WalletService` + `MetaWallet`**: only coin/gem/stone mutation path;
  `add(RewardBundle)`, `try_spend(kind, amount, reason) -> SpendResult`, 50-entry
  memory log, `currency_changed`/`meta_purchased`, debounced save-on-mutation.
  Run summary, double-coins and debug grants use it; no direct wallet writes.
- **`LevelService` + `UnlockService`**: XP `round(120 * 1.18^(level-1))`,
  multi-level grants, `level_up` event; spec §6.2 table in
  `data/progression/levels.tres` (levels 1–20); `is_unlocked(id)`; combined unlock
  toast on the next menu visit. Speed 1.5x/2x gates read UnlockService; debug
  grants still refused outside debug builds.
- **Workshop**: `WorkshopTrack` + 24 `.tres` in `data/workshop/` (4×6, spec §6.3
  effects/caps/base costs; cost `base*1.18^level` rounded to 5; max 50),
  `WorkshopModel` + `WorkshopService` (`level_of`, `cost_of`, `try_buy`,
  add/mul aggregation into ModifierService). `scenes/menu/workshop.tscn`: coin
  header, 4 tabs, scrollable generated rows, current → next, cost, Buy,
  insufficient-funds shake + "Need N more coins", purchase flash/SFX hook. The
  `Upgrades` nav tab routes to it.
- **One modifier pipeline**: workshop + in-run Tree tracks register
  `ModifierService` sources; Tree/Tower/Unit read `get_stat` for damage, speed,
  crit, regen, range, max HP, starting cash, shield, damage reduction, cash/coin/
  XP gain and in-run discount. Run sources removed on battle exit. ADR-023.
- Tests +7 (29 total): migration, corrupt→`.bak`, wallet never negative, workshop
  curve/caps, unlock gates 3/4/10/12, modifier stacking caps, workshop → DPS.
  `tools/persistence_proof.gd` buys a level, reloads with a fresh SaveService and
  asserts level, coins and the +4 % modifier survived.

## M3 delivered (historical summary)

- 6 Tree upgrade tracks in `data/tree/upgrades/` (damage 8 %, speed 6 %, crit 2 pp
  cap 60 %, crit dmg 15 %, range 3 %, regen 0.3 %/s); `RunWallet` is the only cash
  mutation point; generated upgrade panel with hold-to-buy; speed control via
  `BattleClock`; pause/restart/abandon; TapGuard; RunSummary with RewardBundle +
  RewardLedger; F3 debug overlay.
- M3.1 balance: starting cash 120, tower ranges 400/370/340, HP `1.11^w`, clear
  bonus `60+14w`; 18-run probe median 9 (range 9–11). ADR-020/021.

## Deviations / open items

- M4a does **not** implement Magica, Cards, Missions, offline income, shop/ads
  (M4b). Their save sections exist with spec defaults, but no UI reads them yet.
- Workshop row "purchase SFX" is a hook (`metadata/workshop_purchase_sfx`); no
  audio asset exists until M5/M6, so it is a no-op (like the rest of the SFX bank).
- Settings are mirrored into the save (spec §8.2) but `settings.cfg` stays
  authoritative on load; the save copy is for future server sync.
- Shield HP is simulated but not drawn separately on the battle HP bar (M5 UI).
- Save filename stays `user://save_v1.json` although the schema is 2 (ADR-022).
- `battle_controller.gd` (1100) and `battle_hud.gd` (792) still exceed the
  400-line guideline; the M4 split was not in scope.
- 532 draw calls > M2 target 120 (placeholder art, atlas pass M5/M8).
- LDPlayer FPS needs the Android export (M6); 20-min memory soak not run.

## Next tasks — M4b (Magica, Cards, Missions, offline income)

1. **Magica**: `data/magica/magica_nodes.tres` with 12 nodes (Time/Wealth/
   Knowledge), prerequisites, durations, coin/gem costs and effect modifiers;
   `MagicaService` with one active research, UTC `started_at`/`ends_at`, offline
   completion on boot (clamped by the Offline Cap track), cancel refund 50 %,
   claim badge; `scenes/menu/magica.tscn` routed from the nav; tests for
   prerequisite gating, completion across a timestamp delta and cancel refund.
2. **Cards**: `data/cards/cards.tres` 12 cards (rarity, effect modifiers),
   levels 1–5, shards (20/40/80/160), 4 equip slots gated by
   `card_slot_1..4`, drop chance from the workshop `card_drop_chance` stat;
   `CardService` + collection/equip screen; card modifiers enter ModifierService
   as one `&"cards"` source; tests for equip/unequip restoring aggregated stats.
3. **Missions**: daily (3) + weekly (5) from templates, event-driven progress
   from kills/waves/runs, claim-once ledger, 04:00 local reset (UTC storage),
   `MissionService` + screen with progress bars and claim state; tests for
   idempotent increments and a simulated 04:00 boundary.
4. **Offline income**: store `last_seen_at` UTC in the save, compute the delta on
   boot, apply `offline_coin_rate`/`offline_cap_minutes` workshop tracks, show a
   capped "while you were away" modal; tests for 0 s, under-cap and over-cap.
5. Extend `ModifierService` sources for cards/magica, wire the remaining nav
   tabs, add all M4 acceptance tests, update `PROGRESS`/`CHANGELOG`/`BALANCE`
   and tag `v0.5.0-m4` (M4b only — not M4a).
