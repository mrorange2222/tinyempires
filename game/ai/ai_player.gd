extends RefCounted
## Plans one computer kingdom's moves, one action at a time.
##
## The plan runs in stages: attack, then move armies to the front, then spend
## gold. Each call re-plans from scratch, so armies can move and then attack.
## A personality (ai_personality.gd) supplies the weights; this file holds the
## logic shared by all of them. To react to a new rule, add a stage or a
## consideration here and, if it needs tuning, a field in the personality.

const AiBoard = preload("res://game/ai/ai_board.gd")
const AiDifficulty = preload("res://game/ai/ai_difficulty.gd")

# The EmpireGame, held weakly so the game and its AI players do not keep each
# other alive. Untyped to avoid a circular preload.
var game:
	get:
		return _game.get_ref()
var side: int
var personality: Resource
var rng: RandomNumberGenerator
## Planning skills from the difficulty level (ai_difficulty.gd).
var skill: Dictionary = AiDifficulty.get_level("Normal")
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
	for stage: Callable in [_plan_attack, _plan_strike, _plan_move, _plan_spend]:
		var choice: Dictionary = stage.call()
		if not choice.is_empty():
			return choice
	return {}


func _roll_mood() -> void:
	var roll := rng.randf()
	mood = (-0.1 if roll < 0.2 else (0.12 if roll > 0.8 else 0.0)) * float(skill["mood_scale"])


func _jitter(scale: float = 1.0) -> float:
	return rng.randf() * personality.noise * scale * float(skill["noise_scale"])


func _enemy() -> int:
	return 1 - side


func _endgame() -> bool:
	return game.round_number >= game.max_rounds - 2


# --- Stage 1: attack ---------------------------------------------------------

func _attack_threshold() -> float:
	if _rush():
		# Last round: armies are worth nothing afterwards. Moving last, any
		# chance is worth taking; moving first, keep it to good odds.
		return 0.01 if _moves_last() else 0.5
	if game.round_number < personality.attack_from_round and not _endgame():
		return 1.0
	return clampf(personality.min_chance + float(skill["threshold_shift"]) + mood, 0.5, 1.0)


func _attack_score(target: Vector2i, count: int, chance: float) -> float:
	var score: float = chance * 10.0 - game.hex_distance(target, game.kingdoms[_enemy()].capital) * 0.5
	score += personality.weak_target_bias * (count - game.defense(target))
	score += _jitter()
	if game.is_capital(target):
		score += personality.capital_bonus
	if skill["smart_targets"]:
		score += _target_value(target)
	return score


