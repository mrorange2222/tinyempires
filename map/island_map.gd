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
