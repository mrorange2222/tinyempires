extends RefCounted
## Shared drawing for the pieces on the map: soldiers, castles and improvements.
##
## One flat, stylised look for everything: simple shapes, a thin dark outline,
## one shade for depth, a small highlight, and a touch of kingdom colour.
## Functions draw onto any CanvasItem (`ci`) at a base point (where the piece
## stands) with scale `s`, where s = 1 matches a hex radius of 76 px.

const INK := Color(0.07, 0.1, 0.12, 0.9)
const STEEL := Color("#c3cbcc")
const SKIN := Color("#e9c7a3")
const STONE := Color("#d4ccb6")
const STONE_SHADE := Color("#a89f88")
const WOOD := Color("#8a6640")
const WOOD_LIGHT := Color("#c9a978")
const WHEAT := Color("#e3c066")
const LEAF := Color("#4f8a46")
const LEAF_LIGHT := Color("#6fae5c")
const SHADOW := Color(0, 0, 0, 0.28)
const FARM_KINDS: Array[String] = ["wheat", "windmill", "orchard", "pasture"]


static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in range(20):
		var angle := TAU * step / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ci.draw_colored_polygon(points, color)


static func _poly(ci: CanvasItem, base: Vector2, s: float, points: Array, fill: Color, outline := true) -> void:
	var shape := PackedVector2Array()
	for point: Vector2 in points:
		shape.append(base + point * s)
	ci.draw_colored_polygon(shape, fill)
	if outline:
		shape.append(shape[0])
		ci.draw_polyline(shape, INK, 1.0, true)


static func _rect(ci: CanvasItem, base: Vector2, s: float, from: Vector2, to: Vector2, fill: Color, outline := true) -> void:
	_poly(ci, base, s, [from, Vector2(to.x, from.y), to, Vector2(from.x, to.y)], fill, outline)


# --- Decoration ------------------------------------------------------------------

## A small round tree (decoration).
static func tree(ci: CanvasItem, base: Vector2, size: float) -> void:
	ellipse(ci, base + Vector2(size * 0.25, size * 0.12), Vector2(size * 0.75, size * 0.28), Color(0.05, 0.12, 0.05, 0.28))
	ci.draw_line(base, base + Vector2(0, -size * 0.55), Color("#6b4f33"), maxf(2.0, size * 0.18), true)
	var crown := base + Vector2(0, -size * 1.05)
	ci.draw_circle(crown, size * 0.62, Color("#3f6b3c"))
	ci.draw_circle(crown + Vector2(-size * 0.18, -size * 0.2), size * 0.38, Color("#5a8a4a"))
	ci.draw_circle(crown + Vector2(-size * 0.26, -size * 0.3), size * 0.14, Color(1, 1, 0.8, 0.25))


## A gentle grassy hill (decoration).
static func hill(ci: CanvasItem, base: Vector2, width: float) -> void:
	var points := PackedVector2Array()
	var height := width * 0.42
	for step in range(17):
		var t := step / 16.0
		points.append(base + Vector2((t - 0.5) * width, -sin(t * PI) * height))
	ci.draw_colored_polygon(points, Color("#a4a466"))
	var shade := PackedVector2Array()
	for step in range(8, 17):
		var t := step / 16.0
		shade.append(base + Vector2((t - 0.5) * width, -sin(t * PI) * height))
	shade.append(base)
	ci.draw_colored_polygon(shade, Color(0.32, 0.36, 0.18, 0.35))
	ci.draw_polyline(points, Color(0.3, 0.33, 0.17, 0.5), 1.2, true)


## A grass tuft with a small flower (decoration).
static func tuft(ci: CanvasItem, base: Vector2, size: float, variant: int) -> void:
	var green := Color("#4f7a3a")
	for blade in [-1, 0, 1]:
		ci.draw_line(base + Vector2(blade * size * 0.2, 0), base + Vector2(blade * size * 0.45, -size * 0.7),
				green, 1.6, true)
	var petals: Array[Color] = [Color("#f4efd8"), Color("#f2d36b"), Color("#e8a9b8")]
	ci.draw_circle(base + Vector2(size * 0.5, -size * 0.25), maxf(1.6, size * 0.13), petals[variant % 3])


