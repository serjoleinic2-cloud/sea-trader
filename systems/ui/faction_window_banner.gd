extends Control

var _cloth := Color("2e5961")
var _stitch := Color("c6a66a")
var _emblem: Texture2D

func set_faction(faction_id: String) -> void:
	var faction: Dictionary = GameData.get_faction(faction_id)
	var palette: Array = faction.get("palette", ["#132b43", "#2bbcc1", "#c49a58"])
	_cloth = Color(str(palette[1])).darkened(0.48)
	_stitch = Color(str(palette[2]))
	_emblem = GameData.get_faction_emblem(faction_id)
	queue_redraw()

func _ready() -> void:
	custom_minimum_size.y = 18.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w: float = size.x
	var band := PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 8),
		Vector2(w * 0.84, 14), Vector2(w * 0.68, 8),
		Vector2(w * 0.50, 14), Vector2(w * 0.32, 8),
		Vector2(w * 0.16, 14), Vector2(0, 8)
	])
	draw_colored_polygon(band, _cloth)
	draw_polyline(PackedVector2Array([Vector2(0, 8), Vector2(w * 0.16, 14), Vector2(w * 0.32, 8), Vector2(w * 0.50, 14), Vector2(w * 0.68, 8), Vector2(w * 0.84, 14), Vector2(w, 8)]), _stitch, 1.0, true)
	# Small cloth tails turn the faction strip into a banner wrapped over both frame corners.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 6), Vector2(13, 10), Vector2(9, 18), Vector2(0, 13)]), _cloth.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(w, 6), Vector2(w - 13, 10), Vector2(w - 9, 18), Vector2(w, 13)]), _cloth.lightened(0.08))
	if _emblem != null:
		draw_texture_rect(_emblem, Rect2(Vector2(w * 0.5 - 8, 1), Vector2(16, 12)), false)
