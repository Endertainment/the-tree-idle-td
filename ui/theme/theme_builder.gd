## Theme builder — regenerates ui/theme/main_theme.tres from placeholder art.
##
## Run headless after the art has been imported:
##   godot --headless --path . --script res://ui/theme/theme_builder.gd
##
## Generating the Theme keeps nine-slice margins in one place and guarantees the
## .tres references real texture files. Scenes must never define inline styles.
extends SceneTree

const THEME_PATH := "res://ui/theme/main_theme.tres"

const ART_BUTTONS := "res://assets/art/ui/buttons/"
const ART_COMMON := "res://assets/art/ui/common/"
const ART_MENU := "res://assets/art/ui/menu/"
const ART_NAV := "res://assets/art/ui/nav/"
const ART_SHOP := "res://assets/art/meta/shop/"
const ART_BOARD := "res://assets/art/meta/leaderboard/"
const ART_CARDS := "res://assets/art/meta/cards/"

const FONT_DISPLAY := "res://assets/fonts/Alegreya-ExtraBold.ttf"
const FONT_BODY := "res://assets/fonts/Alegreya-Bold.ttf"

const COLOR_TEXT := Color(0.96, 0.94, 0.85, 1.0)
const COLOR_TEXT_MUTED := Color(0.72, 0.78, 0.68, 1.0)
const COLOR_TEXT_DISABLED := Color(0.55, 0.58, 0.52, 1.0)
const COLOR_FOCUS := Color(1.0, 0.86, 0.35, 1.0)


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font_size = 40

	_build_fonts(theme)
	_build_labels(theme)
	_build_buttons(theme)
	_build_panels(theme)
	_build_progress(theme)

	var error: Error = ResourceSaver.save(theme, THEME_PATH)
	if error != OK:
		push_error("Theme builder: could not save %s (error %d)" % [THEME_PATH, error])
		quit(1)
		return
	print("[theme] saved ", THEME_PATH)
	quit(0)


func _build_fonts(theme: Theme) -> void:
	# Display face for headlines and buttons, body face for everything else.
	# Both files are optional: the theme still builds if the artist replaces them.
	var display := load(FONT_DISPLAY) as FontFile
	var body := load(FONT_BODY) as FontFile
	if body != null:
		theme.default_font = body
		theme.set_font("font", &"Label", body)
		theme.set_font("font", &"Button", body)
	if display != null:
		theme.set_font("font", &"Display", display)
		theme.set_font("font", &"Title", display)
		theme.set_font("font", &"BattleButton", display)
		theme.set_font("font", &"PrimaryButton", display)


func _build_labels(theme: Theme) -> void:
	theme.set_font_size("font_size", &"Label", 40)
	theme.set_color("font_color", &"Label", COLOR_TEXT)
	theme.set_color("font_shadow_color", &"Label", Color(0.0, 0.0, 0.0, 0.45))
	theme.set_constant("shadow_offset_x", &"Label", 2)
	theme.set_constant("shadow_offset_y", &"Label", 2)

	theme.set_type_variation(&"Display", &"Label")
	theme.set_font_size("font_size", &"Display", 96)

	theme.set_type_variation(&"Title", &"Label")
	theme.set_font_size("font_size", &"Title", 56)

	theme.set_type_variation(&"Body", &"Label")
	theme.set_font_size("font_size", &"Body", 40)

	theme.set_type_variation(&"Caption", &"Label")
	theme.set_font_size("font_size", &"Caption", 28)
	theme.set_color("font_color", &"Caption", COLOR_TEXT_MUTED)


