extends Control
## The opening screen: a gently animated medieval scene drawn in code, in the
## same flat style as the map pieces, with the main menu and an options panel.

signal new_game_pressed
signal resume_pressed
signal how_to_play_pressed
signal exit_pressed
signal options_changed(new_options: Dictionary)

const TileArt = preload("res://ui/tile_art.gd")
const TITLE_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito-Variable.ttf")
const BLUE := Color("#79c8df")
const CORAL := Color("#e8a08d")
const GOLD := Color("#f0d48a")
const CREAM := Color("#efe6cc")
const MUTED := Color("#93a5a3")
const TILT := 0.58
const TAGLINE := "One island. Two crowns."

## Island tiles (axial q, r) and what stands on each.
const ISLAND: Array = [
	[Vector2i(0, -1), "trees"], [Vector2i(1, -1), "trees_small"], [Vector2i(2, -1), "windmill"],
	[Vector2i(-1, 0), "wheat"], [Vector2i(0, 0), "castle"], [Vector2i(1, 0), "pasture"],
	[Vector2i(-2, 1), "trees"], [Vector2i(-1, 1), "blue_army"], [Vector2i(0, 1), "coral_army"],
]
## Clouds: x as a fraction of the width, height within the band between the
## title and the hills (0 top, 1 bottom), size, drift speed in px/s.
const CLOUDS: Array = [[0.10, 0.55, 1.0, 7.0], [0.42, 0.1, 0.75, 4.5], [0.74, 0.75, 1.15, 6.0],
	[0.93, 0.25, 0.6, 3.5]]

var options := {"rival_speed": "Normal", "fullscreen": false, "show_hints": true}
var time := 0.0
var heading: VBoxContainer
var title_label: Label
var tagline: Label
var menu_box: VBoxContainer
var footer: Label
var menu_buttons := {}
var options_panel: Control
var _option_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_heading()
	_build_menu()
	footer = Label.new()
	footer.text = "Prototype  ·  v0.2"
	footer.add_theme_color_override("font_color", Color(MUTED, 0.8))
	footer.add_theme_font_size_override("font_size", 12)
	add_child(footer)
	options_panel = _build_options_panel()
	add_child(options_panel)
	resized.connect(_layout)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	_layout()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and options_panel.visible and event.is_action_pressed("ui_cancel"):
		options_panel.hide()
		get_viewport().set_input_as_handled()


## Shows the current options on the panel's buttons.
func set_options(new_options: Dictionary) -> void:
	options = new_options.duplicate()
	for key: String in _option_buttons:
		for button: Button in _option_buttons[key]:
			button.set_pressed_no_signal(button.get_meta("value") == options[key])


func open_options() -> void:
	set_options(options)
	options_panel.show()


func set_resume_available(available: bool) -> void:
	menu_buttons["resume"].visible = available
	_layout()


# --- Layout and widgets --------------------------------------------------------

func _font(base: Font, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _box(color: Color, border: Color, radius := 6, pad := Vector2(14, 8)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad.x
	style.content_margin_right = pad.x
	style.content_margin_top = pad.y
	style.content_margin_bottom = pad.y
	style.anti_aliasing = true
	return style


func _build_heading() -> void:
	heading = VBoxContainer.new()
	heading.add_theme_constant_override("separation", 2)
	add_child(heading)
	title_label = Label.new()
	title_label.text = "The Tiny Empire"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", _font(TITLE_FONT, 800))
	title_label.add_theme_color_override("font_color", GOLD)
	title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05, 0.9))
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	heading.add_child(title_label)
	tagline = Label.new()
	tagline.text = TAGLINE
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tag_font := _font(BODY_FONT, 650)
	tag_font.spacing_glyph = 2
	tagline.add_theme_font_override("font", tag_font)
	tagline.add_theme_color_override("font_color", CREAM)
	tagline.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05, 0.7))
	tagline.add_theme_constant_override("outline_size", 4)
	heading.add_child(tagline)


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font(TITLE_FONT, 700))
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _box(Color(0.06, 0.1, 0.13, 0.78), Color("#8a7444")))
	button.add_theme_stylebox_override("hover", _box(Color(0.1, 0.15, 0.18, 0.9), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color(0.04, 0.07, 0.09, 0.92), GOLD))
	return button


