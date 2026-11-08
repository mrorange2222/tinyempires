extends Control

const HexBoard = preload("res://ui/hex_board.gd")
const EmpireGame = preload("res://game/empire_game.gd")
const IslandMap = preload("res://map/island_map.gd")
const TitleScreen = preload("res://ui/title_screen.gd")
const BLUE := Color("#79c8df")
const CORAL := Color("#e8a08d")
const GOLD := Color("#e3ce94")
const NO_TILE := EmpireGame.NO_TILE
const CONTENT := "Margin/Layout/PlayArea/Sidebar/Scroll/Content/"
const SEL := CONTENT + "SelectionCard/Box/"
const ACT := CONTENT + "ActionCard/Box/"
const Icon = preload("res://ui/icon.gd")
const BODY_FONT := preload("res://assets/fonts/Nunito-Variable.ttf")
const TITLE_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const PANEL := Color("#13252b")
const PANEL_EDGE := Color("#2c4349")
const TEXT := Color("#dfe6e2")
const MUTED := Color("#93a5a3")

var game := EmpireGame.new()
var source := NO_TILE
var target := NO_TILE
var send_count := 0
# Difficulty and map size for new matches; remembered between sessions.
var match_settings := {"difficulty": "Normal", "map": "Tiny"}
var remember_settings := true
# On launch, show the title screen (and choose a match from there).
var show_title_on_start := true
var match_started := false
var title_screen: Control
## Saved with the match choices: rival pace, window mode, map hints.
var options := {"rival_speed": "Normal", "fullscreen": false, "show_hints": true}
const RIVAL_SPEEDS := {"Fast": 0.4, "Normal": 0.7, "Slow": 1.0}
var match_info: Label
var new_match_screen: Control
# Pause between rival moves so the player can follow them.
var rival_step_seconds := 0.7
var rival_playing := false
var _match_id := 0
var stat_values: Array[Dictionary] = [{}, {}]
var title_font: FontVariation

@onready var selection_label: Label = $Margin/Layout/Selection
@onready var board: HexBoard = $Margin/Layout/PlayArea/Scroll/Board
@onready var scroll: ScrollContainer = $Margin/Layout/PlayArea/Scroll
@onready var turn_label: Label = $Margin/Layout/Header/Turn
@onready var player_stats: Label = $Margin/Layout/Header/Stats/Player/Row/Label
@onready var rival_stats: Label = $Margin/Layout/Header/Stats/Rival/Row/Label
@onready var status: Label = $Margin/Layout/Legend
@onready var tile_title: Label = get_node(SEL + "TileTitle")
@onready var tile_detail: Label = get_node(SEL + "TileDetail")
@onready var recruit_button: Button = get_node(SEL + "Recruit")
@onready var improve_button: Button = get_node(SEL + "Improve")
@onready var fort_button: Button = get_node(SEL + "Fort")
@onready var expand_button: Button = get_node(SEL + "Expand")
@onready var target_title: Label = get_node(ACT + "TargetTitle")
@onready var count_row: HBoxContainer = get_node(ACT + "Count")
@onready var count_label: Label = get_node(ACT + "Count/Label")
@onready var less_button: Button = get_node(ACT + "Count/Less")
@onready var more_button: Button = get_node(ACT + "Count/More")
@onready var move_button: Button = get_node(ACT + "Move")
@onready var attack_button: Button = get_node(ACT + "Attack")
@onready var preview: Label = get_node(ACT + "Preview")
@onready var kingdom_hint: Label = get_node(CONTENT + "KingdomCard/Box/KingdomHint")
@onready var history_label: Label = get_node(CONTENT + "HistoryCard/Box/History")
@onready var end_button: Button = $Margin/Layout/PlayArea/Sidebar/EndTurn
@onready var rules_dialog: AcceptDialog = $RulesDialog
@onready var result_overlay: ColorRect = $Result
@onready var result_title: Label = $Result/Center/Card/Content/Title
@onready var result_detail: Label = $Result/Center/Card/Content/Detail


