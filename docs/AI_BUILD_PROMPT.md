# THE TREE: IDLE TOWER DEFENSE — MASTER BUILD PROMPT

**Version 1.0 — for an AI coding agent working inside an existing Godot repository.**

---

## 0. HOW TO USE THIS DOCUMENT

This document is the single source of truth for building the game. It is written for an AI coding agent (DeepSeek Harness, Claude Code, Cursor, Codex, ChatGPT, Copilot Chat) that works **inside this repository**.

**Do not read this whole file into the chat every session.** It is a reference, not a prompt. Read `AGENTS.md`, then `docs/PROGRESS.md`, then `docs/milestones/M<N>.md` — the brief lists the exact sections of this document you need. Locate a section by heading (`grep -n "^### 4.6"`), then `read` with an offset around that line. Two to four sections per session is the right budget.

Rules of engagement:

1. **Start with Milestone 0 (section 15).** Do not start with UI, do not start with monetization.
2. **Work milestone by milestone.** Each milestone has a goal, a task list and acceptance criteria. Do not jump ahead, do not partially implement a later milestone "because it was easy".
3. **This is not a prototype.** The output must be a production-shaped, well-structured Godot project that a solo developer can keep editing for a year. Every file you create must be readable, typed, documented, and data-driven.
4. **Never invent APIs.** If you are unsure about a Godot 4.x API or a plugin API, check the documentation or wrap it in an adapter with a stub. A wrong API call is worse than a documented TODO.
5. **Never silently change the design.** If a requirement is impossible or contradictory, stop and ask a short, specific question instead of inventing a different game.
6. **Ask before big architectural decisions.** Small implementation choices: decide yourself and document them in `docs/DECISIONS.md`. Anything that changes folder structure, save format, or a public interface: ask first.

Repository state you are starting from (verify it):

- Godot project already exists: `project.godot` with `config/features=("4.7", "Mobile")`, mobile renderer, `1080x1920` portrait, `canvas_items` stretch with `expand` aspect.
- `scenes/main_menu.tscn` is a throwaway stub (ColorRect + a TextureRect with `menu_bg.jpg`). Replace it, do not extend it.
- `assets/art/ui/bg/menu_bg.jpg` exists and may be reused as the menu background.
- `docs/reference/ui_main_menu.png` and `docs/reference/ui_battle.png` are the approved visual references for layout and mood.
- `AGENTS.md` — the working protocol for this repository (read it first: context rules, session loop, verification, commits).
- `docs/PROGRESS.md` — the current milestone, status table and handoff block. Update it at the end of every session.
- `docs/milestones/M0.md` … `M8.md` — one brief per session-sized chunk of work, each listing the exact spec sections to read.
- `docs/AI_BUILD_PROMPT.md` is this file.
- The repository is initialized with git and pushed to GitHub.

---

## 1. ROLE AND MISSION

You are the **lead gameplay engineer and technical designer** for a small commercial mobile game. You write all the code, scene files, resources, tooling and documentation. There is no separate artist, no separate level designer, and no separate backend developer in this phase: everything is placeholder-driven and data-driven so those roles can be filled later by a human (or another AI).

**Mission:** deliver a complete, shippable-quality vertical slice of *The Tree: Idle Tower Defense* that:

- runs at 60 FPS on a mid-range Android device (and on LDPlayer in this workspace),
- is fully playable from first launch to a run summary and back,
- has all meta-progression screens navigable with correct data flow (even if some content is still placeholders),
- is built from data resources, so new towers, enemies, units, cards, upgrades and missions can be added **without touching gameplay code**,
- uses only placeholder art and placeholder audio, but with a **1:1 asset manifest** so real art can be dropped in without code changes,
- is written so that a human who knows Godot can open any file and understand it in under two minutes.

**Definition of "done" for any task:** the game launches without errors, the feature works, the acceptance criteria of the milestone pass, and the change is committed.

---

## 2. PRODUCT DEFINITION

- **Title:** The Tree: Idle Tower Defense
- **Genre:** tower defense with idle/incremental meta-progression (hybrid-casual, one-thumb, portrait).
- **Fantasy:** a colossal Life Tree stands in a forest clearing. Corrupted creatures pour out of the woods along two winding roads to destroy it. The tree fights back with its own magic and with guardian units perched on its branches; the player raises towers on eight ancient pedestals around it.
- **Platforms:** Android first (test target: LDPlayer x86_64), iOS supported by the same codebase later. No desktop-specific features may leak into gameplay code.
- **Orientation:** portrait only, design resolution `1080x1920`.
- **Session shape:** 10–25 minutes per run; 2–5 minutes per meta session (collect idle rewards, spend coins, upgrade, start next run).
- **Monetization:** hybrid — rewarded ads (speed-up, revive-ish boosts, bonus cash), interstitials (capped), IAP for gems/coins/no-ads/starter pack. No pay-to-win walls in the first 20 waves.
- **Tone:** cozy, vibrant, "storybook fantasy". Not grimdark, not sci-fi.

### 2.1 The three nested loops

**Micro loop (5–20 s):** enemy spawns → towers/tree/units acquire and fire → enemy dies → cash + floating numbers → player taps a pedestal and buys/upgrades something.

**Run loop (10–25 min):** wave starts → wave ends → cash payout → spend cash on towers/units/tree → next wave, harder → every 10th wave a boss → eventually the tree falls → run summary with coins and gems → back to the menu.

**Meta loop (days):** claim Magica research and offline coins → buy Workshop levels → open card packs, equip cards → finish daily missions → push a higher best wave → climb the weekly tournament leaderboard → repeat with a stronger start.

### 2.2 Screen map

```
Boot (splash, service init)
 └─ FirstLaunch (nickname + avatar + language)      [only once]
 └─ MainMenu (Home)
     ├─ Battle → RunSummary → MainMenu
     ├─ Workshop        (permanent coin upgrades)
     ├─ Magica          (idle research)
     ├─ Cards           (collection + equip slots)
     ├─ Missions        (daily / weekly)
     ├─ Shop            (IAP + gem/coin offers)
     ├─ Leaderboard     (global / friends / weekly)
     ├─ Settings        (audio, language, haptics, account)
     └─ Profile         (nickname, level, stats)
```

Every screen is a separate scene. Navigation goes through a single `SceneRouter` autoload with a transition overlay. No screen may `change_scene_to_file()` directly.

---

## 3. HARD TECHNICAL CONSTRAINTS

These are non-negotiable. If something conflicts with them, report the conflict instead of breaking a constraint.

1. **Engine:** Godot 4.x, version matching `project.godot` (`4.7`). GDScript only, strictly typed (`var x: int = 0`, `func f(a: int) -> void:`). No C#, no GDExtension of your own.
2. **Renderer:** `mobile`. No Forward+ only features (no SDFGI, no volumetric fog). Shaders must be mobile-safe (`canvas_item`, low instruction count, no screen texture loops).
3. **Resolution & scaling:** viewport `1080x1920`, stretch `canvas_items`, aspect `expand`. All UI must remain usable on 19.5:9 and 4:3, with safe-area insets for notches (`DisplayServer.get_display_safe_area()`), and the battle field must letterbox gracefully rather than stretch.
4. **Orientation:** portrait, locked.
5. **Performance budget (mid-range Android):** 60 FPS sustained; ≤ 120 live enemies; ≤ 8 towers + 4 units; ≤ 40 live projectiles; total draw calls in battle < 120; no per-frame allocations in `_process` of enemies/projectiles; use `MultiMeshInstance2D` only if profiling proves it necessary; object pooling is mandatory for enemies, projectiles, damage labels and hit FX.
6. **No polling where an event exists.** Use signals, `Timer`, `await`. A `while true: await get_tree().process_frame` loop is a bug.
7. **Everything data-driven.** Enemy stats, tower stats, unit stats, wave tables, upgrade costs, card effects, missions, localization, ad placement ids, IAP product ids — all in `.tres`/`.json` under `res://data/` or `res://config/`. Gameplay `.gd` files must not contain balance numbers (except documented engine-level constants such as `EPSILON`-style helpers and clamp ranges).
8. **No magic strings.** UI text only via `tr()`. Node paths only via `@onready` and `%UniqueName`, never `get_node("../../..")`. Input actions only via named actions in `project.godot`.
9. **Text-based everything.** `.tscn`, `.tres`, `.gd`, `.json`, `.csv`, `.md`. Never commit `.res`, `.scn`, `.import` caches, or `.godot/`. Scenes must be diff-friendly: no embedded binary resources.
10. **Desktop must run the whole game.** Every Android-only plugin (AdMob, Play Billing) is hidden behind a service interface with a functional desktop stub. `F5` in the editor must always work.
11. **No network dependency for core play.** The game must be fully playable offline; network is an enhancement layer (section 8).
12. **Deterministic runs.** Each run gets a `run_seed` (`int`); all combat randomness (crit, spawn jitter, target choice ties) uses a seeded `RandomNumberGenerator` stored in the run state, so a run can be reproduced and validated server-side.
13. **Save safety.** Saves are versioned, written atomically (temp file + rename), checksummed, and never lose progress on a crash. A schema migration function exists from day one.
14. **Accessibility & comfort:** text scaling 100/115/130 %, color-blind-safe state colors (never rely on red/green alone — pair with icons/shape), optional screen-shake toggle, haptics toggle, left/right-handed layout for the upgrade button if it becomes an issue.
15. **All code in English.** Comments in English. Only user-facing strings are localized (Ukrainian + English).
16. **No hidden state in scenes.** Persistent data lives in autoload services and is serialized explicitly. Scenes must be destroyable and re-instantiable at any time without losing progress.

---

## 4. BATTLE DESIGN SPECIFICATION

This is the heart of the game. Implement it exactly; the numbers below are the launch balance values and must live in data resources, not in code.

### 4.1 Arena layout (1080 x 1920 design space)

```
HUD top bar:        y = 0 .. 220     (wave, timer, currencies, settings, speed)
Battle field:       y = 220 .. 1700  (playable area, background art)
HUD bottom:         y = 1700 .. 1920 (tree HP, upgrade button, tower panel when open)

Tree (core):        center @ (540, 980), canopy radius ≈ 250, trunk base ≈ (540, 1060)
Pedestal ring:      radius 330 around (540, 980), 8 slots
Unit slots:         4 anchors on the canopy, radius 165 around (540, 900),
                    angles 45°, 135°, 225°, 315° (upper-left, upper-right, lower-left, lower-right)
Lane A entry:       (250, 240)  — top-left of the field
Lane B entry:       (830, 1740) — bottom-right of the field (mirror of A)
```

The two lanes are **mirrored S-curves** that hug the tree and end at the trunk. They must never cross a pedestal: keep ≥ 110 px clearance between a lane centerline and any pedestal center. Provide an editor-time validation script (`tools/validate_layout.gd`) that prints violations, and a debug overlay (`F3`) that draws lanes, pedestal radii and attack ranges.

### 4.2 Lanes and enemy movement

- Two lanes: **North** and **South**. Each lane is a `Path2D` (Bezier) with 6–8 control points, defined in `res://data/maps/forest_clearing.tres` (an array of curve point arrays), so new maps are pure data.
- Enemies are `PathFollow2D` children (`rotates = false`, `loop = false`) moving at `speed` px/s along `progress`. Spawn at `progress_ratio = 0`; reaching `progress_ratio >= 0.995` = **leak**: deal `leak_damage_pct` of the tree's **max** HP, then despawn (no cash).
- Enemies may be slowed (speed multiplier) and stunned (speed 0) by status effects. Status effects are stackable per type with independent timers; refresh, do not stack duration.
- Enemies never block each other. Visual overlap is solved by a small per-enemy lateral offset (`offset` on `PathFollow2D`, seeded random in ±14 px) so a wave does not look like a single-file conga line.
- Spawning: `WaveManager` reads a `WaveTable`, spawns groups with `{enemy_id, lane, count, interval, start_delay, hp_mult, speed_mult}`. Lane choice is authored per group (some waves are one-lane pressure, some are split).
- Enemy HP bar: small 2-segment bar above the sprite, hidden until first damage, fades after 2 s.

### 4.3 The eight pedestals

- Exactly 8 `Pedestal` nodes, positions from the map resource, each with `range_radius` 330 placement ring.
- States: `locked` (shows lock + unlock condition), `empty` (shows a faint rune circle), `occupied` (tower), `selected` (glow ring + range circle).
- Tap on empty pedestal → build sheet (available tower types, cost, short stat line). Tap on tower → tower sheet (upgrade, sell for 70 % of invested cash, stats, specialization choice at L4/L7 if implemented in a later milestone).
- Range circles are drawn with `_draw()` (no textures), 2 px line, 12 % alpha fill, colored by tower type.
- A pedestal cannot be built on while the game is paused by a modal; modal closes on outside tap.