func _build_menu() -> void:
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	add_child(menu_box)
	var actions := [
		["resume", "Resume", func() -> void: resume_pressed.emit()],
		["new_game", "New Game", func() -> void: new_game_pressed.emit()],
		["how_to_play", "How to Play", func() -> void: how_to_play_pressed.emit()],
		["options", "Options", open_options],
		["exit", "Exit Game", func() -> void: exit_pressed.emit()],
	]
	for action: Array in actions:
		var button := _menu_button(action[1])
		button.name = action[1].replace(" ", "")
		button.pressed.connect(action[2])
		menu_box.add_child(button)
		menu_buttons[action[0]] = button
	menu_buttons["resume"].hide()


func _layout() -> void:
	var title_size := clampi(int(minf(size.x * 0.075, size.y * 0.085)), 34, 92)
	title_label.add_theme_font_size_override("font_size", title_size)
	tagline.add_theme_font_size_override("font_size", clampi(int(title_size * 0.3), 14, 26))
	heading.size = Vector2(size.x, 0)
	heading.size = Vector2(size.x, heading.get_combined_minimum_size().y)
	heading.position = Vector2(0, size.y * 0.06)
	menu_box.size = menu_box.get_combined_minimum_size()
	menu_box.position = Vector2((size.x - menu_box.size.x) / 2.0, size.y - menu_box.size.y - size.y * 0.07)
	footer.size = footer.get_combined_minimum_size()
	footer.position = size - footer.size - Vector2(14, 10)
	queue_redraw()


