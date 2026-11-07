extends RefCounted
## Plans one computer kingdom's moves, one action at a time.
##
## The plan runs in stages: attack, then move armies to the front, then spend
## gold. Each call re-plans from scratch, so armies can move and then attack.
## A personality (ai_personality.gd) supplies the weights; this file holds the
## logic shared by all of them. To react to a new rule, add a stage or a
## consideration here and, if it needs tuning, a field in the personality.

const AiBoard = preload("res://game/ai/ai_board.gd")

# The EmpireGame, held weakly so the game and its AI players do not keep each
# other alive. Untyped to avoid a circular preload.
var game:
	get:
		return _game.get_ref()
var side: int
var personality: Resource
var rng: RandomNumberGenerator
## This turn's mood: negative is bolder, positive more hesitant.
var mood := 0.0


var _game: WeakRef


func _init(game_ref, player_side: int, traits: Resource, random: RandomNumberGenerator) -> void:
	_game = weakref(game_ref)
	side = player_side
	personality = traits
	rng = random


## The next action as {action, tile, to?, count?}, or {} when the turn is done.
func next_action() -> Dictionary:
	if game.ai_actions == 0:
		_roll_mood()
	for stage: Callable in [_plan_attack, _plan_move, _plan_spend]:
		var choice: Dictionary = stage.call()
		if not choice.is_empty():
			return choice
	return {}


func _roll_mood() -> void:
	var roll := rng.randf()
	mood = -0.1 if roll < 0.2 else (0.12 if roll > 0.8 else 0.0)


func _jitter(scale: float = 1.0) -> float:
	return rng.randf() * personality.noise * scale


func _enemy() -> int:
	return 1 - side


func _endgame() -> bool:
	return game.round_number >= game.MAX_ROUNDS - 2


# --- Stage 1: attack ---------------------------------------------------------

func _attack_threshold() -> float:
	if game.round_number < personality.attack_from_round and not _endgame():
		return 1.0
	return clampf(personality.min_chance + mood, 0.5, 1.0)


func _attack_score(target: Vector2i, count: int, chance: float) -> float:
	var score: float = chance * 10.0 - game.hex_distance(target, game.kingdoms[_enemy()].capital) * 0.5
	score += personality.weak_target_bias * (count - game.defense(target))
	score += _jitter()
	if game.is_capital(target):
		score += personality.capital_bonus
	return score


func _plan_attack() -> Dictionary:
	var enemy := _enemy()
	var threshold := _attack_threshold()
	var best := {}
	var best_score := -INF
	for source: Vector2i in game.owners:
		if game.owners[source] != side or game.ready[source] == 0:
			continue
		for target in game.neighbors(source):
			if game.owners[target] != enemy:
				continue
			var count := mini(game.ready[source], game.armies[source] - AiBoard.keep_back(game, source, target, enemy))
			if count < 1:
				continue
			var chance: float = game.win_chance(count, game.defense(target))
			# Late in the match, a long shot at the capital is worth it.
			var long_shot: bool = game.is_capital(target) and chance >= 0.33 and _endgame()
			if chance < threshold and not long_shot:
				continue
			var score := _attack_score(target, count, chance)
			if score > best_score:
				best_score = score
				best = {"action": "attack", "tile": source, "to": target, "count": count}
	return best


# --- Stage 2: move armies toward the front -----------------------------------

func _plan_move() -> Dictionary:
	for source: Vector2i in game.owners:
		if game.owners[source] != side or game.ready[source] == 0 or game.adjacent_to(source, _enemy()):
			continue
		var options := AiBoard.steps_toward_front(game, source, side)
		var count: int = game.ready[source]
		if source == game.kingdoms[side].capital:
			count = mini(count, game.armies[source] - personality.capital_garrison)
		if not options.is_empty() and count > 0:
			var step := options[rng.randi_range(0, options.size() - 1)]
			return {"action": "move", "tile": source, "to": step, "count": count}
	return {}


# --- Stage 3: spend gold -----------------------------------------------------

func _plan_spend() -> Dictionary:
	if game.kingdoms[side].gold < game.RECRUIT_COST:
		return {}
	return _choose_spending(_scan_spending_options())


## Finds the best tile for each kind of spending.
func _scan_spending_options() -> Dictionary:
	var enemy := _enemy()
	var options := {"claim": game.NO_TILE, "improve": game.NO_TILE, "defend": game.NO_TILE, "stage": game.NO_TILE}
	var claim_score := -INF
	var defend_urgency := -1000.0
	var stage_cost := INF
	var claim_toward: Vector2i = game.kingdoms[side].capital if personality.claim_near_home else game.kingdoms[enemy].capital
	for tile: Vector2i in game.owners:
		if game.action_error("claim", tile).is_empty():
			var score: float = -game.hex_distance(tile, claim_toward) + _jitter(0.7)
			if score > claim_score:
				claim_score = score
				options["claim"] = tile
		if game.owners[tile] != side:
			continue
		if options["improve"] == game.NO_TILE and not game.improvements.has(tile) and not game.adjacent_to(tile, enemy):
			options["improve"] = tile
		var threat := AiBoard.threat(game, tile, enemy)
		var need: int = threat - game.defense(tile) + personality.defend_slack
		if (game.is_capital(tile) or threat >= 2) and need >= 0:
			var urgency := need + (5.0 if game.is_capital(tile) else 0.0) + _jitter(0.3)
			if urgency > defend_urgency:
				defend_urgency = urgency
				options["defend"] = tile
		for target in game.neighbors(tile):
			if game.owners[target] == enemy:
				var cost := AiBoard.staging_cost(game, tile, target) + _jitter(0.5)
				if game.is_capital(target):
					cost -= personality.capital_staging
				if cost < stage_cost:
					stage_cost = cost
					options["stage"] = tile
	return options


## Picks what to buy, in priority order.
func _choose_spending(options: Dictionary) -> Dictionary:
	var home: Vector2i = game.kingdoms[side].capital
	var none: Vector2i = game.NO_TILE
	var land_margin: int = 99 if _endgame() else personality.land_margin
	if game.armies[home] < personality.capital_garrison:
		return _buy("recruit", home)
	if game.round_number % personality.improve_every == 0 and not game.improved_this_turn \
			and options["improve"] != none and not _endgame():
		return _buy("improve", options["improve"])
	if options["defend"] != none:
		return _buy("recruit", options["defend"])
	var wants_land: bool = game.tile_count(side) <= game.tile_count(_enemy()) + land_margin
	if options["claim"] != none and (options["stage"] == none or wants_land):
		return _buy("claim", options["claim"])
	if options["stage"] != none:
		return _buy("recruit", options["stage"])
	if options["claim"] != none:
		return _buy("claim", options["claim"])
	return _buy("recruit", home)


func _buy(action: String, tile: Vector2i) -> Dictionary:
	return {"action": action, "tile": tile}
