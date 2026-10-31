# PROGRESS

Single source of truth for "where are we". Updated at the end of every session.
Keep it under 60 lines — it is read at the start of every session.

**Spec version:** 1.0 (`docs/AI_BUILD_PROMPT.md`)
**Current milestone:** M0 — Foundation
**Current branch:** `main` (M0 work may go straight to `main`; from M1 use `feat/mN-*`)
**Godot:** set `$env:GODOT_BIN` or create `tools/godot_path.txt` with the executable path
**Test device:** LDPlayer (Android x86_64)

## Milestones

| # | Milestone | Status | Tag |
|---|---|---|---|
| M0 | Foundation | not started | `v0.1.0-m0` |
| M1 | Battle vertical slice | not started | `v0.2.0-m1` |
| M2 | Combat depth | not started | `v0.3.0-m2` |
| M3 | Run economy, upgrades, speed | not started | `v0.4.0-m3` |
| M4 | Meta progression and persistence | not started | `v0.5.0-m4` |
| M5 | Shell, UX, localization, audio | not started | `v0.6.0-m5` |
| M6 | Android, ads, billing, telemetry | not started | `v0.7.0-m6` |
| M7 | Backend (FastAPI + Neon), live features | not started | `v0.8.0-m7` |
| M8 | Balance, polish, release readiness | not started | `v1.0.0-m8` |

Status values: `not started` · `in progress` · `blocked` · `done`.

## Next 3 tasks

1. Create the folder skeleton from spec §11.1 and the autoload stubs (§8.1).
2. Write `docs/art_manifest.json` + `tools/generate_placeholders.gd` and generate the placeholders (§9).
3. `Boot → MainMenu → Battle` routing with the placeholder theme (§13).

## Open questions / blockers

- Godot version installed locally must match `project.godot` (`4.7` features). Verify before M0.

## Handoff (filled only when a session ends mid-milestone)

```text
State:
Last green commit:
Files in flight:
Next command:
Open questions:
```