func _ready() -> void:
	_apply_theme()
	board.tile_selected.connect(_on_tile_clicked)
	recruit_button.pressed.connect(_act.bind("recruit"))
	improve_button.pressed.connect(_act.bind("improve"))
	fort_button.pressed.connect(_act.bind("fort"))
	expand_button.pressed.connect(_act.bind("claim"))
	move_button.pressed.connect(_act.bind("move"))
	attack_button.pressed.connect(_act.bind("attack"))
	less_button.pressed.connect(_change_count.bind(-1))
	more_button.pressed.connect(_change_count.bind(1))
	end_button.pressed.connect(_end_turn)
	$Margin/Layout/Header/Exit.pressed.connect(show_title)
	$Result/Center/Card/Content/Restart.pressed.connect(open_new_match_screen)
	$Result/Center/Card/Content/MainMenu.pressed.connect(show_title)
	$Margin/Layout/Header/Rules.pressed.connect(func() -> void: rules_dialog.popup_centered())
	for button in [recruit_button, improve_button, fort_button, expand_button, move_button, attack_button,
			less_button, more_button, end_button]:
		button.focus_mode = Control.FOCUS_NONE
		# Long labels must not widen the panel, or the map would jump on selection.
		if button not in [less_button, more_button]:
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for button in [less_button, more_button]:
		button.custom_minimum_size = Vector2(34, 0)
		button.add_theme_font_size_override("font_size", 16)
	less_button.text = "−"
	rules_dialog.dialog_text = "\n".join([
		"GOAL: capture the coral capital to win at once. Otherwise, after round 20 the kingdom with more land wins (equal land is a draw).",
		"",
		"Each turn, spend gold on as many actions as you can afford:",
		"CLAIM: 3 gold. Unclaimed land next to yours. It starts with no armies.",
		"IMPROVE: 3 gold. +1 gold per round. Once per tile.",
		"FORT: 6 gold. +5 defense, including on capitals (+7 total). The tile earns 0 gold: maintenance consumes its normal income. Replaces a farm; cannot be converted back. Survives capture. Defense bonuses do not increase casualties.",
		"RECRUIT: 3 gold. +2 armies on land you owned at the start of this turn. Newly claimed or captured land must wait until next turn. Recruiting uses one of their 2 steps, so they can still move or attack once this turn.",
		"",
		"ARMIES: each army has 2 steps per turn. Moving one tile uses 1 step; attacking uses all that are left.",
		"So an army can move twice, move then attack, or just attack. Winners stop on the captured tile.",
		"Click your tile, then a neighbouring tile:",
		"  your tile -> Move armies there.",
		"  enemy tile -> Attack with the armies you choose to send.",
		"",
		"BATTLE: armies sent + a roll of 0-2 against defenders (+2 on a capital, +5 in a fort) + a roll of 0-2. The attacker must be higher; ties go to the defender. A tile with no armies or defense bonuses falls without a battle.",
		"Each side loses half the other side's armies (rounded up). Winners move in and stop for the turn; a winning attack always keeps at least 1 army. On a captured tile, the defenders lose half the attackers (rounded up); survivors retreat to the neighbouring friendly tile closest to their capital, or are lost if there is none.",
		"",
		"After both kingdoms play: income = 2 + 1 per ordinary tile + 2 per farm tile. Fort tiles earn 0.",
		"",
		"MAP: blue is yours, coral the rival's. Soldiers show armies (one per army, at most three; the tag gives the exact number). A bright dot on the tag means they can still act; grey soldiers are done for this turn. Gold dots: land you can claim. A castle marks each capital. Farms (wheat field, windmill, orchard or pasture; all the same, +1 gold) mark improved tiles. Low stone bastions mark forts (+5 defense, 0 tile income). Coral dots: the rival's last moves.",
		"",
		"RIVAL: pick Easy, Normal, Hard or Expert on the New match screen. Each match the rival also has a hidden personality (Conqueror, Builder, Raider or Guardian; Easy only the gentle two) and its moods vary. At every level it follows the same rules as you, with no bonuses. Its personality is revealed when the match ends.",
	])
	board.game = game
	_load_settings()
	new_match_screen = _build_new_match_screen()
	add_child(new_match_screen)
	if game.map_name != match_settings["map"] or game.difficulty != match_settings["difficulty"]:
		game = EmpireGame.new(-1, match_settings)
		board.game = game
	resized.connect(_update_layout)
	_update_layout()
	status.tooltip_text = "Blue: you. Coral: rival. Soldiers + tag: armies. Bright dot: can still act. Grey: done this turn. Gold dot: claimable land. Coral dot: rival's last moves. Fort: +5 defense, 0 tile income."
	_add_match_info()
	_refresh()
	title_screen = TitleScreen.new()
	title_screen.name = "TitleScreen"
	add_child(title_screen)
	move_child(new_match_screen, -1)
	move_child(rules_dialog, -1)
	title_screen.new_game_pressed.connect(func() -> void: open_new_match_screen(false))
	title_screen.resume_pressed.connect(resume_match)
	title_screen.how_to_play_pressed.connect(func() -> void: rules_dialog.popup_centered())
	title_screen.exit_pressed.connect(func() -> void: get_tree().quit())
	title_screen.options_changed.connect(apply_options)
	apply_options(options, false)
	if show_title_on_start:
		show_title()
	else:
		match_started = true
		title_screen.hide()