func _build_buttons(theme: Theme) -> void:
	theme.set_font_size("font_size", &"Button", 40)
	theme.set_color("font_color", &"Button", COLOR_TEXT)
	theme.set_color("font_hover_color", &"Button", Color.WHITE)
	theme.set_color("font_pressed_color", &"Button", Color(0.86, 0.92, 0.76, 1.0))
	theme.set_color("font_disabled_color", &"Button", COLOR_TEXT_DISABLED)
	theme.set_constant("icon_max_width", &"Button", 56)
	theme.set_constant("h_separation", &"Button", 16)

	_apply_button_skin(theme, &"Button",
		ART_BUTTONS + "button_green_normal.png",
		ART_BUTTONS + "button_green_pressed.png",
		ART_BUTTONS + "button_green_disabled.png", 40, 36)

	theme.set_type_variation(&"PrimaryButton", &"Button")
	_apply_button_skin(theme, &"PrimaryButton",
		ART_BUTTONS + "button_green_normal.png",
		ART_BUTTONS + "button_green_pressed.png",
		ART_BUTTONS + "button_green_disabled.png", 40, 36)

	theme.set_type_variation(&"SecondaryButton", &"Button")
	_apply_button_skin(theme, &"SecondaryButton",
		ART_BUTTONS + "button_blue_normal.png",
		ART_BUTTONS + "button_blue_pressed.png",
		ART_BUTTONS + "button_blue_disabled.png", 40, 36)

	theme.set_type_variation(&"GoldButton", &"Button")
	_apply_button_skin(theme, &"GoldButton",
		ART_BUTTONS + "button_gold_normal.png",
		ART_BUTTONS + "button_gold_pressed.png",
		ART_BUTTONS + "button_gold_disabled.png", 40, 36)

	theme.set_type_variation(&"GhostButton", &"Button")
	_apply_button_skin(theme, &"GhostButton",
		ART_BUTTONS + "button_ghost_normal.png",
		ART_BUTTONS + "button_ghost_pressed.png",
		ART_BUTTONS + "button_ghost_normal.png", 40, 36)

	theme.set_type_variation(&"IconButton", &"Button")
	_apply_button_skin(theme, &"IconButton",
		ART_BUTTONS + "button_icon_round_normal.png",
		ART_BUTTONS + "button_icon_round_pressed.png",
		ART_BUTTONS + "button_icon_round_normal.png", 24, 24)
	theme.set_constant("icon_max_width", &"IconButton", 72)

	theme.set_type_variation(&"BattleButton", &"Button")
	_apply_button_skin(theme, &"BattleButton",
		ART_MENU + "battle_button_normal.png",
		ART_MENU + "battle_button_pressed.png",
		ART_BUTTONS + "button_green_disabled.png", 48, 40)
	theme.set_font_size("font_size", &"BattleButton", 68)
	theme.set_constant("h_separation", &"BattleButton", 6)
	theme.set_constant("icon_max_width", &"BattleButton", 96)

	theme.set_type_variation(&"NavButton", &"Button")
	_apply_button_skin(theme, &"NavButton",
		ART_BUTTONS + "tab_normal.png",
		ART_BUTTONS + "tab_normal.png",
		ART_BUTTONS + "tab_normal.png", 32, 24)
	theme.set_font_size("font_size", &"NavButton", 24)
	theme.set_constant("icon_max_width", &"NavButton", 56)

	theme.set_type_variation(&"NavButtonActive", &"Button")
	_apply_button_skin(theme, &"NavButtonActive",
		ART_BUTTONS + "tab_selected.png",
		ART_BUTTONS + "tab_selected.png",
		ART_BUTTONS + "tab_selected.png", 32, 24)
	theme.set_font_size("font_size", &"NavButtonActive", 24)
	theme.set_constant("icon_max_width", &"NavButtonActive", 56)

	# Card loadout slots. Empty and locked have their own art; a filled slot uses
	# the rarity frame so the card never looks like a generic button.
	theme.set_type_variation(&"CardSlotEmpty", &"Button")
	_apply_button_skin(theme, &"CardSlotEmpty",
		ART_CARDS + "card_slot_empty.png", ART_CARDS + "card_slot_empty.png",
		ART_CARDS + "card_slot_empty.png", 28, 28)
	theme.set_type_variation(&"CardSlotLocked", &"Button")
	_apply_button_skin(theme, &"CardSlotLocked",
		ART_CARDS + "card_slot_locked.png", ART_CARDS + "card_slot_locked.png",
		ART_CARDS + "card_slot_locked.png", 28, 28)
	for rarity: String in ["common", "rare", "epic", "legendary"]:
		var variation := StringName("CardFrame" + rarity.capitalize())
		theme.set_type_variation(variation, &"Button")
		_apply_button_skin(theme, variation,
			ART_CARDS + "card_frame_%s.png" % rarity,
			ART_CARDS + "card_frame_%s.png" % rarity,
			ART_CARDS + "card_frame_%s.png" % rarity, 28, 28)
		theme.set_font_size("font_size", variation, 26)

	# Main-menu stats card (tap target that opens the profile screen).
	theme.set_type_variation(&"StatsCard", &"Button")
	_apply_button_skin(theme, &"StatsCard",
		ART_MENU + "stat_row_9p.png",
		ART_MENU + "stat_row_9p.png",
		ART_MENU + "stat_row_9p.png", 20, 16)
	theme.set_font_size("font_size", &"StatsCard", 40)

	# Blue rewarded-ad offer bar under the Battle CTA.
	theme.set_type_variation(&"SpeedTrial", &"Button")
	_apply_button_skin(theme, &"SpeedTrial",
		ART_MENU + "speed_trial_9p.png",
		ART_MENU + "speed_trial_9p.png",
		ART_MENU + "speed_trial_9p.png", 40, 26)
	theme.set_font_size("font_size", &"SpeedTrial", 42)
	theme.set_constant("h_separation", &"SpeedTrial", 10)
	theme.set_constant("icon_max_width", &"SpeedTrial", 56)


