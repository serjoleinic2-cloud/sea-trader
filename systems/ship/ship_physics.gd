extends Node

## ShipPhysics — applies movement, inertia, turning, visual roll.
## Reads physics parameters from ShipData config + ShipState.
## Writes position and velocity back to GameState.ShipState.
## NO platform dependencies. NO Android API. NO input reading.
## See ARCHITECTURE.md, SYSTEM_MAP.md, DATA_SCHEMA.md.

# ============================================================================
# Physical lower bound; tunable defaults live in ship_catalog.json.

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
var _collision_data_provider: Callable = Callable()
const COLLISION_CLEARANCE: float = 30.0

# ============================================================================
# Public API
# ============================================================================

func set_collision_data_provider(provider: Callable) -> void:
	_collision_data_provider = provider


func is_navigation_move_blocked(current_pos: Vector2, proposed_pos: Vector2) -> bool:
	return _resolve_navigation_collisions(current_pos, proposed_pos).distance_to(proposed_pos) > 0.01


func setup(ship_data: Dictionary, initialize_state: bool = true) -> void:
	"""Initialize from ShipData JSON. Call once before first physics tick."""
	_ship_data = ship_data
	_heading = -PI / 2.0   # start facing up (north)
	_speed = 0.0
	_throttle = 0.0
	_steering = 0.0
	_visual_roll = 0.0
	if not initialize_state:
		restore_from_state()
		return

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
	if bool(GameState.voyage_state.get("active_autopilot", false)):
		restore_from_state()
		_throttle = 0.0
		_steering = 0.0
		_update_visual_roll(delta)
		_write_to_game_state()
		return
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_speed = 0.0
		_throttle = 0.0
		_steering = 0.0
		GameState.ship_state["velocity"] = Vector2.ZERO
		return
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
	var crew_speed_bonus: float = float(_get_crew_stat_total("speed")) / 100.0
	var reward_bonus: float = 0.0
	var rewards: Array[Node] = get_tree().get_nodes_in_group("reward_system")
	if not rewards.is_empty():
		reward_bonus = float(rewards[0].get_bonus_percent("speed")) / 100.0
	return base * engine_ratio * maxf(0.25, 1.0 + crew_speed_bonus + reward_bonus)


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
		var accel: float = float(_ship_data.get("acceleration", 80.0)) * _throttle * _get_engine_ratio()
		_speed = move_toward(_speed, max_spd * _throttle, accel * delta)
	elif _throttle < 0.0:
		# Active brake
		var brake: float = float(_ship_data.get("brake_force", 120.0))
		_speed = move_toward(_speed, 0.0, brake * delta)
	else:
		# Natural deceleration (water friction)
		var decel: float = float(_ship_data.get("deceleration", 60.0))
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
	var speed_factor: float = lerp(1.0, float(_ship_data.get("turn_speed_reduction", 0.35)), speed_ratio)

	var turn_rate: float = float(_ship_data.get("turn_rate", 1.6)) * maneuv * steering_ratio * speed_factor
	_heading += _steering * turn_rate * delta


# ============================================================================
# Internal — position update
# ============================================================================

func _update_position(delta: float) -> void:
	var direction: Vector2 = Vector2(cos(_heading), sin(_heading))
	var displacement: Vector2 = direction * _speed * delta

	var current_pos: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	var new_pos: Vector2 = current_pos + displacement
	new_pos = _resolve_navigation_collisions(current_pos, new_pos)

	var traveled_distance: float = current_pos.distance_to(new_pos)
	GameState.ship_state["position"] = new_pos
	GameState.ship_state["velocity"] = direction * _speed if new_pos != current_pos else Vector2.ZERO
	GameState.player_state.stats["total_distance"] = float(GameState.player_state.stats.get("total_distance", 0.0)) + traveled_distance



func _resolve_navigation_collisions(current_pos: Vector2, proposed_pos: Vector2) -> Vector2:
	if not _collision_data_provider.is_valid():
		return proposed_pos
	var collision_data: Variant = _collision_data_provider.call()
	if not (collision_data is Dictionary):
		return proposed_pos
	var data: Dictionary = collision_data
	for raw_island in data.get("islands", []):
		if not (raw_island is Dictionary):
			continue
		var island: Dictionary = raw_island
		var center: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var radius: float = float(island.get("radius", 0.0))
		if radius <= 0.0 or proposed_pos.distance_to(center) >= radius + COLLISION_CLEARANCE:
			continue
		# A natural-bay mouth is the one safe opening through the coastline.
		var bay_angle: float = float(island.get("bay_angle", 1000.0))
		var bay_width: float = float(island.get("bay_width", 0.0))
		var offset: Vector2 = proposed_pos - center
		var in_bay: bool = bay_angle < 900.0 and absf(wrapf(offset.angle() - bay_angle, -PI, PI)) <= bay_width and offset.length() >= radius * 0.72
		if in_bay:
			continue
		if current_pos.distance_to(center) > radius + COLLISION_CLEARANCE:
			_speed = 0.0
			return current_pos
	for raw_vessel in data.get("vessels", []):
		if not (raw_vessel is Dictionary):
			continue
		var vessel: Dictionary = raw_vessel
		var vessel_pos: Vector2 = Vector2(vessel.get("position", Vector2.ZERO))
		var vessel_id: String = str(vessel.get("id", ""))
		if vessel_id == "visiting_merchant" and str(GameState.ship_state.get("docked_port_id", "")) != "":
			continue
		var vessel_clearance: float = maxf(28.0, float(vessel.get("length", 16.0)) * 0.28) + COLLISION_CLEARANCE
		if proposed_pos.distance_to(vessel_pos) < vessel_clearance and current_pos.distance_to(vessel_pos) >= vessel_clearance:
			_speed = 0.0
			return current_pos
	return proposed_pos


func setup_world_bounds(_w: float, _h: float) -> void:
	"""Legacy API kept for old scenes; the generated sea has no edge."""
	pass


# ============================================================================
# Internal — visual roll
# ============================================================================

func _update_visual_roll(delta: float) -> void:
	var target_roll: float = _steering * float(_ship_data.get("max_roll_degrees", 12.0))

	# Only roll when actually moving
	if _speed < 1.0:
		target_roll = 0.0

	_visual_roll = lerpf(_visual_roll, target_roll, float(_ship_data.get("roll_smooth_speed", 5.0)) * delta)

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
	var crew_fuel_bonus: float = float(_get_crew_stat_total("fuel")) / 100.0
	var consumption: float = float(_ship_data.get("fuel_per_second", 0.5)) * speed_ratio * delta * maxf(0.25, 1.0 - crew_fuel_bonus)

	var current_fuel: float = float(GameState.ship_state.get("fuel", 0.0))
	var new_fuel: float = maxf(current_fuel - consumption, FUEL_MIN)
	GameState.ship_state["fuel"] = new_fuel

	# If out of fuel, cut throttle authority (engine sputters)
	if new_fuel <= FUEL_MIN and _throttle > 0.0:
		_throttle = 0.0


# ============================================================================
# Internal — helpers
# ============================================================================

func _get_crew_stat_total(stat_id: String) -> int:
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	if not (raw_crew is Array):
		return 0
	var total: int = 0
	for employee_id in raw_crew:
		for raw_employee in GameState.employee_state:
			var employee: Dictionary = raw_employee
			if str(employee.get("employee_instance_id", "")) == str(employee_id):
				var stats: Dictionary = employee.get("stats", {})
				var skill_stats: Dictionary = employee.get("skill_stats", {})
				total += int(stats.get(stat_id, 0)) + int(skill_stats.get(stat_id, 0))
				break
	return total

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
