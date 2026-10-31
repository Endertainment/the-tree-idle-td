# BALANCE — launch values, mirrored from data resources

**Tuned on:** 2026-10-31 (M1)
**Source of truth:** the `.tres` files under `res://data/`; this document mirrors
them for review. When a number changes, change the resource and this table in the
same commit.

## Tree (`data/tree/tree_base.tres`)

| Stat | Value |
|---|---|
| Max HP | 1200 |
| Damage | 12 per shot |
| Attack interval | 1.10 s |
| Range | 640 px |
| Projectile speed | 900 px/s (homing) |
| Crit chance / multiplier | 5 % / 2.0x |

## Enemies (`data/enemies/enemy_grunt.tres`)

| ID | HP | Speed | Armor | Leak (% of tree max HP) | Cash |
|---|---|---|---|---|---|
| `grunt` | 60 | 55 | 0 | 4 % | 4 |

Scaling per wave `w` is applied by `WaveManager` from the wave table:
HP `1.16^(w-1)`, speed `min(1 + 0.01*(w-1), 1.40)`, cash `1.09^(w-1)`.

## Towers (`data/towers/tower_archer.tres`)

| Tower | Cost | Damage | Interval | Range | Projectile |
|---|---|---|---|---|---|
| Archer Tower | 60 cash | 14 | 0.90 s | 300 px | arrow, 900 px/s |

M1 caps towers at level 1; `Tower.upgrade()` returns false until M3.

## Waves (`data/waves/wave_table_m1.tres`)

10 authored waves. Count = `6 + floor(1.2*w)`, capped at 30; wave 5 is a swarm
(4 groups, 0.45 s cadence); wave 10 doubles the count (36). Waves are split
across the north and south lanes.

| Wave | Count | HP multiplier | Cash multiplier |
|---|---|---|---|
| 1 | 7 | 1.000 | 1.000 |
| 2 | 8 | 1.160 | 1.090 |
| 3 | 9 | 1.346 | 1.188 |
| 4 | 10 | 1.561 | 1.295 |
| 5 (swarm) | 12 | 1.811 | 1.412 |
| 6 | 13 | 2.100 | 1.539 |
| 7 | 14 | 2.436 | 1.677 |
| 8 | 15 | 2.826 | 1.828 |
| 9 | 16 | 3.278 | 1.993 |
| 10 (double) | 36 | 3.803 | 2.172 |

## Economy

- Starting cash: **50** (`WaveTable.starting_cash`).
- Kill reward: `round(enemy.cash_reward * wave.cash_multiplier)`.
- Wave clear: `20 + 5*wave` (ADR-004).
- Prep skip: `min(10 + 2*wave, 120)`.
- Run summary: coins `sum(8 + 2*wave)` over cleared waves, gems
  `floor(cleared / 5)`, XP `10 * cleared`. Total coins for `n` waves = `n² + 9n`.
- Run cash is lost; coins, gems, XP and best wave persist.

## Layout (`data/maps/forest_clearing.tres`)

- Arena 1080×1920; pedestal ring radius 330 at 45° steps (8 positions).
- Unit slots radius 165 around (540, 900) at 45°, 135°, 225°, 315°.
- Lanes: 7 authored points each, entry (250, 240) / (830, 1740), both end at the
  trunk. Minimum sampled lane-to-pedestal clearance: 118.4 px (target ≥ 110).

## M1 performance note

Desktop probe (RTX 3050 laptop, vsync off): 47 enemies + 8 Archer Towers ran at
> 60 FPS (uncapped average ~1740 FPS over 5 s), projectiles pooled (12 instances,
  no per-shot allocation). LDPlayer FPS is not measured yet; it is an M2
  acceptance item together with 120 enemies.
