extends Control

const HexBoard = preload("res://ui/hex_board.gd")

@onready var selection_label: Label = $Margin/Layout/Selection
@onready var board: HexBoard = $Margin/Layout/PlayArea/Scroll/Board
@onready var scroll: ScrollContainer = $Margin/Layout/PlayArea/Scroll


func _ready() -> void:
	board.tile_selected.connect(_on_tile_selected)
	await get_tree().process_frame
	scroll.scroll_horizontal = roundi((board.size.x - scroll.size.x) / 2.0)
	scroll.scroll_vertical = roundi((board.size.y - scroll.size.y) / 2.0)


func _on_tile_selected(coordinates: Vector2i, terrain: String) -> void:
	selection_label.text = "%s | Hex (%d, %d) | Empty land" % [
		terrain, coordinates.x, coordinates.y,
	]