### 4.4 The Tree (main structure)

Base stats (launch values, all in `res://data/tree/tree_base.tres`):

| Stat | Value | Notes |
|---|---|---|
| Max HP | 1200 | scales with Workshop "Tree Vitality" |
| Damage | 12 | per shot |
| Attack interval | 1.10 s | |
| Range | 640 px | covers both lane approaches |
| Projectile speed | 900 px/s | homing, cannot miss |
| Crit chance | 5 % | |
| Crit multiplier | 2.0x | |
| Regen | 0 %/s | unlocked/upgraded in-run and by cards |
| Targets | 1 | +1 target via in-run upgrade "Split Bolt" (later milestone) |

The tree is a valid target for enemy attacks only if a future enemy type has `attack_range` (none in the launch content); enemies otherwise only damage it on leak.

**Four guardian unit slots** on the canopy. Each slot holds one unit. Units are placed from the unit bar during a run (cost cash), and can be upgraded in place.

- Slot unlocks: slot 1 free from the first run; slot 2 at player level 4; slot 3 via Workshop node "Third Branch" (or 500 coins); slot 4 at player level 12 or 150 gems.
- Units attack independently, using the same targeting/combat pipeline as towers.
- Unit types (launch): **Archer** (fast single target), **Mage** (slow, splash), **Druid** (low damage, applies slow). Each has 10 in-run levels.
- Units are not destroyed by enemies in the launch build (they are part of the tree). Their HP/armor fields exist in data for future boss mechanics but are not used yet.

### 4.5 Towers

Four launch towers, each with 10 levels and one unlockable behavior at level 5. All numbers in `res://data/towers/*.tres`.

| Tower | Cost (cash) | Damage | Interval | Range | Behavior |
|---|---|---|---|---|---|
| Archer Tower | 60 | 14 | 0.90 s | 300 | Single target, fast projectile |
| Cannon | 110 | 45 | 2.20 s | 280 | Splash radius 70, ground-only |
| Frost Spire | 90 | 6 | 1.60 s | 260 | Splash 60 + 35 % slow for 1.5 s |
| Totem | 130 | 0 | — | 260 (aura) | Buffs nearby towers and the tree: +15 % damage, +10 % attack speed; no attack |

- Upgrade cost: `base_cost * 0.8 * 1.55^(level-1)`, level cap 10. Each level: damage ×1.18, range ×1.02, attack interval ×0.97 (floor at 0.35 s).
- Level 5 unlocks the tower's signature behavior (e.g. Archer "Double Shot", Cannon "Shrapnel", Frost "Deep Chill", Totem "Rooted Gift"). Behaviors are scripted strategies selected by ID from a `TowerBehavior` registry, not `if tower_id == ...` chains.
- Duplicate tower types on different pedestals are allowed and expected.
- Selling refunds 70 % of all cash invested in that tower, rounded down.

### 4.6 Enemies

| ID | HP | Speed | Armor | Leak damage | Cash | Notes |
|---|---|---|---|---|---|---|
| `grunt` | 60 | 55 | 0 | 4 % | 4 | Baseline melee creature |
| `runner` | 40 | 95 | 0 | 3 % | 4 | Fast, low HP |
| `tank` | 220 | 40 | 5 | 8 % | 8 | Armored, slow |
| `shaman` | 90 | 50 | 2 | 5 % | 7 | Aura: +20 % speed to enemies within 140 px |
| `boss_troll` | 1800 | 35 | 10 | 25 % | 60 | Every 10th wave; screen shake + banner |

Scaling per wave `w` (applied by `WaveManager` from the wave table, not baked into enemy resources):

- HP multiplier: `1.16^(w-1)`
- Speed multiplier: `min(1 + 0.01*(w-1), 1.40)`
- Cash multiplier: `1.09^(w-1)` (kills must stay worth something, but not scale as fast as HP)
- Enemy count per wave: `6 + floor(1.2*w)`, capped at 40 concurrent-ish spawns per wave, split across lanes by the table.

Armor is flat reduction applied after multipliers: `damage_after_armor = max(damage * (1 + dmg_bonus) - armor, damage * 0.10)`.

### 4.7 Damage pipeline (single source of truth)

All damage goes through `DamageResolver.resolve(DamageContext) -> DamageResult`:

```
base = source.damage
     * source.damage_multiplier        # tree/unit/tower upgrades
     * global_damage_multiplier        # cards, totems, meta
crit = rng.randf() < crit_chance
if crit: base *= crit_multiplier
armor_applied = max(base - target.armor, base * 0.10)
final = max(armor_applied * target.damage_taken_multiplier, 0.0)
```

- Damage types (`physical`, `magic`, `true`) exist in data for future resistances; launch content uses `physical` with armor only.
- Every hit emits one `damage_dealt` event with `{source_id, target_id, amount, is_crit, is_kill}`. HUD, missions and analytics consume events; nothing reads health directly for UI.
- Floating numbers: pooled labels, 0.7 s rise + fade, crit variant larger and gold, capped at 25 simultaneous labels.
- Hit flash: shader uniform `flash_amount` on the enemy sprite, 0.08 s.

### 4.8 Waves, bosses, pacing

- A wave = ordered list of spawn groups; the wave ends when all spawned enemies are dead or leaked **and** the group queue is empty.
- Inter-wave break: 6 s (skippable with "Next Wave" button that grants a bonus of `10 + 2*wave` cash, capped at 120). Preparing early is a skill expression, so the button must be prominent but not accidental (require a 250 ms press-and-hold or a confirm on the first three uses).
- Boss waves: 10, 20, 30 … `boss_troll` with `hp_mult` from the table (e.g. wave 10: ×1.6 of scaled HP), announced by a banner, a 0.4 s slow-motion punch-in, and a dedicated boss HP bar at the top.
- Every 5th wave is a "swarm" wave (many low-HP runners), every 10th is a boss. This rhythm is authored in the wave table, not in code.
- Difficulty must be tuned so that a fresh player with no meta upgrades reaches **wave 8–12** on the first run, and reaches **wave 25–35** after ~3 hours of meta progression. Record this expectation in `docs/BALANCE.md` and validate it with the automated simulation in section 14.1.

### 4.9 Run end, rewards, summary

A run ends when tree HP reaches 0. The tree does not die instantly: play a 1.2 s collapse animation (placeholder: scale + fade + particles), freeze input, then show `RunSummary`.

Run rewards (all granted once, server-validated later):

- **Coins:** `sum over cleared waves of (8 + 2*wave)`; boss waves add 50.
- **Gems:** `1` per 5 cleared waves, `+5` on a new personal best wave.
- **XP:** `10` per cleared wave.
- **Battle pass / tournament points:** `cleared_waves` (used later).

`RunSummary` shows: waves cleared, best wave (and "NEW BEST" state), coins earned, gems earned, XP bar fill animation, one rewarded-ad button "Double coins" (once per run), and "Continue" → MainMenu.

### 4.10 In-run economy and the upgrade panel

- Earn cash from kills and wave clears; starting cash 50.
- The bottom "Upgrade" button opens a bottom sheet with three tabs: **Tree**, **Units**, **Towers** (towers tab lists built towers; tapping one opens its sheet).
- Tree tab rows: Damage, Attack Speed, Crit Chance, Crit Damage, Range, Regen, each with current level, next-value preview (`+8 % → 12.4`), cost, and a buy button that is disabled with a reason when unaffordable.
- **Hold-to-buy**: long-press repeats purchases at 8/s while affordable. Must not double-spend (transaction function returns a typed result).
- Costs and effects per row live in `res://data/tree/upgrades/*.tres`; the panel is generated from the resource list, so adding a new tree stat is a data-only change **and** one entry in the stat enum.
- Upgrade feedback: button punch scale 1.0→1.08→1.0, gold flash on the value, SFX, and the tree flashes with a level-up ring.

### 4.11 Battle HUD (portrait)

Top bar: wave counter + timer, boss HP bar (when active), coin balance (meta currency, **not** spendable in-run, shown for context), gem balance, settings (pause) button, speed control.

- Speed control: segmented `1x | 1.5x | 2x`. Locked segments show a lock and open the "unlock" popup (level / ad / purchase). Speed changes **only the battle simulation**, never UI animation or audio pitch. Implement it by passing `delta * sim_speed` into battle systems (`BattleClock`), not by `Engine.time_scale`.
- Bottom-left: tree HP bar with shield icon, `HP: 95 %` label, low-HP state (< 30 %) pulsing.
- Bottom-right: `Upgrade` button with a notification dot when something is affordable.
- Tapping the tree opens the tree sheet; tapping empty ground dismisses panels.
- Pause overlay: resume, restart run (confirm), abandon run (confirm, awards partial rewards?), settings, and the current run's stats.

### 4.12 Input and feel

- One-thumb play. All interactive targets ≥ 96×96 px, ≥ 48 px apart.
- Tap selection only; no drag-required mechanics in the launch build.
- Every button: press-down scale 0.96 + hover/press tint, release SFX, and a 30 ms input lockout to prevent double taps.
- Camera: fixed (no pan/zoom) for the launch build. Screen shake (toggleable) on boss spawn, tree damage, and big explosions.
- Haptics: light on button confirm, medium on boss spawn and tree leak (toggleable, Android only).

---

## 5. VISUAL LANGUAGE AND REFERENCES

Use the two approved references as the target:

- `docs/reference/ui_main_menu.png` — menu: green wooden panels with beveled gold trim, big glossy green CTA, leaf ornaments, top currency bar, bottom 5-tab navigation.
- `docs/reference/ui_battle.png` — battle: top-down forest clearing, two dirt roads converging on the tree, 8 stone pedestals in a ring, tree with glowing blue runes, floating HP bar bottom-left, upgrade button bottom-right.

**Palette (use these exact hexes in the theme and placeholders):**

| Role | Hex | Use |
|---|---|---|
| Panel dark green | `#0F3D1E` | panel backgrounds |
| Panel green | `#1E6B2E` | raised panels |
| Button green (light) | `#7BD93A` | primary CTA fill |
| Button green (dark) | `#3E9A1E` | CTA border/shadow |
| Gold | `#F2C230` | currency, highlights, trim |
| Blue magic | `#3FA9F5` | magic FX, speed trial, runes |
| Parchment | `#E8D5A8` | scroll/mission panels |
| Danger | `#E0433C` | damage, low HP, close |
| Text light | `#F5F0E1` | body text |
| Text dark | `#1B2A1A` | text on light panels |

**Shape language:** thick 4–6 px dark outlines, rounded 24 px corners, inner top highlight, bottom drop shadow; every panel has a subtle wood-grain or leaf-motif corner decoration. Placeholders must keep these proportions (same corner radius, same padding) so the swap to real art is seamless.

**Typography:** one display font (chunky, rounded, with Cyrillic coverage) for titles and numbers; one body font (humanist sans, Cyrillic). Until fonts are supplied, use Godot's default font with `theme_override_font_sizes` and document the two font hooks in the manifest.

**Icon style:** painted, gold-rimmed, 2 px dark outline, readable at 64 px.

---

## 6. ECONOMY AND PROGRESSION

### 6.1 Currencies

| Currency | Scope | Earned from | Spent on |
|---|---|---|---|
| **Cash** | run only (`run.cash`) | kills (`1.09^(w-1)` scaled), wave clears, "Next Wave" bonus, rewarded ad | towers, tower upgrades, unit placement/upgrades, tree in-run upgrades |
| **Coins** | permanent | waves cleared, missions, Magica, offline income, IAP, ads | Workshop levels, Magica research, card upgrades |
| **Gems** | permanent premium | missions, new best wave, tournaments, IAP, rare drops | card packs, speed unlocks, slot unlocks, cosmetics |
| **Stones** | seasonal | weekly tournament placement | unique abilities / unique towers (post-MVP content, currency exists from launch) |

Hard rules:

- Cash is **never** converted to Coins or Gems. It dies with the run, and the run summary must make that explicit ("Cash is lost when the run ends").
- Coins and Gems are never spent inside a battle. The battle HUD shows them read-only.
- All wallet mutations go through `WalletService` with a transaction log (last 50 entries kept for support/debug) and an `amount > 0` guard. No direct `coins += x` anywhere else.
- Every reward source is a `RewardBundle` (`{coins, gems, stones, cash, xp, cards}`) so mission/IAP/ad rewards share one code path and one UI animation.
- Numbers are displayed with `String.num_int64` and `K/M/B` suffixes at ≥ 10 000.

### 6.2 Player level and unlocks

XP is earned only from cleared waves (`10 XP` each) and missions.

`xp_required(level) = round(120 * 1.18^(level-1))`

