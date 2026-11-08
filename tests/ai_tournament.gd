extends SceneTree
## Long tournament between difficulty levels, for tuning (not part of the
## routine checks). Usage: godot --headless --path . --script res://tests/ai_tournament.gd -- Tiny
const Game = preload("res://game/empire_game.gd")

# Plays `low` against `high`, swapping who moves first; returns high's score.
func duel(low: String, high: String, games: int, map: String) -> Array:
	var high_wins := 0
	var low_wins := 0
	var draws := 0
	var capital := 0
	for i in range(games):
		var high_side := i % 2
		var g := Game.new(5000 + i, {"map": map})
		g.set_ai_difficulty(high_side, high)
		g.set_ai_difficulty(1 - high_side, low)
		while g.winner == -1:
			g.play_ai_turn()
			if g.winner != -1: break
			g.end_turn()
			if g.winner == -1:
				g.play_rival_turn()
		if g.winner == 2:
			draws += 1
		elif g.winner == high_side:
			high_wins += 1
			if g.owners[g.kingdoms[1 - high_side].capital] == high_side: capital += 1
		else:
			low_wins += 1
	return [high_wins, low_wins, draws, capital]

func _initialize() -> void:
	var map: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "Tiny"
	var games := 80
	for pair in [["Easy", "Normal"], ["Normal", "Hard"], ["Hard", "Expert"], ["Normal", "Expert"], ["Easy", "Expert"]]:
		var r := duel(pair[0], pair[1], games, map)
		print("%-6s vs %-6s on %s: %s wins %d, %s wins %d, draws %d (%d%%)" % [pair[1], pair[0], map, pair[1], r[0], pair[0], r[1], r[2], roundi(100.0 * r[0] / games)])
	quit()