func _build_options_panel() -> Control:
	var shade := ColorRect.new()
	shade.name = "Options"
	shade.color = Color(0.02, 0.04, 0.06, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("#13252b"), Color("#6b5f3a"), 12, Vector2(26, 20)))
	card.custom_minimum_size = Vector2(420, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var heading_label := Label.new()
	heading_label.text = "Options"
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.add_theme_font_override("font", _font(TITLE_FONT, 700))
	heading_label.add_theme_font_size_override("font_size", 22)
	heading_label.add_theme_color_override("font_color", Color("#f0e6c8"))
	box.add_child(heading_label)
	_add_choice_row(box, "RIVAL SPEED", "rival_speed", ["Fast", "Normal", "Slow"], ["Fast", "Normal", "Slow"])
	_add_choice_row(box, "DISPLAY", "fullscreen", [false, true], ["Windowed", "Fullscreen"])
	_add_choice_row(box, "MAP HINTS", "show_hints", [true, false], ["On", "Off"])
	var note := Label.new()
	note.text = "Rival speed is the pause between the rival's moves. Map hints mark land you can claim and tiles you can attack or move to."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#c3cfcc"))
	note.add_theme_font_size_override("font_size", 13)
	box.add_child(note)
	var done := Button.new()
	done.name = "Done"
	done.text = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.custom_minimum_size = Vector2(110, 34)
	done.add_theme_stylebox_override("normal", _box(Color("#2f6b5f"), Color("#5fa595")))
	done.add_theme_stylebox_override("hover", _box(Color("#3a7d70"), Color("#9fd3c4")))
	done.pressed.connect(func() -> void: options_panel.hide())
	box.add_child(done)
	shade.set_meta("done", done)
	return shade


func _add_choice_row(box: VBoxContainer, heading_text: String, key: String, values: Array, labels: Array) -> void:
	var heading_label := Label.new()
	heading_label.text = heading_text
	heading_label.add_theme_color_override("font_color", MUTED)
	heading_label.add_theme_font_size_override("font_size", 12)
	box.add_child(heading_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for index in range(values.size()):
		var choice := Button.new()
		choice.text = labels[index]
		choice.toggle_mode = true
		choice.button_group = group
		choice.focus_mode = Control.FOCUS_NONE
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.set_meta("value", values[index])
		choice.add_theme_stylebox_override("normal", _box(Color("#22383e"), Color("#3a5459")))
		choice.add_theme_stylebox_override("hover", _box(Color("#2d4950"), Color("#5f8a90")))
		choice.add_theme_stylebox_override("pressed", _box(Color("#2f6b5f"), Color("#9fd3c4")))
		choice.toggled.connect(func(on: bool) -> void:
			if on:
				options[key] = values[index]
				options_changed.emit(options.duplicate()))
		row.add_child(choice)
		buttons.append(choice)
	_option_buttons[key] = buttons


# --- The scene -------------------------------------------------------------------

func _draw() -> void:
	var area_top := heading.position.y + heading.size.y
	var area_bottom := menu_box.position.y
	var horizon := lerpf(area_top, area_bottom, 0.42)
	_draw_sky(horizon)
	_draw_stars(horizon)
	var sun_radius := size.y * 0.05
	var sun := Vector2(size.x * 0.72, horizon - sun_radius * 0.35)
	_draw_sun(sun, sun_radius)
	_draw_clouds(area_top, horizon)
	_draw_hills(horizon)
	_draw_sea(horizon, sun, sun_radius)
	var radius := clampf(minf(size.x * 0.065, (area_bottom - horizon) * 0.36), 22.0, 74.0)
	# Middle of the island between the horizon and the menu; it may rise a little
	# over the far hills, as if seen from above.
	# Keep the front tiles' sides clear of the menu.
	var lowest := lerpf(horizon, area_bottom, 0.5) + radius * 0.15
	_draw_island(Vector2(size.x * 0.5, minf(lowest, area_bottom - radius * 1.75)), radius)
	_draw_birds(area_top, horizon)
	_draw_shades(area_top)
	_draw_flourishes()


func _gradient(top: float, bottom: float, top_color: Color, bottom_color: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, bottom),
		Vector2(0, bottom)]), PackedColorArray([top_color, top_color, bottom_color, bottom_color]))


func _draw_sky(horizon: float) -> void:
	_gradient(0, horizon * 0.45, Color("#0e1730"), Color("#2c3263"))
	_gradient(horizon * 0.45, horizon * 0.8, Color("#2c3263"), Color("#8a5878"))
	_gradient(horizon * 0.8, horizon + 1, Color("#8a5878"), Color("#f0a26f"))


