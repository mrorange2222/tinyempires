extends Control
## Small vector icon drawn in code, so it stays crisp at any scale.

@export_enum("gold", "armies", "land", "crown") var kind := "gold"
@export var tint := Color("#e3c066")


func _init() -> void:
	custom_minimum_size = Vector2(18, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 1.0
	var dark := Color(0.06, 0.1, 0.12, 0.9)
	match kind:
		"gold":
			draw_circle(c + Vector2(0, 1), r, dark)
			draw_circle(c, r, tint)
			draw_arc(c, r * 0.62, 0, TAU, 24, tint.darkened(0.3), 1.5, true)
			draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.55))
		"armies":
			var shield := PackedVector2Array([
				c + Vector2(-r * 0.85, -r * 0.8), c + Vector2(r * 0.85, -r * 0.8),
				c + Vector2(r * 0.8, r * 0.1), c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.1),
			])
			draw_colored_polygon(shield, tint)
			shield.append(shield[0])
			draw_polyline(shield, dark, 1.5, true)
			draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), Color(1, 1, 1, 0.5), 1.5, true)
		"land":
			var hex := PackedVector2Array()
			for corner in range(6):
				var angle := deg_to_rad(60.0 * corner - 30.0)
				hex.append(c + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(hex, Color(tint, 0.45))
			hex.append(hex[0])
			draw_polyline(hex, tint, 1.8, true)
		"crown":
			var crown := PackedVector2Array([
				c + Vector2(-r, -r * 0.45), c + Vector2(-r * 0.5, r * 0.05),
				c + Vector2(0, -r * 0.85), c + Vector2(r * 0.5, r * 0.05),
				c + Vector2(r, -r * 0.45), c + Vector2(r * 0.75, r * 0.6),
				c + Vector2(-r * 0.75, r * 0.6),
			])
			draw_colored_polygon(crown, tint)
			draw_line(c + Vector2(-r * 0.75, r * 0.85), c + Vector2(r * 0.75, r * 0.85), tint, 2.0, true)
