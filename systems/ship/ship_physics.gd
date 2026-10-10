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
var _handbrake: bool = false
var _yaw_velocity: float = 0.0
var _visual_roll: float = 0.0    # current visual roll in degrees

# Reference to the ship visual node (set by ShipScene on ready)
var ship_node: Node2D = null
var _collision_data_provider: Callable = Callable()
const COLLISION_CLEARANCE: float = 30.0
const CollisionIndex = preload("res://systems/navigation/navigation_collision_index.gd")

# ============================================================================
# Public API
# ============================================================================

func set_collision_data_provider(provider: Callable) -> void:
	_collision_data_provider = provider


func is_navigation_move_blocked(current_pos: Vector2, proposed_pos: Vector2) -> bool:
	# Route planning is a query; a rejected hypothetical move must not stop the ship.
	var saved_speed: float = _speed
	var blocked: bool = _resolve_navigation_collisions(current_pos, proposed_pos).distance_to(proposed_pos) > 0.01
	_speed = saved_speed
	return blocked


func setup(ship_data: Dictionary, initialize_state: bool = true) -> void:
	"""Initialize from ShipData JSON. Call once before first physics tick."""
	_ship_data = ship_data
	_heading = -PI / 2.0   # start facing up (north)
	_speed = 0.0
	_throttle = 0.0
	_steering = 0.0
	_handbrake = false
	_visual_roll = 0.0
	_yaw_velocity = 0.0
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
	GameState.ship_state["heading"] = _heading
	GameState.ship_state["reverse_gear"] = false


func apply_control(throttle: float, steering_input: float) -> void:
	"""Receive normalized control commands from ShipControl.
	throttle: -1 (brake) .. 0 (coast) .. 1 (full gas)
	steering_input: -1 (hard left) .. 0 (straight) .. 1 (hard right)"""
	_throttle = clampf(throttle, -1.0, 1.0)
	_steering = clampf(steering_input, -1.0, 1.0)


func apply_handbrake(enabled: bool) -> void:
	_handbrake = enabled


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
		_handbrake = false
		GameState.ship_state["velocity"] = Vector2.ZERO
		GameState.ship_state["reverse_gear"] = false
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
	"""Restore signed speed against the saved hull heading.
	Heading describes where the bow points; velocity may point the other way."""
	var vel: Vector2 = Vector2(GameState.ship_state.get("velocity", Vector2.ZERO))
	_heading = float(GameState.ship_state.get("heading", -PI / 2.0))
	var forward: Vector2 = Vector2(cos(_heading), sin(_heading))
	_speed = vel.dot(forward)
	if vel.length_squared() < 0.01:
		_speed = 0.0
	GameState.ship_state["reverse_gear"] = _speed < -0.5

# ============================================================================
# Internal — speed update
# ============================================================================

func _update_speed(delta: float) -> void:
	var max_spd: float = get_max_speed()
	var reverse_ratio: float = clampf(float(_ship_data.get("reverse_speed_ratio", 0.25)), 0.1, 0.5)
	if _handbrake:
		var handbrake_force: float = maxf(float(_ship_data.get("brake_force", 120.0)) * 4.0, 360.0)
		_speed = move_toward(_speed, 0.0, handbrake_force * delta)
		if absf(_speed) < 0.5:
			_speed = 0.0
		return

	if _throttle > 0.0:
		var accel: float = float(_ship_data.get("acceleration", 80.0)) * _throttle * _get_engine_ratio()
		_speed = move_toward(_speed, max_spd * _throttle, accel * delta)
	elif _throttle < 0.0:
		if _speed > 0.0:
			# First bring the ship to a full stop; reverse engages on the next tick.
			var brake: float = float(_ship_data.get("brake_force", 120.0))
			_speed = move_toward(_speed, 0.0, brake * absf(_throttle) * delta)
		else:
			var reverse_target: float = -max_spd * reverse_ratio * absf(_throttle)
			var reverse_accel: float = float(_ship_data.get("acceleration", 80.0)) * _get_engine_ratio() * absf(_throttle) * reverse_ratio
			_speed = move_toward(_speed, reverse_target, reverse_accel * delta)
	else:
		var decel: float = float(_ship_data.get("deceleration", 60.0))
		_speed = move_toward(_speed, 0.0, decel * delta)

	_speed = clampf(_speed, -max_spd * reverse_ratio, max_spd)


