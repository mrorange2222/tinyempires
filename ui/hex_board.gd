extends Control

signal tile_selected(coordinates: Vector2i, terrain: String)

const IslandMap = preload("res://map/island_map.gd")
const TileArt = preload("res://ui/tile_art.gd")
const EmpireGame = preload("res://game/empire_game.gd")
const KINGDOM_COLORS: Array[Color] = [Color("#79c8df"), Color("#e8a08d")]
# Polygon edge facing each neighbour direction (see IslandMap.DIRECTIONS).
const EDGE_INDICES: Array[int] = [0, 5, 4, 3, 2, 1]
# The view is turned 180 degrees so the player's kingdom starts at the bottom.
const FLIPPED := true
const PADDING := 8.0
const TILT := 0.58
const LAND_HEIGHT := 0.22
const SHADOW_OFFSET := Vector2(0.10, 0.14)
const MAX_HEX_RADIUS := 120.0
# Marker sizes (soldiers, tags, crowns) are designed at this radius and scale with it.
const REFERENCE_RADIUS := 76.0
const MIN_HEX_RADIUS := 50.0
const WaterShader = preload("res://ui/water.gdshader")

var tiles: Dictionary[Vector2i, String] = IslandMap.create_tiles()
var selected_coordinates := Vector2i.ZERO
var has_selection := false
## Draws claim dots and move/attack marks (an option).
var show_hints := true
var has_hover := false
var has_target := false
var target_coordinates := Vector2i.ZERO
var hovered_coordinates := Vector2i.ZERO
# Setting the game also sets the map: the board fits itself to the new island.
var game: EmpireGame:
	set(value):
		game = value
		if value != null:
			tiles = value.terrain
			if is_node_ready():
				_land_bounds = _map_bounds()
				fit_to_view()
var ground_texture: ImageTexture
var hex_radius := MAX_HEX_RADIUS
var _land_bounds: Rect2
var _water_material: ShaderMaterial


func _ready() -> void:
	ground_texture = _create_ground_texture()
	_land_bounds = _map_bounds()
	var water := ColorRect.new()
	water.name = "Water"
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.show_behind_parent = true
	water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var water_material := ShaderMaterial.new()
	water_material.shader = WaterShader
	water.material = water_material
	add_child(water)
	_water_material = water_material
	resized.connect(_update_water.bind(water_material))
	get_parent_control().resized.connect(fit_to_view)
	fit_to_view()


# Hexes grow to fill the view (up to the maximum size); below the minimum
# size the board stops shrinking and the view scrolls instead.
func fit_to_view() -> void:
	var available := get_parent_control().size - Vector2.ONE * (PADDING * 2.0 + 4.0)
	var units := Vector2(_land_bounds.size.x + SHADOW_OFFSET.x,
			_land_bounds.size.y * TILT + LAND_HEIGHT + SHADOW_OFFSET.y)
	var fit := minf(available.x / units.x, available.y / units.y)
	hex_radius = clampf(fit, MIN_HEX_RADIUS, MAX_HEX_RADIUS)
	custom_minimum_size = (units * hex_radius + Vector2.ONE * PADDING * 2.0).floor()
	_update_water(_water_material)