# --- Soldier -------------------------------------------------------------------

## A stylised soldier: helmet with a plume, tunic, round shield and spear.
## `spent` greys it out (done for this turn).
static func soldier(ci: CanvasItem, feet: Vector2, color: Color, spent: bool, s: float) -> void:
	var steel := STEEL if not spent else Color("#8f9898")
	var steel_dark := steel.darkened(0.35)
	var skin := SKIN if not spent else Color("#b9a796")
	ellipse(ci, feet + Vector2(1, 0), Vector2(10, 3.5) * s, SHADOW)
	ci.draw_line(feet + Vector2(8, 1) * s, feet + Vector2(8, -40) * s, Color("#6b4f33"), 2.0 * s, true)
	_poly(ci, feet, s, [Vector2(8, -46), Vector2(10.5, -39), Vector2(5.5, -39)], steel, false)
	ci.draw_line(feet + Vector2(-3, -9) * s, feet + Vector2(-3, 0) * s, Color("#2b3236"), 3.0 * s, true)
	ci.draw_line(feet + Vector2(3, -9) * s, feet + Vector2(3, 0) * s, Color("#2b3236"), 3.0 * s, true)
	_poly(ci, feet, s, [Vector2(-7.5, -8), Vector2(7.5, -8), Vector2(5.5, -23), Vector2(-5.5, -23)], color)
	ci.draw_line(feet + Vector2(-6.8, -13) * s, feet + Vector2(6.8, -13) * s, color.darkened(0.35), 1.6 * s, true)
	ci.draw_circle(feet + Vector2(8, -18) * s, 1.8 * s, skin)
	ci.draw_circle(feet + Vector2(0, -27.5) * s, 4.4 * s, skin)
	var dome := []
	for step in range(13):
		var angle := PI + PI * step / 12.0
		dome.append(Vector2(cos(angle) * 5.6, -28.5 + sin(angle) * 5.6))
	_poly(ci, feet, s, dome, steel, false)
	ci.draw_line(feet + Vector2(-6.6, -28.3) * s, feet + Vector2(6.6, -28.3) * s, steel_dark, 1.8 * s, true)
	ci.draw_line(feet + Vector2(0, -28.3) * s, feet + Vector2(0, -25.2) * s, steel_dark, 1.2 * s, true)
	ci.draw_circle(feet + Vector2(-2, -31.5) * s, 1.2 * s, Color(1, 1, 1, 0.55))
	ellipse(ci, feet + Vector2(0, -35.5) * s, Vector2(2.2, 3.2) * s, color.lightened(0.15))
	var shield := feet + Vector2(-6.5, -15) * s
	ci.draw_circle(shield, 6.2 * s, color.darkened(0.15))
	ci.draw_arc(shield, 6.2 * s, 0, TAU, 20, steel, 1.6 * s, true)
	ci.draw_circle(shield, 1.6 * s, steel)


# --- Castle --------------------------------------------------------------------

