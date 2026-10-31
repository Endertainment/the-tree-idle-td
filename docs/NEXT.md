# NEXT — handoff

Read this first in a new session. Then `AGENTS.md`, then `docs/PROGRESS.md`.
Everything below is the state as of **2026-10-31 22:30**, after `v1.0.2`.

## Where the project stands

- M0–M8 complete, tagged `v0.1.0-m0` … `v1.0.0-m8`, plus `v1.0.1` (tall-screen arena) and `v1.0.2` (device fixes).
- Test gates: `tools/check_project.ps1`, `tests/run_tests.gd` (74+), `tools/smoke_test.gd`, `tools/battle_smoke.gd`, `tools/lint_locale.gd`.
- Release build: `pwsh -File tools/export_release.ps1` → `build/the-tree.aab` + `build/the-tree-release.apk`.
- Real device: Xiaomi 23090RA98G, Android 16, 1220×2712. `adb` = `C:\Android\Sdk\platform-tools\adb.exe`.
  Install: `adb install -r build/the-tree-release.apk`.

## Fixed in v1.0.2 (verified on device)

1. Tower building never worked from the UI — `Pedestal.is_buildable()` rejected the `SELECTED` state that `open()` sets. Now allowed; build verified (cash 128 → 68, tower placed).
2. Bottom nav sat at a different height per screen — `MenuNav` now inserts an expanding spacer above itself and pins to the bottom.
3. Different content width per screen — all menu scenes normalised to margins 30/26/30/22.
4. Camera cutout covered the top row — `DisplayCutout.top_inset()` (canvas units) is applied to the menu SafeArea and the battle `TopBar`.
5. Arena did not cover 2.22:1 screens (grey band) — world container + cover background (`v1.0.1`).

## Open items (user-reported, need clarification)

- **"Завеликий фейд"** — unclear whether this means (a) the empty gap between content and the nav bar, (b) the screen-transition fade (0.15 s in `SceneRouter`), or (c) the boot fade (0.6 s in `boot.gd`). Ask before changing.

## Backlog, in value order

1. **Art pass** — replace 240 placeholders via `docs/ART_MANIFEST.md` (same paths, no code changes). The tree placeholder overlaps the pedestal ring; check with a real sprite.
2. **Atlas / draw calls** — 543 draw calls vs <120 target (ADR-043). SpriteFrames per enemy instead of per-frame textures.
3. **Device QA leftovers** — 30-min soak, offline relaunch with queued saves, text scale 130 %, safe area on a notched device, purchases via Play internal testing.
4. **Backend runtime** — PostgreSQL/Neon path untested (SQLite only); Docker/Neon run + Alembic on a real DB.
5. **Tutorial** — verify the three hints on a clean install.
6. **Localisation** — review the 653 en/uk strings for tone and consistency.

## How to continue in a new session

Paste this, nothing else:

```text
Continue "The Tree: Idle Tower Defense" in C:\Users\VOVA\Documents\the-tree--idle-td.
Read AGENTS.md, docs/NEXT.md and docs/PROGRESS.md first.
Take the first open item from NEXT.md, plan, then implement with the usual gates
(check_project, tests, smoke) and commit.
```

The repository is the memory: tags, `docs/PROGRESS.md`, `docs/DECISIONS.md`, `docs/DEVICE_QA_*.md`.
