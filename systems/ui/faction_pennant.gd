extends Control

## Reusable cloth pennant. The crest is always loaded from the faction catalog.
var _emblem: Texture2D
var _cloth := Color("162f45")
var _brass := Color("d4aa62")
var _fabric: GradientTexture2D
var faction_id := ""

func _ready() -> void:
	custom_minimum_size = Vector2(76.0, 106.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_faction(value: String) -> void:
	faction_id = value
	var faction: Dictionary = GameData.get_faction(value)
	var palette: Array = faction.get("palette", ["#162f45", "#2bbcc1", "#d4aa62"])
	_cloth = Color(str(faction.get("banner_color", palette[0]))).lightened(0.08)
	_brass = Color(str(palette[2])).lightened(0.14)
	_emblem = GameData.get_faction_emblem(value)
	tooltip_text = str(faction.get("name", "Морская компания"))
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.20, 0.42, 0.66, 0.84, 1.0])
	gradient.colors = PackedColorArray([_cloth.darkened(0.35), _cloth.lightened(0.17), _cloth.darkened(0.18), _cloth.lightened(0.10), _cloth.darkened(0.22), _cloth.lightened(0.05)])
	_fabric = GradientTexture2D.new()
	_fabric.gradient = gradient
	_fabric.width = 128
	_fabric.height = 128
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var outline := PackedVector2Array([Vector2(w * 0.12, 9), Vector2(w * 0.88, 9), Vector2(w * 0.86, h - 6), Vector2(w * 0.50, h * 0.79), Vector2(w * 0.14, h - 6)])
	var shadow := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in outline:
		shadow.append(point + Vector2(3, 3))
		uv.append(point / Vector2(maxf(1, w), maxf(1, h)))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_polygon(outline, PackedColorArray([Color.WHITE]), uv, _fabric)
	var border := outline.duplicate()
	border.append(outline[0])
	draw_polyline(border, _brass, 1.8, true)
	draw_line(Vector2(w * 0.10, 7), Vector2(w * 0.90, 7), _brass, 3.0, true)
	for x in [w * 0.10, w * 0.90]:
		draw_circle(Vector2(x, 7), 3.0, _brass.lightened(0.25))
	if _emblem != null:
		var bounds := Vector2(w * 0.61, h * 0.57)
		var source: Vector2 = _emblem.get_size()
		var fit: float = minf(bounds.x / source.x, bounds.y / source.y)
		var drawn := source * fit
		draw_texture_rect(_emblem, Rect2(Vector2((w - drawn.x) * 0.5, h * 0.17), drawn), false)
