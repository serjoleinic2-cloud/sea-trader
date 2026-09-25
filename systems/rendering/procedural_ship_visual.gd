extends Node2D

## Crisp vector schooner silhouette built and animated directly in Godot.
## The parent rotation remains owned by ShipPhysics; these local transforms
## add only subtle bob, sway and wake effects.

var _sailing_speed: float = 0.0
var _clock: float = 0.0


func set_sailing_speed(value: float) -> void:
	_sailing_speed = maxf(0.0, value)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var motion: float = clampf(_sailing_speed / 24.0, 0.0, 1.0)
	var bob: float = sin(_clock * 2.1) * 2.2 * motion
	var sway: float = sin(_clock * 1.35) * deg_to_rad(1.2) * motion
	draw_set_transform(Vector2(0.0, bob), sway, Vector2.ONE)

	# A narrow wake follows the stern and fades in when the ship gains speed.
	var wake_alpha: float = motion * (0.12 + 0.08 * sin(_clock * 3.0))
	var wake_color := Color(0.67, 0.84, 0.91, wake_alpha)
	draw_polyline(PackedVector2Array([Vector2(-3, 31), Vector2(-7, 43), Vector2(-4, 54)]), wake_color, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(3, 31), Vector2(7, 43), Vector2(4, 54)]), wake_color, 2.0, true)

	# Hull shadow, dark outer planks, and warm inner deck.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -44), Vector2(8, -35), Vector2(13, -16), Vector2(13, 22),
		Vector2(9, 35), Vector2(0, 43), Vector2(-9, 35), Vector2(-13, 22),
		Vector2(-13, -16), Vector2(-8, -35)
	]), Color(0.035, 0.11, 0.16, 0.40))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -49), Vector2(8, -40), Vector2(13, -21), Vector2(13, 18),
		Vector2(9, 31), Vector2(0, 38), Vector2(-9, 31), Vector2(-13, 18),
		Vector2(-13, -21), Vector2(-8, -40)
	]), Color("493126"))
	draw_polyline(PackedVector2Array([
		Vector2(0, -49), Vector2(8, -40), Vector2(13, -21), Vector2(13, 18),
		Vector2(9, 31), Vector2(0, 38), Vector2(-9, 31), Vector2(-13, 18),
		Vector2(-13, -21), Vector2(-8, -40), Vector2(0, -49)
	]), Color("c38a50"), 2.2, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -39), Vector2(7, -32), Vector2(10, -17), Vector2(10, 19),
		Vector2(6, 27), Vector2(0, 32), Vector2(-6, 27), Vector2(-10, 19),
		Vector2(-10, -17), Vector2(-7, -32)
	]), Color("bb8550"))

	# Deck planks, central mast, cabin and bright roof make the tiny top-down
	# silhouette readable even when zoomed far out.
	for plank_y in [-23.0, -15.0, -7.0, 1.0, 9.0, 17.0]:
		var half_width: float = 8.5 if absf(plank_y) < 20.0 else 6.0
		draw_line(Vector2(-half_width, plank_y), Vector2(half_width, plank_y), Color(0.31, 0.19, 0.11, 0.72), 1.0, true)
	draw_line(Vector2(0, -37), Vector2(0, 29), Color("ead0a0"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 8), Vector2(5, 8), Vector2(6, 25), Vector2(0, 29), Vector2(-6, 25)
	]), Color("594638"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 10), Vector2(4, 10), Vector2(4, 19), Vector2(-4, 19)
	]), Color("d8c49a"))
	draw_line(Vector2(-4, 14), Vector2(4, 14), Color("71614a"), 1.2, true)

	# Two cream sails and their seams give a restrained, readable pseudo-3D look.
	draw_colored_polygon(PackedVector2Array([
		Vector2(1, -31), Vector2(1, -3), Vector2(10, -8), Vector2(7, -24)
	]), Color("eee1bf"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -22), Vector2(-1, 3), Vector2(-9, -1), Vector2(-7, -16)
	]), Color("d8c8a3"))
	draw_line(Vector2(2, -28), Vector2(7, -10), Color(0.48, 0.38, 0.25, 0.65), 1.0, true)
	draw_line(Vector2(-2, -19), Vector2(-6, -3), Color(0.48, 0.38, 0.25, 0.55), 1.0, true)
	draw_line(Vector2(0, -40), Vector2(10, -8), Color("d3bd91"), 1.0, true)
	draw_line(Vector2(0, -30), Vector2(-9, -1), Color("d3bd91"), 1.0, true)
	draw_circle(Vector2(0, -38), 2.1, Color("d9b35c"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