# Difficulty and map size of the current match, next to the round counter.
func _add_match_info() -> void:
	match_info = Label.new()
	match_info.name = "MatchInfo"
	match_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	match_info.add_theme_color_override("font_color", MUTED)
	match_info.add_theme_font_size_override("font_size", 12)
	match_info.tooltip_text = "Difficulty and map size. Menu > New Game to change."
	var header: HBoxContainer = $Margin/Layout/Header
	header.add_child(match_info)
	header.move_child(match_info, turn_label.get_index())


# --- New match screen ----------------------------------------------------------

const AiDifficulty = preload("res://game/ai/ai_difficulty.gd")
# Descriptions shown on the New match screen, from the difficulty data.
var DIFFICULTIES := _difficulty_descriptions()


static func _difficulty_descriptions() -> Dictionary:
	var result := {}
	for level: String in AiDifficulty.NAMES:
		result[level] = AiDifficulty.LEVELS[level]["description"]
	return result


const SETTINGS_PATH := "user://settings.cfg"
## Where choices and options are saved (tests use a temporary file).
var settings_path := SETTINGS_PATH


func _load_settings() -> void:
	if not remember_settings:
		return
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var level: String = config.get_value("match", "difficulty", match_settings["difficulty"])
	var map: String = config.get_value("match", "map", match_settings["map"])
	for key: String in options:
		var value: Variant = config.get_value("options", key, options[key])
		if typeof(value) == typeof(options[key]):
			options[key] = value
	if not RIVAL_SPEEDS.has(options["rival_speed"]):
		options["rival_speed"] = "Normal"
	if DIFFICULTIES.has(level):
		match_settings["difficulty"] = level
	if IslandMap.SIZES.has(map):
		match_settings["map"] = map


func _save_settings() -> void:
	if not remember_settings:
		return
	var config := ConfigFile.new()
	config.set_value("match", "difficulty", match_settings["difficulty"])
	config.set_value("match", "map", match_settings["map"])
	for key: String in options:
		config.set_value("options", key, options[key])
	config.save(settings_path)


