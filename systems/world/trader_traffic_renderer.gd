extends Node2D

## Ambient traffic uses the same coast/reef authority as the player ship.
var _world_size := Vector2(4096, 4096)
var _vessels: Array = []
var _ports: Dictionary = {}
var _islands: Array = []
var _home_id: String = ""
var _clock: float = 0.0
var _visuals: Dictionary = {}
var _harbor_passage: int = -1
var external_traffic: Callable
var _guard = preload("res://systems/ship/ship_physics.gd").new()
var _planner = preload("res://systems/navigation/coast_route_planner.gd").new()
const TYPES := ["ship_barque", "ship_schooner", "premium_salvage_schooner", "premium_royal_schooner", "ship_freighter", "premium_golden_clipper"]
const FACTIONS := ["humans", "nerids", "surr", "meridians", "aery", "crystari"]
const MAX_HARBOR_SHIPS := 2
const HARBOR_STAY_SECONDS := 75.0
const HARBOR_REENTRY_SECONDS := 18.0

func _ready() -> void:
	add_to_group("trader_traffic_renderer")

func initialize(world_data: Dictionary) -> void:
	_visuals = GameData.read("res://data/world/ship_visuals.json").get("ships", {})
	_guard.set_collision_data_provider(func(): return {"islands": _islands})
	set_navigation_world(world_data)

func _exit_tree() -> void:
	_guard.free()

func set_navigation_world(world_data: Dictionary) -> void:
	_ports = world_data.get("ports", {})
	_islands = world_data.get("islands", [])
	var home := str(GameState.world_state.get("home_port_id", ""))
	if _vessels.is_empty() or home != _home_id:
		_home_id = home
		_seed_traffic()
	else:
		for vessel in _vessels:
			vessel["route"] = PackedVector2Array()

func _home_geometry() -> Dictionary:
	var port: Dictionary = _ports.get(_home_id, {})
	if port.is_empty():
		return {}
	for island in _islands:
		if str(island.get("id", "")) == str(port.get("island_id", "")):
			return island
	return {}

func _seed_traffic() -> void:
	_vessels.clear()
	_harbor_passage = -1
	var home := _home_geometry()
	for index in range(6):
		var start := Vector2(320 + index * 643, 510 + index * 389)
		var berth := start + Vector2(1300, 900)
		if not home.is_empty():
			var port: Dictionary = _ports[_home_id]
			var forward := Vector2.from_angle(float(home.get("bay_angle", 0.0)))
			var side := forward.orthogonal()
			var anchor := Vector2(port.position)
			var direction := -1.0 if index % 2 == 0 else 1.0
			berth = _berth_position(index % MAX_HARBOR_SHIPS)
			var holding_lane: float = 300.0 + float(index / 2) * _display_length({"ship_type_id": TYPES[0]}) * 2.2
			start = anchor + forward * (float(home.radius) * 1.35 + float(index / 2) * 260.0) + side * direction * holding_lane
		start = _safe_water(start)
		berth = _safe_water(berth)
		var reserved := index < MAX_HARBOR_SHIPS
		_vessels.append({"position": start, "destination": berth if reserved else start, "berth": berth,
			"offshore": start, "route": PackedVector2Array(), "heading": (berth - start).normalized(),
			"speed": 32.0 + index * 3, "wait": float(index) * 8.0, "inbound": reserved,
			"berth_reserved": reserved, "berth_slot": index % MAX_HARBOR_SHIPS if reserved else -1, "at_berth": false,
			"ship_type_id": TYPES[index], "faction_id": FACTIONS[index], "size": 55.0})

func _safe_water(point: Vector2) -> Vector2:
	if not _guard.is_navigation_move_blocked(point + Vector2(0.1, 0), point) and not _guard.is_navigation_move_blocked(point - Vector2(0.1, 0), point):
		return point
	for distance in [100.0, 220.0, 450.0, 900.0, 1800.0, 3600.0]:
		for index in range(16):
			var candidate: Vector2 = point + Vector2.from_angle(index * TAU / 16.0) * float(distance)
			if not _guard.is_navigation_move_blocked(candidate + Vector2(0.1, 0), candidate) and not _guard.is_navigation_move_blocked(candidate - Vector2(0.1, 0), candidate):
				return candidate
	return point

