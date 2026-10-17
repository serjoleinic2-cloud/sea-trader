extends RefCounted

## Shared travel timing for combat resolution and world visuals (map units).
static func flight_seconds(origin: Vector2, target: Vector2, kind: String) -> float:
	var speed: float=360.0
	match kind:
		"mortar": speed=220.0
		"deck_mortar": speed=260.0
		"siege_mortar": speed=190.0
		"void_mortar": speed=175.0
		"rune": speed=520.0
		"focused_rune": speed=560.0
		"storm_rune": speed=500.0
		"leviathan_rune": speed=460.0
		"piercing": speed=600.0
		"scatter": speed=460.0
		"bombard": speed=300.0
		"dread_cannon": speed=270.0
	return clampf(origin.distance_to(target) / speed, 0.35, 3.5)

static func impact_point(origin: Vector2, target: Vector2, hit: bool, sequence: int, hull_length: float) -> Vector2:
	if hit: return target
	var direction: Vector2 = origin.direction_to(target)
	var side: float = -1.0 if posmod(sequence, 2) == 0 else 1.0
	return target + direction.orthogonal() * side * maxf(45.0, hull_length * 0.7) + direction * float(posmod(sequence * 17, 47) - 23)
