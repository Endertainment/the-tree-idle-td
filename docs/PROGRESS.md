# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.
Keep it under 60 lines — it is read at the start of every session.

**Spec version:** 1.0 (`docs/AI_BUILD_PROMPT.md`)
**Current milestone:** M0 — Foundation
**Current branch:** `main` (M0 work may go straight to `main`; from M1 use `feat/mN-*`)
**Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2.stable) — configured in `tools/godot_path.txt`
**Verification:** `pwsh -File tools/check_project.ps1` — green on the current scaffold
**Toolchain gaps (M6 only):** export templates (standard), JDK 17, Android SDK, adb — see `docs/ENVIRONMENT.md`
**Test device:** LDPlayer — `E:\LDPlayer\LDPlayer14` (adb: `E:\LDPlayer\LDPlayer14\adb.exe`); Android SDK: `C:\Android\Sdk`

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | not started | `v0.2.0-m1` |
| M2 | Combat depth | not started | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | not started | `v0.4.0-m3` |
| M4 | Meta progression and persistence | not started | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | not started | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

Status values: `not started` · `in progress` · `blocked` · `done`.

## Next 3 tasks (M1)

1. `MapData` + `forest_clearing.tres`: two lanes, 8 pedestals, 4 unit-slot anchors.
2. `BattleController`/`BattleClock`/`WaveManager`/`Spawner` + `Enemy` on `PathFollow2D`.
3. Tree HP + auto-attack, Archer Tower build/sell, waves 1–10, HUD minimum, run summary.

## Open questions / blockers

- None for M1. Android toolchain (export templates 4.7.2 standard, JDK 17) is only needed at M6.

## Handoff (filled only when a session ends mid-milestone)

```text
State:
Last green commit:
Files in flight:
Next command:
Open questions:
```
