# Architecture decisions (ADR log)

Short, append-only log of decisions that are expensive to reverse. One entry per
decision: context, decision, consequences. New entries are added at the bottom.

## ADR-001 — Mobile renderer

**Status:** accepted (M0)

**Context:** the target is mid-range Android at 60 FPS in portrait. The project
does not need Forward+ features (SDFGI, volumetric fog, high-end screen-space
effects), and those features are expensive or unavailable on mobile GPUs.

**Decision:** use the `mobile` rendering method
(`rendering/renderer/rendering_method="mobile"`) and only mobile-safe
`canvas_item` shaders. Do not use Forward+-only rendering features.

**Consequences:** lower GPU cost and predictable mobile behaviour; any future
effect must be validated in the mobile renderer first. Desktop still runs the
same build, which is required for development.

## ADR-002 — 1080×1920 design space, `canvas_items` + `expand`

**Status:** accepted (M0)

**Context:** the game is portrait-only and must remain usable on 19.5:9 phones
and 4:3 tablets without stretching UI or battle art.

**Decision:** author the viewport at 1080×1920 with stretch mode `canvas_items`
and aspect `expand`, locked to portrait. Layouts anchor to the safe area, and
the battle field will letterbox its playable 1080×1480 region rather than
stretch.

**Consequences:** UI coordinates and art sizes are stable across devices; wider
or taller screens expose extra background area instead of scaling controls.
Every screen must be checked at both aspect extremes.

## ADR-003 — Data-driven resources

**Status:** accepted (M0)

**Context:** balance numbers, content definitions and localisation must change
without editing gameplay code, and the game must remain testable offline.

**Decision:** all content and balance values live in `.tres`/`.json` resources
under `res://data/` and `res://config/` (enemy/tower/unit stats, waves, maps,
upgrade curves, card effects, missions, localisation). Gameplay scripts read
those resources and contain no balance literals. Typed `Resource` classes are
the schema, with ids as `StringName`.

**Consequences:** designers can tune the game without code changes and headless
tests can load the same data. The cost is a data-loading layer and validation
tooling, which is built incrementally from M1.