# ============================================================================
# Internal — heading update (turning)
# ============================================================================

func _update_heading(delta: float) -> void:
	if absf(_speed) < 1.0:
		_yaw_velocity = 0.0
		return

	var steering_ratio: float = _get_steering_ratio()
	var maneuv: float = _ship_data.get("base_maneuverability", 0.85)

	# Turn rate decreases at high speed
	var speed_ratio: float = absf(_speed) / maxf(get_max_speed(), 1.0)
	var speed_factor: float = lerp(1.0, float(_ship_data.get("turn_speed_reduction", 0.35)), speed_ratio)

	var turn_rate: float = float(_ship_data.get("turn_rate", 1.6)) * maneuv * steering_ratio * speed_factor
	# Steering while backing up turns the stern in the same requested
	# direction as forward steering; invert the bow rotation during reverse.
	var travel_direction: float = -1.0 if _speed < 0.0 else 1.0
	var requested: float = _steering * turn_rate * travel_direction
	_yaw_velocity = move_toward(_yaw_velocity,requested,turn_rate*1.8*delta)
	_heading += _yaw_velocity*delta


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
	if traveled_distance < displacement.length() * 0.5:
		_speed = 0.0
	GameState.ship_state["position"] = new_pos
	GameState.ship_state["velocity"] = direction * _speed if new_pos != current_pos else Vector2.ZERO
	GameState.ship_state["reverse_gear"] = _speed < -0.5
	GameState.player_state.stats["total_distance"] = float(GameState.player_state.stats.get("total_distance", 0.0)) + traveled_distance



func _resolve_navigation_collisions(current_pos: Vector2, proposed_pos: Vector2) -> Vector2:
	if not _collision_data_provider.is_valid():
		return proposed_pos
	var collision_data: Variant = _collision_data_provider.call()
	if not (collision_data is Dictionary):
		return proposed_pos
	var data: Dictionary = collision_data
	var move_bounds := Rect2(current_pos, proposed_pos - current_pos).abs().grow(0.01)
	for raw_island in data.get("islands", []):
		if not (raw_island is Dictionary):
			continue
		var island: Dictionary = raw_island
		# Most route/steering probes are short and touch only one port. Bounds
		# are prepared once when its static coastline changes, not for every probe.
		if island.has("navigation_bounds") and not (island.navigation_bounds as Rect2).grow(COLLISION_CLEARANCE).intersects(move_bounds, true):
			continue
		var obstacles: Array = island.get("navigation_obstacles", [])
		var cached_bounds: Array = island.get("navigation_obstacle_bounds", [])
		for obstacle_index in obstacles.size():
			var obstacle: Variant = obstacles[obstacle_index]
			var polygon: PackedVector2Array = obstacle
			if polygon.size() < 3:
				continue
			var bounds: Rect2
			if cached_bounds.size() == obstacles.size():
				bounds = cached_bounds[obstacle_index]
			else:
				bounds = Rect2(polygon[0], Vector2.ZERO)
				for vertex in polygon:
					bounds = bounds.expand(vertex)
			if not bounds.grow(COLLISION_CLEARANCE).intersects(move_bounds, true):
				continue
			var start_clearance := _polygon_clearance(current_pos, polygon)
			if start_clearance < COLLISION_CLEARANCE:
				# A legacy save inside a newly solid pier can move back into free water.
				if _polygon_clearance(proposed_pos, polygon) <= start_clearance + 0.001:
					_speed = 0.0
					return current_pos
				var previous_clearance := start_clearance
				var samples: int = maxi(1, ceili(current_pos.distance_to(proposed_pos) / 15.0))
				for sample_index in range(1, samples + 1):
					var clearance := _polygon_clearance(current_pos.lerp(proposed_pos, float(sample_index) / samples), polygon)
					if clearance + 0.001 < previous_clearance:
						_speed = 0.0
						return current_pos
					previous_clearance = clearance
			elif _obstacle_segment_blocked(current_pos, proposed_pos, polygon):
				_speed = 0.0
				return current_pos
		var center: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var radius: float = float(island.get("radius", 0.0))
		if radius <= 0.0:
			continue
		if Geometry2D.get_closest_point_to_segment(center, current_pos, proposed_pos).distance_to(center) >= radius + COLLISION_CLEARANCE:
			continue
		var current_distance: float = current_pos.distance_to(center)
		var proposed_distance: float = proposed_pos.distance_to(center)
		var current_is_blocked: bool = _island_blocks_position(current_pos, center, radius, island)
		var coast: PackedVector2Array = island.get("coast_polygon", PackedVector2Array())
		if coast.size() >= 3 and not current_is_blocked:
			if _harbor_segment_blocked(current_pos, proposed_pos, center, radius, island, coast):
				_speed = 0.0
				return current_pos
			continue
		var move_distance: float = current_pos.distance_to(proposed_pos)
		var sample_count: int = maxi(1, ceili(move_distance / maxf(1.0, COLLISION_CLEARANCE * 0.5)))

		# Let a save or prior bad position escape outward from inside an island,
		# but never allow tangential movement that could carry the ship through it.
		if current_is_blocked:
			if proposed_distance <= current_distance + 0.001:
				_speed = 0.0
				return current_pos
			var previous_distance: float = current_distance
			for sample_index in range(1, sample_count + 1):
				var sample_position: Vector2 = current_pos.lerp(proposed_pos, float(sample_index) / float(sample_count))
				var sample_distance: float = sample_position.distance_to(center)
				if sample_distance + 0.5 < previous_distance:
					_speed = 0.0
					return current_pos
				previous_distance = sample_distance
			continue

		# Sample the whole step so large frame/autopilot steps cannot tunnel
		# through an island between two safe endpoints.
		for sample_index in range(1, sample_count + 1):
			var sample_position: Vector2 = current_pos.lerp(proposed_pos, float(sample_index) / float(sample_count))
			if _island_blocks_position(sample_position, center, radius, island):
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

