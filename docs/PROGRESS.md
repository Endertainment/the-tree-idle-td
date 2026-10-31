# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.
Keep it under 70 lines — it is read at the start of every session.

**Spec:** 1.0 (`docs/AI_BUILD_PROMPT.md`) · **Milestone:** M3 done, tagged
**Branch:** `main` · **Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2)
**Verification (M3, green):** check_project exit 0 · tests 22/22 · smoke 17/17 scenes ·
battle_smoke PASS (52 checks) · balance_probe reports waves 1-5 (see deviations)
**Toolchain gaps (M6):** Android SDK/adb; LDPlayer `E:\LDPlayer\LDPlayer14`; SDK `C:\Android\Sdk`

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | done | `v0.2.0-m1` |
| M2 | Combat depth | done | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | done (balance acceptance unmet) | `v0.4.0-m3` |
| M4 | Meta progression and persistence | next | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | not started | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

## M3 delivered (playable)

- Tree upgrade tracks: `UpgradeTrack` resource + 6 `.tres` in `data/tree/upgrades/`
  (damage +8 %, attack speed +6 %, crit +2 pp cap 60 %, crit damage +15 %, range
  +3 %, regen +0.3 % max HP/s; costs 40/50/60/60/40/80, growth 1.35-1.45, 30
  levels). Loaded by directory scan, so a new track is a `.tres` + one stat read.
- `RunWallet` + `SpendResult`: the only cash mutation point (50-entry log, typed
  failure reasons); all build/upgrade/sell paths use it; sell stays 70 % invested.
- Upgrade panel generated from data: Tree/Units/Towers tabs, rows with icon, level,
  current → next in green, cost, disabled reason, hold-to-buy at 8/s via
  `HoldToBuy` (stops on the first failed `SpendResult`), affordability dot/pulse,
  Tree level-up flash. Units upgraded in place; tower rows open the tower sheet.
- Speed control 1x/1.5x/2x in the top bar, locked segments show a lock and open a
  "coming soon" popup with a debug-only unlock; `GameState.unlocks` + level 3/10
  gates. Speed is a `BattleClock` delta multiplier only (no `Engine.time_scale`).
- Pause overlay: Resume / Restart (confirm) / Abandon (confirm) / Settings
  placeholder + live run stats. Pauses clock, spawning and timers; HUD stays
  responsive (`PROCESS_MODE_ALWAYS`). Abandon pays exactly the cleared-wave rewards.
- Next-wave skip guarded by `TapGuard`: the first 3 profile skips need a 250 ms
  hold; the skip bonus stays `min(10 + 2w, 120)`.
- `RunSummary` v2: waves, kills, time, cash-lost note, best wave + NEW BEST,
  coins `sum(8+2w)` + 50/boss wave, gems `floor(w/5)` + 5 on a new best, XP `10w`,
  count-up rows, "Double coins" via `RewardedAdStub` (debug fake grant), Continue.
  Rewards are one `RewardBundle` granted once per run id via `RewardLedger`.
- F3 debug overlay: fps, enemies, projectiles, cash, sim speed/pause, wave, kills.
- Verification: +7 unit tests (wallet, hold-to-buy 5 s guard, track curves, DPS
  delta), battle smoke extended to 52 checks (upgrade cost/cash, DPS, speed
  locks, pause freeze, 2x delta, abandon rewards, ledger idempotency, overlay).
- Previews: `docs/preview/m3_battle.png`, `m3_upgrade_panel.png`, `m3_pause.png`.

## Deviations / open items

- **Balance acceptance NOT met:** `docs/milestones/M3.md` wants a skilled run at
  wave 15+. `tools/balance_probe.gd` (greedy auto-play, 8x, prep skips) dies on
  wave 5 for three opening policies (best: 4 cleared). Wave 10 boss has ~11k HP
  under the spec's 1.16 HP scaling while the available cash buys ~150 DPS; the M2
  wave table needs an M8 balance pass. Recorded in `BALANCE.md`; not faked.
- Speed levels 3/10 are unreachable until M4 player levels; debug unlock covers QA.
- "Double coins" always fakes success in debug builds; release shows ad-unavailable
  until `AdsService` lands in M6.
- `battle_controller.gd` (1079) and `battle_hud.gd` (791) exceed the 400-line
  guideline; M3 added collaborators (`UpgradePanel`, `PauseMenu`, `DebugOverlay`)
  but the controller/HUD glue needs an M4 split.
- 532 draw calls > M2 target 120 (placeholder art, atlas pass M5/M8).
- LDPlayer FPS needs the Android export (M6); 20-min memory soak not run.

## Next 3 tasks (M4)

1. `WalletService` with a persistent transaction log + save schema v2 migration;
   move the GameState placeholder meta-wallet path onto it.
2. Workshop tracks (coins, 4 categories) generated from data + upgrade tracks as `.tres`.
3. `UnlockService` from `data/progression/levels.tres` (speed 1.5x @ level 3, 2x @ 10,
   unit slots, cards) replacing the M3 `GameState.unlocks` debug toggle.
