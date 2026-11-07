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


func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for window_size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		root.size = window_size
		for frame in range(10):
			await process_frame
		await _fresh(main)
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
		check(main.exit_dialog.visible and main.exit_dialog.dialog_text.contains("Exit"), "Exit asks for confirmation")
		main.exit_dialog.get_cancel_button().pressed.emit()
		main.exit_dialog.hide()
		check(main.game.winner == -1 and main.is_inside_tree(), "Cancelling exit keeps playing")

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
		await _press(main, main.recruit_button)
		check(game.armies[Vector2i(2, 2)] == 2 and game.ready[Vector2i(2, 2)] == 0 and game.kingdoms[0].gold == 0,
				"Recruit places 2 armies that cannot act yet")
		check(main.recruit_button.disabled and main.preview.text.contains("Need 3 gold"), "Out of gold explained")

		# Attack with fixed dice.
		var enemy := Vector2i(3, 3)
		game.owners[enemy] = 1
		game.armies[enemy] = 2
		game.forced_rolls = [0, 0]
		game.armies[Vector2i(3, 2)] = 3
		game.ready[Vector2i(3, 2)] = 3
		await _tile(main, Vector2i(3, 2))
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
			check(main.end_button.disabled, "Game over disables End turn")
			await _click(main.get_node("Result/Center/Card/Content/Restart"))
			check(not main.result_overlay.visible and main.game.winner == -1 and main.source == Game.NO_TILE,
					"Restart gives a fresh match")

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
		await _fresh(main)
		print("Checked gameplay UI at ", window_size)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot=")) == OK, "Save screenshot")
	if failures == 0:
		print("PASS: ", checks, " gameplay UI checks")
	else:
		printerr("FAIL: ", failures, " / ", checks, " gameplay UI checks")
	quit(0 if failures == 0 else 1)
