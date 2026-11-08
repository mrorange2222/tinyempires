extends SceneTree
## Difficulty levels: setup, signature skills, legal play everywhere, and a
## small fixed-seed tournament confirming the order. (A longer tournament for
## tuning: tests/ai_tournament.gd.)

const Game = preload("res://game/empire_game.gd")
const AiDifficulty = preload("res://game/ai/ai_difficulty.gd")
const IslandMap = preload("res://map/island_map.gd")
var failures := 0
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func consistent(game: Game) -> bool:
	for tile: Vector2i in game.owners:
		if game.armies[tile] < 0 or game.ready[tile] < 0 or game.ready[tile] > game.armies[tile]:
			return false
		if game.fresh[tile] < 0 or game.fresh[tile] > game.ready[tile]:
			return false
	return game.kingdoms[0].gold >= 0 and game.kingdoms[1].gold >= 0


func play_out(game: Game) -> bool:
	var legal := true
	var guard := 0
	while game.winner == -1 and guard < 100:
		guard += 1
		game.play_ai_turn()
		legal = legal and consistent(game)
		if game.winner != -1:
			break
		game.end_turn()
		if game.winner == -1:
			game.play_rival_turn()
		legal = legal and consistent(game)
	return legal and game.winner != -1 and game.round_number <= game.max_rounds


## Wins for `high` over `games` side-swapped matches against `low`.
func duel(low: String, high: String, games: int) -> int:
	var wins := 0
	for i in range(games):
		var high_side := i % 2
		var game := Game.new(8100 + i, {"map": "Tiny"})
		game.set_ai_difficulty(high_side, high)
		game.set_ai_difficulty(1 - high_side, low)
		play_out(game)
		if game.winner == high_side:
			wins += 1
	return wins


func _initialize() -> void:
	# Setup: the rival plays the chosen level; Easy only gets gentle personalities.
	check(AiDifficulty.NAMES == ["Easy", "Normal", "Hard", "Expert"], "Four levels in order")
	for level in AiDifficulty.NAMES:
		var game := Game.new(1, {"difficulty": level})
		check(game.difficulty == level and game.ai_levels[1] == level and game.ai_levels[0] == "Normal",
				"Rival plays %s; the player's side stays Normal" % level)
		check(game.ai_players[1].skill == AiDifficulty.LEVELS[level], "Planner uses the %s skills" % level)
	var easy_styles := {}
	for seed_value in range(30):
		easy_styles[Game.new(seed_value, {"difficulty": "Easy"}).ai_styles[1]] = true
	check(easy_styles.keys().all(func(style: String) -> bool: return style in ["Builder", "Guardian"]),
			"Easy rivals are only Builders or Guardians")
	var game := Game.new(2, {"difficulty": "Hard"})
	game.set_ai_style(1, "Raider")
	check(game.ai_players[1].skill == AiDifficulty.LEVELS["Hard"], "Changing personality keeps the level")

	# Gold alone cannot enable a claim-and-recruit strike on fresh land.
	game = Game.new(3, {"difficulty": "Expert"})
	game.end_turn()
	var capital: Vector2i = game.kingdoms[0].capital
	var stage := Game.NO_TILE
	for tile in game.neighbors(capital):
		if game.owners[tile] == Game.NEUTRAL:
			stage = tile
			break
	var link := Game.NO_TILE
	for tile in game.neighbors(stage):
		if game.owners[tile] == Game.NEUTRAL and game.hex_distance(tile, capital) > 1:
			link = tile
			break
	game.owners[link] = 1
	game.kingdoms[1].gold = 30
	game.ai_players[1].mood = 0.0
	var plan: Dictionary = game.ai_players[1]._plan_strike()
	check(plan.is_empty(), "Expert cannot teleport recruits onto newly claimed land")
	game.armies[link] = 12
	game.ready[link] = 12
	game.fresh[link] = 12
	plan = game.ai_players[1]._plan_strike()
	check(plan.get("action", "") == "claim" and plan.get("tile", Game.NO_TILE) == stage,
			"Expert may claim a staging tile for existing rested armies")
	check(game.execute("claim", stage).is_empty(), "Claim staging tile")
	check(not game.action_error("recruit", stage).is_empty(), "Rival recruits cannot spawn on fresh staging tile")
	plan = game.ai_players[1]._plan_strike()
	check(plan.get("action", "") == "move" and plan.get("to", Game.NO_TILE) == stage,
			"Expert moves existing armies into newly claimed staging land")
	var hard := Game.new(3, {"difficulty": "Hard"})
	hard.end_turn()
	hard.owners[link] = 1
	hard.kingdoms[1].gold = 30
	check(hard.ai_players[1]._plan_strike().get("action", "") != "claim", "Hard does not use claim-and-strike")

	# Shared defensive spending: every level knows how to build a useful fort.
	for level in AiDifficulty.NAMES:
		var fortified := Game.new(22, {"difficulty": level})
		var rival_home := fortified.kingdoms[1].capital
		var invader := rival_home + Vector2i(0, -1)
		fortified.owners[invader] = 0
		fortified.armies[invader] = 8
		fortified.end_turn()
		var income_before := fortified.income(1)
		var choice: Dictionary = fortified.ai_players[1]._plan_spend()
		check(choice.get("action", "") == "fort" and choice.get("tile", Game.NO_TILE) == rival_home,
				"%s builds a threatened capital fort" % level)
		check(fortified.execute("fort", rival_home).is_empty() and fortified.income(1) == income_before - 1
				and fortified.kingdoms[1].gold == 0,
				"%s fort follows the same cost and maintenance rules" % level)

	# Expert capital buffer: it claims free land around its own capital.
	game = Game.new(4, {"difficulty": "Expert"})
	game.end_turn()
	var home: Vector2i = game.kingdoms[1].capital
	var free_before := 0
	for tile in game.neighbors(home):
		if game.owners[tile] == Game.NEUTRAL:
			free_before += 1
	game.play_rival_turn()
	var free_after := 0
	for tile in game.neighbors(home):
		if game.owners[tile] == Game.NEUTRAL:
			free_after += 1
	check(free_before == 0 or free_after < free_before, "Expert secures land around its capital")

	# Every level plays legal, complete matches on every map size.
	for level in AiDifficulty.NAMES:
		for size_name in IslandMap.SIZE_NAMES:
			for seed_value in range(2):
				game = Game.new(400 + seed_value, {"map": size_name, "difficulty": level})
				game.set_ai_difficulty(0, level)
				check(play_out(game), "%s plays a legal full match on %s" % [level, size_name])

	# The levels are ordered (fixed seeds, so this is repeatable).
	var results := {}
	for pair in [["Easy", "Normal"], ["Normal", "Hard"], ["Hard", "Expert"]]:
		var wins := duel(pair[0], pair[1], 24)
		results["%s>%s" % [pair[1], pair[0]]] = wins
		check(wins >= 13, "%s beats %s more often than not (%d/24)" % [pair[1], pair[0], wins])
	print("Tournament (24 games each, sides swapped): ", results)

	if failures == 0:
		print("PASS: ", checks, " difficulty checks")
	else:
		printerr("FAIL: ", failures, " / ", checks, " difficulty checks")
	quit(0 if failures == 0 else 1)
