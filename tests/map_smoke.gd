extends SceneTree

const IslandMap = preload("res://map/island_map.gd")
const HexBoard = preload("res://ui/hex_board.gd")
var failures := 0
var selection_events := 0
var last_picked := Vector2i(-999, -999)


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1


func _on_tile_selected(coordinates: Vector2i, _terrain: String) -> void:
	selection_events += 1
	last_picked = coordinates


func _scroll_to(scroll: ScrollContainer, board: Control, point: Vector2) -> void:
	scroll.scroll_horizontal = roundi(point.x - scroll.size.x / 2.0)
	scroll.scroll_vertical = roundi(point.y - scroll.size.y / 2.0)
	await process_frame
	var visible_point := board.get_global_transform_with_canvas() * point
	_check(scroll.get_global_rect().has_point(visible_point), "Scrolled target must be visible")


func _run() -> void:
	var tiles: Dictionary[Vector2i, String] = IslandMap.create_tiles()
	_check(tiles.size() == 81, "Expected a fixed 9 x 9 board including water")
	_check(tiles == IslandMap.create_tiles(), "Map must be deterministic")
	var land: Array[Vector2i] = []
	var terrains: Array[String] = []
	for coordinates: Vector2i in tiles:
		var terrain := tiles[coordinates]
		if not terrains.has(terrain):
			terrains.append(terrain)
		if terrain != "Water":
			land.append(coordinates)
			for direction: Vector2i in IslandMap.DIRECTIONS:
				_check(tiles.has(coordinates + direction), "Land must have a surrounding water margin")
	_check(land.size() == 35, "Expected 35 land tiles")
	_check(terrains.size() == 2 and terrains.has("Plains") and terrains.has("Water"),
			"Preview must contain only empty plains and water")
	var visited: Array[Vector2i] = [land[0]]
	var frontier: Array[Vector2i] = [land[0]]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for direction: Vector2i in IslandMap.DIRECTIONS:
			var neighbor := current + direction
			if land.has(neighbor) and not visited.has(neighbor):
				visited.append(neighbor)
				frontier.append(neighbor)
	_check(visited.size() == land.size(), "All land must be connected")

	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate()
	root.add_child(main)
	current_scene = main
	var board: HexBoard = main.get_node("Margin/Layout/PlayArea/Scroll/Board")
	board.tile_selected.connect(_on_tile_selected)
	var scroll: ScrollContainer = main.get_node("Margin/Layout/PlayArea/Scroll")
	var selection: Label = main.get_node("Margin/Layout/Selection")
	for window_size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		var had_selection := board.has_selection
		var selected_before_resize := board.selected_coordinates
		var readout_before_resize := selection.text
		root.size = window_size
		for frame in range(10):
			await process_frame
		if had_selection:
			_check(board.has_selection and board.selected_coordinates == selected_before_resize,
					"Resizing must preserve the selected tile")
			_check(selection.text == readout_before_resize, "Resizing must preserve the readout")
		var canvas := Rect2(Vector2.ZERO, main.size)
		for path in ["Margin/Layout/Header/Title", "Margin/Layout/Instructions",
				"Margin/Layout/PlayArea", "Margin/Layout/Legend", "Margin/Layout/Selection"]:
			var control: Control = main.get_node(path)
			_check(canvas.encloses(control.get_global_rect()), "UI must fit: " + path)
		var selection_before_outside_click := board.selected_coordinates
		var outside_viewport := InputEventMouseButton.new()
		outside_viewport.button_index = MOUSE_BUTTON_LEFT
		outside_viewport.pressed = true
		outside_viewport.position = main.get_node("Margin/Layout/Header/Title").global_position + Vector2(5, 5)
		root.push_input(outside_viewport, true)
		_check(board.selected_coordinates == selection_before_outside_click,
				"Clipped map must not intercept clicks outside the scroll viewport")
		outside_viewport.pressed = false
		root.push_input(outside_viewport, true)
		_check(board.hex_radius > HexBoard.MIN_HEX_RADIUS, "Hexes stay above minimum size at this window")
		_check(board.size.x <= scroll.size.x + 1 and board.size.y <= scroll.size.y + 1,
				"Whole island fits without scrolling when hexes can shrink")
		var kinds := {}
		for coordinates: Vector2i in land:
			kinds[board.decor_kind(coordinates)] = true
			_check(board.decor_kind(coordinates) == board.decor_kind(coordinates), "Decor is deterministic")
		_check(kinds.size() == 3, "Groves, hills and meadows all appear")
		var water: ColorRect = board.get_node("Water")
		_check(board.ground_texture != null, "Ground texture must be generated")
		_check(water.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Water rendering must not intercept clicks")
		_check(water.size.is_equal_approx(board.size), "Water must cover the board")
		# Send clicks through the viewport so coordinate conversion and GUI routing are tested.
		for coordinates: Vector2i in tiles:
			var center: Vector2 = board.tile_center(coordinates)
			# Outer water lies beyond the fitted board; it is not shown or clickable.
			if not Rect2(Vector2.ZERO, board.size).has_point(center):
				continue
			await _scroll_to(scroll, board, center)
			for vertex: Vector2 in board.tile_polygon(coordinates):
				_check(tiles[coordinates] == "Water" or Rect2(Vector2.ZERO, board.size).has_point(vertex),
						"Land hex must fit inside board")
			var polygon := board.tile_polygon(coordinates)
			var width := polygon[0].x - polygon[3].x
			var height := polygon[2].y - polygon[5].y
			_check(is_equal_approx(height / width, 2.0 * HexBoard.TILT / sqrt(3.0)),
					"Hex surfaces must use the tilted projection")
			_check(is_equal_approx(width, sqrt(3.0) * board.hex_radius),
					"Hexes use the fitted radius")
			for face in board.tile_faces(coordinates):
				for vertex in face:
					_check(Rect2(Vector2.ZERO, board.size).has_point(vertex),
							"Raised faces must fit inside board")
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = board.get_global_transform_with_canvas() * center
			click.pressed = true
			var previous_selection := board.selected_coordinates
			var previously_selected := board.has_selection
			var previous_readout := selection.text
			var previous_events := selection_events
			root.push_input(click, true)
			if tiles[coordinates] == "Water":
				_check(board.has_selection == previously_selected
						and board.selected_coordinates == previous_selection,
						"Water click must not create or change selection")
				_check(selection.text == previous_readout, "Water click must not change readout")
				_check(selection_events == previous_events, "Water click must not emit selection")
			else:
				_check(last_picked == coordinates, "Click must pick the correct land hex %s got %s" % [coordinates, last_picked])
				_check(selection.text.begins_with("Selected: ")
						and (selection.text.contains("land") or selection.text.contains("capital")),
						"Selection readout must describe the selected land")
				_check(selection_events == previous_events + 1, "Land click must emit selection once")
			click.pressed = false
			root.push_input(click, true)
		var exposed_faces := 0
		for coordinates: Vector2i in land:
			for face in board.tile_faces(coordinates):
				var midpoint := Vector2.ZERO
				for vertex in face:
					midpoint += vertex / 4.0
				var covered := false
				for other: Vector2i in land:
					if Geometry2D.is_point_in_polygon(midpoint, board.tile_polygon(other)):
						covered = true
				if covered:
					continue
				exposed_faces += 1
				await _scroll_to(scroll, board, midpoint)
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.position = board.get_global_transform_with_canvas() * midpoint
				click.pressed = true
				root.push_input(click, true)
				_check(last_picked == coordinates,
						"Visible coastline face must pick land rather than water")
				click.pressed = false
				root.push_input(click, true)
		_check(exposed_faces > 0, "Must test visible raised coastline faces")
		var preserved_selection := board.selected_coordinates
		board.queue_redraw()
		await process_frame
		_check(board.selected_coordinates == preserved_selection, "Redraw must preserve selection")
		var previous: Vector2i = board.selected_coordinates
		await _scroll_to(scroll, board, Vector2(1, 1))
		var outside := InputEventMouseButton.new()
		outside.button_index = MOUSE_BUTTON_LEFT
		outside.pressed = true
		outside.position = board.global_position + Vector2(1, 1)
		root.push_input(outside, true)
		_check(board.selected_coordinates == previous, "Outside click must preserve selection")
		print("Checked all hex centers, ", exposed_faces, " coastline faces, and layout at ", window_size)

	# Squeeze the map area so hexes hit their minimum size; the view must scroll.
	root.size = Vector2i(1280, 800)
	var sidebar: Control = main.get_node("Margin/Layout/PlayArea/Sidebar")
	sidebar.custom_minimum_size.x = 900
	for frame in range(10):
		await process_frame
	_check(is_equal_approx(board.hex_radius, HexBoard.MIN_HEX_RADIUS), "Squeezed map uses minimum hex size")
	_check(board.size.x > scroll.size.x, "Squeezed map overflows horizontally")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.shift_pressed = true
	wheel.position = scroll.global_position + scroll.size / 2.0
	scroll.scroll_horizontal = 0
	await process_frame
	root.push_input(wheel, true)
	await process_frame
	_check(scroll.scroll_horizontal > 0, "Shift + wheel scrolls an overflowing map")
	for coordinates: Vector2i in land:
		await _scroll_to(scroll, board, board.tile_center(coordinates))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = board.get_global_transform_with_canvas() * board.tile_center(coordinates)
		click.pressed = true
		root.push_input(click, true)
		_check(last_picked == coordinates, "Scrolled minimum-size map picks correctly %s got %s" % [coordinates, last_picked])
		click.pressed = false
		root.push_input(click, true)
	sidebar.custom_minimum_size.x = 290
	for frame in range(10):
		await process_frame
	await _scroll_to(scroll, board, board.size / 2.0)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			await RenderingServer.frame_post_draw
			var result := root.get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
			_check(result == OK, "Screenshot must save successfully")
	if failures == 0:
		print("PASS: fixed map, connected land, terrain, selection, water, and resizing")
	else:
		printerr("FAILED: ", failures, " checks")
	quit(0 if failures == 0 else 1)
