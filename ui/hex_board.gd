extends Control

signal tile_selected(coordinates: Vector2i, terrain: String)

const IslandMap = preload("res://map/island_map.gd")
const EmpireGame = preload("res://game/empire_game.gd")
const KINGDOM_COLORS: Array[Color] = [Color("#79c8df"), Color("#e8a08d")]
# Polygon edge facing each neighbour direction (see IslandMap.DIRECTIONS).
const EDGE_INDICES: Array[int] = [0, 5, 4, 3, 2, 1]
# The view is turned 180 degrees so the player's kingdom starts at the bottom.
const FLIPPED := true
const PADDING := 18.0
const TILT := 0.58
const LAND_HEIGHT := 0.22
const SHADOW_OFFSET := Vector2(0.10, 0.14)
const MAX_HEX_RADIUS := 76.0
const MIN_HEX_RADIUS := 50.0
const WaterShader = preload("res://ui/water.gdshader")

var tiles: Dictionary[Vector2i, String] = IslandMap.create_tiles()
var selected_coordinates := Vector2i.ZERO
var has_selection := false
var has_hover := false
var has_target := false
var target_coordinates := Vector2i.ZERO
var hovered_coordinates := Vector2i.ZERO
var game: EmpireGame
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
	var margin := Vector2(sqrt(3.0) / 2.0 + 0.5, 1.5)
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
	slots = slots.slice(0, count)
	slots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for slot_index in range(slots.size()):
		var at := center + Vector2(slots[slot_index].x * r, slots[slot_index].y * r * TILT * 1.6)
		var size := r * (0.15 + 0.03 * float((seed_value + slot_index * 7) % 3))
		match kind:
			"grove":
				_draw_tree(at, size)
			"hills":
				_draw_hill(at, size * 2.4)
			"meadow":
				_draw_tuft(at, size, slot_index + seed_value)


func _draw_tree(base: Vector2, size: float) -> void:
	_draw_ellipse(base + Vector2(size * 0.25, size * 0.12), Vector2(size * 0.75, size * 0.28), Color(0.05, 0.12, 0.05, 0.28))
	draw_line(base, base + Vector2(0, -size * 0.55), Color("#6b4f33"), maxf(2.0, size * 0.18), true)
	var crown := base + Vector2(0, -size * 1.05)
	draw_circle(crown, size * 0.62, Color("#3f6b3c"))
	draw_circle(crown + Vector2(-size * 0.18, -size * 0.2), size * 0.38, Color("#5a8a4a"))
	draw_circle(crown + Vector2(-size * 0.26, -size * 0.3), size * 0.14, Color(1, 1, 0.8, 0.25))


func _draw_hill(base: Vector2, width: float) -> void:
	var points := PackedVector2Array()
	var height := width * 0.42
	for step in range(17):
		var t := step / 16.0
		points.append(base + Vector2((t - 0.5) * width, -sin(t * PI) * height))
	draw_colored_polygon(points, Color("#a4a466"))
	var shade := PackedVector2Array()
	for step in range(8, 17):
		var t := step / 16.0
		shade.append(base + Vector2((t - 0.5) * width, -sin(t * PI) * height))
	shade.append(base)
	draw_colored_polygon(shade, Color(0.32, 0.36, 0.18, 0.35))
	draw_polyline(points, Color(0.3, 0.33, 0.17, 0.5), 1.2, true)


func _draw_tuft(base: Vector2, size: float, variant: int) -> void:
	var green := Color("#4f7a3a")
	for blade in [-1, 0, 1]:
		draw_line(base + Vector2(blade * size * 0.2, 0), base + Vector2(blade * size * 0.45, -size * 0.7),
				green, 1.6, true)
	var petals: Array[Color] = [Color("#f4efd8"), Color("#f2d36b"), Color("#e8a9b8")]
	draw_circle(base + Vector2(size * 0.5, -size * 0.25), maxf(1.6, size * 0.13), petals[variant % 3])


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in range(16):
		var angle := TAU * step / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


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


func _draw_markers() -> void:
	if game == null:
		return
	var scale_factor := hex_radius / MAX_HEX_RADIUS
	# Back to front, so nearer soldiers overlap the ones behind them.
	for coordinates: Vector2i in draw_order():
		var owner: int = game.owners.get(coordinates, EmpireGame.NEUTRAL)
		if owner == EmpireGame.NEUTRAL:
			continue
		var center := tile_center(coordinates)
		var color := KINGDOM_COLORS[owner]
		if game.improvements.has(coordinates):
			var origin := center + Vector2(32, -12) * scale_factor
			for index in range(3):
				var offset := origin + Vector2((index - 1) * 6, (index - 1) * 2) * scale_factor
				draw_line(offset + Vector2(-3, 4) * scale_factor, offset + Vector2(3, -4) * scale_factor,
						Color("#ead198"), 2.5, true)
		var count: int = game.armies[coordinates]
		if count > 0:
			var can_act: bool = owner == game.active and game.ready[coordinates] > 0
			var spent: bool = owner == game.active and not can_act
			_draw_army(center, color, count, spent, scale_factor)
			_draw_army_tag(center + Vector2(19, 13) * scale_factor, color, count, spent,
					can_act and owner == EmpireGame.PLAYER, scale_factor)
		# The crown goes on top so soldiers never hide it.
		if game.is_capital(coordinates):
			_draw_crown(center + Vector2(-33, -20) * scale_factor, color, scale_factor)