## Applies options (from the title screen) and saves them.
func apply_options(new_options: Dictionary, save := true) -> void:
	options = new_options.duplicate()
	rival_step_seconds = RIVAL_SPEEDS.get(options["rival_speed"], 0.7)
	board.show_hints = options["show_hints"]
	board.queue_redraw()
	if title_screen != null:
		title_screen.set_options(options)
	# Window mode only applies to a real window (not headless or embedded runs).
	if DisplayServer.get_name() != "headless" and get_window() == get_tree().root and not Engine.is_embedded_in_editor():
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if options["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and (options["fullscreen"] or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(mode)
	if save:
		_save_settings()


## Keep the match in memory while visiting the menu (#6).
func show_title() -> void:
	new_match_screen.hide()
	result_overlay.hide()
	title_screen.options_panel.hide()
	title_screen.set_resume_available(match_started and game.winner == EmpireGame.NEUTRAL)
	title_screen.show()


func resume_match() -> void:
	if not match_started or game.winner != EmpireGame.NEUTRAL:
		push_warning("There is no unfinished match to resume.")
		return
	new_match_screen.hide()
	title_screen.options_panel.hide()
	title_screen.hide()
	_refresh()


## Opens the choice screen. At launch (`first`) there is no match to return
## to, so Cancel is hidden.
func open_new_match_screen(first: bool = false) -> void:
	new_match_screen.get_meta("cancel").visible = not first
	new_match_screen.get_meta("cancel").text = "Back" if title_screen != null and title_screen.visible else "Cancel"
	for group: String in ["difficulty", "map"]:
		var current: String = match_settings[group]
		if group == "map" and not IslandMap.SIZES.has(current):
			current = "Tiny"
		for button: Button in new_match_screen.get_meta(group):
			button.button_pressed = button.get_meta("value") == current
	_update_new_match_notes()
	new_match_screen.show()


func start_new_match(level: String, map: String) -> void:
	match_settings = {"difficulty": level, "map": map}
	_save_settings()
	new_match_screen.hide()
	title_screen.hide()
	_new_match()


func _chosen(group: String) -> String:
	for button: Button in new_match_screen.get_meta(group):
		if button.button_pressed:
			return button.get_meta("value")
	return match_settings[group]


func _update_new_match_notes() -> void:
	var size: Dictionary = IslandMap.SIZES.get(_chosen("map"), IslandMap.SIZES["Tiny"])
	var notes: Label = new_match_screen.get_meta("notes")
	notes.text = "%s\nAbout %d land tiles, %d rounds." % [DIFFICULTIES[_chosen("difficulty")], size["land"], size["rounds"]]


# One screen with every choice: difficulty, map size, start or cancel.
func _build_new_match_screen() -> Control:
	var shade := ColorRect.new()
	shade.name = "NewMatchScreen"
	shade.color = Color(0.025, 0.05, 0.07, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color("#13252b"), Color("#6b5f3a"), 12, Vector2(26, 20)))
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var title := Label.new()
	title.text = "New match"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f0e6c8"))
	box.add_child(title)
	for group: String in ["difficulty", "map"]:
		var heading := Label.new()
		heading.text = "DIFFICULTY" if group == "difficulty" else "MAP SIZE"
		heading.add_theme_color_override("font_color", MUTED)
		heading.add_theme_font_size_override("font_size", 12)
		box.add_child(heading)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var choices := ButtonGroup.new()
		var buttons: Array[Button] = []
		var values: Array = DIFFICULTIES.keys() if group == "difficulty" else IslandMap.SIZE_NAMES
		for value: String in values:
			var choice := Button.new()
			choice.text = value
			choice.toggle_mode = true
			choice.button_group = choices
			choice.focus_mode = Control.FOCUS_NONE
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice.set_meta("value", value)
			choice.add_theme_stylebox_override("pressed", _style(Color("#2f6b5f"), Color("#9fd3c4")))
			choice.toggled.connect(func(_on: bool) -> void: _update_new_match_notes())
			row.add_child(choice)
			buttons.append(choice)
		shade.set_meta(group, buttons)
	var notes := Label.new()
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.custom_minimum_size = Vector2(0, 40)
	notes.add_theme_color_override("font_color", Color("#c3cfcc"))
	box.add_child(notes)
	shade.set_meta("notes", notes)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(actions)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "Cancel"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func() -> void: new_match_screen.hide())
	actions.add_child(cancel)
	var start := Button.new()
	start.name = "Start"
	start.text = "Start match"
	start.focus_mode = Control.FOCUS_NONE
	_button_styles(start, Color("#2f6b5f"), Color("#5fa595"), Color("#f2f7f2"))
	start.pressed.connect(func() -> void: start_new_match(_chosen("difficulty"), _chosen("map")))
	actions.add_child(start)
	shade.set_meta("cancel", cancel)
	shade.set_meta("start", start)
	return shade


# Tall windows (e.g. tiled side by side) put the info panel under the map as a
# row of cards, so the island can use the full width.
const TALL_RATIO := 0.9
const BOTTOM_PANEL_HEIGHT := 210.0
var tall_layout := false


func _update_layout() -> void:
	var tall := size.y > size.x * TALL_RATIO
	if tall == tall_layout and is_node_ready():
		return
	tall_layout = tall
	var play_area: BoxContainer = $Margin/Layout/PlayArea
	var sidebar: VBoxContainer = $Margin/Layout/PlayArea/Sidebar
	var content: BoxContainer = get_node(CONTENT.trim_suffix("/"))
	play_area.vertical = tall
	content.vertical = not tall
	sidebar.custom_minimum_size = Vector2(0, BOTTOM_PANEL_HEIGHT) if tall else Vector2(240, 0)
	sidebar.size_flags_vertical = Control.SIZE_FILL
	var cards := {"SelectionCard": 2.0, "ActionCard": 2.2, "KingdomCard": 1.0, "HistoryCard": 2.0}
	for card: String in cards:
		var panel: Control = get_node(CONTENT + card)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if tall else Control.SIZE_FILL
		panel.size_flags_stretch_ratio = cards[card]
		panel.size_flags_vertical = Control.SIZE_FILL


