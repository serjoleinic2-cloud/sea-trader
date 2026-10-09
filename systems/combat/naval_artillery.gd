extends RefCounted

## Shared travel timing for combat resolution and world visuals (map units).
static func flight_seconds(origin: Vector2, target: Vector2, kind: String) -> float:
	var speed: float = 220.0 if kind == "mortar" else (520.0 if kind == "rune" else 360.0)
	return clampf(origin.distance_to(target) / speed, 0.35, 3.5)

static func impact_point(origin: Vector2, target: Vector2, hit: bool, sequence: int, hull_length: float) -> Vector2:
	if hit: return target
	var direction: Vector2 = origin.direction_to(target)
	var side: float = -1.0 if posmod(sequence, 2) == 0 else 1.0
	return target + direction.orthogonal() * side * maxf(45.0, hull_length * 0.7) + direction * float(posmod(sequence * 17, 47) - 23)