func _polygon_clearance(point: Vector2, polygon: PackedVector2Array) -> float:
	var distance: float = INF
	for index in polygon.size():
		distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])))
	return -distance if Geometry2D.is_point_in_polygon(point, polygon) else distance

func _obstacle_segment_blocked(start: Vector2, finish: Vector2, polygon: PackedVector2Array) -> bool:
	if _polygon_clearance(finish, polygon) < COLLISION_CLEARANCE:
		return true
	for index in polygon.size():
		var first := polygon[index]
		var second := polygon[(index + 1) % polygon.size()]
		if Geometry2D.segment_intersects_segment(start, finish, first, second) != null:
			return true
		if first.distance_to(Geometry2D.get_closest_point_to_segment(first, start, finish)) < COLLISION_CLEARANCE:
			return true
		if second.distance_to(Geometry2D.get_closest_point_to_segment(second, start, finish)) < COLLISION_CLEARANCE:
			return true
		if finish.distance_to(Geometry2D.get_closest_point_to_segment(finish, first, second)) < COLLISION_CLEARANCE:
			return true
	return false


func _harbor_segment_blocked(start: Vector2, finish: Vector2, center: Vector2, radius: float, island: Dictionary, coast: PackedVector2Array) -> bool:
	if _island_blocks_position(finish, center, radius, island):
		return true
	var edge_bounds: Array = island.get("navigation_coast_edge_bounds", [])
	var move_bounds := Rect2(start, finish - start).abs().grow(COLLISION_CLEARANCE)
	for index in CollisionIndex.nearby_coast_edges(island, Rect2(start, finish - start).abs(), coast.size()):
		if edge_bounds.size() == coast.size() and not (edge_bounds[index] as Rect2).intersects(move_bounds, true):
			continue
		var first: Vector2 = coast[index]
		var second: Vector2 = coast[(index + 1) % coast.size()]
		if Geometry2D.segment_intersects_segment(start, finish, first, second) != null:
			return true
		if first.distance_to(Geometry2D.get_closest_point_to_segment(first, start, finish)) < COLLISION_CLEARANCE:
			return true
	var delta := finish - start
	var relative := start - center
	var length_sq := delta.length_squared()
	if length_sq <= 0.0001:
		return false
	for reef_radius in [float(island.get("reef_inner_radius", 0.0)) - COLLISION_CLEARANCE, float(island.get("reef_outer_radius", 0.0)) + COLLISION_CLEARANCE]:
		var b := 2.0 * relative.dot(delta)
		var c: float = relative.length_squared() - float(reef_radius) * float(reef_radius)
		var discriminant: float = b * b - 4.0 * length_sq * c
		if discriminant < 0:
			continue
		for t in [(-b - sqrt(discriminant)) / (2 * length_sq), (-b + sqrt(discriminant)) / (2 * length_sq)]:
			if t >= 0 and t <= 1 and _island_blocks_position(start + delta * t, center, radius, island):
				return true
	return false

