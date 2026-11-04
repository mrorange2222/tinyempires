extends SceneTree

const IslandMap = preload("res://map/island_map.gd")
const HexBoard = preload("res://ui/hex_board.gd")
var failures := 0
var selection_events := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1


func _on_tile_selected(_coordinates: Vector2i, _terrain: String) -> void:
	selection_events += 1


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
		for path in ["Margin/Layout/Title", "Margin/Layout/Instructions",
				"Margin/Layout/PlayArea", "Margin/Layout/Legend", "Margin/Layout/Selection"]:
			var control: Control = main.get_node(path)
			_check(canvas.encloses(control.get_global_rect()), "UI must fit: " + path)
		var selection_before_outside_click := board.selected_coordinates
		var outside_viewport := InputEventMouseButton.new()
		outside_viewport.button_index = MOUSE_BUTTON_LEFT
		outside_viewport.pressed = true
		outside_viewport.position = main.get_node("Margin/Layout/Title").global_position + Vector2(5, 5)
		root.push_input(outside_viewport, true)
		_check(board.selected_coordinates == selection_before_outside_click,
				"Clipped map must not intercept clicks outside the scroll viewport")
		outside_viewport.pressed = false
		root.push_input(outside_viewport, true)
		_check(scroll.get_h_scroll_bar().visible and scroll.get_v_scroll_bar().visible,
				"Both scrollbars must expose the oversized map")
		_check(board.size.x > scroll.size.x and board.size.y > scroll.size.y,
				"Board must be larger than its viewport")
		var water: ColorRect = board.get_node("Water")
		_check(board.ground_texture != null, "Ground texture must be generated")
		_check(water.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Water rendering must not intercept clicks")
		_check(water.size.is_equal_approx(board.size), "Water must cover the board")
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = scroll.global_position + scroll.size / 2.0
		scroll.scroll_vertical = 0
		await process_frame
		root.push_input(wheel, true)
		await process_frame
		_check(scroll.scroll_vertical > 0, "Mouse wheel must scroll the viewport")
		scroll.scroll_horizontal = 0
		wheel.shift_pressed = true
		root.push_input(wheel, true)
		await process_frame
		_check(scroll.scroll_horizontal > 0, "Shift + wheel must scroll horizontally")
		# Send clicks through the viewport so coordinate conversion and GUI routing are tested.
		for coordinates: Vector2i in tiles:
			var center: Vector2 = board.tile_center(coordinates)
			await _scroll_to(scroll, board, center)
			for vertex: Vector2 in board.tile_polygon(coordinates):
				_check(Rect2(Vector2.ZERO, board.size).has_point(vertex), "Hex must fit inside board")
			var polygon := board.tile_polygon(coordinates)
			var width := polygon[0].x - polygon[3].x
			var height := polygon[2].y - polygon[5].y
			_check(is_equal_approx(height / width, 2.0 * HexBoard.TILT / sqrt(3.0)),
					"Hex surfaces must use the tilted projection")
			_check(is_equal_approx(width, sqrt(3.0) * HexBoard.HEX_RADIUS),
					"Hexes must retain the larger fixed size after resize")
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
				_check(board.has_selection and board.selected_coordinates == coordinates,
						"Click must select the correct land hex")
				_check(selection.text.begins_with("Plains |") and selection.text.ends_with("Empty land"),
						"Selection readout must describe empty plains")
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
				_check(board.selected_coordinates == coordinates,
						"Visible coastline face must select land rather than water")
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