func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 7, pad := Vector2(9, 4)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad.x
	style.content_margin_right = pad.x
	style.content_margin_top = pad.y
	style.content_margin_bottom = pad.y
	style.anti_aliasing = true
	return style


func _font(base: Font, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _button_styles(button: Button, base: Color, edge: Color, text: Color) -> void:
	button.add_theme_stylebox_override("normal", _style(base, edge))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.1), edge.lightened(0.25)))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.15), edge))
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", text)


func _apply_theme() -> void:
	var palette := Theme.new()
	palette.default_font = _font(BODY_FONT, 560)
	palette.default_font_size = 13
	title_font = _font(TITLE_FONT, 700)
	var bold := _font(BODY_FONT, 800)
	palette.set_color("font_color", "Label", TEXT)
	palette.set_stylebox("normal", "Button", _style(Color("#22383e"), Color("#3a5459")))
	palette.set_stylebox("hover", "Button", _style(Color("#2d4950"), Color("#5f8a90")))
	palette.set_stylebox("pressed", "Button", _style(Color("#172a30"), Color("#5f8a90")))
	palette.set_stylebox("disabled", "Button", _style(Color("#182a2f"), Color("#24363b")))
	palette.set_color("font_color", "Button", Color("#e8ede8"))
	palette.set_color("font_disabled_color", "Button", Color("#6f807f"))
	palette.set_font("font", "Button", bold)
	palette.set_stylebox("panel", "PanelContainer", _style(PANEL, PANEL_EDGE, 8, Vector2(9, 6)))
	palette.set_constant("separation", "HSeparator", 10)
	theme = palette
	var title: Label = $Margin/Layout/Header/Title
	title.add_theme_font_override("font", title_font)
	title.add_theme_color_override("font_color", Color("#f0e6c8"))
	for label in [tile_title, target_title, result_title]:
		label.add_theme_font_override("font", title_font)
		label.add_theme_color_override("font_color", Color("#f0e6c8"))
	for label in [rival_stats, player_stats]:
		label.add_theme_font_override("font", title_font)
		label.add_theme_font_size_override("font_size", 14)
	player_stats.add_theme_color_override("font_color", BLUE)
	rival_stats.add_theme_color_override("font_color", CORAL)
	turn_label.add_theme_color_override("font_color", GOLD)
	turn_label.add_theme_font_override("font", bold)
	turn_label.add_theme_stylebox_override("normal", _style(Color("#2a2a1f"), Color("#6b5f3a"), 12, Vector2(10, 3)))
	_button_styles(end_button, Color("#2f6b5f"), Color("#5fa595"), Color("#f2f7f2"))
	end_button.custom_minimum_size.y = 36
	_button_styles(attack_button, Color("#5a2f2a"), Color("#c47766"), Color("#ffd8cc"))
	for header_button in [$Margin/Layout/Header/Rules, $Margin/Layout/Header/Exit]:
		_button_styles(header_button, Color(0, 0, 0, 0), Color("#3a5459"), Color("#cfdad7"))
	for card in ["SelectionCard", "ActionCard", "KingdomCard", "HistoryCard"]:
		var box: VBoxContainer = get_node(CONTENT + card + "/Box")
		box.add_theme_constant_override("separation", 5)
	for heading: Label in [get_node(CONTENT + "KingdomCard/Box/KingdomTitle"), get_node(CONTENT + "HistoryCard/Box/HistoryTitle")]:
		heading.add_theme_color_override("font_color", MUTED)
		heading.add_theme_font_override("font", bold)
		heading.add_theme_font_size_override("font_size", 12)
	for label in [status, selection_label, history_label, $Margin/Layout/Instructions]:
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", MUTED)
	status.add_theme_color_override("font_color", TEXT)
	status.add_theme_stylebox_override("normal", _style(Color("#13252b"), PANEL_EDGE, 6, Vector2(9, 3)))
	tile_detail.add_theme_color_override("font_color", Color("#c3cfcc"))
	preview.add_theme_color_override("font_color", Color("#c3cfcc"))
	$Result/Center/Card.add_theme_stylebox_override("panel", _style(Color("#13252b"), Color("#6b5f3a"), 14, Vector2(32, 26)))
	_build_stat_chips()


