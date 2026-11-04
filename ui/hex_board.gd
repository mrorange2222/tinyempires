extends Control

signal tile_selected(coordinates: Vector2i, terrain: String)

const IslandMap = preload("res://map/island_map.gd")
const PADDING := 18.0
const TILT := 0.58
const LAND_HEIGHT := 0.22
const SHADOW_OFFSET := Vector2(0.10, 0.14)
const HEX_RADIUS := 76.0
const WaterShader = preload("res://ui/water.gdshader")

var tiles: Dictionary[Vector2i, String] = IslandMap.create_tiles()
var selected_coordinates := Vector2i.ZERO
var has_selection := false
var ground_texture: ImageTexture


func _ready() -> void:
	ground_texture = _create_ground_texture()
	var bounds := _map_bounds()
	custom_minimum_size = Vector2(
		(bounds.size.x + SHADOW_OFFSET.x) * HEX_RADIUS + PADDING * 2.0,
		(bounds.size.y * TILT + LAND_HEIGHT + SHADOW_OFFSET.y) * HEX_RADIUS + PADDING * 2.0)
	var water := ColorRect.new()
	water.name = "Water"
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.show_behind_parent = true
	water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var water_material := ShaderMaterial.new()
	water_material.shader = WaterShader
	water.material = water_material
	add_child(water)
	resized.connect(_update_water.bind(water_material))
	_update_water(water_material)


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
			centers.append(tile_center(coordinates) + Vector2(0.0, LAND_HEIGHT * HEX_RADIUS))
	water_material.set_shader_parameter("board_size", size)
	water_material.set_shader_parameter("land_centers", centers)
	water_material.set_shader_parameter("hex_radius", HEX_RADIUS)
	water_material.set_shader_parameter("tilt", TILT)
	queue_redraw()


func _raw_center(coordinates: Vector2i) -> Vector2:
	return Vector2(sqrt(3.0) * (coordinates.x + coordinates.y / 2.0), 1.5 * coordinates.y)


func _map_bounds() -> Rect2:
	var bounds := Rect2(_raw_center(tiles.keys()[0]), Vector2.ZERO)
	for coordinates: Vector2i in tiles:
		bounds = bounds.expand(_raw_center(coordinates))
	return Rect2(bounds.position - Vector2(sqrt(3.0) / 2.0, 1.0),
			bounds.size + Vector2(sqrt(3.0), 2.0))


func tile_center(coordinates: Vector2i) -> Vector2:
	var bounds := _map_bounds()
	var radius := HEX_RADIUS
	var projected := (_raw_center(coordinates) - bounds.get_center()) * Vector2(1.0, TILT)
	var elevation := LAND_HEIGHT if tiles[coordinates] != "Water" else 0.0
	return size / 2.0 + (projected + Vector2(0.0, LAND_HEIGHT / 2.0 - elevation)) * radius


func tile_polygon(coordinates: Vector2i) -> PackedVector2Array:
	var center := tile_center(coordinates)
	var radius := HEX_RADIUS
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
	var drop := Vector2(0.0, LAND_HEIGHT * HEX_RADIUS)
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


func _draw() -> void:
	var radius := HEX_RADIUS
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
	if has_selection:
		var outline := tile_polygon(selected_coordinates)
		outline.append(outline[0])
		draw_polyline(outline, Color("#ffe39a"), 3.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Pick land in reverse painter order; water never changes selection.
		var coordinates_in_front := tiles.keys()
		coordinates_in_front.reverse()
		for coordinates: Vector2i in coordinates_in_front:
			if tiles[coordinates] == "Water":
				continue
			var shapes := tile_faces(coordinates)
			shapes.append(tile_polygon(coordinates))
			for polygon in shapes:
				if Geometry2D.is_point_in_polygon(event.position, polygon):
					selected_coordinates = coordinates
					has_selection = true
					tile_selected.emit(coordinates, tiles[coordinates])
					queue_redraw()
					accept_event()
					return
