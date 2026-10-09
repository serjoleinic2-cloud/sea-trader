extends Node

## Military cargo and physical escorts. Persistent state stays inside fleet_state.
var _main: Node
var _visuals: Dictionary = {}
var _rules: Dictionary
var _naval_rules: Dictionary
var _guard = preload("res://systems/ship/ship_physics.gd").new()
var _planner = preload("res://systems/navigation/coast_route_planner.gd").new()
var _paths: Dictionary = {}
var _trail := PackedVector2Array()
var _save_clock: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	add_to_group("military_transport_system")
	_rules = GameData.read("res://data/combat/military_transport_rules.json")
	_naval_rules = GameData.read("res://data/combat/naval_rules.json")
	_visuals = GameData.read("res://data/world/ship_visuals.json").get("ships",{})

func initialize(main: Node) -> void:
	_main = main
	_guard.set_collision_data_provider(func(): return _navigation_world())
	for ship in vessels():
		ship.merge({"embarked_units":{},"escort_enabled":false,"escort_state":{}},false)
		# Preserve legacy commercial cargo until the player unloads it; new transports have none.
		if ship.get("cargo",[]).is_empty(): ship["cargo_capacity"] = 0

func _exit_tree() -> void:
	_guard.free()

func _navigation_world() -> Dictionary:
	return _main.get("_navigation_world") if _main != null else {"islands":[]}

func transports() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ship in GameState.fleet_state:
		if str(ship.get("ship_type_id","")) == "ship_combat_cutter": result.append(ship)
	return result

func vessels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ship in GameState.fleet_state:
		if str(ship.get("ship_type_id", "")) == "ship_combat_cutter" or bool(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("warship", false)): result.append(ship)
	return result

func clear_orders(id: String) -> void:
	_paths.erase(id)

func _route_replan_due(cache: Dictionary, state: Dictionary) -> bool:
	if cache.is_empty():
		return true
	var retry: float = float(_rules.get("blocked_route_retry_seconds", 6.0))
	return float(state.get("blocked_seconds", 0.0)) >= 0.75 and _time - float(cache.get("time", -INF)) >= retry

func get_transport(id: String) -> Dictionary:
	for ship in vessels():
		if str(ship.instance_id) == id: return ship
	return {}

func capacity(ship: Dictionary) -> Dictionary:
	var soldiers: int = 0
	var artillery: int = 0
	for id in ship.get("embarked_units",{}):
		var count: int = maxi(0,int(ship.embarked_units[id].get("count",0)))
		if _rules.artillery_units.has(id): artillery += count
		else: soldiers += count
	return {"soldiers":soldiers,"artillery":artillery,"soldier_capacity":int(_rules.soldier_capacity),"artillery_capacity":int(_rules.artillery_capacity)}

func _at_home(ship: Dictionary) -> bool:
	var home: String = str(GameState.world_state.get("home_port_id",""))
	return home != "" and str(GameState.ship_state.get("docked_port_id","")) == home and str(ship.get("current_port_id","")) == home

func _locked(id: String) -> bool:
	return GameState.combat_state.get("active_raid",{}).get("transport_ids",[]).has(id) or GameState.combat_state.get("naval_battle", {}).get("ship_ids", []).has(id)