func _build_panels(theme: Theme) -> void:
	theme.set_type_variation(&"PanelGreen", &"PanelContainer")
	_apply_panel_skin(theme, &"PanelGreen", ART_COMMON + "panel_9p_green.png", 24, 24, 24)

	theme.set_type_variation(&"PanelDark", &"PanelContainer")
	_apply_panel_skin(theme, &"PanelDark", ART_COMMON + "panel_9p_dark.png", 24, 24, 24)

	theme.set_type_variation(&"ListRow", &"PanelContainer")
	_apply_panel_skin(theme, &"ListRow", ART_COMMON + "row_9p_green.png", 20, 18, 20)

	theme.set_type_variation(&"Chip", &"PanelContainer")
	_apply_panel_skin(theme, &"Chip", ART_COMMON + "chip_9p.png", 20, 16, 16)

	theme.set_type_variation(&"CurrencyPill", &"PanelContainer")
	_apply_panel_skin(theme, &"CurrencyPill", ART_MENU + "currency_pill_9p.png", 20, 16, 16)

	# The menu top bar art is 890x149 with thick leaf ornaments on both sides:
	# the 9-slice corners are large, and the content margins keep labels and
	# pills inside the frame on every screen that reuses this variation.
	theme.set_type_variation(&"TopBar", &"PanelContainer")
	theme.set_stylebox("panel", &"TopBar",
		_texture_style(ART_MENU + "top_bar_9p.png", 64, 52, 64, 52, 72, 30))

	# Battle draws its own top bar: same frame language, no leaves, tighter
	# padding, different art so the two can evolve independently.
	theme.set_type_variation(&"BattleTopBar", &"PanelContainer")
	theme.set_stylebox("panel", &"BattleTopBar",
		_texture_style("res://assets/art/battle/hud/top_bar_battle_9p.png", 24, 24, 24, 24, 28, 16))

	theme.set_type_variation(&"DailyCard", &"PanelContainer")
	theme.set_stylebox("panel", &"DailyCard",
		_texture_style(ART_MENU + "daily_card_9p.png", 24, 24, 24, 24, 56, 22))
	
	theme.set_type_variation(&"BattlePanel", &"PanelContainer")
	_apply_panel_skin(theme, &"BattlePanel", ART_MENU + "battle_card_9p.png", 24, 24, 20)

	theme.set_type_variation(&"NavBar", &"PanelContainer")
	_apply_panel_skin(theme, &"NavBar", ART_NAV + "nav_bg_9p.png", 24, 24, 16)

	theme.set_type_variation(&"Toast", &"PanelContainer")
	_apply_panel_skin(theme, &"Toast", ART_COMMON + "toast_9p.png", 20, 16, 18)

	theme.set_type_variation(&"OfferCard", &"PanelContainer")
	_apply_panel_skin(theme, &"OfferCard", ART_SHOP + "offer_card_9p.png", 24, 24, 18)

	theme.set_type_variation(&"LeaderRow", &"PanelContainer")
	_apply_panel_skin(theme, &"LeaderRow", ART_BOARD + "row_9p.png", 16, 12, 14)

	theme.set_type_variation(&"PlayerRow", &"PanelContainer")
	_apply_panel_skin(theme, &"PlayerRow", ART_COMMON + "panel_9p_green.png", 24, 24, 18)

	# Every plain PanelContainer should look like a dark card by default.
	theme.set_stylebox("panel", &"PanelContainer",
		_texture_style(ART_COMMON + "panel_9p_dark.png", 24, 24, 24, 24, 20, 16))