## The capital: stone walls between two towers with roofs in kingdom colour,
## a gate, and a flag.
static func castle(ci: CanvasItem, base: Vector2, color: Color, s: float) -> void:
	ellipse(ci, base + Vector2(1, 0), Vector2(22, 5) * s, SHADOW)
	# Wall with battlements.
	_rect(ci, base, s, Vector2(-13, -17), Vector2(13, 0), STONE)
	for x in [-11.0, -5.0, 1.0, 7.0]:
		_rect(ci, base, s, Vector2(x, -20), Vector2(x + 3.5, -17), STONE)
	_rect(ci, base, s, Vector2(4, -16.5), Vector2(12.5, -0.5), STONE_SHADE, false)
	# Gate.
	var gate := [Vector2(-4, 0), Vector2(-4, -7)]
	for step in range(7):
		var angle := PI + PI * step / 6.0
		gate.append(Vector2(cos(angle) * 4.0, -7 + sin(angle) * 4.0))
	gate.append(Vector2(4, 0))
	_poly(ci, base, s, gate, Color("#3a2c22"))
	# Towers with conical roofs.
	for x in [-19.0, 11.0]:
		_rect(ci, base, s, Vector2(x, -26), Vector2(x + 8, 0), STONE)
		_rect(ci, base, s, Vector2(x + 5, -25.5), Vector2(x + 7.5, -0.5), STONE_SHADE, false)
		_rect(ci, base, s, Vector2(x + 3, -19), Vector2(x + 5, -14), Color("#3a2c22"), false)
		_poly(ci, base, s, [Vector2(x - 1.5, -26), Vector2(x + 4, -37), Vector2(x + 9.5, -26)], color)
		_poly(ci, base, s, [Vector2(x + 4, -37), Vector2(x + 9.5, -26), Vector2(x + 5, -26)], color.darkened(0.25), false)
	ci.draw_circle(base + Vector2(-17, -29) * s, 1.3 * s, Color(1, 1, 1, 0.5))
	# Flag on the right tower.
	ci.draw_line(base + Vector2(15, -37) * s, base + Vector2(15, -46) * s, WOOD, 1.3 * s, true)
	_poly(ci, base, s, [Vector2(15, -46), Vector2(23, -43.5), Vector2(15, -41)], color.lightened(0.1))


## A low stone bastion without the capital's tall roofs.
static func fort(ci: CanvasItem, base: Vector2, color: Color, s: float) -> void:
	ellipse(ci, base, Vector2(23, 6) * s, SHADOW)
	_rect(ci, base, s, Vector2(-20, -14), Vector2(20, 0), STONE)
	_rect(ci, base, s, Vector2(7, -13), Vector2(19, -1), STONE_SHADE, false)
	for x in [-20.0, 12.0]:
		_rect(ci, base, s, Vector2(x, -23), Vector2(x + 8, 0), STONE)
		_rect(ci, base, s, Vector2(x + 5, -22), Vector2(x + 7, -1), STONE_SHADE, false)
		for offset in [0.0, 5.0]:
			_rect(ci, base, s, Vector2(x + offset, -27), Vector2(x + offset + 3, -23), STONE)
		_rect(ci, base, s, Vector2(x + 3, -17), Vector2(x + 5, -11), INK, false)
	for x in [-9.0, -2.0, 5.0]:
		_rect(ci, base, s, Vector2(x, -18), Vector2(x + 4, -14), STONE)
	_rect(ci, base, s, Vector2(-4, -9), Vector2(4, 0), WOOD)
	ci.draw_line(base + Vector2(0, -9) * s, base, WOOD_LIGHT, s, true)
	ci.draw_line(base + Vector2(16, -27) * s, base + Vector2(16, -37) * s, WOOD, s, true)
	_poly(ci, base, s, [Vector2(16, -37), Vector2(26, -34), Vector2(16, -31)], color)


# --- Farms (all +1 gold; the look is chosen per tile) ----------------------------

## `phase` turns the windmill sails (radians); 0 is the still map look.
static func farm(ci: CanvasItem, base: Vector2, kind: String, color: Color, s: float, phase := 0.0) -> void:
	match kind:
		"wheat":
			_wheat_farm(ci, base, color, s)
		"windmill":
			_windmill(ci, base, color, s, phase)
		"orchard":
			_orchard(ci, base, color, s)
		_:
			_pasture(ci, base, color, s)


static func _field(ci: CanvasItem, base: Vector2, s: float, from: Vector2, to: Vector2, fill: Color, rows: int) -> void:
	_rect(ci, base, s, from, to, fill)
	for row in range(1, rows):
		var y := lerpf(from.y, to.y, float(row) / rows)
		ci.draw_line(base + Vector2(from.x + 1, y) * s, base + Vector2(to.x - 1, y) * s, fill.darkened(0.22), 1.2 * s, true)


