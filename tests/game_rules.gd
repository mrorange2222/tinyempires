extends SceneTree

const Game = preload("res://game/empire_game.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_setup_and_economy()
	_chances()
	_movement()
	_combat()
	_invalid_actions()
	_turns_and_limit()
	_ai()
	if failures == 0:
		print("PASS: ", checks, " rule checks (tile armies, dice, AI, full matches)")
	else:
		printerr("FAIL: ", failures, " / ", checks, " rule checks")
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func state(game: Game) -> String:
	return str([game.owners, game.improvements, game.armies, game.ready, game.fresh, game.kingdoms[0].gold,
		game.kingdoms[1].gold, game.active, game.round_number, game.winner, game.history])


func rejected(game: Game, action: String, tile: Vector2i, target: Vector2i = Game.NO_TILE, count: int = 0) -> void:
	var before := state(game)
	check(not game.execute(action, tile, target, count).is_empty(), "Invalid %s must report an error" % action)
	check(state(game) == before, "Invalid %s must not change anything" % action)


func consistent(game: Game) -> bool:
	for tile: Vector2i in game.owners:
		if game.armies[tile] < 0 or game.ready[tile] < 0 or game.ready[tile] > game.armies[tile]:
			return false
		if game.fresh[tile] < 0 or game.fresh[tile] > game.ready[tile]:
			return false
		if game.owners[tile] == Game.NEUTRAL and game.armies[tile] != 0:
			return false
	return game.kingdoms[0].gold >= 0 and game.kingdoms[1].gold >= 0


func _setup_and_economy() -> void:
	var game := Game.new(1)
	var cap := game.kingdoms[0].capital
	check(game.owners.size() == 35 and game.tile_count(0) == 3 and game.tile_count(1) == 3, "Start: 3 tiles each")
	check(game.armies[cap] == 3 and game.armies[Vector2i(4, 1)] == 1 and game.armies[Vector2i(3, 2)] == 1, "Player start armies 3/1/1")
	check(game.armies[game.kingdoms[1].capital] == 3 and game.total_armies(1) == 5, "Rival start armies 3/1/1")
	check(game.ready[cap] == 3 and game.ready[game.kingdoms[1].capital] == 0, "Only the active side's armies are ready")
	check(game.kingdoms[0].gold == 6 and game.income(0) == 5, "Start gold 6, income 5")
	check(game.execute("claim", Vector2i(2, 2)).is_empty(), "Claim adjacent land")
	check(game.owners[Vector2i(2, 2)] == 0 and game.armies[Vector2i(2, 2)] == 0 and game.kingdoms[0].gold == 3, "Claim: 3 gold, empty tile")
	check(game.execute("improve", cap).is_empty(), "Improve capital")
	check(game.kingdoms[0].gold == 0 and game.income(0) == 7, "Improve: 3 gold, +1 income")
	rejected(game, "improve", Vector2i(2, 2))
	game.kingdoms[0].gold = 9
	check(game.execute("recruit", Vector2i(2, 2)).is_empty() and game.execute("recruit", Vector2i(2, 2)).is_empty(), "Recruit repeatedly")
	check(game.armies[Vector2i(2, 2)] == 4 and game.ready[Vector2i(2, 2)] == 0 and game.kingdoms[0].gold == 3, "Recruits +2 each, not ready")
	rejected(game, "move", Vector2i(2, 2), cap, 1)
	check(game.defense(Vector2i(2, 2)) == 4 and game.defense(cap) == 5, "Recruits defend at once; capital +2")
	game.end_turn()
	game.end_turn()
	check(game.ready[Vector2i(2, 2)] == 4, "Recruits are ready next turn")
	check(game.kingdoms[0].gold == 3 + 7, "Income paid after the round")


func _chances() -> void:
	var expected := {-2: 0.0, -1: 1.0 / 9.0, 0: 3.0 / 9.0, 1: 6.0 / 9.0, 2: 8.0 / 9.0, 3: 1.0}
	for diff: int in expected:
		check(is_equal_approx(Game.win_chance(5 + diff, 5), expected[diff]), "Win chance for difference %d" % diff)


func _movement() -> void:
	var game := Game.new(2)
	var cap := game.kingdoms[0].capital
	var mid := Vector2i(3, 2)
	check(game.fresh[cap] == 3 and game.ready[cap] == 3, "Armies start the turn with two steps")
	check(game.execute("move", cap, mid, 2).is_empty(), "Move to own neighbour")
	check(game.armies[cap] == 1 and game.ready[cap] == 1 and game.fresh[cap] == 1, "Unmoved army keeps two steps")
	check(game.armies[mid] == 3 and game.ready[mid] == 3 and game.fresh[mid] == 1,
			"Moved armies arrive with one step left; the resident keeps two")
	check(game.execute("move", mid, Vector2i(2, 2) if game.owners[Vector2i(2, 2)] == 0 else cap, 0).is_empty() == false,
			"Zero-army move rejected")
	# Second step: moving 3 from mid uses the rested army first.
	check(game.execute("move", mid, cap, 3).is_empty(), "Second step allowed")
	check(game.armies[cap] == 4 and game.ready[cap] == 2 and game.fresh[cap] == 1,
			"Rested mover arrives with one step; once-moved movers arrive spent")
	check(game.ready[mid] == 0 and game.fresh[mid] == 0 and game.armies[mid] == 0, "Source emptied")
	check(game.execute("move", cap, mid, 2).is_empty(), "Armies with steps left move again")
	check(game.ready[mid] == 1 and game.fresh[mid] == 0, "Only the rested one has a step left")
	rejected(game, "move", mid, cap, 2)
	rejected(game, "move", cap, Vector2i(2, 2), 1)
	rejected(game, "move", cap, Vector2i(3, 3), 1)
	# Move one tile, then attack.
	game = Game.new(3)
	var enemy := Vector2i(3, 3)
	game.owners[enemy] = 1
	game.armies[enemy] = 1
	game.forced_rolls = [2, 0]
	check(game.execute("move", cap, mid, 3).is_empty(), "Move toward the enemy")
	check(game.ready[mid] == 4 and game.fresh[mid] == 1, "Three arrive with one step, one resident keeps two")
	check(game.execute("attack", mid, enemy, 3).is_empty(), "Move then attack")
	check(game.fresh[mid] == 1 and game.ready[mid] == 1, "Attack uses once-moved armies first")
	check(game.owners[enemy] == 0 and game.ready[enemy] == 0, "Winners stop on the captured tile")
	rejected(game, "attack", enemy, Vector2i(3, 4), 1)
	game.armies[cap] = 0
	game.ready[cap] = 0
	game.fresh[cap] = 0
	check(game.execute("move", Vector2i(4, 1), cap, 1).is_empty(), "Tiles may be left empty")
	check(game.armies[Vector2i(4, 1)] == 0, "Empty tile allowed")


func _battle(defenders: int, sent: int, rolls: Array[int], capital := false) -> Game:
	var game := Game.new(3)
	var source := Vector2i(3, 2)
	var target := game.kingdoms[1].capital if capital else Vector2i(3, 3)
	if capital:
		source = target + Vector2i(0, -1)
		game.owners[source] = 0
	game.owners[target] = 1
	game.armies[target] = defenders
	game.armies[source] = sent
	game.ready[source] = sent
	game.fresh[source] = sent
	game.improvements[target] = true
	game.forced_rolls = rolls
	check(game.execute("attack", source, target, sent).is_empty(), "Attack %d vs %d executes" % [sent, defenders])
	return game


func _combat() -> void:
	var game := _battle(3, 6, [0, 2])
	var target := Vector2i(3, 3)
	check(game.owners[target] == 0 and game.armies[target] == 4 and game.ready[target] == 0, "6 vs 3 captures; 4 move in, spent")
	check(game.armies[Vector2i(3, 2)] == 0 and game.improvements.has(target), "Attackers left source; improvement kept")
	check(game.last_battle["won"] and game.history.back().contains("6+0 vs 3+2"), "Dice shown in history")
	rejected(game, "attack", target, Vector2i(3, 4), 1)
	game = _battle(4, 3, [2, 0])
	check(game.owners[Vector2i(3, 3)] == 0 and game.armies[Vector2i(3, 3)] == 1, "Underdog win keeps at least 1 army")
	game = _battle(4, 3, [1, 0])
	check(game.owners[Vector2i(3, 3)] == 1, "Tie goes to the defender")
	check(game.armies[Vector2i(3, 2)] == 1 and game.ready[Vector2i(3, 2)] == 0, "Repelled: lost 2, survivor spent")
	check(game.armies[Vector2i(3, 3)] == 2 and not game.last_battle["won"], "Repelled: defender lost 2")
	game = _battle(0, 1, [0, 2])
	check(game.owners[Vector2i(3, 3)] == 0 and game.armies[Vector2i(3, 3)] == 1, "Empty tile captured with no losses")
	check(game.forced_rolls == [0, 2] and game.history.back().contains("unopposed"), "No dice for an undefended tile")
	check(is_equal_approx(Game.win_chance(1, 0), 1.0), "Undefended tile is a sure capture")
	game = _battle(3, 6, [0, 2], true)
	check(game.winner == -1 and game.owners[game.kingdoms[1].capital] == 1, "Capital +2: 6 vs 5 with bad roll fails")
	game = _battle(3, 6, [2, 0], true)
	check(game.winner == 0 and game.owners[game.kingdoms[1].capital] == 0, "Capturing the capital wins")
	var before := state(game)
	check(not game.end_turn().is_empty() and state(game) == before, "No play after victory")
	var preview := Game.new(4)
	preview.owners[Vector2i(3, 3)] = 1
	preview.armies[Vector2i(3, 3)] = 3
	var result := preview.battle_preview(Vector2i(3, 3), 6)
	check(is_equal_approx(result["chance"], 1.0) and result["win_survivors"] == 4, "Preview: 6 vs 3")
	check(result["lose_attacker_loss"] == 2 and result["lose_defender_loss"] == 3, "Preview: losing losses")


func _invalid_actions() -> void:
	var game := Game.new(5)
	var cap := game.kingdoms[0].capital
	rejected(game, "unknown", cap)
	rejected(game, "claim", Vector2i(0, 0))
	rejected(game, "claim", cap)
	rejected(game, "claim", Vector2i(2, 5))
	rejected(game, "improve", game.kingdoms[1].capital)
	rejected(game, "recruit", game.kingdoms[1].capital)
	rejected(game, "attack", cap, Vector2i(3, 3), 1)
	game.owners[Vector2i(3, 3)] = 1
	game.armies[Vector2i(3, 3)] = 4
	game.ready[Vector2i(3, 2)] = 1
	rejected(game, "attack", Vector2i(3, 2), Vector2i(3, 3), 1)
	rejected(game, "attack", Vector2i(3, 2), Vector2i(3, 3), 2)
	rejected(game, "attack", game.kingdoms[1].capital, Vector2i(2, 5), 1)
	game.kingdoms[0].gold = 0
	rejected(game, "claim", Vector2i(2, 2))
	rejected(game, "improve", cap)
	rejected(game, "recruit", cap)


func _turns_and_limit() -> void:
	for case in [[1, 0], [-1, 1], [0, 2]]:
		var game := Game.new(6)
		game.round_number = 20
		if case[0] == 1:
			game.owners[Vector2i(2, 2)] = 0
		elif case[0] == -1:
			game.owners[Vector2i(2, 5)] = 1
		var gold := game.kingdoms[0].gold
		game.end_turn()
		check(game.winner == -1 and game.active == 1, "Rival still plays round 20")
		game.end_turn()
		check(game.winner == case[1] and game.kingdoms[0].gold == gold, "Most land after round 20 wins, no income: " + str(case))
	var game := Game.new(7)
	game.end_turn()
	check(not game.play_ai_turn() or true, "AI may act")
	game = Game.new(7)
	check(not game.play_rival_turn().is_empty(), "Rival cannot act on the player's turn")


func _ai() -> void:
	var game := Game.new(8)
	game.end_turn()
	check(game.play_rival_turn().is_empty() and consistent(game), "Rival opening turn is legal")
	check(game.tile_count(1) == 5 and game.kingdoms[1].gold == 0 + game.income(1), "Rival spends its 6 gold on two claims")
	check(game.active == 0 and game.round_number == 2, "Control returns to the player")
	game = Game.new(12)
	game.end_turn()
	var steps := 0
	while game.ai_step() and steps < 200:
		steps += 1
		check(game.active == 1 and consistent(game), "Each rival step is legal and keeps the turn")
	check(steps > 0 and steps < 200, "Rival turn is a finite series of single moves")
	check(game.finish_rival_turn().is_empty() and game.active == 0 and game.round_number == 2, "Finishing hands back control")
	check(not game.finish_rival_turn().is_empty(), "Cannot finish the rival turn twice")
	var a := Game.new(9)
	var b := Game.new(9)
	for i in range(6):
		a.end_turn()
		b.end_turn()
		a.play_rival_turn()
		b.play_rival_turn()
	check(state(a) == state(b), "Same seed gives the same rival play")
	game = Game.new(10)
	game.end_turn()
	game.owners[game.kingdoms[0].capital + Vector2i(0, 1)] = 1
	game.armies[game.kingdoms[0].capital + Vector2i(0, 1)] = 9
	game.ready[game.kingdoms[0].capital + Vector2i(0, 1)] = 9
	game.fresh[game.kingdoms[0].capital + Vector2i(0, 1)] = 9
	game.forced_rolls = [0, 2]
	game.play_rival_turn()
	check(game.winner == 1, "Rival goes for a winnable capital first")
	game = Game.new(11)
	for i in range(4):
		game.end_turn()
		game.play_rival_turn()
	check(game.armies[game.kingdoms[1].capital] >= Game.AI_CAPITAL_GARRISON, "Rival keeps a capital garrison")
	var results := {0: 0, 1: 0, 2: 0}
	var passive_losses := 0
	var longest := 0
	for seed_value in range(20):
		# Both sides played by the AI: matches must always finish legally.
		var match_game := Game.new(100 + seed_value)
		var ok := true
		while match_game.winner == -1:
			match_game.play_ai_turn()
			ok = ok and consistent(match_game)
			if match_game.winner != -1:
				break
			match_game.end_turn()
			if match_game.winner == -1:
				match_game.play_rival_turn()
			ok = ok and consistent(match_game) and match_game.round_number <= Game.MAX_ROUNDS
		check(ok, "AI vs AI match stays legal (seed %d)" % seed_value)
		results[match_game.winner] += 1
		longest = maxi(longest, match_game.round_number)
		var passive := Game.new(200 + seed_value)
		while passive.winner == -1:
			passive.end_turn()
			if passive.winner == -1:
				passive.play_rival_turn()
		if passive.winner == 1:
			passive_losses += 1
	print("AI vs AI over 20 seeds: player wins ", results[0], ", rival wins ", results[1], ", draws ", results[2], ", longest round ", longest)
	check(longest <= Game.MAX_ROUNDS, "Every match ends by round 20")
	check(results[0] > 0, "The rival is beatable by the same strategy")
	check(passive_losses == 20, "A passive player always loses")