| Level | Unlock |
|---|---|
| 1 | Battle, Workshop, Settings |
| 2 | Cards tab (1 slot) |
| 3 | Magica tab, speed 1.5x |
| 4 | Unit slot 2, Missions |
| 5 | Card slot 2, Shop |
| 6 | Leaderboard |
| 8 | Tower specialization branch (post-MVP) |
| 10 | Speed 2x, unit slot 3 alternative unlock |
| 12 | Unit slot 4, tournament entry |
| 15 | Card slot 3 |
| 20 | Card slot 4, prestige teaser |

Unlocks are data (`res://data/progression/levels.tres`) and the UI reads `UnlockService.is_unlocked(id)`; no `if player_level >= 4` scattered in scenes.

### 6.3 Workshop (permanent tower/tree upgrades, coins)

Four categories, six upgrade tracks each, max level 50. Cost: `base_cost * 1.18^level`, rounded to 5. Effect is `add` (percentage points) or `mul` (multiplicative) — declared in the resource.

**Attack**

| Track | Effect per level | Base cost |
|---|---|---|
| Tree Damage | +4 % | 50 |
| Unit Damage | +4 % | 60 |
| Tower Damage | +4 % | 70 |
| Crit Chance | +0.4 pp (cap +25 pp) | 80 |
| Crit Damage | +5 % | 80 |
| Attack Speed (all) | +1.5 % | 120 |

**Defense**

| Track | Effect per level | Base cost |
|---|---|---|
| Tree Max HP | +5 % | 50 |
| Tree Regen | +0.04 %/s | 90 |
| Damage Reduction | +0.5 % (cap 60 %) | 100 |
| Starting Cash | +6 cash | 70 |
| Shield at Run Start | +40 shield HP | 150 |
| Leak Damage Reduction | −0.5 pp (cap −40 %) | 140 |

**Utility**

| Track | Effect per level | Base cost |
|---|---|---|
| Cash Gain | +3 % | 60 |
| Coin Gain | +3 % | 90 |
| XP Gain | +3 % | 80 |
| In-Run Discount | −0.8 % (cap −40 %) | 110 |
| Wave Clear Bonus | +4 cash | 75 |
| Offline Cap | +20 min (base 8 h) | 120 |

**Environment**

| Track | Effect per level | Base cost |
|---|---|---|
| Offline Coin Rate | +5 % | 100 |
| Ad Reward Bonus | +4 % | 90 |
| Mission Reward Bonus | +4 % | 90 |
| Magica Speed | +2 % | 130 |
| Free Daily Gems | +0.1 gem/day (rounded up, cap 5) | 200 |
| Card Drop Chance | +0.5 % (cap 15 %) | 160 |

UI: 4 category tabs, a vertical list of tracks with icon, name, `Lv. 12/50`, current → next value, cost, and a buy button. A "Buy max" long-press is nice-to-have (Milestone 8).

### 6.4 Magica (idle research)

Three branches, each a small tree of nodes with prerequisites. Research runs in **real time** and continues while the app is closed (compute from `started_at` + `duration`, clamp offline progress to the Offline Cap). Completed research must be claimable with a "Research complete" badge on the tab.

**Time** (game pace)

| Node | Duration | Cost | Effect |
|---|---|---|---|
| Quickened Roots I–III | 30 m / 2 h / 8 h | 200 / 900 / 3 000 coins | Research speed +10 % each |
| Flow of Ages | 4 h | 1 200 coins | Battle speed option +0.25x (a fourth speed step) |
| Auto-Restart | 12 h | 15 gems | Toggle: automatically start a new run at the same speed after the summary |

**Wealth** (economy)

| Node | Duration | Cost | Effect |
|---|---|---|---|
| Golden Sap I–III | 45 m / 3 h / 10 h | 250 / 1 000 / 3 500 coins | +10 % coins from waves |
| Night Harvest | 6 h | 2 000 coins + 20 gems | Offline income +100 % while closed |
| Merchant's Favor | 2 h | 800 coins | Shop prices −5 %, in-run upgrades −5 % |

**Knowledge** (mechanics)

| Node | Duration | Cost | Effect |
|---|---|---|---|
| Fourth Branch | 8 h | 25 gems | Unit slot 3 |
| Deep Roots | 5 h | 1 500 coins | +1 card slot |
| Ancient Memory | 3 h | 1 000 coins | Start each run with a free Archer Tower voucher |
| Second Wind | 18 h | 40 gems | Once per run, tree survives a lethal hit with 15 % HP |

Rules: one active research at a time (a second slot is a later premium/QoL unlock); cancel refunds 50 %; speed-ups via rewarded ads (max 3/day, each −30 min).

### 6.5 Cards

- Rarities: Common, Rare, Epic, Legendary. Cards have levels 1–5; duplicates convert to shards (`20/40/80/160` per level), auto-upgrade button.
- Equip slots: 1 at level 2, 2 at level 5, 3 at level 15, 4 at level 20; Deep Roots adds one more.
- Card effects are **modifier entries** `{stat, op, value}` applied by `ModifierService` when the loadout changes; the battle reads aggregated modifiers, never individual cards.
- Launch set (12 cards):

| Card | Rarity | Effect |
|---|---|---|
| Greed | Common | +25 % enemies per wave, +20 % cash |
| Vital Roots | Common | +15 % tree max HP |
| Regrowth | Rare | +0.35 %/s tree regen |
| Sharpened Tips | Rare | +8 pp crit chance |
| Heavy Bolts | Rare | +30 % crit damage |
| Swift Winds | Epic | +15 % attack speed |
| Rich Soil | Common | +10 % coins |
| Bark Shield | Rare | +3 armor, +20 % leak damage reduction |
| Lucky Clover | Epic | +10 % gem chance on wave clear |
| Guardian Bond | Epic | +1 unit slot |
| Overgrowth | Rare | +12 % tower damage, +8 % tower range |
| Ancient Pact | Legendary | +25 % all damage, −10 % tree max HP |

Card art placeholders must follow the manifest; card frames are per-rarity 9-slice panels.

### 6.6 Missions (daily and weekly)

- 3 daily missions (reset 04:00 local) and 5 weekly missions (reset Monday 04:00).
- Generated from templates with scaling targets and rewards; templates in `res://data/missions/templates.tres`.
- Template examples: *Clear N waves*, *Kill N enemies*, *Build N towers in one run*, *Reach wave N*, *Deal N crits*, *Clear a run without losing more than 25 % HP*, *Use a rewarded ad N times* (max 1 per day), *Equip N cards*.
- Progress is event-driven (`mission_progress` events from battle), persisted on change, and claimed manually from the Missions screen (claim-all button is a later QoL).
- Daily completion bonus: all 3 → `+30 coins, +2 gems`. Weekly completion: all 5 → `+250 coins, +10 gems, 1 card pack`.
- No mission may require spending premium currency.

### 6.7 Leaderboard, tournaments, social (server-backed)

- **Leaderboard:** weekly, ranked by `max_wave` in the current week, tie-break by earlier submission time then lower play time. Tabs: Global, Friends (later), My rank pinned at the bottom.
- **Tournament:** weekly, 7 days, entry from level 12 or via a ticket. Players are grouped into cohorts of 50 server-side. Each player submits their best run; the client shows the live cohort table (refresh every 5 min, cache offline). Rewards by percentile: top 1 % → 100 stones, top 10 % → 40, top 25 % → 20, top 50 % → 10, participation → 5.
- **Anti-cheat:** a submitted run carries `run_seed`, `duration_seconds`, `waves_cleared`, `total_damage`, `cash_earned`, and an HMAC signature. Server rejects implausible ratios (e.g. waves per minute above a threshold, damage per second above a cap). Client never decides placement.
- Until the backend is live (Milestone 7), `LeaderboardService` and `TournamentService` must work against a `LocalBackendStub` that generates fake cohort entries so the UI is fully testable offline.

---

## 7. MONETIZATION: ADS AND IAP

### 7.1 Architecture

Two service autoloads, both with real Android implementations and desktop stubs:

```gdscript
# Autoload: AdsService  (extends Node)
signal rewarded_earned(placement: StringName)
signal rewarded_failed(placement: StringName, reason: StringName)
signal interstitial_closed()

func is_ready(placement: StringName) -> bool
func show_rewarded(placement: StringName) -> void
func show_interstitial(placement: StringName) -> bool   # false if capped/not ready
func get_cap_status(placement: StringName) -> Dictionary
```

```gdscript
# Autoload: IapService
signal purchase_completed(product_id: StringName, receipt: Dictionary)
signal purchase_failed(product_id: StringName, reason: StringName)
signal purchases_restored(products: PackedStringArray)

func is_available() -> bool
func query_products() -> Array[Dictionary]     # from config, prices from store when available
func purchase(product_id: StringName) -> void
func restore() -> void
```

Rules:

- **All** UI talks to these services only. `if OS.has_feature("android")` may appear **only** inside the Android adapter, nowhere else.
- Desktop/editor stub: rewarded ads resolve after a 2 s fake "ad" with a visible countdown panel (`DebugAdOverlay`) so flows can be tested without a device. The stub must be behind `Settings.debug.fake_monetization = true` in debug builds only.
- Plugin choice must be verified against the installed Godot version before adding: AdMob → `poing-studios/godot-admob-plugin` (Android); Billing → `godot-google-play-billing` / `GodotGooglePlayBilling`. Put them in `addons/`, document the exact version in `docs/DECISIONS.md`, and keep an adapter (`AndroidAdsAdapter`, `AndroidBillingAdapter`) so a plugin swap touches one file.
- Production ad unit IDs and product IDs live in `res://config/monetization.tres`, but the committed file contains **test IDs only**. A `user://monetization_override.tres` may replace them locally; production IDs are injected at export time. Never commit keystores, service account JSON, or real ad unit IDs.
- **Consent:** show a UMP/consent step before the first ad on EEA devices (Google UMP SDK). Until implemented, gate all ads behind a `consent_granted` flag set by the consent dialog; default to `false` in release builds targeted at EEA.
- **No ads for "No Ads" purchasers.** Interstitials and banners disabled; rewarded ads remain opt-in (they are a reward, not an interruption).

### 7.2 Placements (launch)

| Placement | Type | Reward | Cap |
|---|---|---|---|
| `run_double_coins` | rewarded | double the run's coin payout (once per run) | 1/run |
| `speed_unlock_24h` | rewarded | unlock 1.5x (or next locked step) for 24 h | 1/day |
| `free_cash` | rewarded | +150 cash (scales with wave: `100 + 10*wave`) | 2/run |
| `tree_blessing` | rewarded | restore 25 % tree HP, once per run | 1/run |
| `research_speedup` | rewarded | −30 min research time | 3/day |
| `run_end_interstitial` | interstitial | — | every 3rd run, min 120 s apart, never before wave 5 |
| `shop_banner` | banner (later) | — | menu only, bottom safe area |

Every rewarded placement must: check `is_ready`, show a loading state on the button, handle failure with a toast ("Ad not available, try again later"), and never consume the reward twice (server-side verification later via SSV callback).

### 7.3 IAP catalog (launch)

| Product ID | Contents | Type |
|---|---|---|
| `thetree.gems_100` | 100 gems | consumable |
| `thetree.gems_550` | 550 gems (+10 %) | consumable |
| `thetree.gems_1200` | 1 200 gems (+20 %) | consumable |
| `thetree.coins_5000` | 5 000 coins | consumable |
| `thetree.starter_pack` | 300 gems, 2 500 coins, 1 epic card | non-consumable, one-time |
| `thetree.no_ads` | remove interstitials/banners | non-consumable |
| `thetree.speed_pack` | permanent 1.5x + 2x unlock | non-consumable |

Shop UI: grid of offer cards with art placeholder, title, contents, price (from store; fallback "—"), best-value ribbon, and a restore-purchases link. Purchase flow: confirm → store sheet → validate → grant via `RewardBundle` → success popup. Handle pending, cancelled, already-owned, and network errors explicitly.

---

## 8. PLATFORM SERVICES, SAVE DATA, BACKEND

### 8.1 Service autoloads (fixed list and order)

```
EventBus        — typed global signals, no logic
App             — boot sequence, service init order, scene routing entry
SceneRouter     — transitions, back stack, loading overlay
SettingsService — audio, language, haptics, accessibility, debug flags (ConfigFile in user://)
SaveService     — load/save/migrate/checksum, autosave, backup slots
GameState       — player profile, wallet, meta progress (runtime model, serializable)
RunState        — current run state (seed, cash, waves, towers, upgrades)
ModifierService — aggregates cards + workshop + magica + run upgrades into final stats
CombatEvents    — battle-scoped signal bus (damage, kill, leak, wave_started, wave_cleared)
AudioService    — music/SFX pools, buses, ducking
LocaleService   — translation loading, language switching, formatting
ApiClient       — HTTP, auth, retries, offline queue
LeaderboardService / TournamentService — use ApiClient or LocalBackendStub
AdsService / IapService — see section 7
AnalyticsService — event logging (debug console + optional provider)
```