func _process(delta: float) -> void:
	_clock += delta
	for index in range(_vessels.size()):
		var vessel: Dictionary = _vessels[index]
		if float(vessel.get("wait", 0.0)) > 0:
			vessel.wait = maxf(0, float(vessel.wait) - delta)
			continue
		if bool(vessel.get("at_berth", false)):
			vessel["at_berth"] = false
			vessel["inbound"] = false
			vessel["destination"] = vessel.offshore
			vessel["route"] = PackedVector2Array()
		if not bool(vessel.get("berth_reserved", false)):
			var free_slot := _free_berth_slot()
			if free_slot < 0:
				vessel.wait = 2.0
				continue
			vessel["berth_reserved"] = true
			vessel["berth_slot"] = free_slot
			vessel["berth"] = _berth_position(free_slot)
			vessel["inbound"] = true
			vessel["destination"] = vessel.berth
			vessel["route"] = PackedVector2Array()
		var position := Vector2(vessel.position)
		var destination := Vector2(vessel.destination)
		var route: PackedVector2Array = vessel.route
		if route.is_empty():
			route = _planner.plan(position, destination, _islands, Callable(_guard, "is_navigation_move_blocked"))
			vessel.route = route
		if route.is_empty():
			vessel.wait = 3.0 # No safe route: wait rather than cross land.
			continue
		var target: Vector2 = route[0]
		var candidate := position.move_toward(target, float(vessel.speed) * delta)
		var blocked := _guard.is_navigation_move_blocked(position, candidate)
		var length := _display_length(vessel)
		if candidate.distance_to(Vector2(GameState.ship_state.get("position", Vector2.ZERO))) < length + _player_length():
			blocked = true
		for other in _vessels:
			if other == vessel:
				continue
			if Geometry2D.get_closest_point_to_segment(Vector2(other.position), position, candidate).distance_to(Vector2(other.position)) < length + _display_length(other):
				blocked = true
				break
		if external_traffic.is_valid():
			for other in external_traffic.call():
				if Geometry2D.get_closest_point_to_segment(Vector2(other.position), position, candidate).distance_to(Vector2(other.position)) < length + float(other.get("length", 100.0)):
					blocked = true
		if blocked:
			continue
		var home: Dictionary = _home_geometry()
		if not home.is_empty():
			var anchor: Vector2 = _ports[_home_id].position
			var channel_radius: float = float(home.get("visual_radius", home.radius)) * 0.55
			if candidate.distance_to(anchor) < channel_radius:
				if _harbor_passage != -1 and _harbor_passage != index:
					continue
				_harbor_passage = index
			elif _harbor_passage == index:
				_harbor_passage = -1
		vessel.heading = (target - position).normalized() if target != position else vessel.heading
		vessel.position = candidate
		if candidate.distance_to(target) < 0.2:
			route.remove_at(0)
			vessel.route = route
			if route.is_empty():
				if _harbor_passage == index:
					_harbor_passage = -1
				if bool(vessel.inbound):
					vessel["at_berth"] = true
					vessel.wait = HARBOR_STAY_SECONDS
				else:
					vessel["berth_reserved"] = false
					vessel["wait"] = HARBOR_REENTRY_SECONDS + float(index % 3) * 5.0

func _reserved_berths() -> int:
	var count := 0
	for vessel in _vessels:
		if bool(vessel.get("berth_reserved", false)):
			count += 1
	return count

func _free_berth_slot() -> int:
	for slot in range(MAX_HARBOR_SHIPS):
		var taken := false
		for vessel in _vessels:
			if bool(vessel.get("berth_reserved", false)) and int(vessel.get("berth_slot", -1)) == slot:
				taken = true
				break
		if not taken:
			return slot
	return -1

func _berth_position(slot: int) -> Vector2:
	var home := _home_geometry()
	if home.is_empty() or not _ports.has(_home_id):
		return Vector2.ZERO
	var port: Dictionary = _ports[_home_id]
	var forward := Vector2.from_angle(float(home.get("bay_angle", 0.0)))
	var side := forward.orthogonal()
	var gap: float = _display_length({"ship_type_id": TYPES[0]}) * 2.1
	var direction := -1.0 if slot == 0 else 1.0
	return Vector2(port.position) + side * direction * gap * 0.5
	if is_visible_in_tree():
		queue_redraw()

func _display_length(vessel: Dictionary) -> float:
	var player: Dictionary = _visuals.get(str(GameState.ship_state.get("ship_id", "ship_sloop")), {})
	var own: Dictionary = _visuals.get(str(vessel.get("ship_type_id", "ship_barque")), {})
	return maxf(float(player.get("display_length", 3.48)), float(own.get("display_length", 4.5))) / 0.04

func _player_length() -> float:
	return float(_visuals.get(str(GameState.ship_state.get("ship_id", "ship_sloop")), {}).get("display_length", 3.48)) / 0.04

func get_vessel_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for index in range(_vessels.size()):
		var vessel: Dictionary = _vessels[index]
		var ship_id := str(vessel.ship_type_id)
		if ship_id == str(GameState.ship_state.get("ship_id", "ship_sloop")):
			ship_id = TYPES[(index + 1) % TYPES.size()]
		snapshots.append({"id": "ambient_%02d" % index, "position": vessel.position,
			"heading": vessel.heading, "length": _display_length(vessel), "ship_type_id": ship_id,
			"faction_id": vessel.faction_id, "kind": "merchant", "color": Color("adc3ba")})
	var offer: Dictionary = GameState.economy_state.get("merchant", {}).get("active_offer", {})
	if not offer.is_empty() and int(offer.get("quantity_available", 0)) > 0 and not _vessels.is_empty():
		# The offer belongs to an existing vessel; no duplicate hull at its berth.
		snapshots[0]["has_merchant_offer"] = true
	return snapshots

func _draw() -> void:
	for vessel in get_vessel_snapshots():
		var at := Vector2(vessel.position)
		var forward := Vector2(vessel.heading)
		var side := forward.orthogonal()
		var half := float(vessel.length) * 0.5
		draw_colored_polygon(PackedVector2Array([at + forward * half, at - forward * half + side * half * 0.3, at - forward * half - side * half * 0.3]), Color("b9c6ab"))