func _create_ground_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 4127
	noise.frequency = 0.025
	var image := Image.create(512, 256, false, Image.FORMAT_RGB8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var patch := clampf(0.5 + noise.get_noise_2d(x, y) * 0.8, 0.0, 1.0)
			var grain := noise.get_noise_2d(x * 12.0, y * 12.0)
			var color := Color("#668348").lerp(Color("#9ca467"), patch)
			color = color.lightened(maxf(grain, 0.0) * 0.12)
			color = color.darkened(maxf(-grain, 0.0) * 0.10)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _update_water(water_material: ShaderMaterial) -> void:
	var centers := PackedVector2Array()
	for coordinates: Vector2i in tiles:
		if tiles[coordinates] != "Water":
			centers.append(tile_center(coordinates) + Vector2(0.0, LAND_HEIGHT * hex_radius))
	water_material.set_shader_parameter("board_size", size)
	water_material.set_shader_parameter("land_centers", centers)
	water_material.set_shader_parameter("land_count", centers.size())
	water_material.set_shader_parameter("hex_radius", hex_radius)
	water_material.set_shader_parameter("tilt", TILT)
	queue_redraw()


func _raw_center(coordinates: Vector2i) -> Vector2:
	return Vector2(sqrt(3.0) * (coordinates.x + coordinates.y / 2.0), 1.5 * coordinates.y)


# Bounds of the land plus a thin margin of water, in hex-radius units.
func _map_bounds() -> Rect2:
	var bounds := Rect2()
	var first := true
	for coordinates: Vector2i in tiles:
		if tiles[coordinates] == "Water":
			continue
		if first:
			bounds = Rect2(_raw_center(coordinates), Vector2.ZERO)
			first = false
		bounds = bounds.expand(_raw_center(coordinates))
	var margin := Vector2(sqrt(3.0) / 2.0 + 0.25, 1.25)
	return Rect2(bounds.position - margin, bounds.size + margin * 2.0)


## Tiles from back (top of the screen) to front, for drawing and picking.
func draw_order() -> Array[Vector2i]:
	var order: Array[Vector2i] = []
	order.assign(tiles.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ya := _raw_center(a).y * (-1.0 if FLIPPED else 1.0)
		var yb := _raw_center(b).y * (-1.0 if FLIPPED else 1.0)
		if not is_equal_approx(ya, yb):
			return ya < yb
		return _raw_center(a).x < _raw_center(b).x)
	return order


func tile_center(coordinates: Vector2i) -> Vector2:
	var radius := hex_radius
	var offset := _raw_center(coordinates) - _land_bounds.get_center()
	if FLIPPED:
		offset = -offset
	var projected := offset * Vector2(1.0, TILT)
	var elevation := LAND_HEIGHT if tiles[coordinates] != "Water" else 0.0
	return size / 2.0 + (projected + Vector2(0.0, LAND_HEIGHT / 2.0 - elevation)) * radius


func tile_polygon(coordinates: Vector2i) -> PackedVector2Array:
	var center := tile_center(coordinates)
	var radius := hex_radius
	var polygon := PackedVector2Array()
	for corner in range(6):
		var angle := deg_to_rad(60.0 * corner - 30.0)
		polygon.append(center + Vector2(cos(angle), sin(angle) * TILT) * radius)
	return polygon


func tile_faces(coordinates: Vector2i) -> Array[PackedVector2Array]:
	var faces: Array[PackedVector2Array] = []
	if tiles[coordinates] == "Water":
		return faces
	var polygon := tile_polygon(coordinates)
	var drop := Vector2(0.0, LAND_HEIGHT * hex_radius)
	for edge in [1, 2]:
		faces.append(PackedVector2Array([
			polygon[edge], polygon[edge + 1],
			polygon[edge + 1] + drop, polygon[edge] + drop,
		]))
	return faces


func _draw_surface(coordinates: Vector2i) -> void:
	var polygon := tile_polygon(coordinates)
	var uvs := PackedVector2Array()
	for vertex in polygon:
		uvs.append(vertex / size)
	draw_polygon(polygon, PackedColorArray([Color.WHITE]), uvs, ground_texture)
	var center := tile_center(coordinates)
	for edge in range(6):
		var start := polygon[edge]
		var finish := polygon[(edge + 1) % 6]
		var bevel := PackedVector2Array([
			start, finish, finish.lerp(center, 0.035), start.lerp(center, 0.035),
		])
		var light := Color(0.92, 0.94, 0.67, 0.18) if edge >= 3 else Color(0.17, 0.26, 0.12, 0.16)
		draw_colored_polygon(bevel, light)
	polygon.append(polygon[0])
	draw_polyline(polygon, Color(0.20, 0.29, 0.14, 0.26), 1.0, true)
	var owner: int = game.owners[coordinates] if game != null else EmpireGame.NEUTRAL
	if owner != EmpireGame.NEUTRAL:
		var color := KINGDOM_COLORS[owner]
		draw_colored_polygon(tile_polygon(coordinates), Color(color, 0.20))
		for index in range(IslandMap.DIRECTIONS.size()):
			var neighbor := coordinates + IslandMap.DIRECTIONS[index]
			if game.owners.get(neighbor, EmpireGame.NEUTRAL) != owner:
				var edge := (EDGE_INDICES[index] + (3 if FLIPPED else 0)) % 6
				draw_line(polygon[edge], polygon[edge + 1], color, 2.5, true)
	_draw_decor(coordinates)


# Decorative terrain only; it has no effect on the rules. Slots avoid the
# centre (army badge, crown, hints) and the left/right markers.
const DECOR_SLOTS: Array[Vector2] = [
	Vector2(-0.3, -0.34), Vector2(0.3, -0.34), Vector2(-0.56, 0.12),
	Vector2(0.56, 0.12), Vector2(-0.27, 0.38), Vector2(0.27, 0.38),
]


func decor_kind(coordinates: Vector2i) -> String:
	var roll := posmod(coordinates.x * 73 + coordinates.y * 151 + coordinates.x * coordinates.y * 17, 20)
	if roll < 6:
		return "grove"
	if roll < 11:
		return "hills"
	return "meadow"


func _draw_decor(coordinates: Vector2i) -> void:
	var center := tile_center(coordinates)
	var r := hex_radius
	var seed_value := posmod(coordinates.x * 31 + coordinates.y * 57, 97)
	var kind := decor_kind(coordinates)
	var slots: Array[Vector2] = []
	for index in range(DECOR_SLOTS.size()):
		if (seed_value >> index) % 3 != 0 or kind == "meadow":
			slots.append(DECOR_SLOTS[index])
	var count := {"grove": 4, "hills": 2, "meadow": 4}[kind] as int
	# Built-up tiles keep only a little grass, so castles and farms stand out.
	if game != null and (game.is_capital(coordinates) or game.improvements.has(coordinates) or game.forts.has(coordinates)):
		kind = "meadow"
		slots = [DECOR_SLOTS[2], DECOR_SLOTS[4]]
		count = 2
	slots = slots.slice(0, count)
	slots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for slot_index in range(slots.size()):
		var at := center + Vector2(slots[slot_index].x * r, slots[slot_index].y * r * TILT * 1.6)
		var size := r * (0.15 + 0.03 * float((seed_value + slot_index * 7) % 3))
		match kind:
			"grove":
				TileArt.tree(self, at, size)
			"hills":
				TileArt.hill(self, at, size * 2.4)
			"meadow":
				TileArt.tuft(self, at, size, slot_index + seed_value)


func _draw() -> void:
	var radius := hex_radius
	for coordinates: Vector2i in tiles:
		if tiles[coordinates] != "Water":
			var shadow := tile_polygon(coordinates)
			for index in range(shadow.size()):
				shadow[index] += (Vector2(0.0, LAND_HEIGHT) + SHADOW_OFFSET) * radius
			draw_colored_polygon(shadow, Color(0.02, 0.06, 0.09, 0.22))
	# Back-to-front, so nearer land covers the sides behind it.
	for coordinates: Vector2i in draw_order():
		if tiles[coordinates] == "Water":
			continue
		var faces := tile_faces(coordinates)
		for index in range(faces.size()):
			var face := faces[index]
			draw_colored_polygon(face, Color("#827154") if index == 0 else Color("#63593f"))
			var soil_edge := PackedVector2Array([
				face[0].lerp(face[3], 0.25), face[1].lerp(face[2], 0.25),
			])
			draw_polyline(soil_edge, Color(0.28, 0.25, 0.15, 0.35), 1.5, true)
			draw_line(face[0], face[1], Color("#627543"), 3.0, true)
		_draw_surface(coordinates)
	_draw_markers()
	_draw_hints()
	if has_hover and (not has_selection or hovered_coordinates != selected_coordinates):
		var hover := tile_polygon(hovered_coordinates)
		hover.append(hover[0])
		draw_polyline(hover, Color(1, 1, 1, 0.55), 2.0, true)
	_draw_target()
	if has_selection:
		var outline := tile_polygon(selected_coordinates)
		draw_colored_polygon(outline, Color(1.0, 0.89, 0.6, 0.16))
		outline.append(outline[0])
		draw_polyline(outline, Color("#ffe39a"), 3.5, true)


func clear_selection() -> void:
	has_selection = false
	has_target = false
	queue_redraw()


func pick_land(point: Vector2) -> Variant:
	# Front rows are checked first: raised land hides the tiles behind it.
	var coordinates_in_front := draw_order()
	coordinates_in_front.reverse()
	for coordinates: Vector2i in coordinates_in_front:
		if tiles[coordinates] == "Water":
			continue
		var shapes := tile_faces(coordinates)
		shapes.append(tile_polygon(coordinates))
		for polygon in shapes:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return coordinates
	return null


# Tile layout (offsets at the reference radius): buildings stand along the
# back of the tile, soldiers in front of them, the army tag front-right.
const CASTLE_SPOT := Vector2(-24, -10)
const FARM_SPOT := Vector2(-20, -12)
const FARM_SPOT_BESIDE_CASTLE := Vector2(25, -15)
const ARMY_SPOT := Vector2(15, 12)
const ARMY_SPOT_AT_CAPITAL := Vector2(4, 14)
const TAG_OFFSET := Vector2(21, 7)
## Where soldiers stand for 1, 2 or 3 figures (offsets from ARMY_SPOT).
const SOLDIER_SPOTS: Array = [
	[Vector2(0, 0)],
	[Vector2(-8, -3), Vector2(7, 3)],
	[Vector2(-13, -4), Vector2(11, -2), Vector2(-1, 5)],
]


## Farm design for a tile. All farms work the same; the look varies per tile
## (stable for the tile, so it does not change between redraws).
func farm_kind(coordinates: Vector2i) -> String:
	var roll := posmod(coordinates.x * 37 + coordinates.y * 101 + coordinates.x * coordinates.y * 11, 97)
	return TileArt.FARM_KINDS[roll % TileArt.FARM_KINDS.size()]


func _draw_markers() -> void:
	if game == null:
		return
	var s := hex_radius / REFERENCE_RADIUS
	# Back to front, so nearer pieces overlap the ones behind them.
	for coordinates: Vector2i in draw_order():
		var owner: int = game.owners.get(coordinates, EmpireGame.NEUTRAL)
		if owner == EmpireGame.NEUTRAL:
			continue
		var center := tile_center(coordinates)
		var color := KINGDOM_COLORS[owner]
		var capital: bool = game.is_capital(coordinates)
		if capital:
			TileArt.castle(self, center + CASTLE_SPOT * s, color, s * 0.9)
		if game.improvements.has(coordinates):
			var spot := FARM_SPOT_BESIDE_CASTLE if capital else FARM_SPOT
			TileArt.farm(self, center + spot * s, farm_kind(coordinates), color, s * (0.72 if capital else 1.0))
		elif game.forts.has(coordinates):
			var spot := FARM_SPOT_BESIDE_CASTLE if capital else FARM_SPOT
			TileArt.fort(self, center + spot * s, color, s * (0.65 if capital else 0.9))
		var count: int = game.armies[coordinates]
		if count > 0:
			var can_act: bool = owner == game.active and game.ready[coordinates] > 0
			var spent: bool = owner == game.active and not can_act
			var tint := color.lerp(Color("#7a8584"), 0.6) if spent else color
			var army_spot := ARMY_SPOT_AT_CAPITAL if capital else ARMY_SPOT
			for spot: Vector2 in SOLDIER_SPOTS[mini(count, 3) - 1]:
				TileArt.soldier(self, center + (army_spot + spot) * s, tint, spent, s * 0.9)
			_draw_army_tag(center + (army_spot + TAG_OFFSET) * s, color, count, spent,
					can_act and owner == EmpireGame.PLAYER, s)


## Small tag with the exact army count; a bright dot means armies can still act.
func _draw_army_tag(at: Vector2, color: Color, count: int, spent: bool, can_act: bool, s: float) -> void:
	var font := get_theme_default_font()
	var radius := 10.0 * s + 1.5
	draw_circle(at + Vector2(0, 1.5), radius, Color(0.02, 0.06, 0.08, 0.35))
	draw_circle(at, radius, Color("#1d3338"))
	draw_arc(at, radius, 0, TAU, 28, color if not spent else Color(color, 0.5), 1.8, true)
	var text := str(count)
	var font_size := int(round(12 * s + 2))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, at + Vector2(-text_size.x / 2.0, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color("#f1f4ee", 0.6 if spent else 1.0))
	if can_act:
		draw_circle(at + Vector2(radius * 0.8, -radius * 0.8), 3.2, Color("#fff2b8"))


# Hints only appear where the player can act right now.
func _draw_hints() -> void:
	if game == null:
		return
	_draw_rival_changes()
	if not show_hints or game.winner != EmpireGame.NEUTRAL or game.active != EmpireGame.PLAYER:
		return
	var from_own: bool = has_selection and game.owners.get(selected_coordinates, -1) == EmpireGame.PLAYER
	for coordinates: Vector2i in game.owners:
		var center := tile_center(coordinates) + Vector2(0, -46) * (hex_radius / REFERENCE_RADIUS)
		if game.action_error("claim", coordinates).is_empty() \
				and (not from_own or game.are_adjacent(selected_coordinates, coordinates)):
			draw_circle(tile_center(coordinates), 5.0, Color(0.95, 0.87, 0.6, 0.9))
		if not from_own or not game.are_adjacent(selected_coordinates, coordinates):
			continue
		var ready_here: int = game.ready[selected_coordinates]
		if game.action_error("attack", selected_coordinates, coordinates, ready_here).is_empty():
			draw_arc(center, 9.0, 0, TAU, 24, Color("#ffb39e"), 2.0, true)
			draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), Color("#ffb39e"), 2.0, true)
			draw_line(center + Vector2(4, -4), center + Vector2(-4, 4), Color("#ffb39e"), 2.0, true)
		elif game.action_error("move", selected_coordinates, coordinates, ready_here).is_empty():
			draw_arc(center, 8.0, 0, TAU, 24, Color(0.75, 0.9, 1.0, 0.85), 2.0, true)


