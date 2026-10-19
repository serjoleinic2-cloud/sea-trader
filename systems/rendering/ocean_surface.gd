extends RefCounted

## Shared Gerstner waves: metres, seconds. GPU gets these exact parameters.
const SEA_LEVEL: float = -0.18
const TIME_SCALE: float = 0.42
const WAVES: Array[Vector4] = [Vector4(1.0, 0.32, 0.060, 18.0), Vector4(-0.48, 1.0, 0.045, 10.0), Vector4(0.64, 1.0, 0.025, 5.5)]

static func outward_heel(turn_velocity: float) -> float:
	# Bow points along local -Z. Positive 2D yaw turns right; positive local
	# Z rotation raises starboard and lowers port, to the outside of that turn.
	return clampf(turn_velocity * 0.09, -0.08, 0.08)

static func configure_material(material: ShaderMaterial) -> void:
	for index in WAVES.size():
		material.set_shader_parameter(["wave_a", "wave_b", "wave_c"][index], WAVES[index])
	material.set_shader_parameter("wave_time_scale", TIME_SCALE)

static func displacement_at(position: Vector2, time: float) -> Vector3:
	var offset := Vector3.ZERO
	for wave in WAVES:
		var direction := Vector2(wave.x, wave.y).normalized()
		var k: float = TAU / wave.w
		var phase: float = k * (direction.dot(position) - sqrt(9.8 / k) * time * TIME_SCALE)
		var amplitude: float = wave.z / k
		offset += Vector3(direction.x * amplitude * cos(phase), amplitude * sin(phase), direction.y * amplitude * cos(phase))
	return offset

static func height_at(position: Vector2, time: float) -> float:
	# Invert Gerstner's horizontal shift: sample the displaced surface at the
	# actual world position, not the rest mesh below it.
	var base: Vector2 = position
	for _iteration in range(4):
		var offset: Vector3 = displacement_at(base, time)
		base = position - Vector2(offset.x, offset.z)
	return displacement_at(base, time).y

static func float_ship(ship: Node3D, position: Vector2, heading: float, length: float, time: float, delta: float = 0.0) -> void:
	var forward := Vector2.from_angle(heading)
	var right := Vector2(-forward.y, forward.x)
	var half_length: float = maxf(1.0, length * 0.4)
	var half_beam: float = maxf(0.35, length * 0.14)
	var bow: float = height_at(position + forward * half_length, time)
	var stern: float = height_at(position - forward * half_length, time)
	var starboard: float = height_at(position + right * half_beam, time)
	var port: float = height_at(position - right * half_beam, time)
	var target := Vector3(height_at(position, time) * 0.4 + (bow + stern + starboard + port) * 0.15, atan2(bow - stern, half_length * 2.0), atan2(starboard - port, half_beam * 2.0))
	# Store wave-only rotation so the separate turn heel never accumulates here.
	var motion: Vector3 = ship.get_meta("ocean_motion", target)
	var response: float = 1.0 - exp(-delta * clampf(7.0 / sqrt(maxf(length, 1.0)), 1.5, 4.0)) if delta > 0.0 else 1.0
	motion = motion.lerp(target, response)
	ship.set_meta("ocean_motion", motion)
	ship.position.y = SEA_LEVEL + motion.x + 0.04
	ship.rotation.x = motion.y
	ship.rotation.z = motion.z