## Every progress bar is a pill: 32 px art with 16 px caps, so the ends stay
## round at any width. Same mechanism as the XP bar, one implementation.
func _build_progress(theme: Theme) -> void:
	var background := _texture_style(ART_COMMON + "bar_bg.png", 16, 16, 16, 16, 0, 0)
	var fill := _texture_style(ART_COMMON + "bar_fill_green.png", 16, 16, 16, 16, 0, 0)
	theme.set_stylebox("background", &"ProgressBar", background)
	theme.set_stylebox("fill", &"ProgressBar", fill)
	theme.set_font_size("font_size", &"ProgressBar", 22)
	theme.set_color("font_color", &"ProgressBar", COLOR_TEXT)

	# The XP bar keeps its own art (same 9-slice rules) so it can diverge.
	theme.set_type_variation(&"XpBar", &"ProgressBar")
	theme.set_stylebox("background", &"XpBar",
		_texture_style(ART_MENU + "xp_bar_bg.png", 16, 16, 16, 16, 0, 0))
	theme.set_stylebox("fill", &"XpBar",
		_texture_style(ART_MENU + "xp_bar_fill.png", 16, 16, 16, 16, 0, 0))
	theme.set_font_size("font_size", &"XpBar", 20)

func _apply_button_skin(
	theme: Theme,
	type_name: StringName,
	normal_path: String,
	pressed_path: String,
	disabled_path: String,
	margin_h: int,
	margin_v: int
) -> void:
	var normal := _texture_style(normal_path, margin_h, margin_v, margin_h, margin_v, 32, 12)
	var hover := _texture_style(normal_path, margin_h, margin_v, margin_h, margin_v, 32, 12)
	hover.modulate_color = Color(1.08, 1.08, 1.08, 1.0)
	var pressed := _texture_style(pressed_path, margin_h, margin_v, margin_h, margin_v, 32, 12)
	pressed.modulate_color = Color(0.94, 0.94, 0.94, 1.0)
	# The pressed art sinks a few pixels; move the label and icon with it so the
	# whole button reads as physically pressed, not just its background.
	pressed.content_margin_top += 6.0
	pressed.content_margin_bottom -= 6.0
	var disabled := _texture_style(disabled_path, margin_h, margin_v, margin_h, margin_v, 32, 12)
	disabled.modulate_color = Color(0.72, 0.72, 0.72, 1.0)

	theme.set_stylebox("normal", type_name, normal)
	theme.set_stylebox("hover", type_name, hover)
	theme.set_stylebox("pressed", type_name, pressed)
	theme.set_stylebox("disabled", type_name, disabled)
	theme.set_stylebox("focus", type_name, _focus_style(4, 16))


func _apply_panel_skin(
	theme: Theme,
	type_name: StringName,
	texture_path: String,
	margin_h: int,
	margin_v: int,
	content_margin: int
) -> void:
	var panel := _texture_style(texture_path, margin_h, margin_v, margin_h, margin_v, content_margin, content_margin)
	theme.set_stylebox("panel", type_name, panel)


func _texture_style(
	texture_path: String,
	left: int,
	top: int,
	right: int,
	bottom: int,
	content_h: int,
	content_v: int
) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(texture_path) as Texture2D
	box.texture_margin_left = float(left)
	box.texture_margin_top = float(top)
	box.texture_margin_right = float(right)
	box.texture_margin_bottom = float(bottom)
	box.content_margin_left = float(content_h)
	box.content_margin_right = float(content_h)
	box.content_margin_top = float(content_v)
	box.content_margin_bottom = float(content_v)
	return box


func _focus_style(border_width: int, corner_radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = COLOR_FOCUS
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = corner_radius
	box.corner_radius_top_right = corner_radius
	box.corner_radius_bottom_left = corner_radius
	box.corner_radius_bottom_right = corner_radius
	return box