func transfer_units(id: String, unit_id: String, amount: int, embark: bool = true) -> Dictionary:
	var ship: Dictionary = get_transport(id)
	if ship.is_empty() or not _at_home(ship): return _result(false,"Погрузка и выгрузка десанта доступны на вашей базе.")
	if amount <= 0: return _result(false,"Укажите положительное число бойцов или орудий.")
	if _locked(id): return _result(false,"Десант участвует в операции.")
	if not ship.get("cargo",[]).is_empty() or not ship.get("autopilot",{}).is_empty(): return _result(false,"Завершите старый рейс и выгрузите торговый груз.")
	if not GameData.read("res://data/combat/unit_catalog.json").get("units",{}).has(unit_id): return _result(false,"Неизвестный отряд.")
	var before_fleet: Array = GameState.fleet_state.duplicate(true)
	var before_units: Dictionary = GameState.combat_state.get("units",{}).duplicate(true)
	var garrison: Dictionary = GameState.combat_state.get("units",{})
	var aboard: Dictionary = ship.get("embarked_units",{})
	var origin: Dictionary = garrison if embark else aboard
	var destination: Dictionary = aboard if embark else garrison
	var from: Dictionary = origin.get(unit_id,{})
	if int(from.get("count",0)) < amount: return _result(false,"Недостаточно отрядов для перевода.")
	if embark:
		var count: Dictionary = capacity(ship)
		var guns: bool = _rules.artillery_units.has(unit_id)
		if amount + int(count.artillery if guns else count.soldiers) > int(count.artillery_capacity if guns else count.soldier_capacity):
			return _result(false,"Транспорт вмещает 60 бойцов и 6 орудий.")
	var to: Dictionary = destination.get(unit_id,{"count":0,"level":int(from.get("level",1)),"experience":int(from.get("experience",0))})
	# One unit type is a cohort. Never create experience or levels by shuttling units.
	var existing: int = int(to.get("count",0))
	if existing > 0:
		to["experience"] = int((float(to.get("experience",0))*existing+float(from.get("experience",0))*amount)/float(existing+amount))
		to["level"] = mini(int(to.get("level",1)),int(from.get("level",1)))
	to["count"] = existing+amount
	from["count"] = int(from.get("count",0))-amount
	origin[unit_id] = from
	destination[unit_id] = to
	ship["embarked_units"] = aboard
	GameState.combat_state["units"] = garrison
	if embark: ship["escort_enabled"] = true
	if not SaveSystem.save_game():
		GameState.fleet_state = before_fleet
		GameState.combat_state["units"] = before_units
		return _result(false,"Не удалось сохранить перевод отрядов.")
	return _result(true,"Отряды погружены на транспорт." if embark else "Отряды возвращены в гарнизон.")

func get_escort_change_status(id: String) -> Dictionary:
	var ship: Dictionary = get_transport(id)
	if ship.is_empty(): return _result(false,"Военный транспорт не найден.")
	if _locked(id): return _result(false,"Транспорт участвует в операции.")
	if not ship.get("cargo",[]).is_empty() or not ship.get("autopilot",{}).is_empty(): return _result(false,"Сначала завершите рейс и выгрузите старый груз.")
	var docked: String = str(GameState.ship_state.get("docked_port_id", ""))
	if docked == "": return _result(false,"Пришвартуйтесь в порту, чтобы изменить состав эскадры.")
	var state: Dictionary = ship.get("escort_state", {})
	var initialized: bool = bool(state.get("initialized", false))
	var player: Vector2 = _to_vector2(GameState.ship_state.get("position", Vector2.ZERO), Vector2.ZERO)
	var position: Vector2 = _to_vector2(state.get("position", player), player)
	var nearby: bool = initialized and position.distance_to(player) <= float(_rules.max_raid_distance)
	if str(ship.get("current_port_id", "")) != docked and not (bool(ship.get("escort_enabled", false)) and nearby):
		return _result(false,"Транспорт и основной корабль должны быть в одном порту.")
	if initialized and not nearby:
		return _result(false,"Дождитесь прибытия транспорта к вашему порту.")
	return _result(true,"Можно включить сопровождение или оставить транспорт в этом порту.")

func set_escort(id: String, enabled: bool) -> Dictionary:
	var status: Dictionary = get_escort_change_status(id)
	if not bool(status.ok): return status
	var ship: Dictionary = get_transport(id)
	var old_fleet: Array = GameState.fleet_state.duplicate(true)
	ship["escort_enabled"] = enabled
	ship["current_port_id"] = str(GameState.ship_state.get("docked_port_id", ""))
	ship["status"] = "В составе эскадры" if enabled else "Оставлен в порту"
	var state: Dictionary = ship.get("escort_state", {})
	state["blocked_seconds"] = 0.0
	state["avoidance_heading"] = Vector2.ZERO
	ship["escort_state"] = state
	if not SaveSystem.save_game():
		GameState.fleet_state = old_fleet
		return _result(false,"Не удалось сохранить состав эскадры.")
	_paths.erase(id)
	return _result(true,"Транспорт включён в сопровождение." if enabled else "Транспорт оставлен в порту.")

func raid_transports() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player: Vector2 = _to_vector2(GameState.ship_state.get("position", Vector2.ZERO), Vector2.ZERO)
	for ship in transports():
		if not bool(ship.get("escort_enabled",false)): continue
		if not ship.get("autopilot",{}).is_empty(): continue
		var state: Dictionary = ship.get("escort_state",{})
		if not bool(state.get("initialized",false)): continue
		var transport_position: Vector2 = _to_vector2(state.get("position", Vector2.ZERO), Vector2.ZERO)
		if transport_position.distance_to(player) > float(_rules.max_raid_distance): continue
		if _guard.is_navigation_move_blocked(transport_position,player): continue
		var count: Dictionary = capacity(ship)
		if int(count.soldiers) + int(count.artillery) > 0: result.append(ship)
	return result