Initialization order is explicit in `App._ready()`: settings → locale → audio → save → state → api → ads/iap → router. A service that fails to init must degrade gracefully (log + `degraded` flag), never crash the boot.

### 8.2 Save file

Path: `user://save_v1.json` (+ `user://save_v1.bak.json`, written before each overwrite).

```json
{
  "schema_version": 1,
  "saved_at": 1761800000,
  "checksum": "sha256:...",
  "player": {"id": "uuid", "nickname": "Vova", "avatar_id": "elf_01", "level": 7, "xp": 320, "created_at": 1760000000},
  "wallet": {"coins": 12480, "gems": 350, "stones": 0},
  "stats": {"best_wave": 18, "runs_played": 42, "total_kills": 9120, "total_playtime": 5400, "weekly_max_wave": 18, "week_id": "2026-W44"},
  "workshop": {"tree_damage": 12, "tree_hp": 8, "...": 0},
  "magica": {"research": {"node_id": "golden_sap_2", "started_at": 1761700000, "ends_at": 1761710000}, "completed": ["golden_sap_1"]},
  "cards": {"owned": [{"id": "greed", "level": 2, "shards": 10}], "equipped": ["greed", null, null, null]},
  "missions": {"day_id": "2026-10-31", "daily": [{"id": "d_kill_300", "progress": 120, "target": 300, "claimed": false}], "week_id": "2026-W44", "weekly": []},
  "unlocks": ["speed_1_5", "unit_slot_2"],
  "settings": {"music": 0.8, "sfx": 1.0, "ui": 0.9, "haptics": true, "language": "uk", "text_scale": 1.0, "shake": true},
  "shop": {"owned_products": ["thetree.no_ads"], "last_daily_claim": 1761700000},
  "ads": {"rv_today": 2, "rv_day": "2026-10-31", "interstitial_last": 0}
}
```

Requirements:

- `SaveService` writes via `FileAccess` to a temp path, verifies size > 0, then renames over the target; the previous file becomes `.bak`.
- On load: try main → if checksum fails, try backup → if both fail, create a new profile and emit `save_recovered_from_corruption` (analytics + a one-time popup).
- `migrate(from_version)` is a pure function with a test per version step.
- Autosave triggers: run start, wave cleared, run end, meta purchase, screen change away from a modified screen, app pause (`NOTIFICATION_APPLICATION_PAUSED` / `WM_CLOSE_REQUEST`).
- No save on every kill. Debounce to 2 s max once per second during battle.
- A run in progress is **not** resumable in the launch build (documented decision); the save stores only meta progress. Mark `run_resume` as a post-MVP item.

### 8.3 Identity and first launch

First launch flow (`FirstLaunch` scene, skippable language step):

1. Language picker (system default preselected; uk/en).
2. Nickname input: 3–16 chars, letters/digits/underscore/space, profanity list, uniqueness checked server-side later (local uniqueness is not required), live validation.
3. Avatar picker: 6 placeholder avatars.
4. `Continue` → creates `player.id = UUID.v4()`, stores, marks `onboarded = true`, goes to MainMenu.

`AccountService` (part of `GameState`) exposes `get_player_id()`, `get_nickname()`, `rename(new_name)`, `is_guest()`. A real account link (Google/Apple) is post-MVP but the data model must already have `provider` and `provider_uid` fields (nullable).

### 8.4 ApiClient (local-first, server-ready)

```gdscript
class_name ApiClient extends Node

func is_online() -> bool
func request(method: StringName, path: String, body: Dictionary = {}, opts: Dictionary = {}) -> ApiResult
func enqueue(op: Dictionary) -> void          # offline queue, persisted in user://api_queue.json
func flush_queue() -> void                     # exponential backoff, max 5 attempts
```

- Base URL from `res://config/env.tres` (`debug`/`release`), token in `user://auth.json` (never in the save file).
- `ApiResult` is a typed object: `{ok, status, data, error_code, retryable}`. No raw `HTTPRequest` usage outside `ApiClient`.
- Retries: network/timeout/5xx → exponential backoff (1s, 2s, 4s, 8s, 16s, jitter). 4xx → no retry, surface a typed error.
- Idempotency: every mutating call carries `Idempotency-Key` (UUID) so a retried save/purchase does not duplicate.
- Timeouts: 10 s default; save sync 15 s.
- All calls are `await`-able and cancellable when the node is freed.
- The game must be fully playable with `ApiClient.is_online() == false` — verified by an automated offline smoke test.

### 8.5 Backend contract (FastAPI + Neon) — implement in Milestone 7

Server stack: FastAPI (Python 3.12), Pydantic v2, SQLAlchemy 2 async + asyncpg, Alembic migrations, JWT (short access + refresh), PostgreSQL on Neon (pooled connection string), deployed behind HTTPS. Repo: `server/` inside the same monorepo, with its own `pyproject.toml`, `Dockerfile`, `README.md`, and `.env.example`.

Endpoints (all `/v1`, JSON, `Authorization: Bearer <jwt>` except auth):

| Method | Path | Purpose |
|---|---|---|
| POST | `/auth/guest` | `{device_id, nickname}` → `{player_id, access_token, refresh_token, expires_in}` |
| POST | `/auth/refresh` | rotate tokens |
| GET | `/profile` | profile, wallet, level, stats |
| GET | `/save` | full save blob + `revision` + `updated_at` |
| PUT | `/save` | `{revision, payload, checksum}` → 409 on stale revision with server copy |
| GET | `/config` | remote config: balance overrides, feature flags, ad frequency, shop catalog version |
| GET | `/leaderboard?scope=weekly&limit=100&cursor=` | ranked entries + own rank |
| GET | `/tournaments/current` | current tournament, cohort, ends_at, rules |
| GET | `/tournaments/current/standings` | cohort table |
| POST | `/tournaments/current/submit` | `{run_seed, waves, duration_s, damage, cash, signature}` → validated placement |
| POST | `/runs` | run telemetry (optional analytics) |
| POST | `/purchases/verify` | platform receipt verification, idempotent grant |
| POST | `/ads/ssv` | AdMob server-side verification callback (no auth, signed) |
| POST | `/events` | batched analytics (max 100 events) |

DB tables: `players`, `saves` (jsonb + revision), `runs`, `leaderboard_entries` (week_id, player_id, max_wave, submitted_at), `tournaments`, `tournament_entries`, `purchases`, `missions_state`, `events` (partitioned or dropped after 90 days).

Rules: server is authoritative for leaderboard/tournament placement and purchase grants; the client must never be trusted for those. Timezone of weekly reset: Europe/Kyiv, Monday 04:00, stored as UTC in DB.

Deliverable for Milestone 7 also includes: OpenAPI docs page, `docker-compose.yml` for local dev, seed script, and a Postman/`.http` collection. Until then, ship `server/SPEC.md` only (contract + schema), so the client code can be built against the stub.

### 8.6 Analytics (privacy-aware)

`AnalyticsService.track(event: StringName, props: Dictionary)` → debug print in debug builds, batched `POST /events` when online, dropped when offline (no local queue growth). Launch events: `app_open`, `run_start`, `wave_cleared`, `run_end` (waves, duration, coins), `purchase`, `ad_shown`, `ad_rewarded`, `screen_view`, `error`. No personal data beyond a random player UUID.

---

## 9. ART PIPELINE: PLACEHOLDERS AND THE ASSET MANIFEST

### 9.1 Principle

**Every visual in the game is a separate image file with a stable path and a documented size.** No procedural drawing substitutes for a sprite, no `ColorRect` pretends to be a panel, no emoji instead of an icon. Placeholders are generated as flat-color PNGs at the exact final size, with the exact final name. When real art arrives, the file is overwritten at the same path and **zero code changes are required**.

Rules:

1. All art lives under `res://assets/art/<area>/<entity>/<name>.png`. Never reference `res://docs/reference/` from game code.
2. The manifest below is normative. `docs/art_manifest.json` is the machine-readable twin and the single source for the generator.
3. A 9-slice asset is drawn at a fixed size and sliced with the margins in the manifest; the placeholder must paint its border **inside** those margins so stretch artifacts are visible immediately.
4. Variants are separate files: `_normal`, `_pressed`, `_disabled`, `_selected`, `_locked`, `_active`, `_filled`, `_empty`. Do not tint a single sprite in code to fake a state — a designer must be able to change each state independently.
5. Animation frames are numbered with a two-digit suffix: `enemy_grunt_walk_00.png` … `_05.png` (6 frames @ 10 FPS default; per-entity FPS is in data).
6. Sprites are authored on transparent background, trimmed to the described canvas (the canvas size is the *layout* size — do not trim transparent padding).
7. Icons are square, centered, with 8 % inner padding.
8. If an asset is missing at runtime, the loader substitutes `assets/art/_missing.png` (128×128 magenta checker) and logs a warning — never a crash.

### 9.2 Placeholder generator

`tools/generate_placeholders.gd` (editor + headless):

- reads `docs/art_manifest.json` (`[{path, w, h, color, mode, margins}]`),
- for each entry, if the file does not exist, writes a PNG: solid `color`, 2 px border in a darker shade, and for 9-slice assets a 1 px inner rectangle exactly on each slice line,
- prints a summary (`created N, skipped N, failed N`),
- is idempotent and **never overwrites an existing file** (that is how real art is protected),
- also writes `assets/art/_missing.png` and `docs/art_manifest.md` from the JSON.

Placeholder colors by area: `ui` `#1E6B2E`, `buttons` `#7BD93A`, `icons` `#F2C230`, `backgrounds` `#2C4A2A`, `tree` `#2E7D32`, `pedestal` `#6B7A66`, `towers` `#4A6FA5`, `units` `#3FA9F5`, `enemies` `#8A4A3A`, `boss` `#5B2A2A`, `fx` `#FFD54F`, `ui_meta` `#1B5E20`.

### 9.3 UI: shared components

Sizes are in design pixels (1080×1920). `9p` = 9-slice; margins are `left/top/right/bottom` in source pixels.

| File (under `assets/art/`) | Size | Slice | Notes |
|---|---|---|---|
| `ui/common/panel_9p_green.png` | 96×96 | 9p 24/24/24/24 | main screen panel |
| `ui/common/panel_9p_dark.png` | 96×96 | 9p 24/24/24/24 | modal / inset |
| `ui/common/panel_9p_wood.png` | 96×96 | 9p 28/28/28/28 | menu panels |
| `ui/common/panel_9p_parchment.png` | 96×96 | 9p 24/24/24/24 | missions |
| `ui/common/row_9p_green.png` | 96×64 | 9p 20/18/20/18 | list rows |
| `ui/common/header_9p.png` | 96×96 | 9p 24/24/24/24 | screen header bar |
| `ui/common/tooltip_9p.png` | 96×64 | 9p 20/16/20/16 | |
| `ui/common/toast_9p.png` | 96×64 | 9p 20/16/20/16 | |
| `ui/common/chip_9p.png` | 64×48 | 9p 16/12/16/12 | small pill label |
| `ui/common/divider.png` | 400×6 | — | 1 px center line |
| `ui/common/badge_dot.png` | 40×40 | — | notification dot |
| `ui/common/scrollbar_track.png` | 16×64 | 9p 0/8/0/8 | |
| `ui/common/scrollbar_grab.png` | 16×64 | 9p 0/8/0/8 | |
| `ui/common/slider_track.png` | 400×32 | 9p 0/12/0/12 | |
| `ui/common/slider_fill.png` | 400×32 | 9p 0/12/0/12 | |
| `ui/common/slider_knob.png` | 64×64 | — | |
| `ui/common/progress_bg.png` | 400×48 | 9p 0/16/0/16 | |
| `ui/common/progress_fill_green.png` | 400×48 | 9p 0/16/0/16 | also yellow/blue/red variants |
| `ui/common/toggle_on.png` | 128×64 | 9p 28/0/28/0 | |
| `ui/common/toggle_off.png` | 128×64 | 9p 28/0/28/0 | |
| `ui/common/checkbox_on.png` | 64×64 | — | |
| `ui/common/checkbox_off.png` | 64×64 | — | |

Buttons (all `320×120`, 9p `40/36/40/36`; icon buttons are square):

| File | Size | Notes |
|---|---|---|
| `ui/buttons/button_green_{normal,pressed,disabled}.png` | 320×120 | primary CTA |
| `ui/buttons/button_blue_{normal,pressed,disabled}.png` | 320×120 | secondary |
| `ui/buttons/button_gold_{normal,pressed,disabled}.png` | 320×120 | purchase |
| `ui/buttons/button_red_{normal,pressed}.png` | 320×120 | destructive |
| `ui/buttons/button_ghost_{normal,pressed}.png` | 320×120 | cheap alternative |
| `ui/buttons/button_icon_round_{normal,pressed}.png` | 128×128 | settings, pause |
| `ui/buttons/button_close_{normal,pressed}.png` | 96×96 | |
| `ui/buttons/button_back_{normal,pressed}.png` | 96×96 | |
| `ui/buttons/button_plus_{normal,pressed}.png` | 96×96 | currency add |
| `ui/buttons/tab_{normal,selected}.png` | 240×96 | top-level tabs |

