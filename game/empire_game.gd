extends RefCounted

const IslandMap = preload("res://map/island_map.gd")
const AiPlayer = preload("res://game/ai/ai_player.gd")
const AiPersonalities = preload("res://game/ai/ai_personalities.gd")
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
# Read by the computer player.
var improved_this_turn := false
var ai_actions := 0


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
		ai_rng.seed = seed_value * 7919 + 1
	else:
		rng.randomize()
		ai_rng.randomize()
	var names := AiPersonalities.names()
	for side in [PLAYER, RIVAL]:
		set_ai_style(side, names[ai_rng.randi_range(0, names.size() - 1)])
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
	var defender_loss := mini(defenders, ceili(sent / 2.0))
	var escape := retreat_tile(target)
	return {
		"chance": win_chance(sent, defense(target)),
		"win_survivors": sent - mini(sent - 1, attacker_loss),
		"win_retreat": defenders - defender_loss if escape != NO_TILE else 0,
		"win_retreat_lost": defenders - defender_loss if escape == NO_TILE else 0,
		"retreat_tile": escape,
		"lose_attacker_loss": mini(sent, attacker_loss),
		"lose_defender_loss": defender_loss,
	}


# Where surviving defenders of a captured tile withdraw: the adjacent friendly
# tile closest to their capital (ties: the one with more armies), or none.
func retreat_tile(tile: Vector2i) -> Vector2i:
	var side: int = owners.get(tile, NEUTRAL)
	if side == NEUTRAL:
		return NO_TILE
	var best := NO_TILE
	for other in neighbors(tile):
		if owners[other] != side:
			continue
		if best == NO_TILE:
			best = other
			continue
		var distance := hex_distance(other, kingdoms[side].capital)
		var best_distance := hex_distance(best, kingdoms[side].capital)
		if distance < best_distance or (distance == best_distance and armies[other] > armies[best]):
			best = other
	return best


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
			improved_this_turn = true
			note = "improved a tile (+1 gold per round)."
		"recruit":
			kingdom.gold -= RECRUIT_COST
			armies[tile] += RECRUIT_ARMIES
			# Recruiting uses one of the recruits' two steps.
			ready[tile] += RECRUIT_ARMIES
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
		var escape: Vector2i = preview["retreat_tile"]
		var retreating: int = preview["win_retreat"]
		if escape != NO_TILE:
			armies[escape] += retreating
		owners[target] = active
		armies[target] = survivors
		ready[target] = 0
		fresh[target] = 0
		if target == kingdoms[defender_side].capital:
			winner = active
			return "attacked (%s) and captured the enemy capital!" % dice
		var aftermath := ""
		if retreating > 0:
			aftermath = " %d defenders retreated." % retreating
		elif preview["win_retreat_lost"] > 0:
			aftermath = " %d defenders were cut off and lost." % preview["win_retreat_lost"]
		return "attacked (%s) and captured the tile. %d moved in.%s" % [dice, survivors, aftermath]
	var lost: int = preview["lose_attacker_loss"]
	armies[source] += sent - lost
	armies[target] -= preview["lose_defender_loss"]
	return "attacked (%s) and was repelled. Lost %d, defender lost %d." % [
		dice, lost, preview["lose_defender_loss"]]


func _start_turn(side: int) -> void:
	active = side
	improved_this_turn = false
	ai_actions = 0
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


# --- Computer player ---------------------------------------------------------
# The planning logic lives in game/ai/; personalities are data files there.

var ai_rng := RandomNumberGenerator.new()
var ai_players: Array = [null, null]
## Personality name per side, e.g. "Raider".
var ai_styles: Array[String] = ["", ""]


func set_ai_style(side: int, style_name: String) -> void:
	var personality := AiPersonalities.by_name(style_name)
	assert(personality != null, "Unknown AI personality " + style_name)
	set_ai_personality(side, personality)


## Accepts any personality, including blends made with blended_with().
func set_ai_personality(side: int, personality: Resource) -> void:
	ai_players[side] = AiPlayer.new(self, side, personality, ai_rng)
	ai_styles[side] = personality.display_name


func ai_personality(side: int) -> Resource:
	return ai_players[side].personality


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
	if ai_actions == 0:
		_record("Rival passed.")
	return end_turn()


# Plays the active side's whole turn without ending it. Returns whether it acted.
func play_ai_turn() -> bool:
	var acted := false
	while ai_step():
		acted = true
	return acted


# Makes the active side's next computer move. Returns false when it is done.
func ai_step() -> bool:
	if winner != NEUTRAL:
		return false
	var choice: Dictionary = ai_players[active].next_action()
	if choice.is_empty():
		return false
	var error := execute(choice["action"], choice["tile"], choice.get("to", NO_TILE), choice.get("count", 0))
	assert(error.is_empty(), "AI chose an illegal action: " + error)
	ai_actions += 1
	return true