# Top bar: name, then icon + value chips for gold, armies and land.
func _build_stat_chips() -> void:
	for side in [EmpireGame.PLAYER, EmpireGame.RIVAL]:
		var row: HBoxContainer = player_stats.get_parent() if side == EmpireGame.PLAYER else rival_stats.get_parent()
		var color := BLUE if side == EmpireGame.PLAYER else CORAL
		for kind in ["gold", "armies", "land"]:
			var chip := HBoxContainer.new()
			chip.add_theme_constant_override("separation", 4)
			var icon := Icon.new()
			icon.kind = kind
			icon.tint = GOLD if kind == "gold" else color
			icon.custom_minimum_size = Vector2(15, 15)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var value := Label.new()
			value.add_theme_font_override("font", _font(BODY_FONT, 800))
			chip.add_child(icon)
			chip.add_child(value)
			row.add_child(chip)
			stat_values[side][kind] = value
			chip.tooltip_text = {"gold": "Gold (income next round)", "armies": "Armies", "land": "Land tiles"}[kind]


func _new_match() -> void:
	_match_id += 1
	match_started = true
	rival_playing = false
	game = EmpireGame.new(-1, match_settings)
	board.game = game
	result_overlay.hide()
	_select(NO_TILE, NO_TILE)
	status.text = "New %s match on a %s island. Click one of your tiles to begin." % [
		match_settings["difficulty"], match_settings["map"]]
	_refresh()


func _playing() -> bool:
	return game.winner == EmpireGame.NEUTRAL and game.active == EmpireGame.PLAYER \
		and (title_screen == null or not title_screen.visible)


func _select(new_source: Vector2i, new_target: Vector2i) -> void:
	source = new_source
	target = new_target
	board.has_selection = source != NO_TILE
	board.selected_coordinates = source
	board.has_target = target != NO_TILE
	board.target_coordinates = target
	send_count = game.ready.get(source, 0)


# Click your tile, then a neighbour as the target. Clicking the target again,
# or clicking from a tile with no armies left to act, selects that tile instead.
func _on_tile_clicked(tile: Vector2i, _terrain: String) -> void:
	var from_own := source != NO_TILE and game.owners[source] == EmpireGame.PLAYER
	var can_send := from_own and game.ready[source] > 0
	var to_claim := from_own and game.owners[tile] == EmpireGame.NEUTRAL
	if tile != source and tile != target and (can_send or to_claim) and game.are_adjacent(source, tile):
		_select(source, tile)
	elif tile == source and target != NO_TILE:
		_select(source, NO_TILE)
	else:
		_select(tile, NO_TILE)
	_refresh()


func _change_count(delta: int) -> void:
	send_count = clampi(send_count + delta, 1, maxi(1, game.ready.get(source, 0)))
	_refresh()


func _ready_text(tile: Vector2i) -> String:
	var ready_here: int = game.ready[tile]
	if ready_here == 0:
		return "  (none can act)"
	var rested: int = game.fresh[tile]
	if rested == ready_here:
		return "  (%d can act, 2 steps each)" % ready_here
	return "  (%d can act: %d with 2 steps, %d with 1)" % [ready_here, rested, ready_here - rested]


func _target_action() -> String:
	if target == NO_TILE:
		return ""
	match game.owners[target]:
		EmpireGame.PLAYER:
			return "move"
		EmpireGame.RIVAL:
			return "attack"
	return "claim"


func _set_button(button: Button, action: String, tile: Vector2i, to: Vector2i = NO_TILE, count: int = 0) -> String:
	var error := game.action_error(action, tile, to, count)
	button.show()
	button.disabled = not _playing() or not error.is_empty()
	button.tooltip_text = error
	return error