# Tiles the rival changed this turn get a coral dot; the latest one a bold ring.
func _draw_rival_changes() -> void:
	for coordinates: Vector2i in game.rival_changes:
		var marked := tile_polygon(coordinates)
		marked.append(marked[0])
		draw_polyline(marked, Color(1.0, 0.85, 0.8, 0.7), 2.0, true)
		var dot := tile_center(coordinates) + Vector2(-32, 6) * (hex_radius / REFERENCE_RADIUS)
		draw_circle(dot, 6.0, Color("#ffffff"))
		draw_circle(dot, 4.5, Color("#ff8f73"))
	if not game.rival_changes.is_empty():
		var ring := tile_polygon(game.rival_changes.back())
		ring.append(ring[0])
		draw_polyline(ring, Color("#ffb39e"), 4.0, true)


func _draw_target() -> void:
	if not has_target or not has_selection:
		return
	var outline := tile_polygon(target_coordinates)
	outline.append(outline[0])
	draw_polyline(outline, Color("#ffffff"), 3.0, true)
	var from := tile_center(selected_coordinates)
	var to := tile_center(target_coordinates)
	var direction := (to - from).normalized()
	var start := from + direction * hex_radius * 0.35
	var tip := to - direction * hex_radius * 0.35
	draw_line(start, tip, Color(1, 1, 1, 0.9), 4.0, true)
	var side := direction.orthogonal() * 8.0
	draw_colored_polygon(PackedVector2Array([tip + direction * 10.0, tip + side, tip - side]), Color(1, 1, 1, 0.9))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: Variant = pick_land(event.position)
		var changed: bool = (hovered != null) != has_hover or (hovered != null and hovered != hovered_coordinates)
		has_hover = hovered != null
		if has_hover:
			hovered_coordinates = hovered
		if changed:
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var picked: Variant = pick_land(event.position)
		if picked == null:
			return
		var clicked: Vector2i = picked
		selected_coordinates = clicked
		has_selection = true
		tile_selected.emit(clicked, tiles[clicked])
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and has_hover:
		has_hover = false
		queue_redraw()
