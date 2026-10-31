## MagicaScreen — the three research branches (spec 13.7).
##
## Presentation + routing only: starting/cancelling/claiming goes through
## MagicaService, which owns timestamps, wallet transactions and modifier sources.
## The radial timer polls the model once per 0.25 s; offline completion arrives via
## magica_changed from the service.
extends Control

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _coins_pill: CurrencyPill = %CoinsPill
@onready var _gems_pill: CurrencyPill = %GemsPill
@onready var _active_title: Label = %ActiveTitle
@onready var _active_node: Label = %ActiveNode
@onready var _active_remaining: Label = %ActiveRemaining
@onready var _active_hint: Label = %ActiveHint
@onready var _timer: RadialTimer = %Timer
@onready var _claim_button: Button = %ClaimButton
@onready var _speed_up_button: Button = %SpeedUpButton
@onready var _cancel_button: Button = %CancelButton
@onready var _time_box: VBoxContainer = %BranchTimeBox
@onready var _wealth_box: VBoxContainer = %BranchWealthBox
@onready var _knowledge_box: VBoxContainer = %BranchKnowledgeBox
@onready var _node_modal: Modal = %NodeModal
@onready var _cancel_modal: Modal = %CancelModal
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _nav: MenuNav = %MenuNav

var _node_buttons: Dictionary = {}
var _selected: StringName = &""
var _tick: float = 0.0
var _toast_tween: Tween
var _preview_state: Dictionary = {}
var _preview_model: MagicaModel


func _ready() -> void:
	_localize()
	_back_button.pressed.connect(_on_back_pressed)
	_claim_button.pressed.connect(_on_claim_pressed)
	_speed_up_button.pressed.connect(_on_speed_up_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_node_modal.confirmed.connect(_on_node_confirmed)
	_cancel_modal.confirmed.connect(_on_cancel_confirmed)
	MagicaService.magica_changed.connect(_refresh)
	LocaleService.language_changed.connect(_on_language_changed)
	_toast.visible = false
	_build_nodes()
	_refresh()
	set_process(true)


func _exit_tree() -> void:
	if MagicaService.magica_changed.is_connected(_refresh):
		MagicaService.magica_changed.disconnect(_refresh)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh()


func _node_name(node: MagicaNode) -> String:
	return LocaleService.t(node.name_key, node.name)


func _node_description(node: MagicaNode) -> String:
	return LocaleService.t(node.description_key, node.description)


func _node_effect_text(node: MagicaNode) -> String:
	return LocaleService.t("magica.%s_effect" % String(node.id), node.effect_text)


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.25:
		return
	_tick = 0.0
	if not _is_preview() and MagicaService.reconcile():
		return
	_refresh_timer()


func _localize() -> void:
	_title_label.text = LocaleService.t("magica.title", "Magica")
	_back_button.text = LocaleService.t("common.back", "Back")
	_claim_button.text = LocaleService.t("magica.claim", "Claim")
	_speed_up_button.text = LocaleService.t("magica.speed_up", "Speed up (AD)")
	_cancel_button.text = LocaleService.t("magica.cancel", "Cancel")
	_nav.setup(&"")


func _model() -> MagicaModel:
	if _is_preview():
		if _preview_model == null:
			_preview_model = MagicaModel.new()
			_preview_model.setup(MagicaService.get_nodes(), _preview_state)
		return _preview_model
	return MagicaService.get_model()


func _is_preview() -> bool:
	return not _preview_state.is_empty()


func _build_nodes() -> void:
	var boxes := {
		&"time": _time_box,
		&"wealth": _wealth_box,
		&"knowledge": _knowledge_box,
	}
	for branch: StringName in boxes.keys():
		var box: VBoxContainer = boxes[branch]
		for node: MagicaNode in MagicaService.nodes_in_branch(branch):
			var button := Button.new()
			button.name = "Node_%s" % node.id
			button.custom_minimum_size = Vector2(0, 104)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 24)
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.pressed.connect(_on_node_pressed.bind(node.id))
			box.add_child(button)
			_node_buttons[node.id] = button
	AudioBus.bind_buttons(self)


func _refresh() -> void:
	_coins_pill.set_amount(12480 if _is_preview() else WalletService.get_balance(&"coins"))
	_gems_pill.set_amount(350 if _is_preview() else WalletService.get_balance(&"gems"))
	_refresh_nodes()
	_refresh_active()