## Where soldiers stand for 1, 2 or 3 figures (offsets from the tile centre).
const SOLDIER_SPOTS: Array = [
	[Vector2(0, 10)],
	[Vector2(-9, 4), Vector2(9, 12)],
	[Vector2(-15, 3), Vector2(13, 5), Vector2(-1, 15)],
]


## Soldiers standing on a tile: one per army, at most three (the tag shows the total).
func _draw_army(center: Vector2, color: Color, count: int, spent: bool, s: float) -> void:
	var figures := mini(count, 3)
	var tint := color.lerp(Color("#7a8584"), 0.6) if spent else color
	for spot: Vector2 in SOLDIER_SPOTS[figures - 1]:
		_draw_soldier(center + spot * s * 0.85, tint, spent, s * 0.9)


## One stylised soldier: helmet with a plume, tunic, round shield and spear.
func _draw_soldier(feet: Vector2, color: Color, spent: bool, s: float) -> void:
	var ink := Color(0.07, 0.1, 0.12, 0.9)
	var steel := Color("#c3cbcc") if not spent else Color("#8f9898")
	var steel_dark := steel.darkened(0.35)
	var skin := Color("#e9c7a3") if not spent else Color("#b9a796")
	_draw_ellipse(feet + Vector2(1, 0), Vector2(10, 3.5) * s, Color(0, 0, 0, 0.3))
	# Spear behind the body.
	draw_line(feet + Vector2(8, 1) * s, feet + Vector2(8, -40) * s, Color("#6b4f33"), 2.0 * s, true)
	draw_colored_polygon(PackedVector2Array([feet + Vector2(8, -46) * s, feet + Vector2(10.5, -39) * s,
		feet + Vector2(5.5, -39) * s]), steel)
	# Legs.
	draw_line(feet + Vector2(-3, -9) * s, feet + Vector2(-3, 0) * s, Color("#2b3236"), 3.0 * s, true)
	draw_line(feet + Vector2(3, -9) * s, feet + Vector2(3, 0) * s, Color("#2b3236"), 3.0 * s, true)
	# Tunic, slightly flared, with a belt.
	var tunic := PackedVector2Array([feet + Vector2(-7.5, -8) * s, feet + Vector2(7.5, -8) * s,
		feet + Vector2(5.5, -23) * s, feet + Vector2(-5.5, -23) * s])
	draw_colored_polygon(tunic, color)
	draw_line(feet + Vector2(-6.8, -13) * s, feet + Vector2(6.8, -13) * s, color.darkened(0.35), 1.6 * s, true)
	tunic.append(tunic[0])
	draw_polyline(tunic, ink, 1.0, true)
	# Hand on the spear.
	draw_circle(feet + Vector2(8, -18) * s, 1.8 * s, skin)
	# Head.
	draw_circle(feet + Vector2(0, -27.5) * s, 4.4 * s, skin)
	# Helmet: rounded dome with a brim, nose guard and a plume in kingdom colour.
	var dome := PackedVector2Array()
	for step in range(13):
		var angle := PI + PI * step / 12.0
		dome.append(feet + Vector2(cos(angle) * 5.6, -28.5 + sin(angle) * 5.6) * s)
	draw_colored_polygon(dome, steel)
	draw_line(feet + Vector2(-6.6, -28.3) * s, feet + Vector2(6.6, -28.3) * s, steel_dark, 1.8 * s, true)
	draw_line(feet + Vector2(0, -28.3) * s, feet + Vector2(0, -25.2) * s, steel_dark, 1.2 * s, true)
	draw_circle(feet + Vector2(-2, -31.5) * s, 1.2 * s, Color(1, 1, 1, 0.55))
	_draw_ellipse(feet + Vector2(0, -35.5) * s, Vector2(2.2, 3.2) * s, color.lightened(0.15))
	# Round shield in front, kingdom colour with a steel rim and boss.
	var shield := feet + Vector2(-6.5, -15) * s
	draw_circle(shield, 6.2 * s, color.darkened(0.15))
	draw_arc(shield, 6.2 * s, 0, TAU, 20, steel, 1.6 * s, true)
	draw_circle(shield, 1.6 * s, steel)


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


func _draw_crown(at: Vector2, color: Color, s: float) -> void:
	draw_circle(at, 10.5 * s, Color("#1d3338", 0.85))
	var k := s * 0.75
	var crown := PackedVector2Array([
		at + Vector2(-9, -3) * k, at + Vector2(-5, 1) * k, at + Vector2(0, -7) * k,
		at + Vector2(5, 1) * k, at + Vector2(9, -3) * k, at + Vector2(7, 6) * k, at + Vector2(-7, 6) * k,
	])
	draw_colored_polygon(crown, color)


# Hints only appear where the player can act right now.
func _draw_hints() -> void:
	if game == null:
		return
	_draw_rival_changes()
	if game.winner != EmpireGame.NEUTRAL or game.active != EmpireGame.PLAYER:
		return
	var from_own: bool = has_selection and game.owners.get(selected_coordinates, -1) == EmpireGame.PLAYER
	for coordinates: Vector2i in game.owners:
		var center := tile_center(coordinates) + Vector2(0, -46) * (hex_radius / MAX_HEX_RADIUS)
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
		var dot := tile_center(coordinates) + Vector2(-32, 6) * (hex_radius / MAX_HEX_RADIUS)
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