Icons (all `96×96` unless noted):

`ui/icons/icon_coin`, `icon_gem`, `icon_cash`, `icon_stone`, `icon_settings`, `icon_sound_on`, `icon_sound_off`, `icon_music_on`, `icon_music_off`, `icon_vibration`, `icon_language`, `icon_info`, `icon_close`, `icon_check`, `icon_lock`, `icon_clock`, `icon_play`, `icon_pause`, `icon_speed`, `icon_star`, `icon_trophy`, `icon_calendar`, `icon_gift`, `icon_shop`, `icon_cards`, `icon_hammer`, `icon_magic`, `icon_shield`, `icon_sword`, `icon_heart`, `icon_arrow_right`, `icon_ad` (72×72), `icon_reward` (72×72).

Bottom navigation (5 items, each 2 states):

| File | Size | Notes |
|---|---|---|
| `ui/nav/nav_bg_9p.png` | 96×96 | 9p 24/24/24/24, bottom bar |
| `ui/nav/nav_home_{normal,pressed}.png` | 160×160 | |
| `ui/nav/nav_workshop_{normal,pressed}.png` | 160×160 | Upgrades |
| `ui/nav/nav_cards_{normal,pressed}.png` | 160×160 | |
| `ui/nav/nav_missions_{normal,pressed}.png` | 160×160 | |
| `ui/nav/nav_shop_{normal,pressed}.png` | 160×160 | |

### 9.4 Main menu

| File | Size | Notes |
|---|---|---|
| `ui/menu/bg/menu_bg.png` | 1080×1920 | forest + castle; the existing `menu_bg.jpg` may be converted |
| `ui/menu/logo_title.png` | 760×460 | "The Tree:" logotype |
| `ui/menu/logo_subtitle_9p.png` | 640×140 | wooden plank "idle tower defense" |
| `ui/menu/top_bar_9p.png` | 96×96 | 9p 24; coins/gems |
| `ui/menu/currency_pill_9p.png` | 96×64 | 9p 20/16 |
| `ui/menu/profile_frame.png` | 240×240 | avatar ring |
| `ui/menu/avatar_0{1..6}.png` | 200×200 | six selectable avatars |
| `ui/menu/stat_row_9p.png` | 96×64 | best wave / level row |
| `ui/menu/battle_button_{normal,pressed}.png` | 820×300 | main CTA |
| `ui/menu/speed_trial_9p.png` | 660×150 | "Speed Trial +1.5x" bar |
| `ui/menu/daily_card_9p.png` | 96×96 | daily missions card |

### 9.5 Battle

| File | Size | Notes |
|---|---|---|
| `battle/arena/arena_bg.png` | 1080×1920 | forest clearing, two roads, ring of stones |
| `battle/arena/ground_shadow.png` | 256×128 | soft ellipse, alpha |
| `battle/tree/tree_base.png` | 600×680 | life tree; origin bottom-center |
| `battle/tree/tree_glow.png` | 400×400 | additive blue magic glow |
| `battle/tree/tree_hurt_mask.png` | 600×680 | white silhouette for hit flash |
| `battle/tree/unit_slot_empty.png` | 120×120 | |
| `battle/tree/unit_slot_locked.png` | 120×120 | |
| `battle/tree/unit_slot_selected.png` | 140×140 | |
| `battle/pedestal/pedestal_empty.png` | 180×180 | |
| `battle/pedestal/pedestal_selected.png` | 200×200 | |
| `battle/pedestal/pedestal_locked.png` | 180×180 | |
| `battle/pedestal/pedestal_rune.png` | 140×140 | idle animation sprite (2 frames later) |
| `battle/towers/tower_archer_l{1,2,3}.png` | 160×160 | tiers: L1–4, L5–7, L8–10 |
| `battle/towers/tower_cannon_l{1,2,3}.png` | 160×160 | |
| `battle/towers/tower_frost_l{1,2,3}.png` | 160×160 | |
| `battle/towers/tower_totem_l{1,2,3}.png` | 160×160 | |
| `battle/units/unit_archer_idle.png` | 110×110 | |
| `battle/units/unit_mage_idle.png` | 110×110 | |
| `battle/units/unit_druid_idle.png` | 110×110 | |
| `battle/enemies/enemy_grunt_walk_00..05.png` | 128×128 | 6 frames |
| `battle/enemies/enemy_runner_walk_00..05.png` | 128×128 | |
| `battle/enemies/enemy_tank_walk_00..05.png` | 160×160 | |
| `battle/enemies/enemy_shaman_walk_00..05.png` | 128×128 | |
| `battle/enemies/enemy_boss_troll_walk_00..07.png` | 280×280 | 8 frames |
| `battle/enemies/enemy_shadow.png` | 160×80 | shared blob shadow |
| `battle/enemies/hp_bar_bg.png` | 72×14 | |
| `battle/enemies/hp_bar_fill.png` | 68×10 | |
| `battle/projectiles/proj_arrow.png` | 48×24 | |
| `battle/projectiles/proj_cannonball.png` | 48×48 | |
| `battle/projectiles/proj_frost.png` | 40×40 | |
| `battle/projectiles/proj_bolt.png` | 40×40 | tree magic |
| `battle/projectiles/proj_mage.png` | 48×48 | |
| `battle/fx/fx_hit.png` | 64×64 | |
| `battle/fx/fx_death.png` | 128×128 | |
| `battle/fx/fx_explosion_sheet.png` | 512×512 | 4×4 grid of 128×128 |
| `battle/fx/fx_levelup.png` | 160×160 | |
| `battle/fx/fx_leak.png` | 160×160 | |

Battle HUD:

| File | Size | Notes |
|---|---|---|
| `battle/hud/wave_banner_9p.png` | 96×64 | 9p 20/16; "Wave 3 / 15" |
| `battle/hud/boss_hp_frame_9p.png` | 96×48 | 9p 20/12 |
| `battle/hud/boss_hp_fill.png` | 900×36 | 9p 0/12 |
| `battle/hud/tree_hp_frame_9p.png` | 96×96 | 9p 28 |
| `battle/hud/tree_hp_fill.png` | 480×40 | 9p 0/14 |
| `battle/hud/tree_hp_fill_low.png` | 480×40 | pulsing state |
| `battle/hud/cash_pill_9p.png` | 96×64 | |
| `battle/hud/speed_button_{normal,active,locked}.png` | 180×96 | 3 states × 3 sizes (1x/1.5x/2x labels are text) |
| `battle/hud/upgrade_button_{normal,pressed,attention}.png` | 460×140 | |
| `battle/hud/tower_sheet_9p.png` | 96×96 | bottom sheet |
| `battle/hud/tower_card_{normal,selected}.png` | 96×96 | 9p 20 |
| `battle/hud/unit_card_{normal,selected}.png` | 96×96 | 9p 20 |
| `battle/hud/pause_panel_9p.png` | 96×96 | 9p 28 |
| `battle/hud/notification_dot.png` | 40×40 | |

### 9.6 Meta screens

| File | Size | Notes |
|---|---|---|
| `meta/workshop/tab_attack.png` | 96×96 | category icons |
| `meta/workshop/tab_defense.png` | 96×96 | |
| `meta/workshop/tab_utility.png` | 96×96 | |
| `meta/workshop/tab_environment.png` | 96×96 | |
| `meta/workshop/upgrade_row_9p.png` | 96×64 | 9p 20/16 |
| `meta/workshop/track_icon_{damage,hp,crit,speed,economy,offline}.png` | 80×80 | shared track icons |
| `meta/magica/node_frame_{idle,active,done,locked}.png` | 200×200 | |
| `meta/magica/branch_bg_9p.png` | 96×96 | 9p 24 |
| `meta/magica/timer_pill_9p.png` | 96×48 | 9p 16/12 |
| `meta/cards/card_frame_common.png` | 300×420 | 9p 28 |
| `meta/cards/card_frame_rare.png` | 300×420 | |
| `meta/cards/card_frame_epic.png` | 300×420 | |
| `meta/cards/card_frame_legendary.png` | 300×420 | |
| `meta/cards/card_back.png` | 300×420 | |
| `meta/cards/card_slot_empty.png` | 300×420 | |
| `meta/cards/card_art_placeholder.png` | 256×256 | per-card art will be separate files later |
| `meta/shop/offer_card_9p.png` | 96×96 | 9p 24 |
| `meta/shop/ribbon_best_value.png` | 220×64 | |
| `meta/shop/icon_no_ads.png` | 96×96 | |
| `meta/shop/icon_starter_pack.png` | 96×96 | |
| `meta/missions/mission_row_9p.png` | 96×64 | 9p 20/16 |
| `meta/missions/mission_icon.png` | 88×88 | |
| `meta/leaderboard/row_9p.png` | 96×48 | 9p 16/12 |
| `meta/leaderboard/medal_{1,2,3}.png` | 80×80 | |
| `meta/leaderboard/rank_badge.png` | 64×64 | |
| `meta/settings/settings_row_9p.png` | 96×48 | |
| `meta/onboarding/input_9p.png` | 96×48 | nickname field |
| `meta/onboarding/avatar_frame.png` | 220×220 | 9p 24 |
| `meta/common/modal_9p.png` | 96×96 | 9p 28 |

**Totals:** roughly 240 files — every state variant is a separate image (8 enemies × 6–8 frames, 4 towers × 3 tiers, 4 nav items × 2 states, etc.). The generator prints the exact count from `docs/art_manifest.json`; that number is authoritative, this table is the human-readable mirror. Keep both in sync.

**Acceptance for this section:** the manifest is complete enough that a graphic designer can work through it top to bottom without asking a single question about sizes or names, and replacing every file with final art requires no code change.

### 9.7 Fonts

| File | Notes |
|---|---|
| `assets/fonts/display.otf` | chunky rounded display face, Latin + Cyrillic, 3 weights if possible |
| `assets/fonts/body.otf` | humanist sans, Latin + Cyrillic |

Until supplied, use the engine default font through theme variations named `Display` and `Body`, and the manifest lists these two paths so the swap is a file drop. **Cyrillic glyph coverage is mandatory** — check `ї`, `і`, `є`, `ґ` and `№` before accepting a font.

### 9.8 Theme structure

`ui/theme/main_theme.tres` with:

- type variations per widget family: `PrimaryButton`, `SecondaryButton`, `GoldButton`, `DangerButton`, `IconButton`, `TabButton`, `PanelGreen`, `PanelDark`, `PanelWood`, `ListRow`, `Chip`, `CurrencyPill`,
- font sizes: `display_l` 96, `display_m` 72, `title` 56, `body` 40, `body_s` 34, `caption` 28 (design px; the theme is authored at 1080 width),
- `StyleBoxTexture` per state referencing the manifest paths,
- focus/pressed/hover defaults so nothing looks broken with a keyboard or a mouse,
- a `text_scale` multiplier applied by `SettingsService` through a `Theme` duplicate at runtime.

No scene may define inline `StyleBox` colors for standard UI — everything through the theme, except battle-world drawing (range circles, health bars, path debug).

### 9.9 Audio

Buses: `Master` → `Music`, `SFX`, `UI`. Settings store 0–100 % per bus, applied with `linear_to_db` and a mute shortcut at 0.

Required files (placeholders generated by `tools/generate_audio_placeholders.py`, 16-bit mono WAV, 44.1 kHz, distinct pitches so each action is audibly different):

| Folder | Files |
|---|---|
| `assets/audio/music/` | `menu_theme.ogg` (60 s loop), `battle_theme.ogg` (90 s loop), `boss_theme.ogg` (60 s loop) |
| `assets/audio/ui/` | `ui_click.wav`, `ui_back.wav`, `ui_toggle.wav`, `ui_error.wav`, `ui_purchase.wav`, `ui_claim.wav`, `card_flip.wav` |
| `assets/audio/battle/` | `wave_start.wav`, `wave_clear.wav`, `boss_roar.wav`, `tree_hurt.wav`, `enemy_leak.wav`, `enemy_die.wav`, `hit_flesh.wav`, `hit_armor.wav`, `crit.wav`, `shoot_arrow.wav`, `shoot_cannon.wav`, `shoot_frost.wav`, `shoot_magic.wav`, `tower_build.wav`, `tower_upgrade.wav`, `tower_sell.wav`, `upgrade_buy.wav`, `run_defeat.wav` |
| `assets/audio/meta/` | `research_start.wav`, `research_complete.wav`, `coin_gain.wav`, `gem_gain.wav`, `level_up.wav` |