func _refresh() -> void:
	var playing := _playing()
	turn_label.text = "Round %d / %d" % [game.round_number, game.max_rounds]
	match_info.text = "%s  ·  %s" % [game.difficulty, game.map_name]
	player_stats.text = "You"
	rival_stats.text = "Rival"
	for side in [EmpireGame.PLAYER, EmpireGame.RIVAL]:
		stat_values[side]["gold"].text = "%d  (+%d)" % [game.kingdoms[side].gold, game.income(side)]
		stat_values[side]["armies"].text = str(game.total_armies(side))
		stat_values[side]["land"].text = str(game.tile_count(side))
	for control in [recruit_button, improve_button, fort_button, expand_button, target_title,
			count_row, move_button, attack_button]:
		control.hide()
	var reasons: Array[String] = []
	selection_label.text = "Blue: you   Coral: rival   Soldiers + tag: armies   Bright dot: can still act   Grey: done this turn   Coral dot: rival's last moves   Castle: capital   Farm: improved   Fort: +5 defense, 0 income"
	if source == NO_TILE:
		tile_title.text = "Select a tile"
		tile_detail.text = "Click one of your tiles to recruit, improve, or send its armies to a neighbouring tile. Gold dots mark land you can claim."
		preview.text = ""
	else:
		var owner: int = game.owners[source]
		var who := "Unclaimed" if owner == EmpireGame.NEUTRAL else ("Your" if owner == EmpireGame.PLAYER else "Rival")
		tile_title.text = "%s %s" % [who, "capital" if game.is_capital(source) else "land"]
		selection_label.text = "Selected: " + tile_title.text
		var facts: Array[String] = []
		if owner != EmpireGame.NEUTRAL:
			facts.append("Armies: %d%s" % [game.armies[source], _ready_text(source) if owner == EmpireGame.PLAYER else ""])
			if game.is_capital(source):
				facts.append("Capital: defenders count +2.")
			if game.forts.has(source):
				facts.append("Fort: defenders count +5. Maintenance consumes the tile's income.")
			facts.append("Earns %d gold per round%s." % [game.tile_income(source),
				" (farm)" if game.improvements.has(source) else ""])
		else:
			facts.append("Owned land earns +1 gold per round.")
		tile_detail.text = "\n".join(facts)
		preview.text = ""
		if owner == EmpireGame.PLAYER:
			var error := _set_button(recruit_button, "recruit", source)
			if not error.is_empty() and playing:
				reasons.append(error)
			if not game.improvements.has(source) and not game.forts.has(source):
				_set_button(improve_button, "improve", source)
			if not game.forts.has(source):
				_set_button(fort_button, "fort", source)
				fort_button.text = "Replace farm with fort  -  6 gold" if game.improvements.has(source) \
					else "Build fort  -  6 gold, +5 defense"
				fort_button.tooltip_text += "\n+5 defense. This tile will earn 0 gold per round. Replaces any farm permanently."
			if target == NO_TILE:
				preview.text = "Click a neighbouring tile to move, attack or claim. Click a target twice to select it instead." \
					if game.ready[source] > 0 else "These armies cannot act this turn."
		elif owner == EmpireGame.NEUTRAL:
			var error := _set_button(expand_button, "claim", source)
			if not error.is_empty():
				reasons.append(error)
		else:
			preview.text = "To attack, click one of your tiles next to it, then this tile."
	if target != NO_TILE:
		# With a target chosen, explain the target action rather than the tile's.
		reasons.clear()
		_refresh_target(reasons)
	if not reasons.is_empty() and playing:
		preview.text += ("\n\n" if not preview.text.is_empty() else "") + "Not possible now: " + reasons[0]
	var ready_total := 0
	for tile: Vector2i in game.owners:
		if game.owners[tile] == EmpireGame.PLAYER:
			ready_total += game.ready[tile]
	kingdom_hint.text = "%d armies, %d can still act this turn." % [game.total_armies(0), ready_total]
	end_button.disabled = not playing
	end_button.text = "Rival is moving..." if rival_playing else "End turn"
	var recent: Array[String] = []
	for index in range(maxi(0, game.history.size() - 10), game.history.size()):
		recent.append(game.history[index])
	recent.reverse()
	history_label.text = "No moves yet." if recent.is_empty() else "\n".join(recent)
	if game.winner != EmpireGame.NEUTRAL:
		_show_result()
	board.queue_redraw()


