extends RefCounted

const IslandMap = preload("res://map/island_map.gd")
const PLAYER := 0
const RIVAL := 1
const NEUTRAL := -1
const DRAW := 2
const MAX_ROUNDS := 20
const CLAIM_COST := 3
const IMPROVE_COST := 3
const RECRUIT_COST := 3
const RECRUIT_ARMIES := 2
const CAPITAL_DEFENSE := 2
const NO_TILE := Vector2i(-999, -999)
const ACTIONS: Array[String] = ["claim", "improve", "recruit", "move", "attack"]

class Kingdom:
	var gold := 6
	var capital: Vector2i

	func _init(at: Vector2i) -> void:
		capital = at

var terrain: Dictionary[Vector2i, String] = IslandMap.create_tiles()
var owners: Dictionary[Vector2i, int] = {}
var improvements: Dictionary[Vector2i, bool] = {}
var armies: Dictionary[Vector2i, int] = {}
# Armies on a tile that may still move or attack this turn (1 or 2 steps left).
var ready: Dictionary[Vector2i, int] = {}
# Of those, armies that still have both steps (always <= ready).
var fresh: Dictionary[Vector2i, int] = {}
var kingdoms: Array[Kingdom] = [Kingdom.new(Vector2i(3, 1)), Kingdom.new(Vector2i(2, 7))]
var active := PLAYER
var round_number := 1
var winner := NEUTRAL
var history: Array[String] = []
# Tiles the rival changed during its latest turn, for highlighting.
var rival_changes: Array[Vector2i] = []
var last_battle: Dictionary = {}
var rng := RandomNumberGenerator.new()
# Tests may queue dice results (attacker roll, then defender roll).
var forced_rolls: Array[int] = []
var _improved_this_turn := false
var _ai_actions := 0


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for tile: Vector2i in terrain:
		if terrain[tile] != "Water":
			owners[tile] = NEUTRAL
			armies[tile] = 0
			ready[tile] = 0
			fresh[tile] = 0
	for setup in [[PLAYER, [Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 2)]],
			[RIVAL, [Vector2i(2, 7), Vector2i(1, 7), Vector2i(2, 6)]]]:
		for tile: Vector2i in setup[1]:
			owners[tile] = setup[0]
			armies[tile] = 3 if tile == kingdoms[setup[0]].capital else 1
	_start_turn(PLAYER)


func kingdom_name(side: int) -> String:
	return "You" if side == PLAYER else "Rival"


func tile_count(side: int) -> int:
	var count := 0
	for owner: int in owners.values():
		if owner == side:
			count += 1
	return count


func total_armies(side: int) -> int:
	var total := 0
	for tile: Vector2i in owners:
		if owners[tile] == side:
			total += armies[tile]
	return total


func income(side: int) -> int:
	var amount := 2 + tile_count(side)
	for tile: Vector2i in improvements:
		if owners[tile] == side:
			amount += 1
	return amount


func is_capital(tile: Vector2i) -> bool:
	return tile == kingdoms[PLAYER].capital or tile == kingdoms[RIVAL].capital


func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return IslandMap.DIRECTIONS.has(b - a)


func adjacent_to(tile: Vector2i, side: int) -> bool:
	for direction in IslandMap.DIRECTIONS:
		if owners.get(tile + direction, NEUTRAL) == side:
			return true
	return false