`AudioService`: max 16 concurrent SFX, 40 ms per-sound cooldown, ±5 % pitch randomization, music crossfade 0.8 s, duck music by −6 dB while a rewarded ad or a modal video plays, resume on focus. Music must not restart on scene changes (single `AudioStreamPlayer` with crossfade, owned by the autoload).

---

## 10. LOCALIZATION

- Engine: Godot CSV translations. One file: `localization/strings.csv` (`keys,en,uk`) imported as `strings.en.translation` / `strings.uk.translation`, registered in Project Settings → Localization.
- Every visible string uses `tr("key")`. Zero literals in `.tscn` labels (except `%` debug).
- Key format: `<screen>.<component>[.<state>]`, lowercase snake_case. Examples: `menu.battle`, `menu.best_wave`, `battle.wave_progress`, `battle.upgrade.damage.name`, `battle.upgrade.damage.desc`, `settings.music`, `shop.offer.gems_550.name`, `missions.daily.kills.title`.
- Content resources carry `name_key` / `desc_key`, never display text.
- Formatting: `LocaleService.format_number(n)`, `format_duration(seconds)` ("2г 15хв" / "2h 15m"), `format_percent`, `plural(n, "missions.kills")` with `missions.kills.one/few/many` for Ukrainian (1 / 2–4 / 5+ and 11–14 exception).
- Ukrainian is the default for `uk` devices, English otherwise. A language selector lives in Settings and in the first-launch flow; switching applies immediately without a scene reload.
- All UI layouts must tolerate +30 % string length (English or future Polish). Test with `Settings.debug.pseudo_locale` that appends `…` and doubles vowels.
- Numbers use non-breaking spaces for thousands in Ukrainian (`12 480`) and commas in English (`12,480`) — implemented centrally, not per screen.

---

## 11. ARCHITECTURE AND FOLDER STRUCTURE

### 11.1 Repository layout

```
the-tree--idle-td/
├─ project.godot
├─ export_presets.cfg
├─ icon.svg
├─ README.md                    # what this is, how to run, how to build
├─ CHANGELOG.md                 # milestone-level history
├─ .gitignore .gitattributes .editorconfig
├─ docs/
│  ├─ AI_BUILD_PROMPT.md        # this document
│  ├─ GDD.md                    # short design doc derived from this prompt
│  ├─ ARCHITECTURE.md           # service map, data flow, key decisions
│  ├─ ART_MANIFEST.md           # generated from art_manifest.json
│  ├─ art_manifest.json
│  ├─ BALANCE.md                # numbers, curves, tuning notes
│  ├─ DECISIONS.md              # adr-style log
│  └─ reference/                # approved UI screenshots (not shipped)
├─ scenes/
│  ├─ boot/boot.tscn
│  ├─ onboarding/first_launch.tscn
│  ├─ menu/main_menu.tscn
│  ├─ menu/workshop.tscn
│  ├─ menu/magica.tscn
│  ├─ menu/cards.tscn
│  ├─ menu/missions.tscn
│  ├─ menu/shop.tscn
│  ├─ menu/leaderboard.tscn
│  ├─ menu/settings.tscn
│  ├─ menu/profile.tscn
│  ├─ battle/battle.tscn
│  ├─ battle/run_summary.tscn
│  └─ battle/entities/{enemy,tower,unit,projectile,pedestal}.tscn
├─ scripts/
│  ├─ autoload/                 # the services listed in 8.1
│  ├─ battle/                   # BattleController, WaveManager, Spawner, LaneController, BattleClock
│  ├─ combat/                   # DamageResolver, Projectile, TargetingStrategy, StatusEffects
│  ├─ entities/                 # Enemy, Tower, Unit, Tree, Pedestal
│  ├─ data/                     # Resource classes: EnemyData, TowerData, ...
│  ├─ progression/              # WorkshopService, MagicaService, CardService, MissionService
│  ├─ economy/                  # WalletService, Rewards, CostCurve
│  ├─ ui/                       # screen scripts, widgets
│  ├─ platform/                 # Android ads/billing adapters, LocalStubBackend
│  └─ util/                     # Rng, Formatters, Pool, Signals
├─ ui/
│  ├─ theme/main_theme.tres
│  ├─ components/{primary_button,currency_label,list_row,modal,toast,...}.tscn
│  └─ shaders/{hit_flash,outline,glow_soft}.gdshader
├─ data/
│  ├─ enemies/*.tres
│  ├─ towers/*.tres
│  ├─ units/*.tres
│  ├─ tree/tree_base.tres  tree/upgrades/*.tres
│  ├─ cards/*.tres
│  ├─ waves/wave_table.tres
│  ├─ maps/forest_clearing.tres
│  ├─ workshop/*.tres
│  ├─ magica/*.tres
│  ├─ missions/templates.tres
│  └─ progression/levels.tres
├─ config/
│  ├─ env.tres  monetization.tres  shop.tres  remote_defaults.tres
├─ localization/strings.csv
├─ assets/{art,audio,fonts}/
├─ addons/                      # third-party plugins only (admob, billing, gut if used)
├─ tools/                       # placeholder generators, layout validator, balance simulator
└─ tests/                       # headless test runner + test cases
```

### 11.2 Scene composition rules

- **Composition over inheritance.** Base classes: `Entity2D` (position + status), `Tower`, `Enemy`, `Unit` — at most one level of inheritance below each. Behavior differences come from data + strategy objects (`TowerBehavior`, `TargetingStrategy`, `StatusEffect`), not subclasses per tower.
- Every battle entity is its own `.tscn` with a script on the root; children are `Sprite2D`/`AnimatedSprite2D`, `Area2D`, `CollisionShape2D`, `HealthBar`, `StatusComponent`, `Shadow`.
- Battle scene tree:

```
Battle (Node2D)
├─ Arena (Node2D)
│  ├─ Background (Sprite2D)
│  ├─ LaneNorth (Path2D → Curve2D from map data)
│  ├─ LaneSouth (Path2D)
│  └─ Pedestals (Node2D)  → 8 × Pedestal
├─ Tree (Node2D) → 4 × UnitSlot
├─ Enemies (Node2D, y_sort_enabled)
├─ Projectiles (Node2D)
├─ FX (Node2D)
├─ BattleHUD (CanvasLayer)
└─ BattleClock (Node)
```

- Y-sorting on `Enemies` and `Towers` parents so sprites overlap correctly.
- HUD is a separate `CanvasLayer` with `process_mode = ALWAYS` while the battle can pause.
- No `get_node("../../")`. Use `@export` node references, `%UniqueName`, or group lookups (`get_tree().get_first_node_in_group("tree")`) resolved once in `_ready`.

### 11.3 Signals

- Local, upward signals inside a scene: `signal upgrade_requested(track_id: StringName)`.
- Cross-system events: `EventBus` (typed signals, e.g. `wave_cleared(wave: int)`, `currency_changed(kind: StringName, amount: int)`), documented in one file. `EventBus` contains **no** logic.
- Never connect the same signal twice; connections to autoloads are made in `_ready` and disconnected in `_exit_tree` when the emitter is not an autoload.
- Signal names describe facts in the past tense (`wave_cleared`, `purchase_completed`); request methods are verbs (`request_upgrade()`).

### 11.4 Naming

| Kind | Convention | Example |
|---|---|---|
| Files & folders | `snake_case` | `wave_manager.gd`, `tower_sheet.tscn` |
| Classes | `PascalCase` | `class_name WaveManager` |
| Nodes | `PascalCase` | `LaneNorth`, `TreeHpFill` |
| Variables / functions | `snake_case` | `attack_interval`, `apply_damage()` |
| Constants / enums | `UPPER_SNAKE` | `MAX_TOWER_LEVEL` |
| Signals | `snake_case`, past tense | `enemy_died` |
| Resources | `<domain>_<name>.tres` | `enemy_grunt.tres` |
| Data ids | `snake_case` StringName | `&"frost_spire"` |

### 11.5 Data resource schemas (normative)

```gdscript
# scripts/data/enemy_data.gd
class_name EnemyData extends Resource

@export var id: StringName
@export var display_name_key: String
@export var sprite_frames: SpriteFrames
@export var max_hp: float = 60.0
@export var speed: float = 55.0
@export var armor: float = 0.0
@export var leak_damage_pct: float = 4.0       # % of tree max HP
@export var cash_reward: int = 4
@export var spawn_weight: float = 1.0
@export var is_boss: bool = false
@export var boss_bar_scale: float = 1.0
@export var sfx_death: AudioStream
@export var status_resistances: Dictionary = {}  # StringName -> float
@export var aura: AuraData                        # optional buff aura
```

```gdscript
# scripts/data/tower_data.gd
class_name TowerData extends Resource

@export var id: StringName
@export var display_name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var tier_textures: Array[Texture2D]      # 3 tiers
@export var build_cost: int = 60
@export var damage: float = 14.0
@export var attack_interval: float = 0.9
@export var range: float = 300.0
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 900.0
@export var splash_radius: float = 0.0
@export var targets: int = 1
@export var target_mode: StringName = &"first"   # TargetingStrategy id
@export var status_on_hit: StatusData            # optional slow/poison
@export var aura_modifiers: Array[Modifier]      # totem
@export var behavior_id: StringName = &""
@export var unlock_level: int = 1
```

```gdscript
# scripts/data/wave_table.gd
class_name WaveTable extends Resource
@export var waves: Array[WaveDefinition]
@export var boss_every: int = 10
@export var swarm_every: int = 5
@export var prep_time: float = 6.0

class_name WaveDefinition extends Resource
@export var index: int
@export var groups: Array[SpawnGroup]
@export var hp_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var cash_multiplier: float = 1.0
@export var is_boss: bool = false
@export var reward_bonus: int = 0

class_name SpawnGroup extends Resource
@export var enemy_id: StringName
@export var lane: StringName = &"north"     # north | south | both
@export var count: int = 5
@export var interval: float = 0.8
@export var start_delay: float = 0.0
```

Also defined the same way: `UnitData`, `CardData`, `UpgradeTrack`, `WorkshopTrack`, `MagicaNode`, `MissionTemplate`, `MapData`, `Modifier`, `StatusData`, `AuraData`, `LevelCurve`, `RewardBundle`, `ShopProduct`, `AdPlacement`.

`MapData` holds `pedestal_positions: PackedVector2Array`, `unit_slot_positions`, `lane_north_points`, `lane_south_points`, `arena_size: Vector2`, plus `background: Texture2D`.

### 11.6 Balance data

All numbers from sections 4 and 6 live in `.tres` files. `docs/BALANCE.md` mirrors them in tables with a "tuned on <date>" note. When you change a number, change the resource and the doc in the same commit.

---

## 12. CODING STANDARDS AND DOCUMENTATION

### 12.1 Code

- **Typed GDScript everywhere.** `func apply_damage(ctx: DamageContext) -> DamageResult:`. Untyped `Array`/`Dictionary` only at the JSON boundary, immediately converted to typed resources or classes.
- File header: a 2–4 line comment stating purpose, owner system, and key invariants.
- Order inside a script: `class_name`, doc comment, signals, enums, constants, `@export`s, public vars, `@onready`s, lifecycle (`_ready`, `_process`, `_input`), public methods, private methods, helpers.
- Functions ≤ 40 lines, files ≤ 400 lines. If it grows, extract a component or a service.
- `_process` only for visual interpolation. Gameplay ticks in `_physics_process` (or in `BattleClock` timers). Document the reason in a comment when `_process` is used.
- Allocation-free hot paths: cache node refs, avoid `PackedScene.instantiate()` per shot (pool), avoid `String` formatting per frame.
- `assert()` for invariants in debug; `push_error()` with a context dictionary for recoverable failures; `App.log_warn()` for expected degradations (offline, ad unavailable).
- No comments that restate the code. Comments explain trade-offs, invariants, and "why".
- No `TODO` without an owner and a milestone: `# TODO(M3): support tower selling refund cap`.
- Every service exposes a small, mockable interface. Time, RNG, network, ads, billing and storage are injected or accessed through the service, never called statically inside gameplay code (`Time.get_unix_time_from_system()` is allowed only inside `TimeService`).

### 12.2 Documentation deliverables (must exist and stay current)

| File | Content |
|---|---|
| `README.md` | what the game is, how to open/run, how to export to Android, where things live, what works today |
| `docs/ARCHITECTURE.md` | service map, boot order, data flow of a single damage event, save/load flow, add-a-tower walkthrough |
| `docs/BALANCE.md` | all curves and tables, tuning history |
| `docs/DECISIONS.md` | ADR list: context → decision → consequences (date each) |
| `docs/GDD.md` | concise design doc derived from this prompt (one page per system) |
| `docs/ART_MANIFEST.md` | generated; never hand-edited |
| `docs/QA_CHECKLIST.md` | manual test pass per milestone |
| `CHANGELOG.md` | one entry per milestone |

