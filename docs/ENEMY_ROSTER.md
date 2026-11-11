# ENEMY ROSTER

Every enemy in the game, where it comes from and whether it actually spawns.
Source of truth is `data/enemies/*.tres`; this table is the designer's view.

**Status legend:** `live` — spawns in the wave table and its mechanic works.

## Launch roster (M2–M8)

| ID | UA | EN | HP | Speed | Armor | Leak % | Coins | Scale | Role | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| `grunt` | Гоблін | Grunt | 60 | 55 | 0 | 4 | 4 | 1.00 | Масовка | live |
| `runner` | Бігун | Runner | 40 | 95 | 0 | 3 | 4 | 0.86 | Швидкий прорив | live |
| `tank` | Танк | Tank | 220 | 40 | 5 | 8 | 8 | 1.05 | Стіна | live |
| `shaman` | Шаман | Shaman | 90 | 50 | 2 | 5 | 7 | 1.00 | Аура +20 % швидкості, r=140 | live |
| `boss_troll` | Троль-охоронець | Troll Warden | 1800 | 35 | 10 | 25 | 60 | 1.00 | Бос | live |

## Ported from the 20.10.2026 build

Old build: `_backup/The_Tree-ITD-master_2026-10-20_1544.zip`, `data/enemies/*.tres`.
The old model had flat `damage` (against a 1000 HP Tree), `radius` in px and
`coins`. The new model has `leak_damage_pct` (percent of max HP), `scale` and
`cash_reward`, so HP / speed / armor are ported **unchanged** and only the Tree
damage, cash and sprite scale are re-expressed:

- `leak_damage_pct` — rebalanced to the new table's scale (grunt 4 %, tank 8 %),
  not a literal `damage / 1000`.
- `cash_reward` — old coins × ~0.45, so the economy stays in the new band.
- `scale` — old radius ÷ 22 px (the old grunt's radius = scale 1.0).

| ID | UA | EN | HP | Speed | Armor | Leak % | Coins | Scale | Role | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| `raider` | Наїзник | Raider | 120 | 80 | 1 | 6 | 6 | 1.18 | Швидка кавалерія з бронею | live |
| `wyvern` | Вершник на віверні | Wyvern Rider | 90 | 70 | 0 | 5 | 7 | 1.09 | Повітряний, швидкий | live |
| `ram` | Таран | Ram | 400 | 28 | 5 | 12 | 11 | 1.55 | Облога: дуже живучий, великий leak | live |
| `thrower` | Списометальник | Spear Thrower | 70 | 45 | 0 | 5 | 4 | 1.00 | Дальній бій: 320 px, 1.5 %/2.4 с | live |
| `mage` | Чаклун | Warlock | 55 | 40 | 0 | 6 | 5 | 0.91 | Дальній бій: 340 px, 2.0 %/3.0 с | live |
| `trebuchet` | Требушет | Trebuchet | 260 | 20 | 2 | 12 | 13 | 1.45 | Артилерія: 520 px, 3.0 %/4.5 с | live |

### Where they spawn

`tools/generate_wave_table.gd` carves each specialist out of the existing
grunt/runner pool (a grunt first, then a runner), so the tuned
`5 + floor(0.8 × wave)` count never changes and at least 2 mass units stay in
every wave. `ram` replaces a tank instead.

| Enemy | From wave | Takes | HP added to the wave budget |
|---|---|---|---|
| `raider` | 8 | 1 grunt or runner | +60 base |
| `thrower` | 9 | 1 grunt or runner | +10 base |
| `wyvern` | 12 | 1 grunt or runner | +30 base |
| `mage` | 16 | 1 grunt or runner | −5 base |
| `ram` | 20 | 1 tank | +180 base |
| `trebuchet` | 24 | 1 grunt or runner | +200 base |

Boss waves (every 10th) and swarm waves (every 5th) keep their original mix.

## How the ranged attack works

Data (`data/enemies/*.tres`, `scripts/data/enemy_data.gd`):

| Field | Meaning |
|---|---|
| `attack_range` | px along the lane where the enemy stops. `0` = walker |
| `attack_interval` | seconds between shots |
| `attack_damage_pct` | % of the Tree's max HP per hit |
| `attack_projectile` | sprite that flies to the Tree |
| `attack_projectile_speed` | px/s, drives the flight time |
| `attack_sfx` | launch sound id (`AudioBus.play_sfx_id`) |

Flow:

1. `Enemy` stops once `lane_length - progress <= attack_range` and counts down
   the interval; it emits `ranged_shot` and **never leaks** — a ranged enemy wins
   by chipping the Tree, not by touching it.
2. `EnemyManager` forwards the signal; `BattleController` owns an 8-sprite pool,
   the flight (scaled by the battle clock, so pause and 2× work), the impact FX
   and the Tree damage.
3. Damage goes through `TreeEntity.receive_leak()`, so the meta
   `damage_reduction` / `leak_damage_reduction` modifiers and the `tree_hurt` SFX
   apply exactly as they do for a leak — one HP path, not two.
4. `ranged_shots_fired()` / `ranged_hits_landed()` expose counters for tools.

Gates: `test_ported_enemy_roster` (data + every port spawns),
`test_ranged_attack_window` (pure geometry and profile sanity) and
`tools/ranged_probe.gd`, which boots the real battle at wave 9 and proves a shot
is fired, lands, and costs the Tree HP. `battle_smoke` covers the walker side.

## Not ported yet

`orc_airship` (the old build's even-wave boss, 2200 HP, summons wyvern riders).
A second boss needs a rotation in `BattleController`/`WaveManager`; it is scoped
as a separate feature rather than smuggled in as another enemy row.