static func _barn(ci: CanvasItem, base: Vector2, color: Color, s: float, at: Vector2) -> void:
	_rect(ci, base, s, at + Vector2(-6, -9), at + Vector2(6, 0), Color("#b36a45"))
	_rect(ci, base, s, at + Vector2(1.5, -8.5), at + Vector2(5.5, -0.5), Color("#8f5236"), false)
	_poly(ci, base, s, [at + Vector2(-7.5, -9), at + Vector2(0, -15), at + Vector2(7.5, -9)], color)
	_rect(ci, base, s, at + Vector2(-2, -5), at + Vector2(2, 0), Color("#3a2c22"), false)


static func _wheat_farm(ci: CanvasItem, base: Vector2, color: Color, s: float) -> void:
	ellipse(ci, base + Vector2(0, 0), Vector2(20, 4) * s, SHADOW)
	_field(ci, base, s, Vector2(-19, -10), Vector2(5, 0), WHEAT, 4)
	for x in [-15.0, -9.0, -3.0]:
		ci.draw_circle(base + Vector2(x, -7.5) * s, 0.9 * s, Color("#fff1b0"))
	_barn(ci, base, color, s, Vector2(13, 0))


static func _windmill(ci: CanvasItem, base: Vector2, color: Color, s: float, phase := 0.0) -> void:
	ellipse(ci, base, Vector2(18, 4) * s, SHADOW)
	_field(ci, base, s, Vector2(-18, -7), Vector2(-3, 0), Color("#9fbf5a"), 3)
	_poly(ci, base, s, [Vector2(2, 0), Vector2(14, 0), Vector2(12, -20), Vector2(4, -20)], Color("#efe3c5"))
	_poly(ci, base, s, [Vector2(9, 0), Vector2(14, 0), Vector2(12, -20), Vector2(9, -20)], Color("#d6c7a3"), false)
	_rect(ci, base, s, Vector2(6.5, -6), Vector2(9.5, 0), Color("#3a2c22"), false)
	_poly(ci, base, s, [Vector2(2.5, -20), Vector2(8, -27), Vector2(13.5, -20)], color)
	var hub := base + Vector2(8, -21) * s
	for index in range(4):
		var direction := Vector2.from_angle(deg_to_rad(20.0 + 90.0 * index) + phase)
		var side := direction.orthogonal()
		ci.draw_line(hub, hub + direction * 13.0 * s, WOOD, 1.3 * s, true)
		var sail := PackedVector2Array([hub + direction * 4.0 * s, hub + direction * 12.5 * s,
			hub + (direction * 12.5 + side * 3.2) * s, hub + (direction * 4.0 + side * 3.2) * s])
		ci.draw_colored_polygon(sail, Color("#f6efe0"))
		sail.append(sail[0])
		ci.draw_polyline(sail, INK, 0.8, true)
	ci.draw_circle(hub, 1.6 * s, WOOD)


static func _orchard(ci: CanvasItem, base: Vector2, color: Color, s: float) -> void:
	ellipse(ci, base, Vector2(20, 4) * s, SHADOW)
	ci.draw_line(base + Vector2(-19, 0) * s, base + Vector2(19, 0) * s, WOOD_LIGHT, 1.4 * s, true)
	for x in [-17.0, -6.0, 5.0, 16.0]:
		ci.draw_line(base + Vector2(x, 0) * s, base + Vector2(x, -3.5) * s, WOOD, 1.4 * s, true)
	var fruit: Array[Color] = [Color("#e05a4f"), Color("#f2c14e")]
	var index := 0
	for row in [-13.0, -5.0]:
		for x in [-12.0, -1.0, 10.0]:
			var at := base + Vector2(x + (3.0 if row < -10.0 else 0.0), row) * s
			ci.draw_line(at, at + Vector2(0, -3) * s, WOOD, 1.4 * s, true)
			ci.draw_circle(at + Vector2(0, -6) * s, 4.2 * s, LEAF)
			ci.draw_circle(at + Vector2(-1, -7) * s, 2.6 * s, LEAF_LIGHT)
			ci.draw_circle(at + Vector2(1.6, -5) * s, 0.95 * s, fruit[index % 2])
			ci.draw_circle(at + Vector2(-1.8, -4.5) * s, 0.95 * s, fruit[(index + 1) % 2])
			index += 1
	# A small kingdom-coloured flag on the fence post.
	ci.draw_line(base + Vector2(16, -3.5) * s, base + Vector2(16, -10) * s, WOOD, 1.0 * s, true)
	_poly(ci, base, s, [Vector2(16, -10), Vector2(21, -8.5), Vector2(16, -7)], color, false)


