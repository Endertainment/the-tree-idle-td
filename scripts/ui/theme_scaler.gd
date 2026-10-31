## ThemeScaler — applies SettingsService.text_scale to the live UI theme.
##
## The project theme is never mutated: a duplicate is scaled and assigned to the
## window, so switching 100 / 115 / 130 % takes effect immediately and can be
## reverted. Base font sizes are snapshotted once from the authored theme.
class_name ThemeScaler
extends RefCounted

const THEME_PATH := "res://ui/theme/main_theme.tres"

static var _base_sizes: Dictionary = {}
static var _base_default: int = 0


## Scales `root`'s theme by `scale` (1.0 = authored sizes).
static func apply(root: Window, scale: float) -> void:
	if root == null:
		return
	var authored := load(THEME_PATH) as Theme
	if authored == null:
		return
	_snapshot(authored)
	var scaled := authored.duplicate(true) as Theme
	if scaled == null:
		return
	scaled.default_font_size = maxi(roundi(float(_base_default) * scale), 1)
	for type_name: StringName in _base_sizes.keys():
		var sizes: Dictionary = _base_sizes[type_name]
		for size_name: StringName in sizes.keys():
			var base: int = int(sizes[size_name])
			scaled.set_font_size(size_name, type_name, maxi(roundi(float(base) * scale), 1))
	root.theme = scaled


## Snapshot of the authored font sizes, taken once per process.
static func _snapshot(theme: Theme) -> void:
	if not _base_sizes.is_empty():
		return
	_base_default = theme.default_font_size
	for type_name: StringName in theme.get_type_list():
		var sizes: Dictionary = {}
		for size_name: StringName in theme.get_font_size_list(type_name):
			sizes[size_name] = theme.get_font_size(size_name, type_name)
		if not sizes.is_empty():
			_base_sizes[type_name] = sizes


## Clears the cached snapshot (unit tests only).
static func reset_cache() -> void:
	_base_sizes.clear()
	_base_default = 0
