extends Control

signal tile_selected(coordinates: Vector2i, terrain: String)

const IslandMap = preload("res://map/island_map.gd")
const EmpireGame = preload("res://game/empire_game.gd")
const KINGDOM_COLORS: Array[Color] = [Color("#79c8df"), Color("#e8a08d")]
const EDGE_INDICES: Array[int] = [0, 5, 4, 3, 2, 1]
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


func tile_center(coordinates: Vector2i) -> Vector2:
	var radius := hex_radius
	var projected := (_raw_center(coordinates) - _land_bounds.get_center()) * Vector2(1.0, TILT)
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
				var edge := EDGE_INDICES[index]
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
	# Rows are stored back-to-front, so nearer land covers the sides behind it.
	for coordinates: Vector2i in tiles:
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
	var coordinates_in_front := tiles.keys()
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
	var font := get_theme_default_font()
	var scale_factor := hex_radius / MAX_HEX_RADIUS
	for coordinates: Vector2i in game.owners:
		var owner: int = game.owners[coordinates]
		if owner == EmpireGame.NEUTRAL:
			continue
		var center := tile_center(coordinates)
		var color := KINGDOM_COLORS[owner]
		if game.is_capital(coordinates):
			var crown_center := center + Vector2(0, -20) * scale_factor
			var s := scale_factor * 0.8
			var crown := PackedVector2Array([
				crown_center + Vector2(-11, -7) * s, crown_center + Vector2(-6, -2) * s,
				crown_center + Vector2(0, -11) * s, crown_center + Vector2(6, -2) * s,
				crown_center + Vector2(11, -7) * s, crown_center + Vector2(8, 7) * s,
				crown_center + Vector2(-8, 7) * s,
			])
			draw_colored_polygon(crown, color)
		if game.improvements.has(coordinates):
			var origin := center + Vector2(30, -4) * scale_factor
			for index in range(3):
				var offset := origin + Vector2((index - 1) * 6, (index - 1) * 2) * scale_factor
				draw_line(offset + Vector2(-3, 4) * scale_factor, offset + Vector2(3, -4) * scale_factor,
						Color("#ead198"), 2.5, true)
		# Army badge: number of armies; a bright dot means some can still act.
		var badge := center + Vector2(0, 6) * scale_factor
		var badge_radius := 13.0 * scale_factor + 2.0
		# Empty tiles get a quieter badge so occupied ones stand out.
		var empty: bool = game.armies[coordinates] == 0
		if empty:
			badge_radius *= 0.75
		draw_circle(badge + Vector2(0, 2), badge_radius, Color(0.02, 0.06, 0.08, 0.35))
		draw_circle(badge, badge_radius, Color("#1d3338", 0.6 if empty else 1.0))
		draw_arc(badge, badge_radius, 0, TAU, 32, Color(color, 0.5 if empty else 1.0), 2.0, true)
		var text := str(game.armies[coordinates])
		var font_size := int(round((11 if empty else 15) * scale_factor + 2))
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, badge + Vector2(-text_size.x / 2.0, font_size * 0.36), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#f1f4ee", 0.55 if empty else 1.0))
		if owner == game.active and owner == EmpireGame.PLAYER and game.ready[coordinates] > 0:
			draw_circle(badge + Vector2(badge_radius * 0.75, -badge_radius * 0.75), 3.5, Color("#fff2b8"))


# Hints only appear where the player can act right now.
func _draw_hints() -> void:
	if game == null:
		return
	_draw_rival_changes()
	if game.winner != EmpireGame.NEUTRAL or game.active != EmpireGame.PLAYER:
		return
	var from_own: bool = has_selection and game.owners.get(selected_coordinates, -1) == EmpireGame.PLAYER
	for coordinates: Vector2i in game.owners:
		var center := tile_center(coordinates) + Vector2(0, -24) * (hex_radius / MAX_HEX_RADIUS)
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
		var dot := tile_center(coordinates) + Vector2(-30, -4) * (hex_radius / MAX_HEX_RADIUS)
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
