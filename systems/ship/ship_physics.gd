extends Node

## ShipPhysics — applies movement, inertia, turning, visual roll.
## Reads physics parameters from ShipData config + ShipState.
## Writes position and velocity back to GameState.ShipState.
## NO platform dependencies. NO Android API. NO input reading.
## See ARCHITECTURE.md, SYSTEM_MAP.md, DATA_SCHEMA.md.

# ============================================================================
# Tunable constants (placeholder values — TBD per game balance)
# ============================================================================

## Base acceleration multiplier applied to throttle input. TUNABLE.
const BASE_ACCELERATION: float = 80.0

## Base deceleration when throttle is released (friction). TUNABLE.
const BASE_DECELERATION: float = 60.0

## Base braking force when throttle is negative. TUNABLE.
const BASE_BRAKE_FORCE: float = 120.0

## Base turn rate in radians/second at full steering input. TUNABLE.
const BASE_TURN_RATE: float = 1.6

## Turn rate is reduced at high speed by this fraction. TUNABLE.
const TURN_SPEED_REDUCTION: float = 0.35

## Max visual roll angle in degrees. TUNABLE.
const MAX_ROLL_DEGREES: float = 12.0

## Roll interpolation speed (lerp factor per second). TUNABLE.
const ROLL_SMOOTH_SPEED: float = 5.0

## Fuel consumption per second at full speed. Placeholder — TBD.
const FUEL_CONSUMPTION_RATE: float = 0.5

## Minimum fuel above zero (engine sputters, doesn't go below 0). TBD.
const FUEL_MIN: float = 0.0

# ============================================================================
# Runtime state (local to physics, not persisted)
# ============================================================================

var _ship_data: Dictionary = {}
var _heading: float = 0.0        # radians, 0 = right, PI/2 = down
var _speed: float = 0.0          # current scalar speed (pixels/sec)
var _throttle: float = 0.0       # -1..1 from ShipControl
var _steering: float = 0.0       # -1..1 from ShipControl
var _visual_roll: float = 0.0    # current visual roll in degrees

# Reference to the ship visual node (set by ShipScene on ready)
var ship_node: Node2D = null

# ============================================================================
# Public API
# ============================================================================

func setup(ship_data: Dictionary) -> void:
	"""Initialize from ShipData JSON. Call once before first physics tick."""
	_ship_data = ship_data
	_heading = -PI / 2.0   # start facing up (north)
	_speed = 0.0
	_throttle = 0.0
	_steering = 0.0
	_visual_roll = 0.0

	# Initialize GameState.ship_state from ShipData
	GameState.ship_state["ship_id"] = ship_data.get("id", "ship_sloop")
	GameState.ship_state["hull"] = float(ship_data.get("hull_max", 100))
	GameState.ship_state["engine"] = float(ship_data.get("engine_max", 100))
	GameState.ship_state["steering"] = float(ship_data.get("steering_max", 100))
	GameState.ship_state["cargo_hold"] = float(ship_data.get("cargo_hold_max", 100))
	GameState.ship_state["fuel"] = float(ship_data.get("fuel_capacity", 100))
	GameState.ship_state["fuel_max"] = float(ship_data.get("fuel_capacity", 100))
	GameState.ship_state["cargo_capacity"] = int(ship_data.get("cargo_capacity", 50))
	GameState.ship_state["velocity"] = Vector2.ZERO


func apply_control(throttle: float, steering_input: float) -> void:
	"""Receive normalized control commands from ShipControl.
	throttle: -1 (brake) .. 0 (coast) .. 1 (full gas)
	steering_input: -1 (hard left) .. 0 (straight) .. 1 (hard right)"""
	_throttle = clampf(throttle, -1.0, 1.0)
	_steering = clampf(steering_input, -1.0, 1.0)


func physics_tick(delta: float) -> void:
	"""Main physics update. Call every _physics_process tick."""
	_update_speed(delta)
	_update_heading(delta)
	_update_position(delta)
	_update_visual_roll(delta)
	_update_fuel(delta)
	_write_to_game_state()


func get_speed() -> float:
	return _speed


func get_heading_degrees() -> float:
	return rad_to_deg(_heading)


func get_visual_roll() -> float:
	return _visual_roll


func get_max_speed() -> float:
	var base: float = _ship_data.get("base_speed", 120.0)
	var engine_ratio: float = _get_engine_ratio()
	return base * engine_ratio


func restore_from_state() -> void:
	"""Restore physics from saved GameState after app resume."""
	var vel: Vector2 = GameState.ship_state.get("velocity", Vector2.ZERO)
	_speed = vel.length()
	if _speed > 0.0:
		_heading = atan2(vel.y, vel.x)

# ============================================================================
# Internal — speed update
# ============================================================================

