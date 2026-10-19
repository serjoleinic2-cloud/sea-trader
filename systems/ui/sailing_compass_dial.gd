extends Control

var heading_degrees: float = 0.0
var target_relative_radians: float = 0.0
var has_target: bool = false

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.43
	draw_circle(center, radius + 3.0, Color(0.025, 0.055, 0.07, 0.96))
	draw_arc(center, radius + 3.0, 0.0, TAU, 64, Color("#b99a55"), 1.5, true)
	draw_circle(center, radius - 7.0, Color(0.07, 0.12, 0.14, 0.96))
	var directions: Array[String] = ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"]
	var font: Font = ThemeDB.fallback_font
	for index in directions.size():
		var angle: float = -PI * 0.5 + deg_to_rad(float(index) * 45.0 - heading_degrees)
		var radial: Vector2 = Vector2.from_angle(angle)
		var color: Color = Color("#f0d779") if index == 0 else Color("#aebeb9")
		draw_line(center + radial * (radius - 11.0), center + radial * (radius - 5.0), color, 1.0, true)
		# The dial is only 82 px wide; keep two-letter diagonals short and
		# spread them around the rim so neighbouring labels stay legible.
		const LABEL_SIZE: int = 8
		var text_size: Vector2 = font.get_string_size(directions[index], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		draw_string(font, center + radial * (radius - 14.0) - text_size * 0.5 + Vector2(0, 3), directions[index], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)
	var bow := PackedVector2Array([center + Vector2(0, -radius + 24), center + Vector2(-6, 2), center + Vector2(0, -2), center + Vector2(6, 2)])
	draw_colored_polygon(bow, Color("#f2cf70"))
	if has_target:
		var target_vector: Vector2 = Vector2.from_angle(-PI * 0.5 + target_relative_radians)
		draw_circle(center + target_vector * (radius - 1.0), 4.0, Color("#65dce8"))
	draw_circle(center, 2.5, Color("#f5ead1"))