func _process(delta: float) -> void:
	if _main == null: return
	_save_clock += delta
	var player: Vector2 = _to_vector2(GameState.ship_state.get("position", Vector2.ZERO), Vector2.ZERO)
	if _trail.is_empty() or _trail[-1].distance_to(player) > 25:
		_trail.append(player)
		if _trail.size()>400: _trail.remove_at(0)
	var ships: Array[Dictionary] = vessels()
	# Move on every rendered frame. Small collision-checked substeps also avoid
	# jumps after a slow frame, instead of teleporting the models every 0.1 seconds.
	var remaining: float = clampf(delta, 0.0, 0.25)
	while remaining > 0.00001:
		var step: float = minf(remaining, 1.0 / 60.0)
		_time += step
		var formation_index: int = 0
		for ship in ships:
			_step_ship(ship, formation_index, step)
			if bool(ship.get("escort_enabled", false)) and ship.get("autopilot", {}).is_empty() and not _locked(str(ship.instance_id)):
				formation_index += 1
		remaining -= step
	if _save_clock > 15.0 and not ships.is_empty():
		_save_clock = 0.0
		SaveSystem.save_game()

func _length(ship: Dictionary) -> float:
	return float(_visuals.get(str(ship.get("ship_type_id","ship_combat_cutter")),{}).get("display_length",4.3)) / 0.04

func _blocked(from: Vector2, to: Vector2, length: float) -> bool:
	var direction: Vector2 = (to-from).normalized()
	if direction.length_squared()<.1: direction=Vector2.UP
	var side := direction.orthogonal()
	for offset in [Vector2.ZERO,direction*length*.42,-direction*length*.42,side*length*.18,-side*length*.18]:
		if _guard.is_navigation_move_blocked(from+offset,to+offset): return true
	return false

func _free(point: Vector2, length: float) -> bool:
	for direction in [Vector2.RIGHT,Vector2.DOWN]:
		if _blocked(point-direction,point+direction,length): return false
	return true

func _obstacles(id: String) -> Array:
	var result: Array = [{"id":"player","position":_to_vector2(GameState.ship_state.get("position", Vector2.ZERO), Vector2.ZERO),"length":float(_visuals.get(str(GameState.ship_state.get("ship_id","ship_sloop")),{}).get("display_length",3.48))/.04}]
	for snapshot in get_vessel_snapshots():
		if str(snapshot.id)!=id: result.append(snapshot)
	var traders: Node = get_tree().get_first_node_in_group("trader_traffic_renderer")
	if traders != null: result.append_array(traders.get_vessel_snapshots())
	var fleet: Node = get_tree().get_first_node_in_group("fleet_traffic_renderer")
	if fleet != null:
		for snapshot in fleet.get_vessel_snapshots():
			if str(snapshot.get("ship_type_id","")) != "ship_combat_cutter" and not bool(GameData.get_ship(str(snapshot.get("ship_type_id", ""))).get("warship", false)) and str(snapshot.get("kind", "")) != "naval_enemy": result.append(snapshot)
	return result

func _clear_segment(from: Vector2, to: Vector2, length: float, obstacles: Array) -> bool:
	if _blocked(from,to,length): return false
	for other in obstacles:
		var center: Vector2 = _to_vector2(other.get("position", Vector2.ZERO), Vector2.ZERO)
		var gap: float = length + float(other.get("length",100))
		var distance: float = center.distance_to(Geometry2D.get_closest_point_to_segment(center,from,to))
		# Permit moving away from an overlap in an old save, never deeper through it.
		if from.distance_to(center)<gap and to.distance_to(center)>from.distance_to(center) and (from-center).dot(to-from)>=0: continue
		if distance<gap: return false
	return true

func _spawn_position(origin: Vector2, length: float, obstacles: Array) -> Vector2:
	for ring in range(1,18):
		for turn in range(16):
			var point: Vector2 = origin+Vector2.from_angle(turn*TAU/16.0)*length*ring*.7
			if _free(point,length) and _clear_segment(point,point+Vector2(.1,0),length,obstacles): return point
	return Vector2.INF

func _trail_target(distance: float, fallback: Vector2) -> Vector2:
	var remaining: float = distance
	for index in range(_trail.size()-1,0,-1):
		var segment: float = _trail[index].distance_to(_trail[index-1])
		if segment>=remaining: return _trail[index].move_toward(_trail[index-1],remaining)
		remaining-=segment
	return fallback

