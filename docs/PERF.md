# PERF — measured performance (M8)

All numbers below were produced by the tools in this repository on the M8 build
(1.0.0). Nothing here is estimated.

## Desktop stress probe (`tools/perf_probe.gd`)

Command:

```powershell
godot --path . --script res://tools/perf_probe.gd
```

Scene: the real `scenes/battle/battle.tscn`, 120 enemies spawned on both lanes,
8 towers (archer/cannon/frost/totem rotated) and 4 guardian units. Vsync is off;
1 s warm-up, 5 s measurement.

| Metric | Result |
|---|---|
| FPS | **1036.5** (5 183 frames / 5.00 s) |
| Draw calls (peak) | **543** |
| Enemies (peak) | 120 |
| Towers / units | 8 / 4 |
| Process FPS | 1133 |
| Renderer | D3D12 12_0, Forward Mobile, NVIDIA RTX 3050 Laptop |

Verdict: the 55 FPS floor and the 120-enemy load pass with a wide margin on the
desktop development machine.

## LDPlayer 14 (release APK, `build/the-tree-release.apk`)

The release build was installed with `adb install -r` and launched from the
Godot activity. Frame timing was sampled with
`dumpsys SurfaceFlinger --latency` on the game surface while wave 1 was running
with enemies on screen:

| Metric | Result |
|---|---|
| Refresh pacing | **~117 FPS** (124 frames, 8.53 ms average) |
| Cold boot | ~5 s to the language step (release APK) |
| Crash | none in `adb logcat`; activity focused |

This is not the 120-enemy stress case; the device stress number remains
unmeasured because the release build has no debug spawn overlay.

## Draw-call gap (known, deferred)

The M2 brief targets **< 120 draw calls**. The M8 measurement is **543**, so the
target is **not met**. Breakdown/why:

- Enemies already use `AnimatedSprite2D` + `SpriteFrames` (the cheap per-enemy
  win from the M8 brief was already in place), but each enemy also draws a
  shadow sprite and a two-part HP bar, and the placeholder art has one texture
  per sprite.
- UI panels, icons, pills and the button set use individual PNGs; each unique
  texture is a separate draw call, so the HUD adds most of the rest.
- The project uses the Forward Mobile renderer without 2D batching across
  textures; the fix is an atlas pass per family (enemies, towers, UI, icons)
  plus `AtlasTexture`/`SpriteFrames` rewiring, which is art-pipeline work.

Deferred with **ADR-043** (`docs/DECISIONS.md`). No visual regression was
introduced to buy draw calls; frame time on desktop and LDPlayer is healthy.