func neighbors(tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in IslandMap.DIRECTIONS:
		if owners.has(tile + direction):
			result.append(tile + direction)
	return result


func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var delta := a - b
	return maxi(absi(delta.x), maxi(absi(delta.y), absi(delta.x + delta.y)))


func defense(tile: Vector2i) -> int:
	return armies.get(tile, 0) + (CAPITAL_DEFENSE if is_capital(tile) else 0)


# Chance that `sent` armies beat a defense value when both add a 0-2 roll.
static func win_chance(sent: int, defense_value: int) -> float:
	if defense_value == 0:
		return 1.0
	var wins := 0
	for attacker_roll in range(3):
		for defender_roll in range(3):
			if sent + attacker_roll > defense_value + defender_roll:
				wins += 1
	return wins / 9.0


# Predicted results of an attack; losses depend only on who wins.
func battle_preview(target: Vector2i, sent: int) -> Dictionary:
	var defenders: int = armies.get(target, 0)
	var attacker_loss := ceili(defenders / 2.0)
	return {
		"chance": win_chance(sent, defense(target)),
		"win_survivors": sent - mini(sent - 1, attacker_loss),
		"lose_attacker_loss": mini(sent, attacker_loss),
		"lose_defender_loss": mini(defenders, ceili(sent / 2.0)),
	}


func action_error(action: String, tile: Vector2i, target: Vector2i = NO_TILE, count: int = 0) -> String:
	if winner != NEUTRAL:
		return "The match is over. Start a new match to play again."
	if not ACTIONS.has(action):
		return "Unknown action: " + action
	if not owners.has(tile):
		return "Select a land tile."
	var gold := kingdoms[active].gold
	match action:
		"claim":
			if owners[tile] != NEUTRAL:
				return "Only unclaimed land can be claimed."
			if not adjacent_to(tile, active):
				return "Claim land next to your territory."
			if gold < CLAIM_COST:
				return "Need 3 gold to claim."
		"improve":
			if owners[tile] != active:
				return "Improve a tile you own."
			if improvements.has(tile):
				return "This tile is already improved."
			if gold < IMPROVE_COST:
				return "Need 3 gold to improve."
		"recruit":
			if owners[tile] != active:
				return "Recruit on a tile you own."
			if gold < RECRUIT_COST:
				return "Need 3 gold to recruit."
		"move", "attack":
			if owners[tile] != active:
				return "Start from a tile you own."
			if not owners.has(target) or not are_adjacent(tile, target):
				return "Choose a neighbouring tile."
			if ready[tile] == 0:
				return "No armies here can act this turn."
			if count < 1 or count > ready[tile]:
				return "Send between 1 and %d armies." % ready[tile]
			if action == "move" and owners[target] != active:
				return "Armies can only move to your own land."
			if action == "attack":
				if owners[target] == NEUTRAL or owners[target] == active:
					return "Attack an enemy tile."
				if win_chance(count, defense(target)) == 0.0:
					return "No chance to win: send at least %d armies." % (defense(target) - 1)
	return ""


func execute(action: String, tile: Vector2i, target: Vector2i = NO_TILE, count: int = 0) -> String:
	var error := action_error(action, tile, target, count)
	if not error.is_empty():
		return error
	var kingdom := kingdoms[active]
	var note := ""
	var changed := tile
	match action:
		"claim":
			kingdom.gold -= CLAIM_COST
			owners[tile] = active
			armies[tile] = 0
			ready[tile] = 0
			fresh[tile] = 0
			note = "claimed new land."
		"improve":
			kingdom.gold -= IMPROVE_COST
			improvements[tile] = true
			_improved_this_turn = true
			note = "improved a tile (+1 gold per round)."
		"recruit":
			kingdom.gold -= RECRUIT_COST
			armies[tile] += RECRUIT_ARMIES
			note = "recruited 2 armies."
		"move":
			# Movers with two steps go first; they arrive with one step left.
			var rested := mini(count, fresh[tile])
			fresh[tile] -= rested
			ready[tile] -= count
			armies[tile] -= count
			armies[target] += count
			ready[target] += rested
			changed = target
			note = "moved %d %s." % [count, "army" if count == 1 else "armies"]
		"attack":
			note = _attack(tile, target, count)
			changed = target
	if active == RIVAL:
		rival_changes.append(changed)
	_record("%s %s" % [kingdom_name(active), note])
	return ""


func _roll() -> int:
	if not forced_rolls.is_empty():
		return forced_rolls.pop_front()
	return rng.randi_range(0, 2)


func _attack(source: Vector2i, target: Vector2i, sent: int) -> String:
	var preview := battle_preview(target, sent)
	var defender_side := owners[target]
	var attacker_roll := 0
	var defender_roll := 0
	var won := true
	var dice := "unopposed"
	# An undefended tile (no armies, no capital bonus) falls without a battle.
	if defense(target) > 0:
		attacker_roll = _roll()
		defender_roll = _roll()
		won = sent + attacker_roll > defense(target) + defender_roll
		dice = "%d+%d vs %d+%d" % [sent, attacker_roll, defense(target), defender_roll]
	# Attackers that already moved are used first, keeping rested armies free.
	var tired := ready[source] - fresh[source]
	fresh[source] -= sent - mini(sent, tired)
	armies[source] -= sent
	ready[source] -= sent
	last_battle = {"won": won, "attacker_roll": attacker_roll, "defender_roll": defender_roll,
		"sent": sent, "target": target}
	if won:
		var survivors: int = preview["win_survivors"]
		owners[target] = active
		armies[target] = survivors
		ready[target] = 0
		fresh[target] = 0
		if target == kingdoms[defender_side].capital:
			winner = active
			return "attacked (%s) and captured the enemy capital!" % dice
		return "attacked (%s) and captured the tile. %d moved in." % [dice, survivors]
	var lost: int = preview["lose_attacker_loss"]
	armies[source] += sent - lost
	armies[target] -= preview["lose_defender_loss"]
	return "attacked (%s) and was repelled. Lost %d, defender lost %d." % [
		dice, lost, preview["lose_defender_loss"]]


func _start_turn(side: int) -> void:
	active = side
	_improved_this_turn = false
	_ai_actions = 0
	for tile: Vector2i in owners:
		ready[tile] = armies[tile] if owners[tile] == side else 0
		fresh[tile] = ready[tile]


func end_turn() -> String:
	if winner != NEUTRAL:
		return "The match is over."
	if active == PLAYER:
		rival_changes.clear()
		_start_turn(RIVAL)
		return ""
	if round_number >= MAX_ROUNDS:
		_finish_on_land()
		return ""
	for side in [PLAYER, RIVAL]:
		kingdoms[side].gold += income(side)
	round_number += 1
	_record("Income: you +%d gold, rival +%d gold." % [income(PLAYER), income(RIVAL)])
	_start_turn(PLAYER)
	return ""


func _finish_on_land() -> void:
	var player_land := tile_count(PLAYER)
	var rival_land := tile_count(RIVAL)
	if player_land == rival_land:
		winner = DRAW
	else:
		winner = PLAYER if player_land > rival_land else RIVAL
	_record("Round %d complete. Land: you %d, rival %d." % [MAX_ROUNDS, player_land, rival_land])


func _record(message: String) -> void:
	history.append("R%d | %s" % [round_number, message])
	if history.size() > 80:
		history.pop_front()


# --- Computer player (works for whichever side is active) -------------------

const AI_MIN_CHANCE := 0.66
const AI_CAPITAL_GARRISON := 2


func play_rival_turn() -> String:
	if winner != NEUTRAL or active != RIVAL:
		return "Rival cannot act outside its turn or after the match ends."
	while ai_step():
		pass
	return finish_rival_turn()


func finish_rival_turn() -> String:
	if winner != NEUTRAL:
		return ""
	if active != RIVAL:
		return "It is not the rival's turn."
	if _ai_actions == 0:
		_record("Rival passed.")
	return end_turn()


# Plays the active side's whole turn without ending it. Returns whether it acted.
func play_ai_turn() -> bool:
	var acted := false
	while ai_step():
		acted = true
	return acted


# Makes the active side's next computer move. Returns false when it is done.
# Each call re-plans, so armies can move one step and then attack.
func ai_step() -> bool:
	if winner != NEUTRAL:
		return false
	var me := active
	var choice := _ai_best_attack(me)
	if choice.is_empty():
		choice = _ai_next_move(me)
	if choice.is_empty() and kingdoms[me].gold >= RECRUIT_COST:
		choice = _ai_spend_step(me)
	if choice.is_empty():
		return false
	_must(execute(choice["action"], choice["tile"], choice.get("to", NO_TILE), choice.get("count", 0)))
	_ai_actions += 1
	return true


func _must(error: String) -> void:
	assert(error.is_empty(), "AI chose an illegal action: " + error)


func _ai_best_attack(me: int) -> Dictionary:
	var enemy := 1 - me
	var best := {}
	var best_score := -INF
	for source: Vector2i in owners:
		if owners[source] != me or ready[source] == 0:
			continue
		for target in neighbors(source):
			if owners[target] != enemy:
				continue
			# Keep one army behind if the source still borders other enemy land.
			var keep := 0
			for other in neighbors(source):
				if other != target and owners[other] == enemy:
					keep = 1
			var count := mini(ready[source], armies[source] - keep)
			if count < 1:
				continue
			var chance := win_chance(count, defense(target))
			if chance < AI_MIN_CHANCE and not (is_capital(target) and chance >= 0.33 and round_number >= MAX_ROUNDS - 2):
				continue
			var score := chance * 10.0 - hex_distance(target, kingdoms[enemy].capital)
			if is_capital(target):
				score += 100.0
			if score > best_score:
				best_score = score
				best = {"action": "attack", "tile": source, "to": target, "count": count}
	return best


func _front_distance(tile: Vector2i, enemy: int) -> int:
	var best := 1000
	for other: Vector2i in owners:
		if owners[other] == enemy:
			best = mini(best, hex_distance(tile, other))
	return best


func _ai_next_move(me: int) -> Dictionary:
	var enemy := 1 - me
	for source: Vector2i in owners:
		if owners[source] != me or ready[source] == 0 or adjacent_to(source, enemy):
			continue
		var best_step := NO_TILE
		var best_distance := _front_distance(source, enemy)
		for step in neighbors(source):
			if owners[step] == me and _front_distance(step, enemy) < best_distance:
				best_distance = _front_distance(step, enemy)
				best_step = step
		# The capital always keeps a small garrison.
		var count: int = ready[source]
		if source == kingdoms[me].capital:
			count = mini(count, armies[source] - AI_CAPITAL_GARRISON)
		if best_step != NO_TILE and count > 0:
			return {"action": "move", "tile": source, "to": best_step, "count": count}
	return {}


# Strongest enemy stack that could attack this tile next turn: armies have two
# steps, so stacks up to two tiles away count.
func _threat(tile: Vector2i, enemy: int) -> int:
	var strongest := 0
	for other: Vector2i in owners:
		if owners[other] == enemy and hex_distance(tile, other) <= 2:
			strongest = maxi(strongest, armies[other])
	return strongest


func _ai_spend_step(me: int) -> Dictionary:
	var enemy := 1 - me
	var claim := NO_TILE
	var improve := NO_TILE
	var defend := NO_TILE
	var defend_need := -1000
	var stage := NO_TILE
	var stage_cost := 1000
	for tile: Vector2i in owners:
		if action_error("claim", tile).is_empty():
			if claim == NO_TILE or hex_distance(tile, kingdoms[enemy].capital) < hex_distance(claim, kingdoms[enemy].capital):
				claim = tile
		if owners[tile] != me:
			continue
		if improve == NO_TILE and not improvements.has(tile) and not adjacent_to(tile, enemy):
			improve = tile
		var threat := _threat(tile, enemy)
		var need := threat - defense(tile)
		if (is_capital(tile) or threat >= 2) and need >= 0 and need + (5 if is_capital(tile) else 0) > defend_need:
			defend_need = need + (5 if is_capital(tile) else 0)
			defend = tile
		for target in neighbors(tile):
			if owners[target] == enemy:
				var cost := defense(target) + 1 - armies[tile] - (3 if is_capital(target) else 0)
				if cost < stage_cost:
					stage_cost = cost
					stage = tile
	if armies[kingdoms[me].capital] < AI_CAPITAL_GARRISON:
		return {"action": "recruit", "tile": kingdoms[me].capital}
	if round_number % 3 == 0 and not _improved_this_turn and improve != NO_TILE:
		return {"action": "improve", "tile": improve}
	if defend != NO_TILE:
		return {"action": "recruit", "tile": defend}
	if claim != NO_TILE and (stage == NO_TILE or tile_count(me) <= tile_count(enemy) + 1):
		return {"action": "claim", "tile": claim}
	if stage != NO_TILE:
		return {"action": "recruit", "tile": stage}
	if claim != NO_TILE:
		return {"action": "claim", "tile": claim}
	return {"action": "recruit", "tile": kingdoms[me].capital}