func _plan_attack() -> Dictionary:
	var enemy := _enemy()
	var threshold := _attack_threshold()
	var home: Vector2i = game.kingdoms[side].capital
	var best := {}
	var best_score := -INF
	for source: Vector2i in game.owners:
		if game.owners[source] != side or game.ready[source] == 0:
			continue
		for target in game.neighbors(source):
			if game.owners[target] != enemy:
				continue
			var keep := 0 if _rush() and _moves_last() else AiBoard.keep_back(game, source, target, enemy)
			var count := mini(game.ready[source], game.armies[source] - keep)
			if count < 1:
				continue
			var chance: float = game.win_chance(count, game.defense(target))
			# Late in the match, a long shot at the capital is worth it.
			var long_shot: bool = game.is_capital(target) and chance >= 0.33 and _endgame()
			# Expert retakes tiles touching its capital at even odds.
			var at_home: bool = skill["capital_buffer"] and game.hex_distance(target, home) == 1
			if chance < threshold and not long_shot and not (at_home and chance >= 0.5):
				continue
			if skill["risk_check"] and _risky_capture(source, target, count):
				continue
			var score := _attack_score(target, count, chance)
			if skill["capital_buffer"] and game.hex_distance(target, game.kingdoms[side].capital) == 1:
				score += 30.0
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
			count = mini(count, game.armies[source] - _capital_reserve())
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
	var options := {"claim": game.NO_TILE, "improve": game.NO_TILE, "fort": game.NO_TILE,
		"defend": game.NO_TILE, "stage": game.NO_TILE}
	var claim_score := -INF
	var defend_urgency := -1000.0
	var fort_urgency := -INF
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
		if options["improve"] == game.NO_TILE and game.action_error("improve", tile).is_empty() and not game.adjacent_to(tile, enemy):
			options["improve"] = tile
		var threat := _threat(tile)
		var need: int = threat - game.defense(tile) + personality.defend_slack
		if not _endgame() and threat >= 2 and need >= 0 and game.action_error("fort", tile).is_empty():
			var urgency := need + (5.0 if game.is_capital(tile) else 0.0)
			if urgency > fort_urgency:
				fort_urgency = urgency
				options["fort"] = tile
		if (game.is_capital(tile) or threat >= 2) and need >= 0 and game.can_recruit_on(tile):
			var urgency := need + (5.0 if game.is_capital(tile) else 0.0) + _jitter(0.3)
			if urgency > defend_urgency:
				defend_urgency = urgency
				options["defend"] = tile
		for target in game.neighbors(tile):
			if game.owners[target] == enemy and game.can_recruit_on(tile):
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
	if _rush():
		# Every claim is a sure tile; leftover gold goes to armies at the front.
		if options["claim"] != none:
			return _buy("claim", options["claim"])
		if options["stage"] != none:
			return _buy("recruit", options["stage"])
	if options["fort"] != none:
		return _buy("fort", options["fort"])
	var land_margin: int = 99 if _endgame() else personality.land_margin
	if game.armies[home] < _capital_reserve() and game.can_recruit_on(home):
		return _buy("recruit", home)
	if skill["capital_buffer"]:
		# Secure approaches so the enemy cannot stage existing armies there.
		for tile in game.neighbors(home):
			if game.action_error("claim", tile).is_empty():
				return _buy("claim", tile)
	if game.round_number % personality.improve_every == 0 and not game.improved_this_turn \
			and options["improve"] != none and not _endgame():
		return _buy("improve", options["improve"])
	if options["defend"] != none:
		return _buy("recruit", options["defend"])
	# Expert invests early: an improvement pays for itself after 3 rounds.
	if skill["early_improve"] and not game.improved_this_turn and options["improve"] != none \
			and game.max_rounds - game.round_number >= 6:
		return _buy("improve", options["improve"])
	var wants_land: bool = game.tile_count(side) <= game.tile_count(_enemy()) + land_margin
	if options["claim"] != none and (options["stage"] == none or wants_land):
		return _buy("claim", options["claim"])
	if options["stage"] != none and skill.get("staging", true):
		return _buy("recruit", options["stage"])
	if options["claim"] != none:
		return _buy("claim", options["claim"])
	if not skill.get("staging", true):
		# Easy keeps its gold for defence and land instead of building up attacks.
		return {}
	return _buy("recruit", home) if game.can_recruit_on(home) else {}


func _buy(action: String, tile: Vector2i) -> Dictionary:
	return {"action": action, "tile": tile}


# --- Skills used by the harder levels ------------------------------------------

## How much an enemy tile is worth taking beyond the land itself.
func _target_value(target: Vector2i) -> float:
	var value := 0.0
	if game.improvements.has(target):
		value += 3.0
	if game.forts.has(target):
		value += 2.0
	value += game.armies[target] * 0.3
	return value


## Strongest attack the enemy could make on `tile` next turn. At Hard and
## above it also counts armies the enemy could recruit next to a valuable tile
## (recruits can attack straight away).
func _threat(tile: Vector2i) -> int:
	var enemy := _enemy()
	var threat := AiBoard.threat(game, tile, enemy)
	if skill["recruit_threat"] and (game.is_capital(tile) or game.improvements.has(tile) or game.forts.has(tile)):
		var recruits: int = (game.kingdoms[enemy].gold + game.income(enemy)) / game.RECRUIT_COST * game.RECRUIT_ARMIES
		for other in game.neighbors(tile):
			if game.owners[other] == enemy:
				threat = maxi(threat, game.armies[other] + recruits)
	return threat


## Endgame rush (Expert): this is the final round of the match.
func _rush() -> bool:
	return skill.get("endgame_rush", false) and game.round_number >= game.max_rounds


## The rival plays second, so its final turn gets no reply.
func _moves_last() -> bool:
	return side == game.RIVAL


## Armies to keep on the capital: the personality's garrison, or at Expert
## enough to hold against the current threat.
func _capital_reserve() -> int:
	if _rush() and _moves_last():
		return 0
	var fort_bonus: int = game.FORT_DEFENSE if game.forts.has(game.kingdoms[side].capital) else 0
	var reserve: int = maxi(0, personality.capital_garrison - fort_bonus)
	if skill["capital_guard"]:
		# Enough that the enemy's strongest one-turn strike has at most a 1 in
		# 3 chance: defenders + capital bonus at least equal to the strike.
		reserve = maxi(reserve, capital_strike_threat() - game.CAPITAL_DEFENSE - fort_bonus)
	return reserve


