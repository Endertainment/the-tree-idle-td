# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.
Keep it under 60 lines — it is read at the start of every session.

**Spec:** 1.0 (`docs/AI_BUILD_PROMPT.md`) · **Milestone:** M3 (M2 done, tagged)
**Branch:** `main` · **Godot:** `C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe` (4.7.2)
**Verification (M2, green):** check_project exit 0 · tests 15/15 · smoke 17/17 scenes ·
battle_smoke PASS (22 checks) · validate_layout OK · perf probe PASS (1907.2 FPS desktop)
**Toolchain gaps (M6):** Android SDK/adb; LDPlayer `E:\LDPlayer\LDPlayer14`; SDK `C:\Android\Sdk`

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | done | `v0.1.0-m0` |
| M1 | Battle vertical slice | done | `v0.2.0-m1` |
| M2 | Combat depth | done | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | next | `v0.4.0-m3` |
| M4 | Meta progression and persistence | not started | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | not started | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

## M2 delivered (playable)

- Enemies `runner`/`tank`/`shaman`/`boss_troll`; pooled enemies, hit flash shader, shaman speed
  aura, boss HP bar (replaces wave bar) + spawn banner; bosses 10/20/30 with authored x1.6 HP.
- Towers archer/cannon/frost/totem: 10 levels, 3 data tiers (L1-4/5-7/8-10), level-5 behavior
  registry (Double Shot/Shrapnel/Deep Chill/Rooted Gift), 4 target modes, select/upgrade/sell 70 %.
- Units archer/mage/druid in 4 canopy slots; unlock data (level 4 / Workshop / level 12 or 150
  gems), placement + in-place L1-10 upgrade (`50*1.45^(lvl-1)`) from the bottom sheet.
- Combat: slow refresh (no stack), splash falloff, true-damage hook, target multiplier,
  spatial-hash targeting, pooled damage labels (cap 25), pooled FX, Totem aura.
- Waves: 30 authored waves (`wave_table_m2.tres`), swarm 5/15/25, boss 10/20/30, all 5 enemies.
- Split `battle_controller.gd` into state/flow + `battle_hud_controller`, `build_sheet`,
  `tower_sheet`, `unit_slots`; HUD never mutates run state.
- Perf: **1907.2 FPS** (RTX 3050, vsync off) at 120 enemies + 8 towers + 4 units; 532 draw calls.

## Deviations / open items

- 532 draw calls > M2 brief's 120: placeholder art has one texture per walk frame (no batching);
  atlas pass in M5/M8. FPS floor (55) is met on desktop.
- LDPlayer FPS needs the Android export (M6); 20-min memory soak not run (all hot entities pooled).
- Workshop slot 3 stays locked with a visible condition until M4 (no workshop service yet).
- Boss waves carry `reward_bonus = 50` in data for M3's reward bundle.

## Next 3 tasks (M3)

1. Tree upgrade tracks (damage/speed/crit/crit dmg/range/regen) as `.tres` + generated panel.
2. `BattleClock` speed 1x/1.5x/2x segmented control (1x button is a placeholder today).
3. Pause menu (resume/restart/abandon) + full `RunSummary` reward bundle (coins, gems, XP, best).

## Handoff

```text
State: M2 tagged v0.3.0-m2, all M2 checks green
Files in flight: none
Next command: pwsh -File tools/check_project.ps1
Open questions: none for M3
```
