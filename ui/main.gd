extends Control

const HexBoard = preload("res://ui/hex_board.gd")
const EmpireGame = preload("res://game/empire_game.gd")
const BLUE := Color("#79c8df")
const CORAL := Color("#e8a08d")
const GOLD := Color("#e3ce94")
const NO_TILE := EmpireGame.NO_TILE
const CONTENT := "Margin/Layout/PlayArea/Sidebar/Scroll/Content/"
const SEL := CONTENT + "SelectionCard/Box/"
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
@onready var player_stats: Label = $Margin/Layout/Stats/Player/Row/Label
@onready var rival_stats: Label = $Margin/Layout/Stats/Rival/Row/Label
@onready var status: Label = $Margin/Layout/Legend
@onready var tile_title: Label = get_node(SEL + "TileTitle")
@onready var tile_detail: Label = get_node(SEL + "TileDetail")
@onready var recruit_button: Button = get_node(SEL + "Recruit")
@onready var improve_button: Button = get_node(SEL + "Improve")
@onready var expand_button: Button = get_node(SEL + "Expand")
@onready var target_separator: HSeparator = get_node(SEL + "TargetSeparator")
@onready var target_title: Label = get_node(SEL + "TargetTitle")
@onready var count_row: HBoxContainer = get_node(SEL + "Count")
@onready var count_label: Label = get_node(SEL + "Count/Label")
@onready var less_button: Button = get_node(SEL + "Count/Less")
@onready var more_button: Button = get_node(SEL + "Count/More")
@onready var move_button: Button = get_node(SEL + "Move")
@onready var attack_button: Button = get_node(SEL + "Attack")
@onready var preview: Label = get_node(SEL + "Preview")
@onready var kingdom_hint: Label = get_node(CONTENT + "KingdomCard/Box/KingdomHint")
@onready var history_label: Label = get_node(CONTENT + "HistoryCard/Box/History")
@onready var end_button: Button = $Margin/Layout/PlayArea/Sidebar/EndTurn
@onready var rules_dialog: AcceptDialog = $RulesDialog
@onready var exit_dialog: ConfirmationDialog = $ExitDialog
@onready var result_overlay: ColorRect = $Result
@onready var result_title: Label = $Result/Center/Card/Content/Title
@onready var result_detail: Label = $Result/Center/Card/Content/Detail


func _ready() -> void:
	_apply_theme()
	board.tile_selected.connect(_on_tile_clicked)
	recruit_button.pressed.connect(_act.bind("recruit"))
	improve_button.pressed.connect(_act.bind("improve"))
	expand_button.pressed.connect(_act.bind("claim"))
	move_button.pressed.connect(_act.bind("move"))
	attack_button.pressed.connect(_act.bind("attack"))
	less_button.pressed.connect(_change_count.bind(-1))
	more_button.pressed.connect(_change_count.bind(1))
	end_button.pressed.connect(_end_turn)
	$Margin/Layout/Header/NewMatch.pressed.connect(_new_match)
	$Margin/Layout/Header/Exit.pressed.connect(func() -> void: exit_dialog.popup_centered())
	exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	$Result/Center/Card/Content/Restart.pressed.connect(_new_match)
	$Margin/Layout/Header/Rules.pressed.connect(func() -> void: rules_dialog.popup_centered())
	for button in [recruit_button, improve_button, expand_button, move_button, attack_button,
			less_button, more_button, end_button]:
		button.focus_mode = Control.FOCUS_NONE
		# Long labels must not widen the panel, or the map would jump on selection.
		if button not in [less_button, more_button]:
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for button in [less_button, more_button]:
		button.custom_minimum_size = Vector2(40, 0)
		button.add_theme_font_size_override("font_size", 19)
	less_button.text = "−"
	rules_dialog.dialog_text = "\n".join([
		"GOAL: capture the coral capital to win at once. Otherwise, after round 20 the kingdom with more land wins (equal land is a draw).",
		"",
		"Each turn, spend gold on as many actions as you can afford:",
		"CLAIM: 3 gold. Unclaimed land next to yours. It starts with no armies.",
		"IMPROVE: 3 gold. +1 gold per round. Once per tile.",
		"RECRUIT: 3 gold. +2 armies on a tile you choose. Recruiting uses one of their 2 steps, so they can still move or attack once this turn.",
		"",
		"ARMIES: each army has 2 steps per turn. Moving one tile uses 1 step; attacking uses all that are left.",
		"So an army can move twice, move then attack, or just attack. Winners stop on the captured tile.",
		"Click your tile, then a neighbouring tile:",
		"  your tile -> Move armies there.",
		"  enemy tile -> Attack with the armies you choose to send.",
		"",
		"BATTLE: armies sent + a roll of 0-2 against defenders (+2 on a capital) + a roll of 0-2. The attacker must be higher; ties go to the defender. A tile with no defenders falls without a battle.",
		"Each side loses half the other side's armies (rounded up). Winners move in and stop for the turn; a winning attack always keeps at least 1 army. On a captured tile, the defenders lose half the attackers (rounded up); survivors retreat to the neighbouring friendly tile closest to their capital, or are lost if there is none.",
		"",
		"After both kingdoms play: income = 2 + owned tiles + improvements.",
		"",
		"RIVAL: each match it has a hidden personality (Conqueror, Builder, Raider or Guardian) and its moods vary from turn to turn. It follows the same rules as you, with no bonuses. Its personality is revealed when the match ends.",
	])
	board.game = game
	_refresh()