func _update_speed(delta: float) -> void:
	var max_spd: float = get_max_speed()

	if _throttle > 0.0:
		# Accelerate
		var accel: float = BASE_ACCELERATION * _throttle * _get_engine_ratio()
		_speed = move_toward(_speed, max_spd * _throttle, accel * delta)
	elif _throttle < 0.0:
		# Active brake
		var brake: float = BASE_BRAKE_FORCE
		_speed = move_toward(_speed, 0.0, brake * delta)
	else:
		# Natural deceleration (water friction)
		var decel: float = BASE_DECELERATION
		_speed = move_toward(_speed, 0.0, decel * delta)

	_speed = clampf(_speed, 0.0, max_spd)


# ============================================================================
# Internal — heading update (turning)
# ============================================================================

func _update_heading(delta: float) -> void:
	if absf(_steering) < 0.01 or _speed < 1.0:
		return

	var steering_ratio: float = _get_steering_ratio()
	var maneuv: float = _ship_data.get("base_maneuverability", 0.85)

	# Turn rate decreases at high speed
	var speed_ratio: float = _speed / maxf(get_max_speed(), 1.0)
	var speed_factor: float = lerp(1.0, TURN_SPEED_REDUCTION, speed_ratio)

	var turn_rate: float = BASE_TURN_RATE * maneuv * steering_ratio * speed_factor
	_heading += _steering * turn_rate * delta


# ============================================================================
# Internal — position update
# ============================================================================

func _update_position(delta: float) -> void:
	var direction: Vector2 = Vector2(cos(_heading), sin(_heading))
	var displacement: Vector2 = direction * _speed * delta

	var current_pos: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	var new_pos: Vector2 = current_pos + displacement

	# Clamp to world bounds
	var world_size: Vector2 = Vector2(
		_ship_data.get("_world_w", 4096.0),
		_ship_data.get("_world_h", 4096.0)
	)
	# World size injected via setup_world_bounds if available; otherwise use default
	new_pos.x = clampf(new_pos.x, 0.0, world_size.x)
	new_pos.y = clampf(new_pos.y, 0.0, world_size.y)

	GameState.ship_state["position"] = new_pos
	GameState.ship_state["velocity"] = direction * _speed


func setup_world_bounds(w: float, h: float) -> void:
	"""Inject world size for clamping. Called by scene init."""
	_ship_data["_world_w"] = w
	_ship_data["_world_h"] = h


# ============================================================================
# Internal — visual roll
# ============================================================================

func _update_visual_roll(delta: float) -> void:
	var target_roll: float = _steering * MAX_ROLL_DEGREES

	# Only roll when actually moving
	if _speed < 1.0:
		target_roll = 0.0

	_visual_roll = lerpf(_visual_roll, target_roll, ROLL_SMOOTH_SPEED * delta)

	# Apply to ship node if assigned
	if ship_node != null:
		ship_node.rotation_degrees = rad_to_deg(_heading) + 90.0 + _visual_roll


# ============================================================================
# Internal — fuel
# ============================================================================

func _update_fuel(delta: float) -> void:
	if _speed < 0.5:
		return

	var speed_ratio: float = _speed / maxf(get_max_speed(), 1.0)
	var consumption: float = FUEL_CONSUMPTION_RATE * speed_ratio * delta

	var current_fuel: float = float(GameState.ship_state.get("fuel", 0.0))
	var new_fuel: float = maxf(current_fuel - consumption, FUEL_MIN)
	GameState.ship_state["fuel"] = new_fuel

	# If out of fuel, cut throttle authority (engine sputters)
	if new_fuel <= FUEL_MIN and _throttle > 0.0:
		_throttle = 0.0


# ============================================================================
# Internal — helpers
# ============================================================================

func _get_engine_ratio() -> float:
	var engine: float = float(GameState.ship_state.get("engine", 100.0))
	var engine_max: float = float(_ship_data.get("engine_max", 100.0))
	return clampf(engine / maxf(engine_max, 1.0), 0.0, 1.0)


func _get_steering_ratio() -> float:
	var steering: float = float(GameState.ship_state.get("steering", 100.0))
	var steering_max: float = float(_ship_data.get("steering_max", 100.0))
	return clampf(steering / maxf(steering_max, 1.0), 0.0, 1.0)


func _write_to_game_state() -> void:
	# position and velocity written in _update_position
	# fuel written in _update_fuel
	# also sync world_state.current_position
	GameState.world_state["current_position"] = GameState.ship_state.get("position", Vector2.ZERO)
	EventBus.ship_moved.emit(
		GameState.ship_state.get("position", Vector2.ZERO),
		GameState.ship_state.get("velocity", Vector2.ZERO)
	)
