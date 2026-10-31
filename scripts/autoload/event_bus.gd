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

## Emitted after the last enemy of a wave has been cleared.
signal wave_cleared(wave: int)

## Emitted when a run starts (after RunState.reset()).
signal run_started()

## Emitted when a run ends. `waves` is the highest cleared wave.
signal run_ended(waves: int)