func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 8, pad := Vector2(12, 8)) -> StyleBoxFlat:
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
	palette.default_font_size = 15
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
	palette.set_stylebox("panel", "PanelContainer", _style(PANEL, PANEL_EDGE, 10, Vector2(14, 12)))
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
		label.add_theme_font_size_override("font_size", 17)
	player_stats.add_theme_color_override("font_color", BLUE)
	rival_stats.add_theme_color_override("font_color", CORAL)
	turn_label.add_theme_color_override("font_color", GOLD)
	turn_label.add_theme_font_override("font", bold)
	turn_label.add_theme_stylebox_override("normal", _style(Color("#2a2a1f"), Color("#6b5f3a"), 14, Vector2(14, 5)))
	_button_styles(end_button, Color("#2f6b5f"), Color("#5fa595"), Color("#f2f7f2"))
	end_button.custom_minimum_size.y = 44
	_button_styles(attack_button, Color("#5a2f2a"), Color("#c47766"), Color("#ffd8cc"))
	for header_button in [$Margin/Layout/Header/Rules, $Margin/Layout/Header/NewMatch, $Margin/Layout/Header/Exit]:
		_button_styles(header_button, Color(0, 0, 0, 0), Color("#3a5459"), Color("#cfdad7"))
	for card in ["SelectionCard", "KingdomCard", "HistoryCard"]:
		var box: VBoxContainer = get_node(CONTENT + card + "/Box")
		box.add_theme_constant_override("separation", 8)
	for heading: Label in [get_node(CONTENT + "KingdomCard/Box/KingdomTitle"), get_node(CONTENT + "HistoryCard/Box/HistoryTitle")]:
		heading.add_theme_color_override("font_color", MUTED)
		heading.add_theme_font_override("font", bold)
		heading.add_theme_font_size_override("font_size", 12)
	for label in [status, selection_label, history_label, $Margin/Layout/Instructions]:
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", MUTED)
	status.add_theme_color_override("font_color", TEXT)
	status.add_theme_stylebox_override("normal", _style(Color("#13252b"), PANEL_EDGE, 8, Vector2(12, 6)))
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
			chip.add_theme_constant_override("separation", 6)
			var icon := Icon.new()
			icon.kind = kind
			icon.tint = GOLD if kind == "gold" else color
			icon.custom_minimum_size = Vector2(18, 18)
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
	rival_playing = false
	game = EmpireGame.new()
	board.game = game
	result_overlay.hide()
	_select(NO_TILE, NO_TILE)
	status.text = "New match. Click one of your tiles to begin."
	_refresh()


func _playing() -> bool:
	return game.winner == EmpireGame.NEUTRAL and game.active == EmpireGame.PLAYER


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
	turn_label.text = "Round %d / %d" % [game.round_number, EmpireGame.MAX_ROUNDS]
	player_stats.text = "You"
	rival_stats.text = "Rival"
	for side in [EmpireGame.PLAYER, EmpireGame.RIVAL]:
		stat_values[side]["gold"].text = "%d  (+%d)" % [game.kingdoms[side].gold, game.income(side)]
		stat_values[side]["armies"].text = str(game.total_armies(side))
		stat_values[side]["land"].text = str(game.tile_count(side))
	for control in [recruit_button, improve_button, expand_button, target_separator, target_title,
			count_row, move_button, attack_button]:
		control.hide()
	var reasons: Array[String] = []
	selection_label.text = "Blue: you   Coral: rival   Soldiers + tag: armies   Bright dot: can still act   Grey: done this turn   Coral dot: rival's last moves   Gold strokes: improved"
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
			facts.append("Earns %d gold per round%s." % [2 if game.improvements.has(source) else 1,
				" (improved)" if game.improvements.has(source) else ""])
		else:
			facts.append("Owned land earns +1 gold per round.")
		tile_detail.text = "\n".join(facts)
		preview.text = ""
		if owner == EmpireGame.PLAYER:
			var error := _set_button(recruit_button, "recruit", source)
			if not error.is_empty() and playing:
				reasons.append(error)
			if not game.improvements.has(source):
				_set_button(improve_button, "improve", source)
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
	target_separator.show()
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
	if defenders == 0 and not game.is_capital(target):
		preview.text = "Undefended: captured without a battle. %d %s move in." % [send_count, "army" if send_count == 1 else "armies"]
	else:
		var aftermath := ""
		if game.is_capital(target):
			aftermath = " and you win the game"
		elif result["win_retreat"] > 0:
			aftermath = "; %d of theirs retreat" % result["win_retreat"]
		elif result["win_retreat_lost"] > 0:
			aftermath = "; %d of theirs are cut off and lost" % result["win_retreat_lost"]
		preview.text = "Defenders %d%s.\nWin: %d of your armies move in%s.\nLose: you lose %d, they lose %d." % [
			defenders, " +2 capital" if game.is_capital(target) else "", result["win_survivors"],
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
	# One rival move at a time; a new match during the turn stops the loop.
	while match_id == _match_id and game.ai_step():
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
		result_title.text = "Draw. Equal land after %d rounds." % EmpireGame.MAX_ROUNDS
	elif game.winner == EmpireGame.PLAYER:
		result_title.text = "Victory! The rival capital is yours." if by_capital else "Victory! You hold the most land."
	else:
		result_title.text = "Defeat. Your capital has fallen." if by_capital else "Defeat. The rival holds more land."
	var rival := game.ai_personality(EmpireGame.RIVAL)
	result_detail.text = "Round %d. Land: you %d, rival %d.\nThe rival was a %s: %s." % [game.round_number,
		game.tile_count(0), game.tile_count(1), rival.display_name, rival.description]
	status.text = result_title.text
