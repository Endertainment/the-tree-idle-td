## DebugOverlay — F3 diagnostic panel for the battle (debug builds only).
##
## Read-only: reads BattleController.get_debug_snapshot() and renders fps, active
## enemies, projectiles in flight, cash, simulation speed and wave. Used by the
## perf gate and manual QA; never instantiated in release builds.
class_name DebugOverlay
extends CanvasLayer

const TOGGLE_KEY := KEY_F3
const REFRESH_SECONDS := 0.25
const PANEL_WIDTH := 520.0

var _battle: BattleController
var _panel: PanelContainer
var _label: Label
var _refresh_timer: float = 0.0
var _last_text: String = ""


func setup(battle: BattleController) -> void:
	_battle = battle
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != TOGGLE_KEY:
		return
	toggle()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer < REFRESH_SECONDS:
		return
	_refresh_timer = 0.0
	_refresh()


## Toggles the panel and returns the new visibility.
func toggle() -> bool:
	visible = not visible
	if visible:
		_refresh()
	return visible


## Current panel text (tests assert the numbers are wired).
func get_debug_text() -> String:
	return _last_text


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.theme_type_variation = &"PanelDark"
	_panel.offset_left = 24.0
	_panel.offset_top = 340.0
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	_label = Label.new()
	_label.theme_type_variation = &"Caption"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)


func _refresh() -> void:
	if _battle == null or not is_instance_valid(_battle) or _label == null:
		return
	var snapshot := _battle.get_debug_snapshot()
	var speed := float(snapshot.get("speed", 1.0))
	var pause_text := LocaleService.t("debug.paused", "paused") if bool(snapshot.get("paused", false)) else ""
	_last_text = "\n".join([
		"F3 · %s" % LocaleService.t("debug.title", "Debug"),
		"FPS: %d" % int(snapshot.get("fps", 0)),
		"%s: %d" % [LocaleService.t("debug.enemies", "Enemies"), int(snapshot.get("enemies", 0))],
		"%s: %d" % [LocaleService.t("debug.projectiles", "Projectiles"), int(snapshot.get("projectiles", 0))],
		"%s: %d" % [LocaleService.t("battle.cash", "Cash"), int(snapshot.get("cash", 0))],
		"%s: %sx %s" % [LocaleService.t("debug.speed", "Sim speed"), _format_speed(speed), pause_text],
		"%s: %d (%s %d)" % [
			LocaleService.t("battle.wave", "Wave"),
			int(snapshot.get("wave", 0)),
			LocaleService.t("debug.cleared", "cleared"),
			int(snapshot.get("cleared", 0)),
		],
		"%s: %d" % [LocaleService.t("summary.kills", "Kills"), int(snapshot.get("kills", 0))],
	])
	_label.text = _last_text


func _format_speed(speed: float) -> String:
	if is_equal_approx(speed, roundf(speed)):
		return str(int(roundf(speed)))
	return "%.1f" % speed
