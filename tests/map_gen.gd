extends SceneTree
## Generated islands: fairness, shape and playability for every map size.

const IslandMap = preload("res://map/island_map.gd")
const Game = preload("res://game/empire_game.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _land(tiles: Dictionary) -> Array[Vector2i]:
	var land: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		if tiles[tile] != "Water":
			land.append(tile)
	return land


func _connected(land: Array[Vector2i]) -> bool:
	var seen := {land[0]: true}
	var frontier: Array[Vector2i] = [land[0]]
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_back()
		for direction in IslandMap.DIRECTIONS:
			var next := tile + direction
			if land.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size() == land.size()


func _distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return maxi(absi(d.x), maxi(absi(d.y), absi(d.x + d.y)))


func _run() -> void:
	for size_name in IslandMap.SIZE_NAMES:
		var spec: Dictionary = IslandMap.SIZES[size_name]
		var side: int = spec["side"]
		var shapes := {}
		for seed_value in range(30):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var map := IslandMap.build(size_name, rng)
			var tiles: Dictionary = map["tiles"]
			var land := _land(tiles)
			var tag := "%s seed %d" % [size_name, seed_value]
			shapes[str(land)] = true
			check(map["name"] == size_name and map["rounds"] == spec["rounds"], "Name and round limit: " + tag)
			check(land.size() >= spec["land"] and land.size() <= spec["land"] + 1, "Land count: " + tag)
			var symmetric := true
			var inside := true
			var margin := true
			for tile in land:
				var column := tile.x + floori(tile.y / 2.0)
				inside = inside and tile.y >= 1 and tile.y <= side and column >= 1 and column <= side
				symmetric = symmetric and tiles.get(IslandMap.mirror(tile, side), "Water") != "Water"
				symmetric = symmetric and IslandMap.mirror(IslandMap.mirror(tile, side), side) == tile
				for direction in IslandMap.DIRECTIONS:
					margin = margin and tiles.has(tile + direction)
			check(inside, "Land within the %dx%d area: %s" % [side, side, tag])
			check(symmetric, "Island is mirror-symmetric: " + tag)
			check(margin, "Water ring around the land: " + tag)
			check(_connected(land), "Land is connected: " + tag)
			var starts: Array = map["starts"]
			var player: Array = starts[0]
			var rival: Array = starts[1]
			check(player.size() == 3 and rival.size() == 3, "Three starting tiles each: " + tag)
			var all_start := {}
			for tile in player + rival:
				check(land.has(tile), "Starting tile is land: " + tag)
				all_start[tile] = true
			check(all_start.size() == 6, "Starting tiles do not overlap: " + tag)
			for index in range(3):
				check(rival[index] == IslandMap.mirror(player[index], side), "Rival start mirrors the player's: " + tag)
			for tile in [player[1], player[2]]:
				check(_distance(tile, player[0]) == 1, "Starting tiles touch the capital: " + tag)
			for a in player:
				for b in rival:
					check(_distance(a, b) >= 2, "Kingdoms do not start touching: " + tag)
			check(_distance(player[0], rival[0]) >= side / 2 + 1, "Capitals are far apart: " + tag)
			check(rival[0].y - player[0].y >= side / 2, "Capitals face each other top to bottom: " + tag)
		check(shapes.size() >= 25, "%s: different seeds give different islands (%d)" % [size_name, shapes.size()])
		var again := RandomNumberGenerator.new()
		again.seed = 3
		var first := IslandMap.build(size_name, again)
		again.seed = 3
		check(str(first) == str(IslandMap.build(size_name, again)), "Same seed, same island: " + size_name)

	# Full AI-vs-AI matches on every size.
	for size_name in IslandMap.SIZE_NAMES:
		var longest := 0
		for seed_value in range(8):
			var game := Game.new(300 + seed_value, {"map": size_name})
			check(game.map_name == size_name and game.max_rounds == IslandMap.SIZES[size_name]["rounds"], "Game uses the chosen map")
			check(game.tile_count(0) == 3 and game.tile_count(1) == 3 and game.total_armies(0) == 5, "Standard start on " + size_name)
			var guard := 0
			while game.winner == -1 and guard < 200:
				guard += 1
				game.play_ai_turn()
				if game.winner != -1:
					break
				game.end_turn()
				if game.winner == -1:
					game.play_rival_turn()
			check(game.winner != -1 and game.round_number <= game.max_rounds, "Match on %s finishes in time" % size_name)
			longest = maxi(longest, game.round_number)
		print("%s: matches end by round %d (limit %d)" % [size_name, longest, IslandMap.SIZES[size_name]["rounds"]])

	# The board fits and picks tiles on every size.
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.remember_settings = false
	main.show_title_on_start = false
	root.add_child(main)
	for frame in range(5):
		await process_frame
	for size_name in IslandMap.SIZE_NAMES:
		var game := Game.new(11, {"map": size_name})
		main.game = game
		main.board.game = game
		main._refresh()
		for frame in range(5):
			await process_frame
		var board: Control = main.board
		var bounds := Rect2(Vector2.ZERO, board.size)
		var all_fit := true
		var all_pick := true
		for tile in _land(game.terrain):
			for vertex in board.tile_polygon(tile):
				all_fit = all_fit and bounds.grow(1).has_point(vertex)
			all_pick = all_pick and board.pick_land(board.tile_center(tile)) == tile
		check(all_fit, "Whole %s island fits the board" % size_name)
		check(all_pick, "Every %s tile can be clicked" % size_name)
		check(board.hex_radius >= board.MIN_HEX_RADIUS, "Hex size within limits on " + size_name)
		check(main.turn_label.text.ends_with("/ %d" % game.max_rounds), "Round counter shows the %s limit" % size_name)

	if failures == 0:
		print("PASS: ", checks, " map generation checks")
	else:
		printerr("FAIL: ", failures, " / ", checks, " map generation checks")
	quit(0 if failures == 0 else 1)