func _hash(index: int, salt: float) -> float:
	return fposmod(sin(index * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _draw_stars(horizon: float) -> void:
	for index in range(48):
		var at := Vector2(_hash(index, 1.0) * size.x, _hash(index, 2.0) * horizon * 0.55)
		var glow := 0.35 + 0.3 * sin(time * 1.3 + index * 1.7)
		draw_circle(at, 0.8 + _hash(index, 3.0), Color(1, 0.97, 0.88, glow))


func _draw_sun(center: Vector2, radius: float) -> void:
	for ring in range(5):
		draw_circle(center, radius * (1.0 + ring * 0.38), Color(1, 0.78, 0.45, 0.1 - ring * 0.018))
	draw_circle(center, radius, Color("#ffd37a"))
	draw_circle(center + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.55, Color("#ffe6a8"))


func _draw_clouds(area_top: float, horizon: float) -> void:
	var unit := minf(size.y / 800.0, (horizon - area_top) / 150.0)
	var band_top := area_top + 34.0 * unit
	var band_bottom := horizon - size.y * 0.09
	for cloud: Array in CLOUDS:
		var s: float = cloud[2] * unit
		var span := size.x + 260.0 * s
		var x := fposmod(cloud[0] * size.x + time * cloud[3], span) - 130.0 * s
		_draw_cloud(Vector2(x, lerpf(band_top, band_bottom, cloud[1])), s)


func _draw_cloud(at: Vector2, s: float) -> void:
	var puffs := [[-34, 0, 20], [-8, -10, 27], [22, -4, 22], [44, 4, 15]]
	TileArt.ellipse(self, at + Vector2(4, 12) * s, Vector2(62, 11) * s, Color("#a86f86", 0.85))
	for puff: Array in puffs:
		draw_circle(at + Vector2(puff[0], puff[1] + 4) * s, puff[2] * s, Color("#a86f86", 0.85))
	for puff: Array in puffs:
		draw_circle(at + Vector2(puff[0], puff[1]) * s, puff[2] * 0.9 * s, Color("#f3c3b0", 0.95))
	draw_circle(at + Vector2(-12, -18) * s, 9 * s, Color(1, 1, 1, 0.25))


func _ridge(horizon: float, height: float, frequency: float, phase: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, horizon + 1)])
	var steps := 48
	for step in range(steps + 1):
		var x := size.x * step / steps
		var wave := 0.55 + 0.3 * sin(x * frequency + phase) + 0.15 * sin(x * frequency * 2.7 + phase * 1.9)
		points.append(Vector2(x, horizon - height * wave))
	points.append(Vector2(size.x, horizon + 1))
	draw_colored_polygon(points, color)


func _draw_hills(horizon: float) -> void:
	_ridge(horizon, size.y * 0.075, 0.0065, 1.2, Color("#6a4f74"))
	# A far-off tower on the hills.
	var tower := Vector2(size.x * 0.17, horizon - size.y * 0.06)
	var t := size.y / 800.0
	draw_rect(Rect2(tower + Vector2(-5, -18) * t, Vector2(10, 22) * t), Color("#55405f"))
	draw_colored_polygon(PackedVector2Array([tower + Vector2(-7, -18) * t, tower + Vector2(0, -30) * t,
		tower + Vector2(7, -18) * t]), Color("#55405f"))
	_ridge(horizon, size.y * 0.045, 0.011, 4.0, Color("#3f4766"))


func _draw_sea(horizon: float, sun: Vector2, sun_radius: float) -> void:
	_gradient(horizon, size.y, Color("#7b6a88"), Color("#0b2a3c"))
	_gradient(horizon, horizon + size.y * 0.02, Color(1, 0.75, 0.55, 0.35), Color(1, 0.75, 0.55, 0.0))
	# Sun glitter on the water.
	for row in range(14):
		var y := horizon + 4.0 + row * row * 0.9 + row * 3.0
		if y > size.y:
			break
		var width := sun_radius * 1.7 * (1.0 - row / 16.0) * (0.65 + 0.35 * sin(time * 2.2 + row * 1.3))
		draw_line(Vector2(sun.x - width, y), Vector2(sun.x + width, y), Color(1, 0.85, 0.55, 0.55 - row * 0.035), 2.0)
	# Drifting wave lines.
	for index in range(36):
		var depth := _hash(index, 5.0)
		var y := lerpf(horizon + 6.0, size.y, depth * depth)
		var length := 10.0 + depth * 36.0
		var x := fposmod(_hash(index, 6.0) * size.x + time * (6.0 + depth * 14.0), size.x + length) - length
		draw_line(Vector2(x, y), Vector2(x + length, y), Color(0.85, 0.92, 1.0, 0.07 + depth * 0.1), 1.5)