func _island_blocks_position(position: Vector2, center: Vector2, radius: float, island: Dictionary) -> bool:
	if position.distance_to(center) >= radius + COLLISION_CLEARANCE:
		return false
	var polygon: PackedVector2Array = island.get("coast_polygon", PackedVector2Array())
	if polygon.size() >= 3:
		if Geometry2D.is_point_in_polygon(position, polygon):
			return true
		var edge_bounds: Array = island.get("navigation_coast_edge_bounds", [])
		for index in CollisionIndex.nearby_coast_edges(island, Rect2(position, Vector2.ZERO), polygon.size()):
			if edge_bounds.size() == polygon.size() and not (edge_bounds[index] as Rect2).grow(COLLISION_CLEARANCE).has_point(position):
				continue
			if position.distance_to(Geometry2D.get_closest_point_to_segment(position, polygon[index], polygon[(index + 1) % polygon.size()])) < COLLISION_CLEARANCE:
				return true
		var offset := position - center
		var in_reef := offset.length() >= float(island.get("reef_inner_radius", INF)) - COLLISION_CLEARANCE and offset.length() <= float(island.get("reef_outer_radius", 0.0)) + COLLISION_CLEARANCE
		var in_entrance := absf(wrapf(offset.angle() - float(island.get("bay_angle", 0.0)), -PI, PI)) < float(island.get("bay_width", 0.34))
		return in_reef and not in_entrance
	var bay_angle: float = float(island.get("bay_angle", 1000.0))
	var bay_width: float = float(island.get("bay_width", 0.0))
	var offset: Vector2 = position - center
	var bay_depth: float = clampf(float(island.get("bay_depth", 0.72)), 0.65, 0.9)
	var in_bay: bool = bay_angle < 900.0 and bay_width > 0.0 and absf(wrapf(offset.angle() - bay_angle, -PI, PI)) <= bay_width and offset.length() >= radius * bay_depth
	return not in_bay


func setup_world_bounds(_w: float, _h: float) -> void:
	"""Legacy API kept for old scenes; the generated sea has no edge."""
	pass


# ============================================================================
# Internal — visual roll
# ============================================================================

func _update_visual_roll(delta: float) -> void:
	var target_roll: float = _steering * float(_ship_data.get("max_roll_degrees", 12.0))

	# Only roll when actually moving
	if absf(_speed) < 1.0:
		target_roll = 0.0

	_visual_roll = lerpf(_visual_roll, target_roll, float(_ship_data.get("roll_smooth_speed", 5.0)) * delta)

	# Apply to ship node if assigned
	if ship_node != null:
		ship_node.rotation_degrees = rad_to_deg(_heading) + 90.0 + _visual_roll


# ============================================================================
# Internal — fuel
# ============================================================================

func _update_fuel(delta: float) -> void:
	if absf(_speed) < 0.5:
		return

	var speed_ratio: float = absf(_speed) / maxf(get_max_speed(), 1.0)
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
	GameState.ship_state["heading"] = _heading
	GameState.ship_state["turn_velocity"] = _yaw_velocity
	GameState.ship_state["visual_roll"] = _visual_roll
	GameState.world_state["current_position"] = GameState.ship_state.get("position", Vector2.ZERO)
	EventBus.ship_moved.emit(
		GameState.ship_state.get("position", Vector2.ZERO),
		GameState.ship_state.get("velocity", Vector2.ZERO)
	)
