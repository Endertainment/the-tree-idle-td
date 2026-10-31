## CardsScreen — loadout slots, collection grid and card detail (spec 13.8).
##
## Presentation only: CardService owns ownership, shards, slot gating, persistence
## and the aggregated `&"cards"` modifier source. Filters/sort are view state.
extends Control

const FILTERS: Array[StringName] = [&"all", &"common", &"rare", &"epic", &"legendary", &"owned"]
const FILTER_LABELS: Dictionary = {
	&"all": ["cards.filter.all", "All"],
	&"common": ["cards.rarity.common", "Common"],
	&"rare": ["cards.rarity.rare", "Rare"],
	&"epic": ["cards.rarity.epic", "Epic"],
	&"legendary": ["cards.rarity.legendary", "Legendary"],
	&"owned": ["cards.filter.owned", "Owned"],
}
const SORTS: Array[StringName] = [&"rarity", &"level", &"new"]
const CARD_FRAME_PATH := "res://assets/art/meta/cards/card_frame_%s.png"

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _slots_row: HBoxContainer = %SlotsRow
@onready var _filter_row: HBoxContainer = %FilterRow
@onready var _sort_button: Button = %SortButton
@onready var _collection_grid: GridContainer = %CollectionGrid
@onready var _stats_label: Label = %StatsLabel
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _detail_overlay: Control = %DetailOverlay
@onready var _detail_scrim: Button = %DetailScrim
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_rarity: Label = %DetailRarity
@onready var _detail_effects: Label = %DetailEffects
@onready var _detail_level: Label = %DetailLevel
@onready var _shards_bar: ProgressBar = %ShardsBar
@onready var _detail_where: Label = %DetailWhere
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _equip_button: Button = %EquipButton
@onready var _close_detail_button: Button = %CloseDetailButton
@onready var _nav: MenuNav = %MenuNav

var _slot_buttons: Array[Button] = []
var _filter_buttons: Dictionary = {}
var _selected: StringName = &""
var _filter: StringName = &"all"
var _sort_mode: StringName = &"rarity"
var _replace_mode: StringName = &""
var _toast_tween: Tween
var _preview_state: Dictionary = {}
var _preview_collection: CardCollection


func _ready() -> void:
	_localize()
	_back_button.pressed.connect(_on_back_pressed)
	_sort_button.pressed.connect(_on_sort_pressed)
	_detail_scrim.pressed.connect(_close_detail)
	_close_detail_button.pressed.connect(_close_detail)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_equip_button.pressed.connect(_on_equip_pressed)
	CardService.cards_changed.connect(_refresh)
	LocaleService.language_changed.connect(_on_language_changed)
	_toast.visible = false
	_detail_overlay.visible = false
	_build_slots()
	_build_filters()
	_refresh()


func _exit_tree() -> void:
	if CardService.cards_changed.is_connected(_refresh):
		CardService.cards_changed.disconnect(_refresh)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh_filters()
	if _selected != &"":
		_refresh_detail()
	AudioBus.bind_buttons(self)


## Localised display helpers for content resources (keys live in strings.csv).
func _card_name(card: CardData) -> String:
	return LocaleService.t(card.name_key, card.name)


func _rarity_label(card: CardData) -> String:
	var key := "cards.rarity.%s" % String(card.rarity)
	return LocaleService.t(key, card.rarity_label())


func _where_to_get(card: CardData) -> String:
	var key := "card.%s_where" % String(card.id)
	return LocaleService.t(key, card.where_to_get)


