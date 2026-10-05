extends RefCounted

## Same four components as tropical_ocean.gdshader. Positions are world metres.
const SEA_LEVEL: float = -0.18
const DIRECTIONS: Array[Vector2] = [Vector2(0.32, 0.11), Vector2(-0.19, 0.36), Vector2(0.57, -0.28), Vector2(-0.13, -0.43)]
const AMPLITUDES: Array[float] = [0.14, 0.075, 0.035, 0.025]
const SPEEDS: Array[float] = [0.83, 0.67, 1.02, -0.51]

static func height_at(position: Vector2, time: float) -> float:
	var height: float = 0.0
	for i in range(4): height += sin(position.dot(DIRECTIONS[i]) + time * SPEEDS[i]) * AMPLITUDES[i]
	return height

static func float_ship(ship: Node3D, position: Vector2, heading: float, length: float, time: float) -> void:
	var forward := Vector2.from_angle(heading)
	var right := Vector2(-forward.y, forward.x)
	var half_length: float = maxf(1.0, length * 0.4)
	var half_beam: float = maxf(0.35, length * 0.14)
	var bow: float = height_at(position + forward * half_length, time)
	var stern: float = height_at(position - forward * half_length, time)
	var starboard: float = height_at(position + right * half_beam, time)
	var port: float = height_at(position - right * half_beam, time)
	# Asset origin is its waterline. Stable center supports the whole hull footprint.
	ship.position.y = SEA_LEVEL + height_at(position, time) + 0.04
	ship.rotation.x = atan2(bow - stern, half_length * 2.0)
	ship.rotation.z = atan2(starboard - port, half_beam * 2.0)
