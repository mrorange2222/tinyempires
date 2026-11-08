extends SceneTree

const Game = preload("res://game/empire_game.gd")
const Main = preload("res://ui/main.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _click(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = control.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await process_frame


func _tile(main: Main, tile: Vector2i) -> void:
	var center := main.board.tile_center(tile)
	main.scroll.scroll_horizontal = roundi(center.x - main.scroll.size.x / 2.0)
	main.scroll.scroll_vertical = roundi(center.y - main.scroll.size.y / 2.0)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = main.board.get_global_transform_with_canvas() * center
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await process_frame


func _press(main: Main, button: Button) -> void:
	check(button.visible, "Button is shown: " + button.name)
	if button != main.end_button:
		main.get_node("Margin/Layout/PlayArea/Sidebar/Scroll").ensure_control_visible(button)
	await process_frame
	await _click(button)


func _wait_rival(main: Main) -> void:
	var guard := 0
	while main.rival_playing and guard < 2000:
		guard += 1
		await process_frame
	check(not main.rival_playing, "Rival turn finishes")


func _fresh(main: Main, seed_value: int = 7) -> void:
	main.rival_step_seconds = 0.0
	main._new_match()
	main.game = Game.new(seed_value)
	main.board.game = main.game
	main._refresh()
	await process_frame


func _match_state(game: Game) -> Dictionary:
	return {
		"terrain": game.terrain.duplicate(),
		"owners": game.owners.duplicate(),
		"improvements": game.improvements.duplicate(),
		"forts": game.forts.duplicate(),
		"recruit_tiles": game.recruit_tiles.duplicate(),
		"armies": game.armies.duplicate(),
		"ready": game.ready.duplicate(),
		"fresh": game.fresh.duplicate(),
		"gold": [game.kingdoms[0].gold, game.kingdoms[1].gold],
		"capitals": [game.kingdoms[0].capital, game.kingdoms[1].capital],
		"active": game.active,
		"round": game.round_number,
		"winner": game.winner,
		"history": game.history.duplicate(),
		"rival_changes": game.rival_changes.duplicate(),
		"last_battle": game.last_battle.duplicate(true),
		"map": game.map_name,
		"difficulty": game.difficulty,
		"max_rounds": game.max_rounds,
		"rng": game.rng.state,
		"ai_rng": game.ai_rng.state,
		"ai_actions": game.ai_actions,
	}


func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Tests play on the classic island and leave saved settings alone.
	main.remember_settings = false
	main.show_title_on_start = false
	main.match_settings = {"difficulty": "Normal", "map": "Classic"}
	root.add_child(main)
	current_scene = main
	for window_size in [Vector2i(1280, 800), Vector2i(800, 600), Vector2i(953, 1040)]:
		root.size = window_size
		for frame in range(10):
			await process_frame
		await _fresh(main)
		# Use the real window shape: a tiling window manager may ignore the requested size.
		var tall: bool = main.size.y > main.size.x * 0.9
		check(main.tall_layout == tall, "Layout mode matches window shape at %s" % window_size)
		var play_area: BoxContainer = main.get_node("Margin/Layout/PlayArea")
		check(play_area.vertical == tall, "Info panel sits under the map only in tall windows")
		check(main.board.hex_radius > 60.0, "Island is drawn large (radius %d) at %s" % [main.board.hex_radius, window_size])
		var game: Game = main.game
		var cap := game.kingdoms[0].capital
		check(main.turn_label.text == "Round 1 / 20" and main.stat_values[0]["gold"].text == "6  (+5)"
				and main.stat_values[0]["armies"].text == "5" and main.stat_values[1]["land"].text == "3",
				"Top bar shows round, gold, income, armies and land")
		check(main.title_font != null and main.theme.default_font is FontVariation, "Custom fonts are applied")
		check(not main.recruit_button.visible and not main.move_button.visible and not main.attack_button.visible,
				"No actions shown without a selection")
		await _click(main.get_node("Margin/Layout/Header/Rules"))
		check(main.rules_dialog.visible and main.rules_dialog.dialog_text.contains("BATTLE"), "Rules are accessible")
		main.rules_dialog.hide()
		await _click(main.get_node("Margin/Layout/Header/Exit"))
		check(main.title_screen.visible and main.game == game and main.game.winner == -1,
				"Menu returns immediately without ending the match")
		await _click(main.title_screen.menu_buttons["resume"])
		check(not main.title_screen.visible and main._playing(), "Resume returns to playing")

		var map_width := main.scroll.size.x
		await _tile(main, cap)
		check(main.source == cap and main.tile_title.text == "Your capital", "Select own capital")
		await _tile(main, Vector2i(3, 2))
		check(is_equal_approx(main.scroll.size.x, map_width), "Map does not resize when the panel changes")
		await _tile(main, cap)
		await _tile(main, cap)
		check(main.recruit_button.visible and main.improve_button.visible and main.tile_detail.text.contains("3 can act"),
				"Own tile shows recruit, improve and ready armies")
		await _tile(main, Vector2i(3, 2))
		check(main.source == cap and main.target == Vector2i(3, 2) and main.board.has_target, "Neighbour becomes target")
		check(main.move_button.visible and main.count_label.text == "Send 3 of 3", "Move defaults to all ready armies")
		await _press(main, main.less_button)
		check(main.count_label.text == "Send 2 of 3" and main.move_button.text == "Move 2 armies", "Count control")
		await _press(main, main.move_button)
		check(game.armies[cap] == 1 and game.armies[Vector2i(3, 2)] == 3, "Move executes with chosen count")
		check(main.source == cap and main.target == Game.NO_TILE, "Source stays selected while armies can act")
		await _tile(main, Vector2i(3, 2))
		check(main.source == cap and main.target == Vector2i(3, 2), "Neighbour is targeted first")
		await _tile(main, Vector2i(3, 2))
		check(main.source == Vector2i(3, 2) and main.target == Game.NO_TILE, "Clicking the target again selects it")
		check(main.tile_detail.text.contains("3  (3 can act: 1 with 2 steps, 2 with 1)"),
				"Moved armies keep one step; the resident keeps two")
		await _tile(main, cap)
		check(main.target == cap and main.count_label.text == "Send 3 of 3", "Armies with steps left can be sent")
		check(main.preview.text.contains("1 will arrive with 1 step left"), "Move preview explains steps")
		await _press(main, main.move_button)
		check(game.ready[Vector2i(3, 2)] == 0, "Last ready army moved")
		await _tile(main, cap)
		check(main.source == cap and main.target == Game.NO_TILE, "From a spent tile, a click selects instead")

		await _tile(main, cap)
		await _tile(main, Vector2i(2, 2))
		check(main.target == Vector2i(2, 2) and main.expand_button.visible and not main.expand_button.disabled,
				"Unclaimed neighbour offers Claim")
		await _press(main, main.expand_button)
		check(game.owners[Vector2i(2, 2)] == 0 and game.kingdoms[0].gold == 3 and main.source == Game.NO_TILE,
				"Claim executes and clears selection")
		var distant := Vector2i.ZERO
		for tile: Vector2i in game.owners:
			if game.owners[tile] == -1 and not game.adjacent_to(tile, 0):
				distant = tile
				break
		await _tile(main, distant)
		check(main.expand_button.visible and main.expand_button.disabled and main.preview.text.contains("Not possible now"),
				"Distant land explains why it cannot be claimed")
		await _tile(main, Vector2i(2, 2))
		check(main.recruit_button.disabled and main.preview.text.contains("next turn"), "New land explains recruiting delay")
		check(main.fort_button.visible and main.fort_button.disabled and main.fort_button.tooltip_text.contains("Need 6 gold"),
				"Fort construction shows its affordability and maintenance")
		await _tile(main, cap)
		await _press(main, main.recruit_button)
		check(game.armies[cap] == 6 and game.ready[cap] == 4 and game.fresh[cap] == 1
				and game.kingdoms[0].gold == 0, "Recruit on established land places 2 armies with one step left")
		check(main.tile_detail.text.contains("4 can act: 1 with 2 steps, 3 with 1"), "Recruits shown with one step")
		check(main.recruit_button.disabled and main.preview.text.contains("Need 3 gold"), "Out of gold explained")

		# Attack with fixed dice.
		var enemy := Vector2i(3, 3)
		game.owners[enemy] = 1
		game.armies[enemy] = 2
		game.forced_rolls = [0, 0]
		game.armies[Vector2i(3, 2)] = 3
		game.ready[Vector2i(3, 2)] = 3
		await _tile(main, Vector2i(3, 2))
		await _tile(main, Vector2i(3, 2))
		check(main.source == Vector2i(3, 2), "Second click selects the targeted tile")
		await _tile(main, enemy)
		check(main.attack_button.visible and main.attack_button.text.contains("Attack with 3")
				and main.attack_button.text.contains("67%"), "Attack shows count and chance")
		check(main.preview.text.contains("Defenders 2") and main.preview.text.contains("Win: 2"), "Attack preview outcomes")
		await _press(main, main.less_button)
		check(main.attack_button.text.contains("Attack with 2") and main.attack_button.text.contains("33%"), "Chance follows count")
		await _press(main, main.more_button)
		await _press(main, main.attack_button)
		check(game.owners[enemy] == 0 and game.armies[enemy] == 2 and main.history_label.text.contains("3+0 vs 2+0"),
				"Attack resolves with dice in history")
		var front := Vector2i(4, 3)
		game.owners[front] = 1
		game.armies[front] = 5
		game.owners[Vector2i(4, 4)] = 1
		game.armies[enemy] = 8
		game.ready[enemy] = 8
		main._select(enemy, front)
		main.send_count = 8
		main._refresh()
		check(main.preview.text.contains("1 of theirs retreat"), "Preview shows defenders that would retreat")
		game.owners[Vector2i(4, 4)] = -1
		main._refresh()
		check(main.preview.text.contains("1 of theirs are cut off and lost"), "Preview shows cut-off defenders")
		game.owners[front] = -1
		game.armies[front] = 0
		game.armies[enemy] = 2
		game.ready[enemy] = 0
		main._select(Game.NO_TILE, Game.NO_TILE)
		main._refresh()
		game.owners[Vector2i(4, 2)] = 1
		game.armies[Vector2i(4, 2)] = 9
		game.armies[Vector2i(3, 2)] = 1
		game.ready[Vector2i(3, 2)] = 1
		await _tile(main, Vector2i(3, 2))
		await _tile(main, Vector2i(4, 2))
		check(main.attack_button.disabled and main.preview.text.contains("No chance"), "Hopeless attack is blocked with a reason")

		await _press(main, main.end_button)
		await _wait_rival(main)
		check(game.round_number == 2 and game.active == 0 and main.history_label.text.contains("Rival"),
				"End turn runs the rival and returns control")
		check(game.ready[Vector2i(2, 2)] == game.armies[Vector2i(2, 2)], "Armies are ready again next turn")

		for winner in [0, 1]:
			await _fresh(main)
			game = main.game
			var defender: int = 1 - winner
			var capital := game.kingdoms[defender].capital
			var staging := capital + Vector2i(0, -1 if winner == 0 else 1)
			game.owners[staging] = winner
			game.armies[staging] = 9
			game.armies[capital] = 0
			if winner == 0:
				game.ready[staging] = 9
				await _tile(main, staging)
				await _tile(main, capital)
				await _press(main, main.attack_button)
			else:
				game.end_turn()
				game.ready[staging] = 9
				check(game.execute("attack", staging, capital, 9).is_empty(), "Rival capital capture fixture")
				main._refresh()
			check(main.result_overlay.visible and game.winner == winner, "Victory/defeat screen")
			check(main.result_detail.text.contains("rival was a") and main.result_detail.text.contains(game.ai_styles[1]),
					"Result reveals the rival's personality")
			check(main.end_button.disabled, "Game over disables End turn")
			await _click(main.get_node("Result/Center/Card/Content/Restart"))
			check(main.new_match_screen.visible, "Play another match opens the New match screen")
			await _click(main.new_match_screen.get_meta("start"))
			check(not main.new_match_screen.visible and not main.result_overlay.visible and main.game.winner == -1
					and main.source == Game.NO_TILE, "Restart gives a fresh match")
			main.game.winner = winner
			main._refresh()
			await _click(main.get_node("Result/Center/Card/Content/MainMenu"))
			check(main.title_screen.visible and not main.result_overlay.visible and not main.new_match_screen.visible,
					"Victory/defeat Main Menu returns directly to the title")
			check(not main.title_screen.menu_buttons["resume"].visible, "Result Main Menu does not offer Resume for a finished match")
			await _click(main.title_screen.menu_buttons["new_game"])
			await _click(main.new_match_screen.get_meta("start"))
			check(not main.title_screen.visible and main.game.winner == Game.NEUTRAL,
					"New Game works after leaving the result screen")

		await _fresh(main)
		main.game.round_number = 20
		for extra in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]:
			main.game.owners[extra] = 0
		await _press(main, main.end_button)
		await _wait_rival(main)
		check(main.result_overlay.visible and main.result_title.text.contains("most land"), "Round-limit victory screen")
		check(main.stat_values[0]["land"].text == str(main.game.tile_count(0)), "Top bar land matches")
		# Timed rival turn: moves arrive one at a time and the player waits.
		await _fresh(main)
		main.rival_step_seconds = 0.05
		await _press(main, main.end_button)
		check(main.rival_playing and main.end_button.disabled and main.end_button.text == "Rival is moving...",
				"End turn is locked while the rival moves")
		var seen := main.game.history.size()
		await create_timer(0.08).timeout
		check(main.rival_playing and main.game.history.size() > seen and main.game.active == 1,
				"Rival moves appear one by one")
		check(main.status.text.begins_with("Rival: ") and not main.game.rival_changes.is_empty(), "Status shows the rival's move")
		await _wait_rival(main)
		check(main.game.active == 0 and main.game.round_number == 2 and not main.end_button.disabled, "Control returns after the rival")
		main.rival_step_seconds = 0.05
		await _press(main, main.end_button)
		main._new_match()
		await create_timer(0.3).timeout
		check(main.game.round_number == 1 and main.game.active == 0 and main.game.history.is_empty(),
				"New match during the rival turn stops it cleanly")
		# Menu > New Game: Back keeps the match available for Resume.
		await _fresh(main)
		var before_match := main.game
		check(not main.has_node("Margin/Layout/Header/NewMatch"), "No New Match button in the top bar")
		await _click(main.get_node("Margin/Layout/Header/Exit"))
		await _click(main.title_screen.menu_buttons["new_game"])
		check(main.new_match_screen.visible, "Menu > New Game opens the choice screen")
		check(main.new_match_screen.get_meta("difficulty").size() == 4 and main.new_match_screen.get_meta("map").size() == 3,
				"Four difficulties and three map sizes offered")
		await _click(main.new_match_screen.get_meta("cancel"))
		check(not main.new_match_screen.visible and main.title_screen.visible and main.game == before_match,
				"Back keeps the current match on the menu")
		await _click(main.title_screen.menu_buttons["resume"])
		for level in ["Easy", "Expert"]:
			for map_size in ["Minuscule", "Small"]:
				await _click(main.get_node("Margin/Layout/Header/Exit"))
				await _click(main.title_screen.menu_buttons["new_game"])
				for button: Button in main.new_match_screen.get_meta("difficulty"):
					if button.get_meta("value") == level:
						await _click(button)
				for button: Button in main.new_match_screen.get_meta("map"):
					if button.get_meta("value") == map_size:
						await _click(button)
				var notes: Label = main.new_match_screen.get_meta("notes")
				check(notes.text.contains(str(Game.IslandMap.SIZES[map_size]["rounds"])) and notes.text.contains(main.DIFFICULTIES[level]),
						"Notes describe %s on %s" % [level, map_size])
				await _click(main.new_match_screen.get_meta("start"))
				check(main.game.difficulty == level and main.game.map_name == map_size, "Start uses %s on %s" % [level, map_size])
				check(main.game.max_rounds == Game.IslandMap.SIZES[map_size]["rounds"] and main.turn_label.text.ends_with(
						"/ %d" % main.game.max_rounds), "Round limit follows the map size")
				check(main.status.text.contains(level) and main.status.text.contains(map_size), "Status names the new match")
				var home: Vector2i = main.game.kingdoms[0].capital
				await _tile(main, home)
				check(main.source == home and main.tile_title.text == "Your capital", "Generated map is playable by clicking")
		main.match_settings = {"difficulty": "Normal", "map": "Classic"}
		await _fresh(main)
		await _tile(main, main.game.kingdoms[0].capital)
		check(main.fort_button.visible and not main.fort_button.disabled, "Fort is available on the capital")
		await _press(main, main.fort_button)
		check(main.game.defense(main.source) == 10 and main.tile_detail.text.contains("+5")
				and main.tile_detail.text.contains("Earns 0") and main.stat_values[0]["gold"].text == "0  (+4)",
				"Fort UI shows stacked defense, zero tile income and exact kingdom income")
		check(not main.fort_button.visible and not main.improve_button.visible, "Fort cannot be rebuilt or replaced with a farm")
		var fortified_enemy := Vector2i(3, 3)
		main.game.owners[fortified_enemy] = 1
		main.game.forts[fortified_enemy] = true
		main.game.armies[Vector2i(3, 2)] = 8
		main.game.ready[Vector2i(3, 2)] = 8
		await _tile(main, Vector2i(3, 2))
		await _tile(main, Vector2i(3, 2))
		await _tile(main, fortified_enemy)
		check(main.attack_button.text.contains("100%") and main.preview.text.contains("Defenders 0 +5 fort")
				and not main.preview.text.contains("Undefended"), "Empty fort preview includes defense and a real battle")
		await _fresh(main)
		main.game.kingdoms[0].gold = 9
		await _tile(main, main.game.kingdoms[0].capital)
		await _press(main, main.improve_button)
		check(main.fort_button.text.contains("Replace farm"), "Farm replacement is clearly labelled")
		await _press(main, main.fort_button)
		check(not main.game.improvements.has(main.source) and main.game.forts.has(main.source),
				"Replacing farm builds fort through the UI")
		await _fresh(main)
		print("Checked gameplay UI at ", window_size)

	# Launch: the title screen comes first; New Game opens the match choices.
	main.queue_free()
	await process_frame
	var launched: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	launched.remember_settings = false
	root.add_child(launched)
	current_scene = launched
	for frame in range(5):
		await process_frame
	var title: Control = launched.title_screen
	check(title.visible and not launched.new_match_screen.visible, "Launch shows the title screen")
	check(title.menu_buttons.keys() == ["resume", "new_game", "how_to_play", "options", "exit"],
			"Menu: Resume, New Game, How to Play, Options, Exit Game")
	check(not title.menu_buttons["resume"].visible, "No Resume before starting a match")
	check(title.menu_buttons["exit"].text == "Exit Game", "Exit Game is labelled clearly")
	await _click(title.menu_buttons["how_to_play"])
	check(launched.rules_dialog.visible and launched.rules_dialog.dialog_text.contains("BATTLE"), "How to Play shows the rules")
	launched.rules_dialog.hide()
	await _click(title.menu_buttons["new_game"])
	check(launched.new_match_screen.visible and launched.new_match_screen.get_meta("cancel").visible
			and launched.new_match_screen.get_meta("cancel").text == "Back", "New Game opens match choices with Back")
	await _click(launched.new_match_screen.get_meta("cancel"))
	check(title.visible and not launched.new_match_screen.visible, "Back returns to the title screen")
	check(not title.menu_buttons["resume"].visible, "Cancelling initial setup does not create a resumable match")
	await _click(title.menu_buttons["new_game"])
	for button: Button in launched.new_match_screen.get_meta("difficulty"):
		if button.get_meta("value") == "Hard":
			await _click(button)
	for button: Button in launched.new_match_screen.get_meta("map"):
		if button.get_meta("value") == "Minuscule":
			await _click(button)
	await _click(launched.new_match_screen.get_meta("start"))
	check(not title.visible and not launched.new_match_screen.visible and launched.game.difficulty == "Hard"
			and launched.game.map_name == "Minuscule", "Start plays the chosen match")
	check(launched.match_info.text == "Hard  ·  Minuscule", "Top bar shows difficulty and map size")
	launched.open_new_match_screen()
	check(launched.new_match_screen.get_meta("cancel").text == "Cancel", "In a match the screen offers Cancel")
	launched.new_match_screen.hide()

	# Options: rival speed, map hints, display; applied at once.
	launched.show_title()
	await process_frame
	await _click(title.menu_buttons["options"])
	check(title.options_panel.visible, "Options opens its panel")
	var speed_buttons: Array = title._option_buttons["rival_speed"]
	var hint_buttons: Array = title._option_buttons["show_hints"]
	var display_buttons: Array = title._option_buttons["fullscreen"]
	check(speed_buttons.size() == 3 and hint_buttons.size() == 2 and display_buttons.size() == 2, "Three options with their choices")
	await _click(speed_buttons[2])
	check(is_equal_approx(launched.rival_step_seconds, 1.0) and launched.options["rival_speed"] == "Slow", "Slow rival speed applies")
	await _click(speed_buttons[0])
	check(is_equal_approx(launched.rival_step_seconds, 0.4), "Fast rival speed applies")
	await _click(hint_buttons[1])
	check(not launched.board.show_hints and launched.options["show_hints"] == false, "Map hints can be turned off")
	await _click(hint_buttons[0])
	check(launched.board.show_hints, "Map hints can be turned back on")
	await _click(title.options_panel.get_meta("done"))
	check(not title.options_panel.visible and title.visible, "Done closes Options")

	# Menu returns immediately and keeps the current match.
	launched.start_new_match("Normal", "Tiny")
	await process_frame
	var home := launched.game.kingdoms[0].capital
	await _tile(launched, home)
	await _press(launched, launched.recruit_button)
	await _press(launched, launched.improve_button)
	for neighbor: Vector2i in launched.game.owners:
		if neighbor != home and launched.game.owners[neighbor] == Game.PLAYER:
			await _tile(launched, neighbor)
			break
	await _press(launched, launched.less_button)
	var preserved_game := launched.game
	var preserved_state := _match_state(preserved_game)
	var preserved_selection := [launched.source, launched.target, launched.send_count]
	var preserved_scroll := Vector2i(launched.scroll.scroll_horizontal, launched.scroll.scroll_vertical)
	var preserved_status := launched.status.text
	var menu_button: Button = launched.get_node("Margin/Layout/Header/Exit")
	check(menu_button.text == "Menu", "In-game button is Menu")
	await _click(menu_button)
	check(title.visible and launched.is_inside_tree(), "Menu returns directly to the title screen")
	check(title.menu_buttons["resume"].visible and not launched._playing(), "Resume is offered and gameplay is blocked on the menu")
	launched._end_turn()
	await create_timer(0.1).timeout
	check(_match_state(launched.game) == preserved_state, "Menu does not change the current match")
	await _click(title.menu_buttons["new_game"])
	await _click(launched.new_match_screen.get_meta("cancel"))
	check(title.visible and title.menu_buttons["resume"].visible and launched.game == preserved_game,
			"Backing out of New Game keeps Resume and the same match")
	await _click(title.menu_buttons["resume"])
	check(not title.visible and launched.game == preserved_game and launched.board.game == preserved_game
			and _match_state(launched.game) == preserved_state, "Resume preserves the board, resources, armies, steps, turn and settings")
	check([launched.source, launched.target, launched.send_count] == preserved_selection
			and Vector2i(launched.scroll.scroll_horizontal, launched.scroll.scroll_vertical) == preserved_scroll
			and launched.status.text == preserved_status, "Resume preserves selection, send count, scroll and status")
	check(launched._playing() and not launched.end_button.disabled, "Resume restores player controls")

	# Pausing the rival preserves its exact turn, including randomness.
	launched.match_settings = {"difficulty": "Normal", "map": "Classic"}
	await _fresh(launched)
	var uninterrupted := Game.new(7)
	check(uninterrupted.end_turn().is_empty(), "Uninterrupted rival fixture starts")
	while uninterrupted.ai_step():
		pass
	check(uninterrupted.finish_rival_turn().is_empty(), "Uninterrupted rival fixture finishes")
	launched.rival_step_seconds = 0.05
	launched._end_turn()
	for visit in range(2):
		launched.show_title()
		var paused_state := _match_state(launched.game)
		await create_timer(0.15).timeout
		check(launched.rival_playing and launched.game.active == Game.RIVAL
				and _match_state(launched.game) == paused_state, "Menu pauses the rival, including income and RNG (visit %d)" % visit)
		await _click(title.menu_buttons["resume"])
	await _wait_rival(launched)
	check(_match_state(launched.game) == _match_state(uninterrupted),
			"Resumed rival matches uninterrupted play exactly: no duplicated actions or income")

	# Replacing a paused match cancels its pending rival turn.
	launched._end_turn()
	launched.show_title()
	var replaced_game := launched.game
	await create_timer(0.1).timeout
	launched.start_new_match("Easy", "Minuscule")
	await create_timer(0.15).timeout
	check(launched.game != replaced_game and launched.game.round_number == 1 and launched.game.active == Game.PLAYER
			and launched.game.history.is_empty() and not launched.rival_playing and not title.visible,
			"New Game replaces the paused match without old rival actions leaking into it")
	launched.game.winner = Game.PLAYER
	launched._refresh()
	launched.show_title()
	check(not title.menu_buttons["resume"].visible, "Finished matches cannot be resumed")
	launched.start_new_match("Normal", "Tiny")
	check(not launched.result_overlay.visible and launched.game.winner == Game.NEUTRAL,
			"New Game after a finished match clears the result")

	# Options and match choices are saved and restored on the next launch.
	var temp_path := "user://test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	var first: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	first.settings_path = temp_path
	root.add_child(first)
	await process_frame
	first.apply_options({"rival_speed": "Slow", "fullscreen": false, "show_hints": false})
	first.start_new_match("Expert", "Small")
	first.queue_free()
	await process_frame
	var second: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	second.settings_path = temp_path
	root.add_child(second)
	await process_frame
	check(second.options["rival_speed"] == "Slow" and not second.options["show_hints"]
			and is_equal_approx(second.rival_step_seconds, 1.0) and not second.board.show_hints, "Options are restored")
	check(second.match_settings == {"difficulty": "Expert", "map": "Small"}, "Match choices are restored")
	var speed: Array = second.title_screen._option_buttons["rival_speed"]
	check(speed[2].button_pressed and not speed[1].button_pressed, "Options panel shows the saved choices")
	second.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot=")) == OK, "Save screenshot")
	if failures == 0:
		print("PASS: ", checks, " gameplay UI checks")
	else:
		printerr("FAIL: ", failures, " / ", checks, " gameplay UI checks")
	quit(0 if failures == 0 else 1)