func _hex_corners(center: Vector2, radius: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for corner in range(6):
		var angle := deg_to_rad(60.0 * corner - 30.0)
		corners.append(center + Vector2(cos(angle), sin(angle) * TILT) * radius)
	return corners


func _draw_island(center: Vector2, radius: float) -> void:
	var s := radius / 76.0
	var tiles := ISLAND.duplicate()
	tiles.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0].y < b[0].y or (a[0].y == b[0].y and a[0].x < b[0].x))
	# Shadows and foam first, so every tile sits on them.
	for tile: Array in tiles:
		var base := center + _offset(tile[0], radius)
		TileArt.ellipse(self, base + Vector2(radius * 0.12, radius * 0.22), Vector2(radius * 1.05, radius * 0.6), Color(0, 0, 0, 0.22))
	for tile: Array in tiles:
		var base := center + _offset(tile[0], radius)
		var foam := PackedVector2Array()
		for step in range(13):
			var angle := PI * step / 12.0
			foam.append(base + Vector2(cos(angle) * radius * 0.98, sin(angle) * radius * 0.62 + 3.0))
		draw_polyline(foam, Color(1, 1, 1, 0.22 + 0.12 * sin(time * 2.0 + tile[0].x * 1.7)), 1.5, true)
	for tile: Array in tiles:
		var kind: String = tile[1]
		var height := radius * (0.6 if kind == "castle" else 0.24)
		var top := center + _offset(tile[0], radius) - Vector2(0, height)
		_draw_tile(top, radius, height, kind == "castle")
		_draw_tile_piece(kind, top, radius, s, tile[0])


func _offset(axial: Vector2i, radius: float) -> Vector2:
	return Vector2(sqrt(3.0) * (axial.x + axial.y / 2.0), 1.5 * axial.y * TILT) * radius


func _draw_tile(top: Vector2, radius: float, height: float, hill: bool) -> void:
	var corners := _hex_corners(top, radius)
	var drop := Vector2(0, height)
	var faces := [[0, 1, Color("#9a7a55")], [1, 2, Color("#86683f")], [2, 3, Color("#6e5636")], [3, 4, Color("#5a472e")]]
	for face: Array in faces:
		var a: Vector2 = corners[face[0]]
		var b: Vector2 = corners[face[1]]
		draw_colored_polygon(PackedVector2Array([a, b, b + drop, a + drop]), face[2])
		draw_line(a + drop * 0.3, b + drop * 0.3, Color(0.25, 0.2, 0.12, 0.35), 1.2, true)
	draw_colored_polygon(corners, Color("#93ad62") if hill else Color("#86a35d"))
	var outline := corners.duplicate()
	outline.append(corners[0])
	draw_polyline(outline, Color(0.2, 0.29, 0.14, 0.5), 1.2, true)
	# Warm sunset light on the edges facing the sun.
	draw_line(corners[4], corners[5], Color("#ffd29a", 0.35), 2.0, true)
	draw_line(corners[5], corners[0], Color("#ffd29a", 0.55), 2.0, true)


func _draw_tile_piece(kind: String, top: Vector2, radius: float, s: float, axial: Vector2i) -> void:
	match kind:
		"castle":
			_draw_banner(top + Vector2(-radius * 0.62, radius * 0.1), radius, BLUE, 0.0)
			_draw_banner(top + Vector2(radius * 0.62, radius * 0.1), radius, CORAL, 1.7)
			TileArt.castle(self, top + Vector2(0, radius * 0.18), Color("#d9b06a"), s * 2.3)
		"windmill":
			TileArt.farm(self, top + Vector2(-radius * 0.1, radius * 0.12), "windmill", CORAL, s * 1.7, time * 0.9)
		"wheat":
			TileArt.farm(self, top + Vector2(0, radius * 0.12), "wheat", BLUE, s * 1.5)
		"pasture":
			TileArt.farm(self, top + Vector2(0, radius * 0.14), "pasture", CORAL, s * 1.5)
		"hill":
			TileArt.hill(self, top + Vector2(-radius * 0.15, radius * 0.1), radius * 0.9)
			TileArt.tree(self, top + Vector2(radius * 0.4, radius * 0.18), radius * 0.2)
		"trees_small":
			for spot: Vector2 in [Vector2(-0.4, 0.15), Vector2(0.35, 0.05)]:
				TileArt.tree(self, top + spot * radius, radius * 0.18)
		"trees":
			for spot: Vector2 in [Vector2(-0.35, 0.0), Vector2(0.2, -0.1), Vector2(0.0, 0.22), Vector2(0.45, 0.2)]:
				TileArt.tree(self, top + spot * radius, radius * (0.2 + 0.04 * ((axial.x + int(spot.x * 10)) % 2)))
		"blue_army", "coral_army":
			var color := BLUE if kind == "blue_army" else CORAL
			for spot: Vector2 in [Vector2(-0.25, -0.02), Vector2(0.22, 0.12)]:
				TileArt.soldier(self, top + spot * radius, color, false, s * 1.45)