static func _pasture(ci: CanvasItem, base: Vector2, color: Color, s: float) -> void:
	ellipse(ci, base, Vector2(20, 4) * s, SHADOW)
	_rect(ci, base, s, Vector2(-19, -12), Vector2(10, 0), Color("#8fb85a"), false)
	for y in [-12.0, 0.0]:
		ci.draw_line(base + Vector2(-19, y) * s, base + Vector2(10, y) * s, WOOD_LIGHT, 1.3 * s, true)
		ci.draw_line(base + Vector2(-19, y - 2.5) * s, base + Vector2(10, y - 2.5) * s, WOOD_LIGHT, 1.0 * s, true)
	for x in [-19.0, -9.0, 0.0, 10.0]:
		for y in [-12.0, 0.0]:
			ci.draw_line(base + Vector2(x, y) * s, base + Vector2(x, y - 4) * s, WOOD, 1.3 * s, true)
	for sheep: Vector2 in [Vector2(-12, -4), Vector2(-3, -8)]:
		var at := base + sheep * s
		ellipse(ci, at + Vector2(0, 0.8) * s, Vector2(3.6, 1.0) * s, SHADOW)
		ellipse(ci, at, Vector2(3.6, 2.6) * s, Color("#f5f2ea"))
		ci.draw_circle(at + Vector2(3.2, -1.2) * s, 1.4 * s, Color("#3b3533"))
	# Hay bale and a small shed with a kingdom-coloured roof.
	ellipse(ci, base + Vector2(5, -5) * s, Vector2(2.6, 2.0) * s, WHEAT)
	_rect(ci, base, s, Vector2(12, -8), Vector2(19, 0), Color("#b8946a"))
	_poly(ci, base, s, [Vector2(11, -8), Vector2(15.5, -12.5), Vector2(20, -8)], color)


# --- Future: workshop (sketch only, not used by the rules yet) -------------------

static func workshop(ci: CanvasItem, base: Vector2, color: Color, s: float) -> void:
	ellipse(ci, base, Vector2(17, 4) * s, SHADOW)
	_rect(ci, base, s, Vector2(-14, -14), Vector2(10, 0), Color("#e8dcc0"))
	for x in [-14.0, -6.0, 2.0, 10.0]:
		ci.draw_line(base + Vector2(x, -14) * s, base + Vector2(x, 0) * s, WOOD, 1.3 * s, true)
	ci.draw_line(base + Vector2(-14, -7) * s, base + Vector2(10, -7) * s, WOOD, 1.3 * s, true)
	_poly(ci, base, s, [Vector2(-16, -14), Vector2(-2, -23), Vector2(12, -14)], color)
	_rect(ci, base, s, Vector2(4, -26), Vector2(8, -18), STONE_SHADE)
	for puff in [Vector2(6.5, -29), Vector2(8.5, -33), Vector2(11, -36)]:
		ci.draw_circle(base + puff * s, (1.6 + puff.x * 0.1) * s, Color(0.9, 0.92, 0.9, 0.7))
	# Gear sign.
	var gear := base + Vector2(16, -9) * s
	for tooth in range(8):
		var direction := Vector2.from_angle(TAU * tooth / 8.0)
		ci.draw_line(gear, gear + direction * 4.2 * s, Color("#9aa3a6"), 2.0 * s, true)
	ci.draw_circle(gear, 3.0 * s, Color("#b9c2c4"))
	ci.draw_circle(gear, 1.1 * s, INK)