func _effect_lines(card: CardData, level: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for effect: ModifierData in card.effects:
		var line := card.effect_line(effect, level)
		if line.is_empty():
			continue
		var label_entry: Array = CardData.STAT_LABELS.get(effect.stat, [String(effect.stat).capitalize(), "percent"])
		var translated := LocaleService.t("stat.%s" % String(effect.stat), str(label_entry[0]))
		lines.append(line.replace(str(label_entry[0]), translated))
	return lines


func _localize() -> void:
	_title_label.text = LocaleService.t("cards.title", "Cards")
	_back_button.text = LocaleService.t("common.back", "Back")
	_upgrade_button.text = LocaleService.t("cards.upgrade", "Upgrade")
	_equip_button.text = LocaleService.t("cards.equip", "Equip")
	_close_detail_button.text = LocaleService.t("common.close", "Close")
	_sort_button.add_theme_font_size_override("font_size", 24)
	_sort_button.clip_text = true
	_nav.setup(&"cards")


func _collection() -> CardCollection:
	if not _preview_state.is_empty():
		if _preview_collection == null:
			_preview_collection = CardCollection.new()
			_preview_collection.setup(CardService.get_cards(), _preview_state)
		return _preview_collection
	return CardService.get_collection()


func _slot_count() -> int:
	if not _preview_state.is_empty():
		return 4
	return CardService.slot_count()


func _build_slots() -> void:
	for slot in CardCollection.MAX_SLOTS:
		var button := Button.new()
		button.name = "Slot%d" % slot
		button.custom_minimum_size = Vector2(0, 170)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.pressed.connect(_on_slot_pressed.bind(slot))
		_slots_row.add_child(button)
		_slot_buttons.append(button)


func _build_filters() -> void:
	for filter: StringName in FILTERS:
		var button := Button.new()
		button.name = "Filter%s" % String(filter).capitalize()
		button.custom_minimum_size = Vector2(0, 82)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"SecondaryButton"
		button.add_theme_font_size_override("font_size", 22)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(_on_filter_pressed.bind(filter))
		_filter_row.add_child(button)
		_filter_buttons[filter] = button


func _refresh() -> void:
	_refresh_slots()
	_refresh_filters()
	_rebuild_grid()
	_refresh_stats()
	if _selected != &"":
		_refresh_detail()


func _refresh_slots() -> void:
	var collection := _collection()
	var unlocked := _slot_count()
	for slot in CardCollection.MAX_SLOTS:
		var button := _slot_buttons[slot]
		if slot >= unlocked:
			button.text = "%s\n%s" % [
				LocaleService.t("cards.locked_slot", "Locked"),
				_slot_requirement(slot),
			]
			button.theme_type_variation = &"SecondaryButton"
			button.modulate = Color(0.58, 0.62, 0.56, 1.0)
			continue
		var card_id := collection.slot_card(slot)
		if card_id == &"":
			button.text = "%s\n%s %d" % [
				LocaleService.t("cards.empty_slot", "Empty"),
				LocaleService.t("cards.slot", "Slot"),
				slot + 1,
			]
			button.theme_type_variation = &"PrimaryButton"
			button.modulate = Color(1, 1, 1, 0.72)
			continue
		var card := collection.get_card(card_id)
		button.text = "%s\n%s %d" % [
			_card_name(card),
			LocaleService.t("workshop.level_short", "Lv"),
			collection.level_of(card_id),
		]
		button.theme_type_variation = &"GoldButton"
		button.modulate = card.rarity_color()
		_apply_rarity_frame(button, card)


func _slot_requirement(slot: int) -> String:
	match slot:
		0, 1, 2, 3:
			return LocaleService.t("cards.player_level_value", "Player level %d") % [2, 5, 15, 20][slot]
		_:
			return LocaleService.t("cards.deep_roots", "Deep Roots")


func _refresh_filters() -> void:
	for filter: StringName in _filter_buttons.keys():
		var button: Button = _filter_buttons[filter]
		var active := filter == _filter
		button.theme_type_variation = &"GoldButton" if active else &"SecondaryButton"
		button.modulate = Color.WHITE if active else Color(0.8, 0.84, 0.78, 1.0)
		_apply_filter_text(button, filter)
	_sort_button.text = _sort_label(_sort_mode)
	_sort_button.tooltip_text = LocaleService.t("cards.sort", "Sort")


func _apply_filter_text(button: Button, filter: StringName) -> void:
	var entry: Array = FILTER_LABELS[filter]
	button.text = LocaleService.t(str(entry[0]), str(entry[1]))


func _sort_label(mode: StringName) -> String:
	match mode:
		&"level":
			return LocaleService.t("cards.sort.level", "Level")
		&"new":
			return LocaleService.t("cards.sort.new", "New")
		_:
			return LocaleService.t("cards.sort.rarity", "Rarity")


func _on_filter_pressed(filter: StringName) -> void:
	_filter = filter
	_refresh_filters()
	_rebuild_grid()


func _on_sort_pressed() -> void:
	var index := SORTS.find(_sort_mode)
	_sort_mode = SORTS[(index + 1) % SORTS.size()]
	_refresh_filters()
	_rebuild_grid()


func _rebuild_grid() -> void:
	for child: Node in _collection_grid.get_children():
		_collection_grid.remove_child(child)
		child.queue_free()
	var collection := _collection()
	var cards: Array[CardData] = collection.get_cards().duplicate()
	if _sort_mode == &"level":
		cards.sort_custom(func(a: CardData, b: CardData) -> bool:
			if collection.level_of(a.id) == collection.level_of(b.id):
				return CardData.RARITIES.find(a.rarity) < CardData.RARITIES.find(b.rarity)
			return collection.level_of(a.id) > collection.level_of(b.id)
		)
	elif _sort_mode == &"new":
		cards.reverse()
	for card: CardData in cards:
		if _filter == &"owned" and not collection.is_owned(card.id):
			continue
		if _filter != &"all" and _filter != &"owned" and card.rarity != _filter:
			continue
		_collection_grid.add_child(_card_tile(card, collection))


func _card_tile(card: CardData, collection: CardCollection) -> Button:
	var button := Button.new()
	button.name = "Card_%s" % card.id
	button.custom_minimum_size = Vector2(0, 230)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.icon = card.art
	button.expand_icon = true
	button.add_theme_font_size_override("font_size", 22)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = true
	var owned := collection.is_owned(card.id)
	if owned:
		button.text = "%s\n%s %d" % [
			_card_name(card),
			LocaleService.t("workshop.level_short", "Lv"),
			collection.level_of(card.id),
		]
		button.theme_type_variation = &"GoldButton" if card.rarity == &"legendary" else &"PrimaryButton"
		button.modulate = card.rarity_color()
	else:
		button.text = "%s\n%s" % [_card_name(card), LocaleService.t("cards.not_owned", "Not owned")]
		button.theme_type_variation = &"SecondaryButton"
		button.modulate = Color(0.58, 0.62, 0.56, 1.0)
		_apply_rarity_frame(button, card)
	button.pressed.connect(_select_card.bind(card.id))
	return button


## Rarity frame from the manifest (common/rare/epic/legendary). The frame is the
## button skin so it also survives hover/pressed states without extra overlays.
func _apply_rarity_frame(button: Button, card: CardData) -> void:
	var path := CARD_FRAME_PATH % String(card.rarity)
	if not ResourceLoader.exists(path):
		return
	var frame := StyleBoxTexture.new()
	frame.texture = load(path) as Texture2D
	frame.texture_margin_left = 28.0
	frame.texture_margin_top = 28.0
	frame.texture_margin_right = 28.0
	frame.texture_margin_bottom = 28.0
	frame.content_margin_left = 12.0
	frame.content_margin_right = 12.0
	frame.content_margin_top = 12.0
	frame.content_margin_bottom = 12.0
	button.add_theme_stylebox_override("normal", frame)
	button.add_theme_stylebox_override("hover", frame)
	button.add_theme_stylebox_override("pressed", frame)


func _refresh_stats() -> void:
	var collection := _collection()
	var equipped := collection.equipped_count()
	var parts: PackedStringArray = []
	var entries := collection.effect_entries()
	for stat: String in entries.keys():
		var entry: Dictionary = entries[stat]
		var value := float(entry.get("mul", 0.0))
		var unit := "%"
		if is_zero_approx(value):
			value = float(entry.get("add", 0.0))
			unit = ""
		if is_zero_approx(value):
			continue
		var label_entry: Array = CardData.STAT_LABELS.get(StringName(stat), [stat.capitalize(), "percent"])
		var suffix := " " + LocaleService.t("cards.pp", "pp") if str(label_entry[1]) == "pp" else ""
		var stat_label := LocaleService.t("stat.%s" % String(stat), str(label_entry[0]))
		parts.append("%s %+d%s%s" % [stat_label, int(round(value * 100.0)), suffix, unit])
		if parts.size() >= 4:
			break
	var summary := " · ".join(parts)
	if summary.is_empty():
		summary = LocaleService.t("cards.no_bonus", "No cards equipped")
	_stats_label.text = "%s %d/%d  ·  %s" % [
		LocaleService.t("cards.equipped", "Equipped"),
		equipped,
		_slot_count(),
		summary,
	]


func _select_card(card_id: StringName) -> void:
	_selected = card_id
	AudioBus.play_ui(&"card_flip")
	_refresh_detail()
	_detail_overlay.visible = true


func _refresh_detail() -> void:
	var collection := _collection()
	var card := collection.get_card(_selected)
	if card == null:
		_close_detail()
		return
	var owned := collection.is_owned(card.id)
	var level := collection.level_of(card.id) if owned else 1
	_detail_title.text = _card_name(card)
	_detail_rarity.text = _rarity_label(card)
	_detail_rarity.modulate = card.rarity_color()
	_detail_effects.text = "\n".join(_effect_lines(card, level))
	_detail_where.text = "%s %s" % [
		LocaleService.t("cards.where_to_get", "Where to get:"),
		_where_to_get(card),
	]
	if owned:
		var cost := collection.shard_cost(card.id)
		var shards := collection.shards_of(card.id)
		_detail_level.text = "%s %d / %d  ·  %d / %d %s" % [
			LocaleService.t("workshop.level_short", "Lv"),
			level,
			CardData.MAX_LEVEL,
			shards,
			cost if cost > 0 else shards,
			LocaleService.t("cards.shards", "shards"),
		]
		_shards_bar.max_value = maxf(float(cost), 1.0)
		_shards_bar.value = float(cost if cost > 0 else 1)
		if cost > 0:
			_shards_bar.value = float(mini(shards, cost))
		_upgrade_button.visible = true
		var max_level := level >= CardData.MAX_LEVEL
		_upgrade_button.disabled = max_level or not collection.can_upgrade(card.id)
		_upgrade_button.text = LocaleService.t("cards.max_level", "Max level") if max_level else "%s (%d)" % [
			LocaleService.t("cards.upgrade", "Upgrade"), cost
		]
	else:
		_detail_level.text = LocaleService.t("cards.not_owned", "Not owned")
		_shards_bar.max_value = 1.0
		_shards_bar.value = 0.0
		_upgrade_button.visible = false
	var equipped := collection.slot_of(card.id) >= 0
	_equip_button.visible = owned
	_equip_button.text = LocaleService.t("cards.unequip", "Unequip") if equipped else LocaleService.t("cards.equip", "Equip")
	_equip_button.disabled = not owned or (not equipped and _slot_count() <= 0)


func _on_upgrade_pressed() -> void:
	if _preview_state.is_empty():
		if not CardService.try_upgrade(_selected):
			AudioBus.play_ui(&"ui_error")
			_show_toast(LocaleService.t("cards.not_enough_shards", "Not enough shards"))
			return
	else:
		_collection().upgrade(_selected)
	AudioBus.play_ui(&"ui_purchase")
	_refresh()
	_show_toast(LocaleService.t("cards.upgraded", "Card upgraded"))


func _on_equip_pressed() -> void:
	var collection := _collection()
	if not collection.is_owned(_selected):
		return
	var current_slot := collection.slot_of(_selected)
	if current_slot >= 0:
		if _preview_state.is_empty():
			CardService.unequip(current_slot)
		else:
			collection.unequip(current_slot)
		AudioBus.play_ui(&"ui_toggle")
		_show_toast(LocaleService.t("cards.unequipped", "Card unequipped"))
		_refresh()
		return
	if _slot_count() <= 0:
		AudioBus.play_ui(&"ui_error")
		_show_toast(LocaleService.t("cards.no_slot", "Unlock a card slot first"))
		return
	if collection.equipped_count() >= _slot_count():
		_replace_mode = _selected
		_show_toast(LocaleService.t("cards.pick_slot", "Tap a slot to replace"))
		return
	if _preview_state.is_empty():
		CardService.equip(_selected)
	else:
		collection.equip(_selected, -1, _slot_count())
	_show_toast(LocaleService.t("cards.equipped_toast", "Card equipped"))
	_refresh()


func _on_slot_pressed(slot: int) -> void:
	var collection := _collection()
	if _slot_count() <= 0:
		AudioBus.play_ui(&"ui_error")
		_show_toast(LocaleService.t("cards.no_slot", "Unlock a card slot first"))
		return
	if slot >= _slot_count():
		_show_toast(_slot_requirement(slot))
		return
	if _replace_mode != &"":
		if _preview_state.is_empty():
			CardService.equip(_replace_mode, slot)
		else:
			collection.equip(_replace_mode, slot, _slot_count())
		_replace_mode = &""
		_show_toast(LocaleService.t("cards.equipped_toast", "Card equipped"))
		_refresh()
		return
	var card_id := collection.slot_card(slot)
	if card_id != &"":
		_select_card(card_id)
		return
	if _selected != &"" and collection.is_owned(_selected) and collection.slot_of(_selected) < 0:
		if _preview_state.is_empty():
			CardService.equip(_selected, slot)
		else:
			collection.equip(_selected, slot, _slot_count())
		_show_toast(LocaleService.t("cards.equipped_toast", "Card equipped"))
		_refresh()


func _close_detail() -> void:
	_detail_overlay.visible = false


func _on_back_pressed() -> void:
	SaveService.request_save()
	SceneRouter.back()


## Android back closes the detail modal before leaving the screen.
func handle_back_request() -> bool:
	if _detail_overlay.visible:
		_close_detail()
		return true
	return false


func _on_shop_pressed() -> void:
	SceneRouter.goto(&"shop")


func _show_toast(message: String) -> void:
	ToastService.show_toast(message)


## Tooling-only populated state for docs/preview captures.
func stage_preview() -> void:
	_preview_state = {
		"owned": [
			{"id": "greed", "level": 3, "shards": 12},
			{"id": "vital_roots", "level": 2, "shards": 40},
			{"id": "regrowth", "level": 1, "shards": 20},
			{"id": "sharpened_tips", "level": 2, "shards": 20},
			{"id": "swift_winds", "level": 1, "shards": 0},
			{"id": "rich_soil", "level": 1, "shards": 0},
			{"id": "bark_shield", "level": 1, "shards": 20},
			{"id": "overgrowth", "level": 2, "shards": 60},
			{"id": "ancient_pact", "level": 1, "shards": 20},
		],
		"equipped": ["greed", "vital_roots", "swift_winds", null, null],
	}
	_preview_collection = null
	_refresh()


## Tooling-only: opens the detail modal for a `detail` capture.
func stage_sheet_preview(_sheet: String) -> void:
	stage_preview()
	_select_card(&"ancient_pact")