func _refresh_target(reasons: Array[String]) -> void:
	var action := _target_action()
	var ready_here: int = game.ready[source]
	send_count = clampi(send_count, 1, maxi(1, ready_here))
	target_title.show()
	if action == "claim":
		target_title.text = "Claim the neighbouring land"
		var error := _set_button(expand_button, "claim", target)
		if not error.is_empty():
			reasons.append(error)
		return
	count_row.show()
	count_label.text = "Send %d of %d" % [send_count, ready_here]
	less_button.disabled = send_count <= 1
	more_button.disabled = send_count >= ready_here
	if action == "move":
		target_title.text = "Move armies"
		var error := _set_button(move_button, "move", source, target, send_count)
		move_button.text = "Move %d %s" % [send_count, "army" if send_count == 1 else "armies"]
		var rested := mini(send_count, game.fresh[source])
		preview.text = "%d will arrive with 1 step left (enough to move or attack again)." % rested if rested > 0 \
			else "They arrive with no steps left this turn."
		if not error.is_empty():
			reasons.append(error)
		return
	target_title.text = "Attack %s" % ("the rival capital" if game.is_capital(target) else "rival land")
	var result := game.battle_preview(target, send_count)
	var error := _set_button(attack_button, "attack", source, target, send_count)
	attack_button.text = "Attack with %d  (%d%% chance)" % [send_count, roundi(result["chance"] * 100.0)]
	var defenders: int = game.armies[target]
	if game.defense(target) == 0:
		preview.text = "Undefended: captured without a battle. %d %s move in." % [send_count, "army" if send_count == 1 else "armies"]
	else:
		var aftermath := ""
		if game.is_capital(target):
			aftermath = " and you win the game"
		elif result["win_retreat"] > 0:
			aftermath = "; %d of theirs retreat" % result["win_retreat"]
		elif result["win_retreat_lost"] > 0:
			aftermath = "; %d of theirs are cut off and lost" % result["win_retreat_lost"]
		var bonuses := " +2 capital" if game.is_capital(target) else ""
		if game.forts.has(target):
			bonuses += " +5 fort"
		preview.text = "Defenders %d%s.\nWin: %d of your armies move in%s.\nLose: you lose %d, they lose %d." % [
			defenders, bonuses, result["win_survivors"],
			aftermath, result["lose_attacker_loss"], result["lose_defender_loss"]]
	if not error.is_empty():
		reasons.append(error)


func _act(action: String) -> void:
	var tile := source
	var to := target
	if action == "claim" and target != NO_TILE:
		tile = target
		to = NO_TILE
	var error := game.execute(action, tile, to, send_count)
	if not error.is_empty():
		status.text = error
		push_warning(error)
		_refresh()
		return
	status.text = game.history.back().get_slice("| ", 1)
	match action:
		"move", "attack":
			# Keep working from the same tile if it still has armies that can act.
			if game.owners.get(source, -1) == EmpireGame.PLAYER and game.ready[source] > 0:
				_select(source, NO_TILE)
			else:
				_select(NO_TILE, NO_TILE)
		"claim":
			_select(NO_TILE, NO_TILE)
		_:
			send_count = game.ready.get(source, 0)
	_refresh()


func _end_turn() -> void:
	if not _playing():
		return
	_select(NO_TILE, NO_TILE)
	var error := game.end_turn()
	if not error.is_empty():
		status.text = error
		push_error(error)
		return
	var match_id := _match_id
	rival_playing = true
	status.text = "The rival is moving..."
	_refresh()
	# Menu visits pause this same turn; a new match cancels it.
	while match_id == _match_id:
		while title_screen.visible and match_id == _match_id:
			await get_tree().process_frame
		if match_id != _match_id:
			return
		if not game.ai_step():
			break
		status.text = "Rival: " + game.history.back().get_slice("| ", 1)
		_refresh()
		if rival_step_seconds > 0.0:
			await get_tree().create_timer(rival_step_seconds).timeout
		else:
			await get_tree().process_frame
	if match_id != _match_id:
		return
	rival_playing = false
	error = game.finish_rival_turn()
	if not error.is_empty():
		status.text = error
		push_error(error)
	elif game.winner == EmpireGame.NEUTRAL:
		status.text = "Your turn. You received %d gold. The rival's moves are marked with coral dots." % game.income(0)
	_refresh()


func _show_result() -> void:
	result_overlay.show()
	var by_capital := game.owners[game.kingdoms[0].capital] != 0 or game.owners[game.kingdoms[1].capital] != 1
	if game.winner == EmpireGame.DRAW:
		result_title.text = "Draw. Equal land after %d rounds." % game.max_rounds
	elif game.winner == EmpireGame.PLAYER:
		result_title.text = "Victory! The rival capital is yours." if by_capital else "Victory! You hold the most land."
	else:
		result_title.text = "Defeat. Your capital has fallen." if by_capital else "Defeat. The rival holds more land."
	var rival := game.ai_personality(EmpireGame.RIVAL)
	result_detail.text = "Round %d. Land: you %d, rival %d.\nThe %s rival was a %s: %s." % [game.round_number,
		game.tile_count(0), game.tile_count(1), game.difficulty, rival.display_name, rival.description]
	status.text = result_title.text
