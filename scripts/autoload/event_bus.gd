## EventBus — typed global signal bus (autoload).
##
## Contains no logic by design. Systems emit facts here in the past tense and
## interested UI/services subscribe. Subscribers own their connection lifetime:
## connect in _ready(), and disconnect in _exit_tree() when the emitter is not
## an autoload.
extends Node

## Emitted by SceneRouter after a new scene has been instanced.
signal scene_changed(scene_id: StringName)

## Emitted whenever a wallet balance changes. `kind` is one of
## &"coins", &"gems", &"stones".
signal currency_changed(kind: StringName, amount: int)

## Emitted when a wave begins spawning. `is_boss` selects the boss music.
signal wave_started(wave: int, is_boss: bool)

## Emitted after the last enemy of a wave has been cleared.
signal wave_cleared(wave: int)

## Emitted when a boss spawns and when its corpse is removed (HUD + audio).
signal boss_spawned()
signal boss_removed()

## Emitted by MagicaService/screen when research starts or a node completes.
signal research_started(node_id: StringName)
signal research_completed(node_id: StringName)

## Emitted when a run starts (after RunState.reset()).
signal run_started()

## Emitted when a run ends. `waves` is the highest cleared wave.
signal run_ended(waves: int)

## Emitted for every resolved hit (spec 4.7). `target_id` 0 is the Tree;
## enemies use their run-local uid.
signal damage_dealt(source_id: StringName, target_id: int, amount: float, is_crit: bool, is_kill: bool)

## Emitted when the in-run cash balance changes. Not a meta wallet currency.
signal run_cash_changed(amount: int)

## Emitted once per enemy death (mission progress; `is_boss` for future quests).
signal enemy_killed(enemy_id: StringName, is_boss: bool)

## Emitted when an enemy reaches the Tree (mission progress).
signal enemy_leaked(enemy_id: StringName)

## Emitted after a tower is built. `run_count` is the number built in this run.
signal tower_built(tower_id: StringName, run_count: int)

## Emitted when a card drop was granted (battle banner / collection badge).
signal card_dropped(card_id: StringName)

## Emitted when the Magica "Second Wind" node saves the Tree from a lethal hit.
signal second_wind_used()

## Emitted after a successful permanent-currency spend (workshop, research...).
signal meta_purchased(kind: StringName, amount: int, reason: StringName)

## Emitted when the player gains a level (after xp has been applied).
signal level_up(level: int)

## Emitted once per feature id when a player level unlocks it.
signal unlocked(unlock_id: StringName)