func _refresh_nodes() -> void:
	var model := _model()
	for node: MagicaNode in MagicaService.get_nodes():
		var button: Button = _node_buttons.get(node.id, null)
		if button == null:
			continue
		var status := _node_status(model, node)
		button.text = "%s\n%s" % [_node_name(node), status]
		var state := _node_state(model, node)
		match state:
			"done":
				button.theme_type_variation = &"GoldButton"
				button.modulate = Color(0.86, 1.0, 0.82, 1.0)
			"active", "pending":
				button.theme_type_variation = &"GoldButton"
				button.modulate = Color.WHITE
			"available":
				button.theme_type_variation = &"PrimaryButton"
				button.modulate = Color.WHITE
			_:
				button.theme_type_variation = &"GhostButton"
				button.modulate = Color(0.78, 0.82, 0.76, 1.0)


func _node_state(model: MagicaModel, node: MagicaNode) -> String:
	if model.is_completed(node.id):
		return "done"
	if model.get_pending_claim() == node.id:
		return "pending"
	if model.has_active_research() and model.active_node_id() == node.id:
		return "active"
	if model.is_available(node.id):
		return "available"
	return "locked"


func _node_status(model: MagicaModel, node: MagicaNode) -> String:
	match _node_state(model, node):
		"done":
			return LocaleService.t("magica.done", "Done")
		"pending":
			return LocaleService.t("magica.complete", "Complete!")
		"active":
			return LocaleService.t("magica.researching", "Researching")
		"available":
			return "%s · %s" % [_duration_text(node.duration_seconds), _cost_text(node)]
		_:
			return LocaleService.t("magica.locked", "Locked")


func _refresh_active() -> void:
	var model := _model()
	if model.has_pending_claim():
		var pending := model.get_node_by_id(model.get_pending_claim())
		_active_title.text = LocaleService.t("magica.complete", "Research complete!")
		_active_node.text = _node_name(pending) if pending != null else ""
		_active_hint.text = LocaleService.t("magica.claim_hint", "Tap Claim to activate its effect.")
		_active_remaining.text = ""
		_timer.progress = 1.0
		_claim_button.visible = true
		_speed_up_button.visible = false
		_cancel_button.visible = false
		return
	if model.has_active_research():
		var node := model.get_node_by_id(model.active_node_id())
		_active_title.text = LocaleService.t("magica.active", "Researching")
		_active_node.text = _node_name(node) if node != null else ""
		_active_hint.text = LocaleService.t("magica.active_hint", "Research continues while the app is closed.")
		_claim_button.visible = false
		_speed_up_button.visible = true
		_cancel_button.visible = true
		_refresh_timer()
		return
	_active_title.text = LocaleService.t("magica.idle", "No active research")
	_active_node.text = LocaleService.t("magica.pick", "Pick a node to begin")
	_active_hint.text = LocaleService.t("magica.idle_hint", "One research at a time. Completed nodes apply immediately.")
	_active_remaining.text = ""
	_timer.progress = 0.0
	_claim_button.visible = false
	_speed_up_button.visible = false
	_cancel_button.visible = false


func _refresh_timer() -> void:
	var model := _model()
	if not model.has_active_research():
		return
	_timer.progress = model.progress(TimeService.now_unix())
	_active_remaining.text = TimeService.format_clock(model.remaining_seconds(TimeService.now_unix()))


func _on_node_pressed(node_id: StringName) -> void:
	_selected = node_id
	var model := _model()
	var node := MagicaService.get_node_by_id(node_id)
	if node == null:
		return
	var lines: PackedStringArray = []
	lines.append(_node_description(node))
	lines.append("%s %s" % [LocaleService.t("magica.effect", "Effect:"), _node_effect_text(node)])
	lines.append("%s %s" % [LocaleService.t("magica.duration", "Duration:"), _duration_text(node.duration_seconds)])
	lines.append("%s %s" % [LocaleService.t("magica.cost", "Cost:"), _cost_text(node)])
	if not model.missing_prerequisites(node_id).is_empty():
		var names: PackedStringArray = []
		for required: StringName in model.missing_prerequisites(node_id):
			var prerequisite := MagicaService.get_node_by_id(required)
			names.append(_node_name(prerequisite) if prerequisite != null else String(required))
		lines.append("%s %s" % [LocaleService.t("magica.requires", "Requires:"), ", ".join(names)])
	var confirm_text := LocaleService.t("magica.start", "Start") if model.is_available(node_id) else LocaleService.t("common.ok", "OK")
	_node_modal.open(_node_name(node), "\n".join(lines), confirm_text, LocaleService.t("common.close", "Close"))