func _step_ship(ship: Dictionary, index: int, delta: float) -> void:
	if not ship.get("autopilot",{}).is_empty(): return
	var id: String = str(ship.instance_id)
	var length: float = _length(ship)
	var state: Dictionary = ship.get("escort_state",{})
	var obstacles: Array = _obstacles(id)
	var leader: Vector2 = _to_vector2(GameState.ship_state.get("position", Vector2.ZERO), Vector2.ZERO)
	var forward := Vector2.from_angle(float(GameState.ship_state.get("heading",-PI*.5)))
	var left := Vector2(forward.y,-forward.x)
	var spacing: float = maxf(length,float(obstacles[0].length))
	var row: int = index/2
	var column: int = index%2
	var target: Vector2 = leader-forward*spacing*(float(_rules.formation_aft_lengths)+0.6+row*2.0)+left*spacing*(float(_rules.formation_left_lengths)+float(column)*2.2)
	if not bool(state.get("initialized",false)):
		var origin: Vector2 = target
		if not bool(ship.get("escort_enabled",false)):
			var port: Dictionary = _navigation_world().get("ports",{}).get(str(ship.get("current_port_id","")),{})
			origin = _to_vector2(port.get("position",leader), leader)
		var point: Vector2 = _spawn_position(origin,length,obstacles)
		if not point.is_finite(): return
		state={"position":point,"heading":forward,"initialized":true,"blocked_seconds":0.0}
		ship["escort_state"]=state
	if float(ship.get("hull", 1)) <= 0: return
	var tactical: bool = GameState.combat_state.get("naval_battle", {}).get("ship_ids", []).has(id)
	if (not bool(ship.get("escort_enabled",false)) and not tactical) or (_locked(id) and not tactical): return
	if tactical:
		target = _to_vector2(ship.get("naval_order", {}).get("point", state.position), state.position)
	var position: Vector2 = _to_vector2(state.get("position", leader), leader)
	var docked: String = str(GameState.ship_state.get("docked_port_id",""))
	ship["current_port_id"] = docked if position.distance_to(leader)<float(_rules.max_raid_distance) else ""
	# In narrow channels follow the leader's actually travelled wake in single file.
	if not tactical and (not _free(target,length) or _blocked(position,target,length)):
		target=_trail_target(spacing*(2.0+index*1.7),leader-forward*spacing*(2.0+index*1.7))
	if not _free(target,length):
		target=_spawn_position(leader,length,obstacles)
	if not target.is_finite():
		ship["status"]="Ожидает свободный проход"
		return
	var attack_order: Dictionary=ship.get("naval_order",{})
	var facing_heading: Vector2=Vector2.ZERO
	if attack_order.has("broadside_heading"): facing_heading=_to_vector2(attack_order.broadside_heading,Vector2.ZERO)
	elif attack_order.has("bow_heading"): facing_heading=_to_vector2(attack_order.bow_heading,Vector2.ZERO)
	elif attack_order.has("stern_heading"): facing_heading=_to_vector2(attack_order.stern_heading,Vector2.ZERO)
	if tactical and str(attack_order.get("kind",""))=="attack" and facing_heading.length_squared()>.1 and position.distance_to(target)<length*.26:
		var current_broadside_heading: Vector2=_to_vector2(state.get("heading",Vector2.UP),Vector2.UP).normalized()
		var desired_heading: Vector2=facing_heading.normalized()
		var broadside_turn_rate: float=clampf(95.0/maxf(80.0,length),.28,1.05)*float(GameData.get_ship(str(ship.ship_type_id)).get("base_maneuverability",.85))
		var broadside_turn: float=clampf(current_broadside_heading.angle_to(desired_heading),-broadside_turn_rate*delta,broadside_turn_rate*delta)
		state["heading"]=current_broadside_heading.rotated(broadside_turn).normalized()
		state["turn_velocity"]=broadside_turn/maxf(.001,delta)
		state["speed"]=move_toward(float(state.get("speed",0.0)),0.0,clampf(3200.0/maxf(80.0,length),10,40)*delta)
		state["position"]=position
		state["blocked_seconds"]=0.0
		ship["escort_state"]=state
		ship["status"]="Бортом к противнику" if attack_order.has("broadside_heading") else ("Кормой к противнику" if attack_order.has("stern_heading") else "Носом к противнику")
		return
	if position.distance_to(target)<length*.26:
		ship["status"]="В строю" if docked=="" else "На рейде порта"
		state["blocked_seconds"] = 0.0
		state["speed"] = 0.0
		state["turn_velocity"] = 0.0
		return
	var cache: Dictionary = _paths.get(id,{})
	# Moving formation targets used to trigger a full route rebuild every two
	# seconds. Let local collision steering follow the wake continuously; rebuild
	# a coastal route only for a ship that has actually stopped against an obstacle.
	if _route_replan_due(cache, state):
		var islands: Array = []
		var world_islands: Array = _navigation_world().get("islands",[])
		var route_bounds := Rect2(position, target-position).abs().grow(700.0+length)
		for raw_island in world_islands:
			var island: Dictionary = raw_island
			var island_position: Vector2 = _to_vector2(island.get("position",Vector2.ZERO),Vector2.ZERO)
			var island_radius: float = float(island.get("radius",0.0))
			var bounds: Rect2 = island.get("navigation_bounds",Rect2(island_position-Vector2.ONE*island_radius,Vector2.ONE*island_radius*2.0))
			if not bounds.grow(700.0+length).intersects(route_bounds):
				continue
			var nearby: Dictionary = island.duplicate(false)
			nearby["radius"] = island_radius+length*.55
			islands.append(nearby)
		# Planner nodes must clear the entire escort hull, not just its centre point.
		if float(state.get("blocked_seconds",0))>float(_rules.stuck_repath_seconds):
			for obstacle in obstacles:
				var obstacle_position: Vector2 = _to_vector2(obstacle.get("position", Vector2.ZERO), Vector2.ZERO)
				if obstacle_position.distance_to(position)<length*6 and obstacle_position.distance_to(target)>length*2:
					islands.append({"position":obstacle_position,"radius":(length+float(obstacle.get("length",100)))*.55+24})
		var path: PackedVector2Array = _planner.plan(position,target,islands,func(a:Vector2,b:Vector2):
			if _blocked(a,b,length):return true
			for island in islands:
				var island_position: Vector2 = _to_vector2(island.get("position", Vector2.ZERO), Vector2.ZERO)
				if not island.has("id") and a.distance_to(island_position)>float(island.radius) and Geometry2D.get_closest_point_to_segment(island_position,a,b).distance_to(island_position)<float(island.radius):return true
			return false,48.0+length*.35)
		cache={"path":path,"target":target,"time":_time}
		_paths[id]=cache
	var path: PackedVector2Array = cache.get("path",PackedVector2Array())
	while not path.is_empty() and position.distance_to(path[0])<length*.2: path.remove_at(0)
	cache["path"]=path
	# If the visibility planner cannot form a path, don't aim at our own position:
	# that produces a zero steering vector and leaves the escort pushing its old heading forever.
	var no_direct_route: bool = path.is_empty() and _blocked(position,target,length)
	var waypoint: Vector2 = target if path.is_empty() else path[0]
	var direction: Vector2 = position.direction_to(waypoint)
	var current_heading: Vector2 = _to_vector2(state.get("heading", direction), direction).normalized()
	if current_heading.length_squared() < 0.01:
		current_heading = direction
	# Turn at a bounded angular speed even when the route planner has no path.
	# Snapping to the first collision-free candidate made the ship oscillate as
	# tiny changes in collision geometry changed which side was tested first.
	var definition: Dictionary = GameData.get_ship(str(ship.ship_type_id))
	var turn_rate: float = clampf(95.0/maxf(80.0,length),.28,1.05)*float(definition.get("base_maneuverability",.85))
	var player_velocity: Vector2 = _to_vector2(GameState.ship_state.get("velocity", Vector2.ZERO), Vector2.ZERO)
	var cruise: float = float(definition.get("base_speed",118))
	var requested: float = cruise if tactical else minf(cruise*1.25,maxf(cruise,player_velocity.length()*float(_rules.catchup_speed_multiplier)))
	var acceleration: float = clampf(3200.0/maxf(80,length),10,40)
	var brake_speed: float = sqrt(2.0*acceleration*maxf(0,position.distance_to(waypoint)-length*.2))
	var alignment: float = clampf((current_heading.dot(direction)+1.0)*.5,.2,1.0)
	var speed: float = move_toward(float(state.get("speed",0)),minf(requested,brake_speed)*alignment,acceleration*delta)
	state["speed"] = speed
	var distance: float = minf(speed*delta,position.distance_to(waypoint)*0.82)
	var steering_angles: Array[float] = [0.0,.35,-.35,.7,-.7,1.1,-1.1]
	if no_direct_route or float(state.get("blocked_seconds",0.0)) > float(_rules.stuck_repath_seconds):
		# The short forward fan cannot escape a route blocked on both sides.
		# Probe sideways and astern; collision checks still reject every unsafe step.
		steering_angles.append_array([1.5,-1.5,1.9,-1.9,2.35,-2.35,2.8,-2.8,PI])
	var best_wanted: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	var preferred: Vector2 = _to_vector2(state.get("avoidance_heading", Vector2.ZERO), Vector2.ZERO).normalized()
	for angle in steering_angles:
		var wanted: Vector2 = direction.rotated(float(angle))
		var next: Vector2 = position+wanted*distance
		if distance>0 and _clear_segment(position,next,length,obstacles):
			# Prefer forward progress, but reward continuity strongly enough to
			# keep choosing the same side of an obstacle across adjacent frames.
			var score: float = wanted.dot(direction) * 0.75 + wanted.dot(current_heading) * 0.45
			if preferred.length_squared() > 0.1:
				score += wanted.dot(preferred) * 0.35
			if score > best_score:
				best_score = score
				best_wanted = wanted
	var moved: bool = false
	var turn_toward: Vector2 = best_wanted if best_wanted.length_squared() > 0.1 else (preferred if preferred.length_squared() > 0.1 else direction)
	var turn: float = clampf(current_heading.angle_to(turn_toward), -turn_rate * delta, turn_rate * delta)
	state["turn_velocity"] = turn/maxf(.001,delta)
	var steer: Vector2 = current_heading.rotated(turn).normalized()
	var next: Vector2 = position + steer * distance
	if distance > 0.0 and _clear_segment(position, next, length, obstacles):
		moved = true
	if moved:
		state["position"] = next
		state["heading"] = steer
		state["avoidance_heading"] = turn_toward if no_direct_route else Vector2.ZERO
		state["blocked_seconds"] = 0.0
	else:
		# Rotate smoothly in place when even the bounded turn step is blocked.
		state["heading"] = current_heading.rotated(turn).normalized()
		state["avoidance_heading"] = turn_toward
		state["blocked_seconds"] = float(state.get("blocked_seconds",0)) + delta
	ship["status"]="Сопровождает" if moved else "Перестраивает маршрут"
	ship["escort_state"]=state

