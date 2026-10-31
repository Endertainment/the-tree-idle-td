# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.
Keep it under 60 lines — it is read at the start of every session.

**Spec version:** 1.0 (`docs/AI_BUILD_PROMPT.md`)
**Current milestone:** M2 — Combat depth
**Current branch:** `main` (M1 landed from `feat/m1-battle`)
**Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2.stable) — configured in `tools/godot_path.txt`
**Verification (M1, green):** `check_project.ps1` exit 0 · `tests/run_tests.gd` 8/8 · `tools/smoke_test.gd` 15/15 scenes · `tools/battle_smoke.gd` PASS · `tools/validate_layout.gd` OK
**Toolchain gaps (M6 only):** Android SDK/adb; see `docs/ENVIRONMENT.md`
**Test device:** LDPlayer — `E:\LDPlayer\LDPlayer14` (adb: `E:\LDPlayer\LDPlayer14\adb.exe`); Android SDK: `C:\Android\Sdk`

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | done | `v0.2.0-m1` |
| M2 | Combat depth | not started | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | not started | `v0.4.0-m3` |
| M4 | Meta progression and persistence | not started | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | not started | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

## M1 delivered (playable)

- Data resources: `forest_clearing.tres` (2 smooth lanes, 8 pedestals, 4 unit anchors), `enemy_grunt.tres`, `tower_archer.tres`, `tree_base.tres`, `wave_table_m1.tres` (10 waves).
- Combat: `DamageResolver` (crit before flat armor, 10 % floor), pooled homing projectiles, Tree auto-attack, Archer Tower, leak/death/cash, 6 s prep + skip bonus, wave banner, build sheet, tree HP bar, run summary with grant-once rewards.
- Proof: `tools/battle_smoke.gd` (8 pedestals, 3 towers, 7 spawns, kills, cash delta), `tools/validate_layout.gd` (worst clearance 118.4 px), `docs/preview/m1_battle.png` + `m1_battle_combat.png`.
- Desktop perf probe: 47 enemies + 8 towers > 60 FPS (vsync off); LDPlayer FPS not measured yet.

## Next 3 tasks (M2)

1. `runner`, `tank`, `shaman`, `boss_troll` data + scenes; shaman aura.
2. `cannon`, `frost_spire`, `totem` towers, 3 visual tiers, level-5 `TowerBehavior` registry.
3. Units (`unit_archer`, `unit_mage`, `unit_druid`) in the 4 canopy slots + placement flow.

## Open questions / blockers

- None blocking. M1 brief intentionally omitted tower selling (70 % refund) and tower sheets; both are M3 scope and documented in DECISIONS ADR-008.
- Wave-clear cash formula is an M1 addition (spec gives no direct number): ADR-004.

## Handoff (filled only when a session ends mid-milestone)

```text
State: M1 tagged v0.2.0-m1, all M1 checks green
Last green commit: see tag v0.2.0-m1
Files in flight: none
Next command: pwsh -File tools/check_project.ps1
Open questions: none for M2
```