func _on_node_confirmed() -> void:
	if _selected == &"" or _is_preview():
		return
	if not MagicaService.is_available(_selected):
		AudioBus.play_ui(&"ui_error")
		_show_toast(_locked_reason(_model(), _selected))
		return
	var result := MagicaService.try_start(_selected)
	if result.is_ok():
		EventBus.research_started.emit(_selected)
		_show_toast(LocaleService.t("magica.started", "Research started"))
		return
	AudioBus.play_ui(&"ui_error")
	_show_toast(_spend_reason(result))


func _locked_reason(model: MagicaModel, node_id: StringName) -> String:
	var reason := model.block_reason(node_id)
	match reason:
		"prerequisites":
			return LocaleService.t("magica.need_prereq", "Complete the prerequisite nodes first")
		"busy":
			return LocaleService.t("magica.one_at_a_time", "Only one research at a time")
		"completed":
			return LocaleService.t("magica.already_done", "Already researched")
		"claim":
			return LocaleService.t("magica.claim_first", "Claim the finished research first")
		_:
			return LocaleService.t("magica.locked", "Locked")


func _spend_reason(result: SpendResult) -> String:
	if result.code == SpendResult.Code.INSUFFICIENT_FUNDS:
		var kind := LocaleService.t("magica.currency", "currency")
		return LocaleService.t("magica.not_enough", "Not enough %s") % kind
	return LocaleService.t("magica.cannot_start", "Cannot start this research")


func _on_claim_pressed() -> void:
	if _is_preview():
		return
	var claimed := MagicaService.claim()
	if claimed == &"":
		AudioBus.play_ui(&"ui_error")
		_show_toast(LocaleService.t("magica.nothing_to_claim", "Nothing to claim"))
		return
	EventBus.research_completed.emit(claimed)
	var node := MagicaService.get_node_by_id(claimed)
	_show_toast(LocaleService.t("magica.claimed", "Research complete: %s") % (_node_name(node) if node != null else ""))


func _on_speed_up_pressed() -> void:
	_show_toast(LocaleService.t("magica.ads_soon", "Rewarded speed-ups arrive with M6"))
	MagicaService.speed_up()


func _on_cancel_pressed() -> void:
	if _is_preview() or not MagicaService.has_active_research():
		return
	_cancel_modal.open(
		LocaleService.t("magica.cancel_title", "Cancel research?"),
		LocaleService.t("magica.cancel_body", "50 % of the coins and gems are refunded."),
		LocaleService.t("magica.cancel_confirm", "Cancel research"),
		LocaleService.t("magica.keep", "Keep researching")
	)


func _on_cancel_confirmed() -> void:
	if _is_preview():
		return
	var refund := MagicaService.cancel()
	if refund.is_empty():
		return
	AudioBus.play_ui(&"ui_back")
	_show_toast(LocaleService.t("magica.cancelled", "Research cancelled, 50 % refunded"))


func _on_back_pressed() -> void:
	SaveService.request_save()
	SceneRouter.back()


func _on_shop_pressed() -> void:
	SceneRouter.goto(&"shop")


func _duration_text(seconds: int) -> String:
	return _format_duration(seconds)


func _format_duration(seconds: int) -> String:
	return LocaleService.format_duration(seconds)


func _cost_text(node: MagicaNode) -> String:
	var parts: PackedStringArray = []
	if node.coin_cost > 0:
		parts.append("%s %s" % [LocaleService.format_number(node.coin_cost), LocaleService.t("common.coins_short", "coins")])
	if node.gem_cost > 0:
		parts.append("%s %s" % [LocaleService.format_number(node.gem_cost), LocaleService.t("common.gems_short", "gems")])
	return " + ".join(parts) if not parts.is_empty() else LocaleService.t("common.free", "Free")


func _show_toast(message: String) -> void:
	ToastService.show_toast(message)


## Tooling-only populated state for docs/preview captures.
func stage_preview() -> void:
	var now := TimeService.now_unix()
	_preview_state = {
		"research": {
			"node_id": "deep_roots",
			"started_at": now - 7200,
			"ends_at": now + 3600,
		},
		"completed": ["quickened_roots_1", "golden_sap_1", "fourth_branch"],
		"pending_claim": "",
	}
	_preview_model = null
	_refresh()
