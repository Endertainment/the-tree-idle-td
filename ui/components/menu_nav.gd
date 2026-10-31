## MenuNav — the five-tab bottom navigation shared by every meta screen.
##
## Builds Home / Upgrades / Cards / Missions / Shop buttons from the art manifest,
## highlights the active tab, shows notification dots from the live services and
## routes through SceneRouter. Shop now opens the real shop screen (M5b).
class_name MenuNav
extends PanelContainer

const BADGE_TEXTURE := "res://assets/art/ui/common/badge_dot.png"
const TABS: Array[StringName] = [&"home", &"workshop", &"cards", &"missions", &"shop"]
const ICONS: Dictionary = {
	&"home": "res://assets/art/ui/nav/nav_home_normal.png",
	&"workshop": "res://assets/art/ui/nav/nav_workshop_normal.png",
	&"cards": "res://assets/art/ui/nav/nav_cards_normal.png",
	&"missions": "res://assets/art/ui/nav/nav_missions_normal.png",
	&"shop": "res://assets/art/ui/nav/nav_shop_normal.png",
}
const LABELS: Dictionary = {
	&"home": ["menu.nav.home", "Home"],
	&"workshop": ["menu.nav.workshop", "Upgrades"],
	&"cards": ["menu.nav.cards", "Cards"],
	&"missions": ["menu.nav.missions", "Missions"],
	&"shop": ["menu.nav.shop", "Shop"],
}

var _buttons: Dictionary = {}
var _dots: Dictionary = {}
var _labels: Dictionary = {}
var _active: StringName = &""
var _row: HBoxContainer


func _ready() -> void:
	theme_type_variation = &"NavBar"
	custom_minimum_size = Vector2(0, 220)
	_build()
	setup(_active)
	_connect_services()


func _exit_tree() -> void:
	if MissionService.missions_changed.is_connected(_refresh_notifications):
		MissionService.missions_changed.disconnect(_refresh_notifications)
	if CardService.cards_changed.is_connected(_refresh_notifications):
		CardService.cards_changed.disconnect(_refresh_notifications)
	if MagicaService.magica_changed.is_connected(_refresh_notifications):
		MagicaService.magica_changed.disconnect(_refresh_notifications)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


## Highlights `active`; an empty id leaves every tab inactive (Magica screen).
func setup(active_tab: StringName) -> void:
	_active = active_tab
	for tab: StringName in _buttons.keys():
		var button: Button = _buttons[tab]
		var is_active := tab == _active
		button.theme_type_variation = &"NavButtonActive" if is_active else &"NavButton"
		button.modulate = Color.WHITE if is_active else Color(0.58, 0.62, 0.56, 1.0)
	_refresh_notifications()


## Shows or hides the red notification dot for one tab.
func set_notification(tab: StringName, visible: bool) -> void:
	var dot: TextureRect = _dots.get(tab, null)
	if dot != null:
		dot.visible = visible


func _connect_services() -> void:
	if not MissionService.missions_changed.is_connected(_refresh_notifications):
		MissionService.missions_changed.connect(_refresh_notifications)
	if not CardService.cards_changed.is_connected(_refresh_notifications):
		CardService.cards_changed.connect(_refresh_notifications)
	if not MagicaService.magica_changed.is_connected(_refresh_notifications):
		MagicaService.magica_changed.connect(_refresh_notifications)
	if not LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.connect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	for tab: StringName in _labels.keys():
		var label: Label = _labels[tab]
		var entry: Array = LABELS[tab]
		label.text = LocaleService.t(str(entry[0]), str(entry[1]))


## Dots: missions ready to claim, cards ready to upgrade, Magica claim on Home.
func _refresh_notifications() -> void:
	var missions_ready := MissionService.claimable_count(&"daily") + MissionService.claimable_count(&"weekly") > 0
	set_notification(&"missions", missions_ready)
	var card_ready := false
	for card: CardData in CardService.get_cards():
		if CardService.can_upgrade(card.id):
			card_ready = true
			break
	set_notification(&"cards", card_ready)
	set_notification(&"home", MagicaService.has_pending_claim())


func _build() -> void:
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	for tab: StringName in TABS:
		_row.add_child(_create_button(tab))


func _create_button(tab: StringName) -> Button:
	var button := Button.new()
	button.name = "Nav%s" % String(tab).capitalize()
	button.custom_minimum_size = Vector2(0, 170)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"NavButton"
	button.pressed.connect(_on_pressed.bind(tab))

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(content)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.texture = load(str(ICONS[tab])) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var label_entry: Array = LABELS[tab]
	var label := Label.new()
	label.text = LocaleService.t(str(label_entry[0]), str(label_entry[1]))
	label.theme_type_variation = &"Caption"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	_labels[tab] = label

	var dot := TextureRect.new()
	dot.name = "Notification"
	dot.texture = load(BADGE_TEXTURE) as Texture2D
	dot.custom_minimum_size = Vector2(34, 34)
	dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -46.0
	dot.offset_top = 6.0
	dot.offset_right = -12.0
	dot.offset_bottom = 40.0
	button.add_child(dot)
	_dots[tab] = dot

	_buttons[tab] = button
	return button


func _on_pressed(tab: StringName) -> void:
	if tab == _active:
		return
	match tab:
		&"home":
			SceneRouter.goto(&"main_menu")
		&"workshop":
			SceneRouter.goto(&"workshop")
		&"cards":
			SceneRouter.goto(&"cards")
		&"missions":
			SceneRouter.goto(&"missions")
		&"shop":
			SceneRouter.goto(&"shop")