**"Add a new tower" walkthrough** must be true and short: create a `.tres`, add a scene, add an icon to the manifest, register it in the build list. If the walkthrough requires touching more than three gameplay files, the architecture is wrong — fix the architecture.

### 12.3 Error handling and degradation

- Services that can fail (ads, billing, network, save) return typed results and never throw. The UI shows a toast and stays interactive.
- Boot never blocks for more than 3 s; slow services (ads) initialize in the background after the menu is visible.
- Every `await` on a network/plugin call has a timeout.
- A crash must be caught where possible (`error` signal on `HTTPRequest`, `OS` low-memory), logged, and the game must return to the menu instead of freezing.

---

## 13. UI SPECIFICATION PER SCREEN

All screens: portrait, safe-area aware, header 160 px tall with back button and title, content scrolls if needed, bottom padding ≥ 40 px. Backgrounds use the menu background art at 60 % brightness behind panels.

### 13.1 Boot

Black → logo fade-in (0.8 s) → service init progress (thin bar) → route to `FirstLaunch` (if `!onboarded`) or `MainMenu`. Never longer than 2.5 s on a mid device. Shows the app version in the corner (debug builds also show the commit hash if available).

### 13.2 First launch

Steps in one screen or three pages (wizard): language → nickname + avatar → "Play". Nickname validation inline, avatar grid 3×2, CTA disabled until valid. Includes "You can change this later in Settings". Stores the profile, sets `onboarded`, syncs to server when online.

### 13.3 Main menu (target: `docs/reference/ui_main_menu.png`)

Top: coin pill + `+`, gem pill + `+`, settings gear. Center: logotype over the tree, then a stats card (best wave, player level with XP bar, avatar). Then the primary `Battle` CTA, the `Speed Trial` bar (ad/level offer), then the `Daily Missions 0/3` card with `View`. Bottom: 5-tab navigation (Home, Upgrades, Cards, Missions, Shop) — active tab highlighted, notification dots from services.

`Battle` starts the run immediately at the selected speed; if a rewarded speed offer is active, show it as a secondary bar, not a blocker.

### 13.4 Battle

As specified in 4.11. Additional requirements:

- Tower/unit build sheets are bottom sheets with a drag-to-dismiss handle and a scrim; the game pauses (`process_mode` on battle systems) while a sheet is open, except the wave timer continues? **Decision: pause the simulation**, but the wave timer freezes too. Document it.
- The sheet lists towers as cards with icon, name, cost, one-line role, and a disabled state with a reason ("Not enough cash", "Locked until level 7").
- Upgrade sheet: current level, `Lv 3 → 4` preview with green deltas, cost, buy button with affordability state, hold-to-repeat, and the tower's range circle highlighted while open.
- Boss bar replaces the wave bar; it shows boss name, HP, and armor icon.
- On tree HP < 30 %: red vignette pulse, heartbeat SFX, and the HP bar shakes.
- On wave clear: 0.6 s banner ("Wave 5 cleared +120 cash") + coins fly to the cash counter (pooled particles or tweened icons).
- "Next wave in 6…" countdown is visible and skippable.

### 13.5 Run summary

Dark scrim over the frozen battlefield. Panel: "Run over" / "Wave 18", stats rows (waves, kills, damage, time), reward rows with count-up animation (coins, gems, XP), "NEW BEST" ribbon if applicable, a rewarded "Double coins" button (one per run), and `Continue`. Must never block progress if the ad fails.

### 13.6 Workshop

Header with coin balance. Four category tabs (Attack, Defense, Utility, Environment) with icons. Vertical list of track rows: icon, name, `Lv 12/50`, current → next, cost, buy. Sticky footer "Buy max" (long-press). Insufficient funds: button dimmed + shake on tap + "Need 320 more coins" toast. All purchases confirm with a sound and a value flash; no confirmation dialog (too slow) except for gem purchases.

### 13.7 Magica

Three branch columns/rows with node graphs, connectors drawn with `Line2D`. Node states: locked (prereq missing, tap explains), available, researching (radial timer + remaining time), done. One active research at a time. Top card shows the active research with "Speed up (AD)" and "Cancel". Completed nodes get a check and their effect listed in a summary panel ("+10 % research speed").

### 13.8 Cards

Top: 4 equip slots (locked slots show the unlock condition). Collection grid below with filters (All / rarity / owned), sort (new, rarity, level). Card detail modal: art, rarity frame, effect text with live numbers, level and shards progress, `Upgrade` (costs shards), `Equip` / `Unequip`, and a "where to get" line. Equipping into a full set asks which slot to replace. Card effects update `ModifierService` immediately; a small "stats" summary shows total bonuses.

### 13.9 Missions

Two sections (Daily with reset countdown, Weekly with reset countdown). Row: icon, title, progress bar `120/300`, reward chips, `Claim` button when complete. "Claim all" when ≥ 2 complete. Completed rows collapse to a claimed state. A footer note explains the reset time in local time.

### 13.10 Shop

Tabs: `Gems`, `Coins`, `Special`. Grid of offer cards (2 columns): art placeholder, title, contents, bonus badge, price button. `No ads` and `Starter pack` appear in Special. A restore-purchases text button at the bottom. IAP disabled state shows "Store unavailable" instead of a broken button (desktop builds, no Play Services).

### 13.11 Leaderboard

Tabs: Weekly / All-time / Tournament. Header with the player's own rank pinned. Rows: rank, avatar, nickname, best wave, medal for top 3. Pull-to-refresh, offline banner with cached data and "last updated" time. Empty state explains that the first run will place the player.

### 13.12 Settings

Sections: Audio (music, SFX, UI sliders), Game (language, text scale, screen shake, haptics, damage numbers, FPS counter in debug), Account (nickname, player ID with copy, restore/connect later), Legal (privacy policy link, terms, ad consent), Support (version, contact). Sliders apply live. A "Reset progress" button (double confirm, typed word) exists in debug only.

---

## 14. TESTING, QA AND PERFORMANCE

### 14.1 Automated checks (must run headless, no display)

- `tools/check_project.ps1`: runs `godot --headless --path . --quit` and fails on any script parse error (grep stderr for `SCRIPT ERROR`/`Parse Error`), missing resources, or import errors. Run after every milestone and before every commit that touches scenes/resources.
- `tests/run_tests.gd` (`godot --headless --script res://tests/run_tests.gd`): a tiny custom runner (`test_*` methods, colored output, non-zero exit on failure). Cover at minimum:
  - damage resolver: armor floor, crit, multipliers, true damage,
  - cost curves: monotonic, integer, level caps,
  - wallet: no negative balances, transaction rollback,
  - save: round-trip, checksum failure → backup, migration v1→vN,
  - modifier aggregation: cards + workshop stacking and caps,
  - wave table: every wave references existing enemies, lanes valid, boss cadence,
  - mission progress: idempotent increments, claim once,
  - localization: every key used in `.tscn`/`.gd` exists in the CSV (a simple key extractor test),
  - asset manifest: every path referenced by a scene exists on disk.
- `tools/validate_layout.gd`: pedestal/lane clearance, slots inside arena, safe-area overlap.
- `tools/simulate_run.gd --runs=200 --profile=new|mid|max`: headless bot that plays waves with a simple heuristic (buy the cheapest affordable upgrade, build towers in order) and prints the wave distribution. Target: new player 8–12, ~3 h player 25–35, maxed 45+. Tune data until it matches; record results in `docs/BALANCE.md`.

### 14.2 Manual QA (per milestone, `docs/QA_CHECKLIST.md`)

- Cold start ≤ 5 s on LDPlayer, ≤ 3 s on a real device.
- Battle: 60 FPS with 80 enemies + 8 towers; check with the debug overlay (`F3`: FPS, entity counts, draw calls).
- Touch: every button reachable one-handed; no double-tap purchases; hold-to-buy does not overspend.
- Save: force-close during a run, reopen → meta progress intact, no corruption.
- Offline: airplane mode → all screens usable, ads/billing show graceful states, save sync queues.
- Language switch mid-screen: no missing glyphs, no layout overflow.
- Background/foreground during battle: simulation pauses, audio resumes, no timer desync.
- Android back button: closes modals first, then opens the pause menu, never exits mid-run without confirmation.

### 14.3 Performance rules

- Profile with the engine's monitor before optimizing; write numbers in `docs/BALANCE.md` or a perf note.
- Enemy update cost must be O(1) per enemy per tick (no group scans per frame). Targets are found via a spatial hash updated on spawn/despawn.
- Projectiles use simple `move_toward` + distance checks, not physics bodies, unless homing requires it.
- Audio: no more than 16 simultaneous players; reuse a pool.
- Textures: atlases for UI icons (one atlas per screen family) to cut draw calls; keep individual files as source, pack on export if needed.
- No per-frame `tr()` calls in `_process` — cache localized strings on language change.

---

## 15. MILESTONES

Work strictly in order. After each milestone: run the checks, update docs, commit, and report a short summary with what works, what is stubbed, and the next milestone's first task.

### M0 — Foundation (project hygiene and skeleton)

**Goal:** the project opens clean, boots into a placeholder menu, has the full folder skeleton, theme, and placeholder pipeline.

Tasks:

1. Create the folder structure from section 11.1 with `.gdignore` where needed and `README.md` placeholders.
2. Implement autoload skeletons with documented interfaces: `EventBus`, `App`, `SceneRouter`, `SettingsService`, `LocaleService`, `AudioService`, `SaveService`, `GameState`, `RunState`, `ModifierService`, `TimeService`, `RngService`.
3. `Boot` scene → fade → `MainMenu` placeholder with a working `Battle` button that routes to an empty battle scene.
4. `ui/theme/main_theme.tres` with type variations and placeholder styleboxes; `ui/components/` with `PrimaryButton`, `Panel`, `CurrencyPill`, `Modal`, `Toast`, `ProgressBar`.
5. `docs/art_manifest.json` (all entries from section 9), `tools/generate_placeholders.gd`, generate the assets, verify count.
6. `tools/check_project.ps1` + `tests/run_tests.gd` with 3 trivial tests.
7. `.gitignore` verified: `.godot/`, `android/`, `build/`, `*.apk`, `*.aab`, `export_credentials.cfg`, `.vscode/`, `*.log`. `.gitattributes` for LF and binary art.
8. `README.md` with run/export instructions, `docs/DECISIONS.md` with the first 3 ADRs (mobile renderer, 1080×1920 expand, data-driven resources).

**Acceptance:** no console errors on boot; every manifest entry has a placeholder PNG (the generator reports `created = total, failed = 0`); F5 → menu → battle → back works; tests pass; `docs/ART_MANIFEST.md` generated.

### M1 — Battle vertical slice

**Goal:** one playable run, ugly but correct.

Tasks: arena + background + lanes from `MapData`; tree with HP and auto-attack; 8 pedestals; build/upgrade/sell Archer Tower; one enemy type (`grunt`) following both lanes; spawner + `WaveManager` reading a 10-wave table; leak damage; cash rewards; wave banner and countdown; defeat → run summary with coin payout → menu; battle HUD minimum (wave, cash, tree HP, upgrade button).

**Acceptance:** a run can be started and lost; enemies follow the paths without jitter; towers kill enemies; cash math matches the spec; waves 1–10 have increasing difficulty; summary grants coins once; no errors in the console; 60 FPS on LDPlayer with 40 enemies.

### M2 — Combat depth

**Goal:** the full launch combat vocabulary.

Tasks: 4 enemy types + boss, 4 towers with tiers and level-5 behaviors, 3 guardian units + 4 slots, damage resolver with crit/armor, status effects (slow), targeting strategies, projectiles with pooling, hit flash, damage numbers, death FX, y-sorting, spatial hash targeting, boss bar, swarm/boss wave cadence, screen shake.

**Acceptance:** every tower and unit is buildable and upgrades to level 10; crit and slow are visible and correct per the formulas; 120 enemies run at ≥ 55 FPS; bosses appear at waves 10/20/30 with a banner; no leaks of node references after 20 minutes of play (memory stable).

### M3 — Run economy, upgrades, speed

**Goal:** the in-run decision space is complete.

Tasks: tree in-run upgrade tracks (damage, attack speed, crit chance, crit damage, range, regen), unit placement and upgrades, hold-to-buy with transaction safety, "next wave" cash bonus, speed control 1x/1.5x/2x with lock states, pause menu (resume/restart/abandon/settings), full run summary with rewards and double-coins ad hook (stubbed), run debug panel.