## A tall waving banner on a pole, in a kingdom's colour.
func _draw_banner(base: Vector2, radius: float, color: Color, phase: float) -> void:
	var pole := radius * 1.45
	var top := base - Vector2(0, pole)
	draw_line(base, top, Color("#6b4f33"), maxf(2.0, radius * 0.045), true)
	draw_circle(top, radius * 0.05, Color("#e3c066"))
	var length := radius * 0.62
	var depth := radius * 0.4
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for step in range(9):
		var along := step / 8.0
		var wave := sin(time * 3.2 + phase - along * 3.5) * radius * 0.05 * along
		upper.append(top + Vector2(along * length, radius * 0.06 + wave))
		lower.append(top + Vector2(along * length, radius * 0.06 + depth + wave))
	var flag := PackedVector2Array(upper)
	# Swallowtail notch at the end.
	flag.append((upper[8] + lower[8]) / 2.0 + Vector2(-length * 0.18, 0))
	lower.reverse()
	flag.append_array(lower)
	draw_colored_polygon(flag, color)
	var outline := flag.duplicate()
	outline.append(flag[0])
	draw_polyline(outline, TileArt.INK, 1.2, true)
	draw_circle((upper[3] + lower[5]) / 2.0, radius * 0.07, color.lightened(0.45))


func _draw_birds(area_top: float, horizon: float) -> void:
	for index in range(3):
		var x := fposmod(size.x * 0.15 + time * 22.0 + index * 46.0, size.x + 120.0) - 60.0
		var y := lerpf(area_top, horizon, 0.45) + index * 12.0 + sin(time * 1.6 + index) * 5.0
		var flap := sin(time * 7.0 + index * 2.0) * 3.0
		var at := Vector2(x, y)
		draw_polyline(PackedVector2Array([at + Vector2(-7, -2 + flap), at, at + Vector2(7, -2 + flap)]),
			Color(0.16, 0.13, 0.22, 0.8), 1.6, true)


## Darkens the top behind the title and the bottom behind the menu.
func _draw_shades(area_top: float) -> void:
	_gradient(0, area_top + 20, Color(0.02, 0.03, 0.08, 0.5), Color(0.02, 0.03, 0.08, 0.0))
	_gradient(menu_box.position.y - 60, size.y, Color(0.02, 0.05, 0.08, 0.0), Color(0.02, 0.05, 0.08, 0.7))


func _draw_flourishes() -> void:
	var font := tagline.get_theme_font("font")
	var font_size := tagline.get_theme_font_size("font_size")
	var width := font.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y := heading.position.y + tagline.position.y + tagline.size.y / 2.0
	var middle := size.x / 2.0
	for side in [-1.0, 1.0]:
		var inner := Vector2(middle + side * (width / 2.0 + 16.0), y)
		var outer := inner + Vector2(side * minf(110.0, size.x * 0.12), 0)
		draw_line(inner, outer, Color(GOLD, 0.75), 1.5, true)
		var d := 4.0
		draw_colored_polygon(PackedVector2Array([outer + Vector2(0, -d), outer + Vector2(side * d, 0),
			outer + Vector2(0, d), outer + Vector2(-side * d, 0)]), GOLD)