## Everything the enemy could throw at our capital next turn: armies on enemy
## tiles within two steps (they can gather next to it and still attack), plus
## the armies its gold could recruit next to the capital (recruits can attack).
func capital_strike_threat() -> int:
	var enemy := _enemy()
	var home: Vector2i = game.kingdoms[side].capital
	var total := 0
	var borders_capital := false
	for tile: Vector2i in game.owners:
		if game.owners[tile] != enemy:
			continue
		var distance: int = game.hex_distance(tile, home)
		if distance <= 2:
			total += game.armies[tile]
		if distance == 1:
			borders_capital = true
	if borders_capital:
		total += (game.kingdoms[enemy].gold + game.income(enemy)) / game.RECRUIT_COST * game.RECRUIT_ARMIES
	return total


## Expert: would the enemy most likely take this tile straight back?
func _risky_capture(source: Vector2i, target: Vector2i, count: int) -> bool:
	if game.is_capital(target) or (_rush() and _moves_last()):
		return false
	var survivors: int = game.battle_preview(target, count)["win_survivors"]
	var counter := 0
	for other: Vector2i in game.owners:
		if game.owners[other] == _enemy() and other != target and game.hex_distance(other, target) <= 2:
			counter = maxi(counter, game.armies[other])
	var lost_back: bool = game.win_chance(counter, survivors) >= 0.66
	return lost_back and not game.improvements.has(target) and game.armies[target] < 2


## Smallest army that wins against `defense` with at least `threshold` chance.
func _armies_needed(defense: int, threshold: float) -> int:
	for count in range(1, 80):
		if game.win_chance(count, defense) >= threshold:
			return count
	return 80


## Rested armies on `tile` that can step next door and still attack, keeping
## what the tile itself needs.
func _spare_rested(tile: Vector2i) -> int:
	var keep := 0
	if tile == game.kingdoms[side].capital:
		keep = _capital_reserve()
	elif game.adjacent_to(tile, _enemy()):
		keep = 1
	return clampi(mini(game.fresh[tile], game.armies[tile] - keep), 0, 1000)


# --- Stage 1b: coordinated strike (Hard and Expert) ------------------------------

## Picks an enemy tile that can be taken this turn by gathering rested armies
## from neighbouring tiles and recruiting at the staging tile, then returns
## the next preparation step. The attack stage strikes once enough armies stand
## ready on the staging tile.
func _plan_strike() -> Dictionary:
	if not skill["strikes"]:
		return {}
	# In the final round, claims come first (a sure tile per 3 gold).
	if _rush() and game.kingdoms[side].gold >= game.CLAIM_COST:
		for tile: Vector2i in game.owners:
			if game.action_error("claim", tile).is_empty():
				return {}
	var enemy := _enemy()
	var threshold := _attack_threshold()
	var gold_armies: int = game.kingdoms[side].gold / game.RECRUIT_COST * game.RECRUIT_ARMIES
	var best := {}
	var best_score := -INF
	for target: Vector2i in game.owners:
		if game.owners[target] != enemy:
			continue
		var need := _armies_needed(game.defense(target), threshold)
		for stage in game.neighbors(target):
			# Expert may also stage on neutral land it claims this turn.
			var claim_first: bool = skill["claim_strikes"] and game.action_error("claim", stage).is_empty()
			if game.owners[stage] != side and not claim_first:
				continue
			var keep := 0 if claim_first else AiBoard.keep_back(game, stage, target, enemy)
			var here: int = 0 if claim_first else clampi(mini(game.ready[stage], game.armies[stage] - keep), 0, 1000)
			var helpers := 0
			for other in game.neighbors(stage):
				if game.owners[other] == side:
					helpers += _spare_rested(other)
			var recruits := gold_armies if game.can_recruit_on(stage) else 0
			if here + helpers + recruits < need or here >= need:
				continue
			if skill["risk_check"] and _risky_capture(stage, target, need):
				continue
			var bring := need - here
			var from_gold := maxi(0, bring - helpers)
			var score := 4.0 + _target_value(target) - bring * 0.3 - from_gold * 0.4 + _jitter()
			if claim_first:
				score -= 1.0
			if game.is_capital(target):
				score += personality.capital_bonus * 0.2
			if score > best_score:
				best_score = score
				best = {"target": target, "stage": stage, "need": need, "keep": keep}
	if best.is_empty():
		return {}
	var stage: Vector2i = best["stage"]
	if game.owners[stage] == game.NEUTRAL:
		return _buy("claim", stage)
	var have: int = mini(game.ready[stage], game.armies[stage] - best["keep"])
	var missing: int = best["need"] - have
	for other in game.neighbors(stage):
		if game.owners[other] == side and _spare_rested(other) > 0:
			return {"action": "move", "tile": other, "to": stage, "count": mini(_spare_rested(other), missing)}
	if game.action_error("recruit", stage).is_empty():
		return _buy("recruit", stage)
	return {}
