extends RefCounted
## Board analysis shared by every computer personality. These read the game
## state and never change it. When new rules arrive (terrain, units...), update
## these helpers and all personalities see the new picture.


## Hex distance from `tile` to the nearest tile owned by `enemy`.
static func front_distance(game, tile: Vector2i, enemy: int) -> int:
	var best := 1000
	for other: Vector2i in game.owners:
		if game.owners[other] == enemy:
			best = mini(best, game.hex_distance(tile, other))
	return best


## Strongest enemy stack that could attack `tile` next turn. Armies have two
## steps, so stacks up to two tiles away count.
static func threat(game, tile: Vector2i, enemy: int) -> int:
	var strongest := 0
	for other: Vector2i in game.owners:
		if game.owners[other] == enemy and game.hex_distance(tile, other) <= 2:
			strongest = maxi(strongest, game.armies[other])
	return strongest


## Armies to leave behind when attacking from `source` into `target`: one, if
## the source still borders other enemy land.
static func keep_back(game, source: Vector2i, target: Vector2i, enemy: int) -> int:
	for other in game.neighbors(source):
		if other != target and game.owners[other] == enemy:
			return 1
	return 0


## Steps from `source` to own neighbouring tiles that are closer to the front.
static func steps_toward_front(game, source: Vector2i, side: int) -> Array[Vector2i]:
	var enemy := 1 - side
	var here := front_distance(game, source, enemy)
	var options: Array[Vector2i] = []
	for step in game.neighbors(source):
		if game.owners[step] == side and front_distance(game, step, enemy) < here:
			options.append(step)
	return options


## Extra armies `tile` needs before it could attack `target` with a good chance.
static func staging_cost(game, tile: Vector2i, target: Vector2i) -> int:
	return game.defense(target) + 1 - game.armies[tile]