func get_vessel_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ship in vessels():
		if not ship.get("autopilot",{}).is_empty(): continue
		var state: Dictionary = ship.get("escort_state",{})
		if not bool(state.get("initialized",false)):continue
		var position: Vector2 = _to_vector2(state.get("position", Vector2.ZERO), Vector2.ZERO)
		var heading: Vector2 = _to_vector2(state.get("heading", Vector2.UP), Vector2.UP)
		var sink_duration: float=float(_naval_rules.get("sinking_duration_seconds",8.0))
		var sink_progress: float=clampf(float(ship.get("sink_elapsed",0))/maxf(.1,sink_duration),0.0,1.0) if bool(ship.get("sinking",false)) else 0.0
		if float(ship.get("hull",0))<=0 and sink_progress>=1.0: continue
		if heading.length_squared() < 0.0001:
			heading = Vector2.UP
		var definition: Dictionary=GameData.get_ship(str(ship.get("ship_type_id","")))
		var maximum: float=float(definition.get("hull_max",maxf(1,float(ship.get("hull",1)))))*(1.0+float(_naval_rules.get("hull_growth_per_level",.06))*maxi(0,int(ship.get("level",1))-1))
		result.append({"id":str(ship.get("instance_id", "")),"ship_type_id":str(ship.get("ship_type_id", "")),"name":str(ship.get("name","Военный транспорт")),"position":position,"heading":heading.normalized(),"length":_length(ship),"kind":"fleet","faction_id":str(GameState.player_state.get("origin_race_id","humans")),"in_transit":bool(ship.get("escort_enabled",false)),"port_id":str(ship.get("current_port_id","")),"speed":float(state.get("speed",0)),"turn_velocity":float(state.get("turn_velocity",0)),"color":Color("cba761"),"hull":float(ship.get("hull",0)),"hull_max":maximum,"sinking":bool(ship.get("sinking",false)),"sink_progress":sink_progress})
	return result

func _to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary and value.has("x") and value.has("y"):
		return Vector2(float(value["x"]), float(value["y"]))
	if value is String:
		var parts: PackedStringArray = value.trim_prefix("(").trim_suffix(")").split(",")
		if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float(): return Vector2(float(parts[0]), float(parts[1]))
	return fallback

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