**Acceptance:** a skilled player can reach wave 15+; upgrading changes DPS measurably (verify with a test that computes expected DPS); speed 2x does not break wave timing; pause/resume does not duplicate spawns; abandoning grants the same rewards as dying at that wave.

### M4 — Meta progression and persistence

**Goal:** progress survives restarts and screens are data-driven.

Tasks: save schema + migration + atomic write + backup; wallet service with transaction log; XP/levels and unlocks; Workshop screen with 24 tracks; Magica with 12 nodes, real-time research and offline completion; Cards (12 cards, 4 slots, shards, upgrade); Missions (daily/weekly generation, progress, claim, reset); offline income calculation on boot; `ModifierService` integration with battle.

**Acceptance:** close the app during research, reopen after the timer → completed; Workshop purchase persists and changes battle stats (verified by a test that compares a run's starting DPS); card equip changes the same stats; missions reset at 04:00 local; corrupted save recovers from backup; fresh profile can complete onboarding and reach wave 10 with no meta upgrades.

### M5 — Shell, UX, localization, audio

**Goal:** the game looks and sounds like a product, with placeholders.

Tasks: main menu per reference; navigation and routing with transitions; settings screen (audio, language, text scale, haptics, shake); onboarding wizard; shop UI with stub products; leaderboard UI with local stub data; profile; full uk/en strings; audio service with music crossfade and all SFX hooks; toasts, modals, loading states; empty/error states; notifications dots.

**Acceptance:** every screen is reachable and back-navigable; language switch is instant; all placeholder art is used and no `ColorRect` masquerades as UI; audio settings persist; no untranslated strings (key extractor test passes); first-launch flow works on a clean save.

### M6 — Android, ads, billing, telemetry

**Goal:** a real APK on LDPlayer, with monetization.

Tasks: Android export presets (debug + release), keystore instructions, `adb install` helper script; AdMob plugin + adapters + deterministic desktop stub; rewarded placements wired (double coins, free cash, blessing, speed 24 h, research speed-up); interstitial caps; consent (UMP) gate; Play Billing plugin + products + restore + grant flow + failure states; analytics events; safe-area and notch handling; haptics; app lifecycle (pause/resume/back).

**Acceptance:** APK installs on LDPlayer, runs 60 FPS, back button behaves; rewarded ad grants exactly one reward and survives app kill mid-ad; purchase grants once and restores after reinstall (test products); no crashes with Play Services disabled; analytics events logged in debug console.

### M7 — Backend (FastAPI + Neon) and live features

**Goal:** accounts, cloud saves, leaderboard, tournaments.

Tasks: `server/` FastAPI app, models, migrations, auth, save sync with conflict resolution, remote config, leaderboard endpoints, tournament endpoints + anti-cheat validation, purchase verification stub, OpenAPI docs, docker-compose, seed script; client: `ApiClient` integration, offline queue, sync UI states, leaderboard and tournament screens against the real API, weekly reset handling.

**Acceptance:** two devices with the same account see the same progress; offline changes sync on reconnect without data loss; leaderboard returns the player's rank; a fake run with impossible stats is rejected; weekly reset moves entries to the previous week; server runs locally with one command.

### M8 — Balance, polish, release readiness

**Goal:** shippable vertical slice.

Tasks: balance simulation to hit the wave targets; difficulty curve pass; juice pass (hit-stop, camera punch, particle polish); first-run tutorial hints (3 tooltips); performance pass with profiling notes; store listing assets (icon, screenshots, feature graphic placeholders); version/build numbering; privacy policy and data safety checklist; crash reporting hook; release checklist doc.

**Acceptance:** simulation matches targets; first 10 minutes have no dead ends; no crash in a 30-minute session; APK < 60 MB; release build runs with production-like config in airplane mode; `docs/RELEASE.md` checklist fully green.

### Phase gate (applies to every milestone)

- [ ] `tools/check_project.ps1` passes.
- [ ] `tests/run_tests.gd` passes.
- [ ] No new warnings in the Godot console on boot.
- [ ] Docs updated (`ARCHITECTURE.md`, `BALANCE.md`, `CHANGELOG.md`).
- [ ] Manual QA checklist for the milestone filled in.
- [ ] Commit(s) created with the milestone prefix.
- [ ] A 5-line summary written for the human: what works, what is stubbed, known issues, next task.

---

## 16. GIT WORKFLOW

- Default branch `main`, protected by convention (no direct pushes after M3; use branches).
- Branch per milestone: `feat/m1-battle-slice`, `feat/m2-combat-depth`, … Bug fixes: `fix/<short-slug>`.
- Conventional Commits: `feat(battle): add wave manager`, `fix(save): handle corrupt checksum`, `chore(deps): add admob plugin`, `docs(art): regenerate manifest`, `test(combat): cover armor floor`.
- Commit small and often (a working state each time). Never commit a broken boot.
- Tags at the end of each milestone: `v0.1.0-m1`, `v0.2.0-m2`, …, `v1.0.0-m8`.
- `.gitignore` must exclude: `.godot/`, `android/`, `build/`, `*.apk`, `*.aab`, `*.keystore`, `*.jks`, `export_credentials.cfg`, `user://`-like local files, `.vscode/`, `.idea/`, `*.log`, `*.tmp`.
- Commit `.import` files (Godot needs stable UIDs); commit `export_presets.cfg` **only** if it contains no secrets.
- Use Git LFS if any single asset exceeds 5 MB; placeholders are flat-color PNGs and must stay tiny (< 5 KB each).
- PR description template: what changed, how to test, screenshots for UI changes, checklist from the phase gate.
- `CHANGELOG.md`: `## [0.2.0] - M2 Combat depth` with bullet points and a "known issues" line.

---

## 17. WORKING PROTOCOL FOR THE AI

### 17.1 At the start of a milestone

Reply with, in this order:

1. A 5–8 bullet plan.
2. The exact list of files you will create or modify (paths).
3. Any blocking question — maximum 3, each with a proposed default so work can continue.
4. Then start implementing, beginning with data/resources and services, UI last.

### 17.2 While implementing

- One logical unit per message: a service, a resource set, a scene + its script. Do not dump 15 files at once.
- **Full file contents**, no `...` ellipses, no "rest unchanged" (unless the human explicitly says to patch). Every file must be complete and runnable.
- After each file batch: what it does, what depends on it, what is still missing.
- If a file is too large for one message, split it at a clean boundary and say so.
- Never claim something works unless you ran the headless check (if you have tool access) or clearly mark it as unverified.
- If the human's request conflicts with this document, point to the section and ask which wins.

### 17.3 At the end of a milestone

Deliver:

- Summary of what was built (bullets).
- How to verify manually, step by step, on LDPlayer.
- Known limitations and stubs.
- Test/check results.
- Suggested commit message and branch name.
- The first 3 tasks of the next milestone.

### 17.4 Style of answers

- Concise, technical, no marketing language.
- Code blocks with the file path as the first line comment.
- Tables for parameter lists; prose only where it adds meaning.
- If you must choose, prefer the simplest solution that satisfies the spec and document the trade-off.

### 17.5 When you are unsure

- Godot API uncertainty → check the docs for the exact version; if you cannot, write an adapter with a clear `# VERIFY:` comment and a stub, and tell the human.
- Plugin uncertainty → do not guess imports; isolate behind an interface and provide the integration checklist.
- Balance uncertainty → implement the spec numbers, add a tunable resource, and note it in `docs/BALANCE.md`.

### 17.6 Session protocol inside an agent harness (DeepSeek Harness, Claude Code, Cursor)

Long autonomous sessions fail in a predictable way: the agent forgets a constraint, re-reads files, and starts "refactoring" finished code. Prevent it structurally:

1. **One session = one milestone brief.** Open a fresh session per milestone (`docs/milestones/M<N>.md`). Do not chain milestones in one conversation.
2. **The spec stays on disk.** Never paste this document into the chat; read only the sections the brief lists, via `grep` + `read` with an offset.
3. **Persistent state lives in files**, not in the conversation: `docs/PROGRESS.md` (status + handoff), `docs/DECISIONS.md`, `CHANGELOG.md`, git history.
4. **The session ends with a handoff, not with a summary.** If the milestone is not finished, write the handoff block (`state`, `last green commit`, `files in flight`, `next command`) and start a new session from it.
5. **A red check blocks progress.** `tools/check_project.ps1` and `tests/run_tests.gd` run after every batch; "it should work" is not a report.
6. **Delegate noise.** Wide exploration (finding usages, auditing files, reading plugin docs) goes to a subagent whose context is disposable; only the 10-line result comes back.
7. **Budget:** the full spec is ~24k tokens; one brief plus its sections is ~6–10k. If a session needs more than four spec sections, the brief is wrong — split the milestone.

---

## 18. FORBIDDEN PRACTICES

1. **No prototype shortcuts that become architecture**: no giant `battle.gd` (800+ lines), no game logic in UI scripts, no `get_node("../../")`, no global state hidden in scenes.
2. **No hardcoded balance numbers** in gameplay code, no hardcoded UI strings, no hardcoded screen coordinates outside `MapData`/theme.
3. **No dependence on a plugin for the game to boot.** Ads, billing and network must degrade to stubs.
4. **No `Engine.time_scale`** for the speed feature; no pausing via `get_tree().paused` without setting `process_mode` on the HUD and autoloads deliberately.
5. **No coroutine-driven game loop** (`while true: await ...`) for waves, spawning, or timers.
6. **No per-frame allocations** in enemies, projectiles, or damage labels; no `instantiate()` per projectile.
7. **No silent data loss**: never reset a save without a backup, never overwrite progress on a migration failure.
8. **No fake completion**: an empty screen, a button that does nothing, or a `TODO` in place of required behavior is not "done". Stubs must be explicit, labeled `STUB(Mn)`, and listed in the milestone summary.
9. **No unlicensed assets** committed to the repo. Placeholders are generated by our own script.
10. **No secrets in git**: no keystores, no API keys, no production ad unit IDs, no service account JSON.
11. **No dependency bloat**: every addon must be justified in `docs/DECISIONS.md` with a version and a fallback plan.
12. **No dark patterns**: no forced interstitials on launch, no ad before wave 5, no timers that can only be skipped by paying, no paywalled core content in the first 20 waves.

---

## 19. APPENDIX

### 19.1 Canonical IDs

Enemies: `grunt`, `runner`, `tank`, `shaman`, `boss_troll`.
Towers: `archer_tower`, `cannon`, `frost_spire`, `totem`.
Units: `unit_archer`, `unit_mage`, `unit_druid`.
Currencies: `cash`, `coins`, `gems`, `stones`.
Lanes: `north`, `south`.
Targeting: `first`, `last`, `closest`, `strongest`, `random`.
Ad placements: `run_double_coins`, `free_cash`, `tree_blessing`, `speed_unlock_24h`, `research_speedup`, `run_end_interstitial`.
Scenes: `boot`, `first_launch`, `main_menu`, `battle`, `run_summary`, `workshop`, `magica`, `cards`, `missions`, `shop`, `leaderboard`, `settings`, `profile`.

### 19.2 Glossary

- **Run** — one battle attempt from wave 1 until the tree dies.
- **Wave** — one authored group of spawns; clearing it grants cash and coins.
- **Pedestal** — one of 8 build spots around the tree.
- **Unit slot** — one of 4 spots on the canopy for guardian units.
- **Leak** — an enemy reaching the tree; deals percentage damage to the tree's max HP.
- **Meta** — everything that persists between runs (coins, gems, workshop, magica, cards).
- **Idle** — progress accrued while the app is closed (research, offline coins).

### 19.3 First-run acceptance scenario (use it as the definition of "playable")

1. Fresh install → boot → language → nickname "Test" → avatar → menu.
2. Tap Battle → wave 1 starts → 8 grunts walk in from the north lane.
3. Build an Archer Tower on the nearest pedestal → it shoots → enemies die → cash +4 each.
4. Wave 3 → place a unit in slot 1 → it shoots too.
5. Wave 5 → upgrade tree damage twice → enemies die faster (visible).
6. Wave 12 → the tree falls → summary shows 11 waves, coins, XP → coins are added to the wallet.
7. Open Workshop → buy "Tree Damage" → return to menu → start a new run → the tree hits harder.
8. Kill the app, reopen → nickname, wallet, workshop level and best wave are intact.

If any step fails, the build is not playable, regardless of how many other features exist.

### 19.4 What "done" means for the whole prompt

A build where a new player can install the APK, play a run, lose, spend coins, upgrade, come back stronger, watch an ad for a bonus, buy a gem pack in a test environment, see their name on a leaderboard served by the FastAPI backend, and where a developer can add a new tower in under 30 minutes by editing three data files — without touching gameplay code and without breaking anything else.

---

*End of specification. Start with Milestone 0, section 15. If something here is ambiguous, ask before coding; if something is missing, propose an addition in `docs/DECISIONS.md` and continue.*
