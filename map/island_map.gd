extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const LAND_SPANS: Array[Vector2i] = [
	Vector2i(3, 5), Vector2i(2, 6), Vector2i(1, 6),
	Vector2i(1, 7), Vector2i(2, 7), Vector2i(2, 6), Vector2i(3, 5),
]


static func create_tiles() -> Dictionary[Vector2i, String]:
	var tiles: Dictionary[Vector2i, String] = {}
	for row in range(9):
		for column in range(9):
			var coordinates := Vector2i(column - floori(row / 2.0), row)
			var terrain := "Water"
			if row >= 1 and row <= 7:
				var span := LAND_SPANS[row - 1]
				if column >= span.x and column <= span.y:
					terrain = "Plains"
			tiles[coordinates] = terrain
	return tiles


# --- Map choices -----------------------------------------------------------------

## Generated sizes: side of the square land area (rows x columns, even so the
## island can be mirrored exactly), land tiles to grow, and the round limit.
const SIZES := {
	"Minuscule": {"side": 6, "land": 22, "rounds": 15},
	"Tiny": {"side": 8, "land": 35, "rounds": 20},
	"Small": {"side": 10, "land": 55, "rounds": 25},
}
const SIZE_NAMES: Array[String] = ["Minuscule", "Tiny", "Small"]
const CLASSIC := "Classic"


## A map for a match: {"name", "tiles", "starts": [player tiles, rival tiles],
## "rounds"}. Each start list is [capital, tile, tile]. "Classic" is the fixed
## hand-made island; the other sizes are generated from `rng`.
static func build(map_name: String, rng: RandomNumberGenerator) -> Dictionary:
	if map_name == CLASSIC or not SIZES.has(map_name):
		return {
			"name": CLASSIC,
			"tiles": create_tiles(),
			"starts": [[Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 2)],
				[Vector2i(2, 7), Vector2i(1, 7), Vector2i(2, 6)]],
			"rounds": 20,
		}
	var spec: Dictionary = SIZES[map_name]
	var map := generate(spec["side"], spec["land"], rng)
	map["name"] = map_name
	map["rounds"] = spec["rounds"]
	return map


static func to_axial(column: int, row: int) -> Vector2i:
	return Vector2i(column - floori(row / 2.0), row)


## Mirror point of the generated area: a tile and its mirror image are
## symmetric through the island's centre (a 180 degree turn). `side` is even.
static func mirror(tile: Vector2i, side: int) -> Vector2i:
	var mirror_q := (side + 1) - side / 2
	return Vector2i(mirror_q - tile.x, side + 1 - tile.y)


## Grows a connected island that is identical for both kingdoms when turned
## 180 degrees, inside a side x side area with a ring of water around it.
static func generate(side: int, land_target: int, rng: RandomNumberGenerator) -> Dictionary:
	var area: Dictionary[Vector2i, bool] = {}
	var tiles: Dictionary[Vector2i, String] = {}
	for row in range(side + 2):
		for column in range(side + 2):
			var tile := to_axial(column, row)
			var inside := row >= 1 and row <= side and column >= 1 and column <= side
			tiles[tile] = "Water"
			if inside:
				area[tile] = true
	var land: Dictionary[Vector2i, bool] = {}
	# Start from the two middle tiles, which are mirror images and neighbours.
	var seed_tile := Vector2i(ceili(((side + 1) - side / 2) / 2.0), side / 2)
	land[seed_tile] = true
	land[mirror(seed_tile, side)] = true
	while land.size() < land_target:
		var frontier: Array[Vector2i] = []
		var weights: Array[float] = []
		var total := 0.0
		for tile: Vector2i in area:
			if land.has(tile):
				continue
			var touching := 0
			for direction in DIRECTIONS:
				if land.has(tile + direction):
					touching += 1
			if touching == 0:
				continue
			# Favour tiles touching more land for a solid island, with some
			# randomness for an irregular coast.
			var weight := 1.0 + touching * touching * 0.6
			frontier.append(tile)
			weights.append(weight)
			total += weight
		if frontier.is_empty():
			break
		var pick := rng.randf() * total
		var chosen := frontier.back() as Vector2i
		for index in range(frontier.size()):
			pick -= weights[index]
			if pick <= 0.0:
				chosen = frontier[index]
				break
		land[chosen] = true
		land[mirror(chosen, side)] = true
	for tile: Vector2i in land:
		tiles[tile] = "Plains"
	var player := _start_tiles(land, side)
	var rival: Array[Vector2i] = []
	for tile: Vector2i in player:
		rival.append(mirror(tile, side))
	return {"tiles": tiles, "starts": [player, rival]}


## The capitals are far apart, mostly top to bottom: the player's capital is
## the land tile farthest (by rows, then distance) from its mirror image, the
## rival's capital, preferring tiles with three land neighbours.
## Its two starting tiles are the neighbours with the most land around them.
static func _start_tiles(land: Dictionary[Vector2i, bool], side: int) -> Array[Vector2i]:
	var middle := (side + 1) / 2.0
	var capital := Vector2i.ZERO
	var best := -INF
	for tile: Vector2i in land:
		var neighbours := _land_neighbours(land, tile).size()
		if neighbours < 2:
			continue
		var other := mirror(tile, side)
		var delta := tile - other
		var apart := maxi(absi(delta.x), maxi(absi(delta.y), absi(delta.x + delta.y)))
		var column := tile.x + floori(tile.y / 2.0)
		# Far apart, mostly top to bottom (the player starts at the bottom of the
		# screen), on sturdy ground, near the middle column.
		var rows_apart := other.y - tile.y
		var score := rows_apart * 10.0 + apart * 4.0 + (6.0 if neighbours >= 3 else 0.0) - absf(column - middle) * 0.5
		if tile.y > other.y or (tile.y == other.y and tile.x > other.x):
			continue
		if score > best:
			best = score
			capital = tile
	var options := _land_neighbours(land, capital)
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _land_neighbours(land, a).size() > _land_neighbours(land, b).size())
	return [capital, options[0], options[1]]


static func _land_neighbours(land: Dictionary[Vector2i, bool], tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		if land.has(tile + direction):
			result.append(tile + direction)
	return result
