extends Node

## Live offline naval combat. All mutable state is saved in GameState.
var _main: Node
var _military: Node
var _rules: Dictionary = {}
var _visuals: Dictionary = {}
var _clock: float = 0.0
var _patrol_clock: float = 0.0
var _save_clock: float = 0.0
var _economy = preload("res://systems/economy/economy_model.gd").new()

func _ready() -> void:
	add_to_group("naval_combat_system")
	_rules = GameData.read("res://data/combat/naval_rules.json")
	_visuals = GameData.read("res://data/world/ship_visuals.json").get("ships", {})

func initialize(main: Node, military: Node) -> void:
	_main = main; _military = military
	GameState.combat_state.merge({"naval_battle":{},"naval_enemies":{},"naval_arsenal":[],"naval_report":{},"naval_time":0.0},false)
	_clock = float(GameState.combat_state.naval_time)
	_repair_training_ship_ids()
	for ship in warships(): normalize_ship(ship)

func _repair_training_ship_ids() -> void:
	# Older practice encounters reused this ID after a destroyed ship was left in
	# the fleet. Keep the living ship addressable and retain the older ships.
	var matches: Array[Dictionary] = []
	var used: Dictionary = {}
	for ship in GameState.fleet_state:
		used[str(ship.get("instance_id", ""))] = true
		if str(ship.get("instance_id", "")) == "debug_training_warship": matches.append(ship)
	if matches.size() < 2: return
	var keeper: Dictionary = matches[0]
	for ship in matches:
		if float(ship.get("hull", 0)) > 0:
			keeper = ship
			break
	var suffix: int = 1
	for ship in matches:
		if is_same(ship, keeper): continue
		var id: String = "debug_training_warship_archived_%d" % suffix
		while used.has(id):
			suffix += 1
			id = "debug_training_warship_archived_%d" % suffix
		ship.instance_id = id
		used[id] = true

func warships() -> Array[Dictionary]:
	var ships: Array[Dictionary] = []
	for ship in GameState.fleet_state:
		if bool(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("warship", false)): ships.append(ship)
	return ships

func normalize_ship(ship: Dictionary) -> void:
	var definition: Dictionary = GameData.get_ship(str(ship.get("ship_type_id", "")))
	ship.merge({"level":1,"experience":0,"hull":float(definition.get("hull_max",280)),"commander":{},"guns":[],"naval_order":{},"naval_reload":-1.0,"escort_enabled":false,"escort_state":{},"cargo":[],"autopilot":{}},false)
	while ship.guns.size() < int(definition.get("gun_slots",2)): ship.guns.append({})

func ship_by_id(id: String) -> Dictionary:
	for ship in warships():
		if str(ship.instance_id) == id: return ship
	return {}

func position(ship: Dictionary) -> Vector2:
	return vector(ship.get("escort_state", {}).get("position", GameState.ship_state.get("position", Vector2.ZERO)))

func vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Dictionary: return Vector2(float(value.get("x",0)),float(value.get("y",0)))
	if value is Array and value.size() >= 2: return Vector2(float(value[0]),float(value[1]))
	if value is String:
		var parts: PackedStringArray = value.trim_prefix("(").trim_suffix(")").split(",")
		if parts.size()==2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float(): return Vector2(float(parts[0]),float(parts[1]))
	return Vector2.ZERO

func hull_max(ship: Dictionary) -> float:
	return float(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("hull_max", 280)) * (1.0 + float(_rules.hull_growth_per_level) * (int(ship.get("level",1))-1))

func active() -> bool:
	return bool(GameState.combat_state.get("naval_battle", {}).get("active",false))

func alert_radius() -> float:
	return float(_visuals.get(str(GameState.ship_state.get("ship_id","ship_sloop")),{}).get("display_length",3.48))/.04 * float(_rules.alert_hull_lengths)

func ready_for_battle() -> bool:
	if str(GameState.ship_state.get("docked_port_id", "")) != "": return false
	var player: Vector2 = vector(GameState.ship_state.get("position", Vector2.ZERO))
	for ship in warships():
		if bool(ship.get("escort_enabled",false)) and float(ship.get("hull",0))>0 and bool(ship.get("escort_state",{}).get("initialized",false)) and position(ship).distance_to(player)<alert_radius()*float(_rules.escort_readiness_radius_multiplier): return true
	return false

func nearby_enemies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ready_for_battle() or active(): return result
	var player: Vector2 = vector(GameState.ship_state.get("position", Vector2.ZERO))
	for enemy in GameState.combat_state.get("naval_enemies",{}).values():
		if _enemy_alive(enemy) and vector(enemy.position).distance_to(player)<=alert_radius(): result.append(enemy)
	return result

func create_training_encounter() -> Dictionary:
	if not OS.is_debug_build(): return _result(false,"Учебный бой доступен только в отладочной сборке.")
	if active(): return _result(false,"Сначала завершите текущий бой.")
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		return _result(false,"Выйдите из порта в море, затем вызовите учебный патруль.")
	var race_ids: Array[String] = ["nerids", "surr", "meridians", "aery", "crystari", "humans"]
	var player_race: String = str(GameState.player_state.get("origin_race_id", "humans"))
	var race_index: int = race_ids.find(player_race)
	var enemy_race: String = race_ids[(race_index + 1) % race_ids.size()]
	var player_position: Vector2 = vector(GameState.ship_state.get("position", Vector2.ZERO))
	var count: int = int(_rules.get("training_ship_count",3))
	var ships: Array[Dictionary] = []
	for candidate in warships():
		if float(candidate.get("hull",0))>0 and ships.size()<count: ships.append(candidate)
	for index in count:
		if ships.size()>=count: break
		var id: String = "debug_training_warship" if index==0 else "debug_training_warship_%d" % (index+1)
		var candidate: Dictionary = ship_by_id(id)
		if not candidate.is_empty() and ships.any(func(existing): return is_same(existing,candidate)): continue
		if candidate.is_empty(): candidate = _new_training_ship(id,player_race,mini(ships.size()+1,3))
		ships.append(candidate)
	var largest: float = float(_visuals.get("war_%s_3" % enemy_race,{}).get("display_length",7.3))/.04
	for ship in ships:
		largest=maxf(largest,float(_visuals.get(str(ship.ship_type_id),{}).get("display_length",5.1))/.04)
	var positions: Array[Vector2] = _training_positions(player_position,count,largest)
	if positions.is_empty(): return _result(false,"Здесь берег или причалы мешают стрельбе. Отойдите дальше в открытое море.")
	return _transaction(func():
		for index in ships.size():
			var ship: Dictionary = ships[index]
			if ship_by_id(str(ship.instance_id)).is_empty(): GameState.fleet_state.append(ship)
			normalize_ship(ship)
			ship.hull = hull_max(ship)
			ship.erase("sinking")
			ship.erase("sink_elapsed")
			ship.naval_reload = 0.0
			for gun in ship.guns:
				if not gun.is_empty(): gun.cooldown = 0.0
			var armed: bool = ship.guns.any(func(gun): return not gun.is_empty())
			if not armed and not ship.guns.is_empty(): ship.guns[0] = {"kind":"cannon","level":1,"experience":0,"cooldown":0.0}
			ship["escort_enabled"] = true
			ship["current_port_id"] = ""
			ship["autopilot"] = {}
			ship["escort_state"] = {"initialized": true, "position": positions[index*2], "heading": positions[index*2].direction_to(positions[index*2+1]), "blocked_seconds": 0.0, "avoidance_heading": Vector2.ZERO}
		# Practice durability accounts for the maximum sustained damage of the entire escort.
		var damage_per_second: float = 0.0
		for ally in warships():
			if not bool(ally.get("escort_enabled", false)): continue
			var volley_damage: float = 0.0
			var volley_reload: float = 0.0
			for gun in ally.get("guns", []):
				if gun.is_empty(): continue
				var definition: Dictionary = _rules.guns.get(str(gun.kind), {})
				var skills: Dictionary = ally.get("commander",{}).get("skills",{})
				var bonus: float = float(_rules.skill_bonus)
				var damage: float = float(definition.get("damage",18)) * (1.0+float(_rules.gun_damage_growth_per_level)*(int(gun.level)-1)) * (1.0+bonus*int(skills.get("gunnery",0)))
				var reload_time: float = float(definition.get("reload",8))/(1.0+bonus*int(skills.get("reload",0)))
				volley_damage += damage
				volley_reload = maxf(volley_reload,reload_time)
			damage_per_second += volley_damage/maxf(.1,volley_reload)
		var training_hull: float = maxf(float(_rules.training_minimum_hull),damage_per_second*float(_rules.training_target_seconds))
		GameState.combat_state.naval_report = {}
		for index in count:
			var enemy_id: String = "debug_training_patrol" if index==0 else "debug_training_patrol_%d" % (index+1)
			var enemy_definition: Dictionary = GameData.get_ship("war_%s_%d" % [enemy_race,mini(index+1,3)])
			GameState.combat_state.naval_enemies[enemy_id] = {
			"id": enemy_id,
			"ship_type_id": str(enemy_definition.get("id", "war_%s_1" % enemy_race)),
			"name": "Учебный патруль №%d" % (index+1),
			"training": true,
			"training_group": "debug_training_patrol",
			"faction_id": enemy_race,
			"position": positions[index*2+1],
			"heading": positions[index*2+1].direction_to(positions[index*2]),
			"hull": training_hull,
			"hull_max": training_hull,
			"level": 1,
			"hostile": false,
			"warning": 0.0,
			"cooldown": 3.0,
			"retreat_until": 0.0
			}
	, "Учебный бой: %d ваших боевых корабля против %d врагов, минимум 2 минуты. Z — начать; ЛКМ — выбрать корабль и цель; зажатая ПКМ — двигать карту; колёсико — масштаб." % [ships.size(),count])

func _new_training_ship(id: String, race: String, tier: int) -> Dictionary:
	return {"instance_id":id,"ship_type_id":"war_%s_%d" % [race,tier],"name":"Учебный страж №%d" % tier,"current_port_id":"","status":"В сопровождении","crew":[],"cargo":[],"cargo_capacity":0,"autopilot":{},"escort_enabled":true,"escort_state":{},"embarked_units":{"coast_guard":{"count":8,"level":1,"experience":0}},"commander":{"name":"Учебный командир","race_id":race,"level":1,"experience":0,"skill_points":0,"skills":{"gunnery":1,"accuracy":1,"reload":0}},"guns":[{"kind":"cannon","level":1,"experience":0,"cooldown":0.0},{"kind":"rune","level":1,"experience":0,"cooldown":0.0}]}

func _training_positions(origin: Vector2, count: int, largest_length: float) -> Array[Vector2]:
	var radius: float = alert_radius()
	var spacing: float = largest_length*float(_rules.get("training_row_spacing_lengths",2.2))
	for turn in 24:
		var direction: Vector2 = Vector2.from_angle(turn*TAU/24.0)
		var result: Array[Vector2] = []
		for index in count:
			var row: int = 0 if index==0 else ceili(index/2.0)*(1 if index%2==1 else -1)
			var offset: Vector2 = direction.orthogonal()*spacing*row
			var ally: Vector2 = origin-direction*radius*.5+offset
			var enemy: Vector2 = origin+direction*radius*.5+offset
			if _military!=null:
				if not _military._free(ally,largest_length) or not _military._free(enemy,largest_length): break
				if _military._guard.is_navigation_move_blocked(origin,ally) or _military._guard.is_navigation_move_blocked(ally,enemy): break
			result.append_array([ally,enemy])
		if result.size()==count*2: return result
	return []

func _enemy_alive(enemy: Dictionary) -> bool:
	return float(enemy.get("hull",0))>0 and float(enemy.get("retreat_until",0))<=_clock

func _management_status(ship: Dictionary) -> Dictionary:
	if ship.is_empty(): return _result(false,"Боевой корабль не найден.")
	if active(): return _result(false,"Сначала завершите морской бой.")
	var docked: String = str(GameState.ship_state.get("docked_port_id",""))
	if docked=="": return _result(false,"Оснащение доступно в общем порту.")
	if str(ship.get("current_port_id","")) != docked: return _result(false,"Дождитесь корабля в этом порту.")
	return _result(true,"")

func management_status(id: String) -> Dictionary:
	return _management_status(ship_by_id(id))

func _transaction(action: Callable, message: String) -> Dictionary:
	var before_fleet: Array = GameState.fleet_state.duplicate(true)
	var before_combat: Dictionary = GameState.combat_state.duplicate(true)
	var before_money: float = float(GameState.player_state.money)
	action.call()
	if not SaveSystem.save_game():
		GameState.fleet_state = before_fleet; GameState.combat_state = before_combat; GameState.player_state.money = before_money
		return _result(false,"Не удалось сохранить изменения.")
	EventBus.naval_battle_changed.emit()
	return _result(true,message)

func hire_commander(id: String) -> Dictionary:
	var ship: Dictionary = ship_by_id(id)
	var status: Dictionary = _management_status(ship)
	if not status.ok: return status
	normalize_ship(ship)
	if not ship.commander.is_empty(): return _result(false,"Командир уже назначен.")
	if float(GameState.player_state.money)<float(_rules.commander_cost): return _result(false,"Не хватает монет: %d." % int(_rules.commander_cost))
	return _transaction(func():
		GameState.player_state.money -= float(_rules.commander_cost)
		ship.commander = {"name":"Командир «%s»" % str(ship.name),"race_id":str(GameState.player_state.get("origin_race_id","humans")),"level":1,"experience":0,"skill_points":1,"skills":{"gunnery":0,"accuracy":0,"reload":0}}, "Военный командир назначен. Доступно очко навыка.")

func train_skill(id: String, skill: String) -> Dictionary:
	var ship: Dictionary = ship_by_id(id)
	var status: Dictionary = _management_status(ship)
	if not status.ok: return status
	var commander: Dictionary = ship.get("commander",{})
	if commander.is_empty() or not commander.skills.has(skill): return _result(false,"Назначьте командира.")
	if int(commander.skill_points)<=0 or int(commander.skills[skill])>=int(_rules.skill_cap): return _result(false,"Недостаточно очков или навык достиг предела.")
	return _transaction(func(): commander.skills[skill] += 1; commander.skill_points -= 1,"Навык улучшен.")

func install_gun(id: String, slot: int, kind: String, arsenal_index: int = -1) -> Dictionary:
	var ship: Dictionary = ship_by_id(id)
	var status: Dictionary = _management_status(ship)
	if not status.ok: return status
	normalize_ship(ship)
	if slot<0 or slot>=ship.guns.size() or not ship.guns[slot].is_empty(): return _result(false,"Выберите свободный слот.")
	var inventory: Array = GameState.combat_state.naval_arsenal
	if arsenal_index>=0:
		if arsenal_index>=inventory.size(): return _result(false,"Орудие отсутствует в арсенале.")
		return _transaction(func(): ship.guns[slot] = inventory.pop_at(arsenal_index),"Орудие установлено из арсенала с сохранением опыта.")
	if not _rules.guns.has(kind): return _result(false,"Неизвестное орудие.")
	var cost: float = float(_rules.guns[kind].cost)
	if float(GameState.player_state.money)<cost: return _result(false,"Не хватает монет: %d." % int(cost))
	return _transaction(func():
		GameState.player_state.money -= cost
		ship.guns[slot] = {"kind":kind,"level":1,"experience":0,"cooldown":0.0},"Орудие куплено и установлено.")

func remove_gun(id: String, slot: int) -> Dictionary:
	var ship: Dictionary = ship_by_id(id)
	var status: Dictionary = _management_status(ship)
	if not status.ok: return status
	if slot<0 or slot>=ship.get("guns",[]).size() or ship.guns[slot].is_empty(): return _result(false,"Слот пуст.")
	return _transaction(func(): GameState.combat_state.naval_arsenal.append(ship.guns[slot].duplicate(true)); ship.guns[slot]={},"Орудие возвращено в арсенал; опыт сохранён.")

func gun_level_cap(ship: Dictionary, gun: Dictionary) -> int:
	var commander: Dictionary = ship.get("commander",{})
	if commander.is_empty(): return 1
	var skill: String = str(_rules.guns.get(str(gun.get("kind","")),{}).get("skill","gunnery"))
	return mini(int(_rules.max_level), int(commander.get("level",1))+int(commander.get("skills",{}).get(skill,0)))

func upgrade_gun(id: String, slot: int) -> Dictionary:
	var ship: Dictionary = ship_by_id(id)
	var status: Dictionary = _management_status(ship)
	if not status.ok: return status
	if slot<0 or slot>=ship.get("guns",[]).size() or ship.guns[slot].is_empty(): return _result(false,"Слот пуст.")
	var gun: Dictionary = ship.guns[slot]
	var level: int = int(gun.level)
	if level>=gun_level_cap(ship,gun): return _result(false,"Улучшите командира и профильный навык орудия.")
	var xp: int = int(_rules.gun_level_xp)*level
	var cost: float = float(_rules.gun_level_cost)*level
	if int(gun.experience)<xp or float(GameState.player_state.money)<cost: return _result(false,"Требуется опыт %d/%d и %d монет." % [int(gun.experience),xp,int(cost)])
	return _transaction(func(): gun.level+=1; gun.experience-=xp; GameState.player_state.money-=cost,"Орудие улучшено.")

func upgrade_ship(id: String) -> Dictionary:
	var ship: Dictionary = ship_by_id(id)
	var status: Dictionary = _management_status(ship)
	if not status.ok: return status
	var level: int = int(ship.get("level",1))
	var xp: int = level*int(_rules.ship_level_xp)
	var cost: float = level*float(_rules.ship_level_cost)
	if level>=int(_rules.max_level): return _result(false,"Корабль достиг максимального уровня.")
	if int(ship.get("experience",0))<xp or float(GameState.player_state.money)<cost: return _result(false,"Требуется опыт %d/%d и %d монет." % [int(ship.get("experience",0)),xp,int(cost)])
	return _transaction(func(): ship.level=level+1; ship.experience-=xp; GameState.player_state.money-=cost,"Корабль улучшен; максимальная прочность повышена.")

func repair_ship(id: String) -> Dictionary:
	var ship: Dictionary = ship_by_id(id)
	var status: Dictionary = _management_status(ship)
	if not status.ok: return status
	var missing: float = maxf(0,hull_max(ship)-float(ship.get("hull",0)))
	var cost: float = ceil(missing*float(_rules.repair_per_hull))
	if float(GameState.player_state.money)<cost: return _result(false,"Ремонт стоит %d монет." % int(cost))
	return _transaction(func(): ship.hull=hull_max(ship); ship.erase("sinking"); ship.erase("sink_elapsed"); GameState.player_state.money-=cost,"Корабль отремонтирован.")

func begin_battle(enemy_ids: Array = [], enemy_initiated: bool = false) -> Dictionary:
	if active(): return _result(false,"Бой уже идёт.")
	if not ready_for_battle(): return _result(false,"Для боя нужен боевой корабль в сопровождении в море.")
	if bool(GameState.combat_state.get("active_raid",{}).get("active",false)): return _result(false,"Сначала завершите десантную операцию.")
	var near: Array[Dictionary] = nearby_enemies()
	# The debug exercise has exactly its own three targets; unrelated NPCs remain
	# outside the exercise even if their patrol happens to pass nearby.
	if enemy_ids.is_empty() and near.any(func(enemy): return str(enemy.get("training_group",""))=="debug_training_patrol"):
		near=near.filter(func(enemy): return str(enemy.get("training_group",""))=="debug_training_patrol")
	var ids: Array = []
	for enemy in near:
		if enemy_ids.is_empty() or enemy_ids.has(str(enemy.id)): ids.append(str(enemy.id))
	# A practice wing may be outside the initial five-hull alert circle. Once its
	# lead vessel is engaged, include its nearby companions in the same battle.
	var groups: Array = []
	for id in ids:
		var group: String = str(GameState.combat_state.naval_enemies[id].get("training_group",""))
		if group!="" and not groups.has(group): groups.append(group)
	for enemy in GameState.combat_state.naval_enemies.values():
		if groups.has(str(enemy.get("training_group",""))) and _enemy_alive(enemy) and vector(enemy.position).distance_to(vector(GameState.ship_state.position))<alert_radius()*2 and not ids.has(str(enemy.id)): ids.append(str(enemy.id))
	if ids.is_empty(): return _result(false,"Противник вышел из радиуса обнаружения.")
	var battle: Dictionary = {"active":true,"enemy_initiated":enemy_initiated,"ship_ids":[],"enemy_ids":ids,"previous_escorts":{},"truce_pending":false,"shots":0,"elapsed":0.0,"projectiles":[],"notice":"Выберите свой корабль на карте справа, затем красный корабль врага: приказ атаковать."}
	for ship in warships():
		if bool(ship.get("escort_enabled",false)) and float(ship.get("hull",0))>0:
			battle.ship_ids.append(str(ship.instance_id)); battle.previous_escorts[str(ship.instance_id)] = true
	var status: Dictionary = _transaction(func():
		GameState.combat_state.naval_report={}
		GameState.combat_state.naval_battle=battle
		for enemy_id in battle.enemy_ids:
			GameState.combat_state.naval_enemies[enemy_id].retreat_until=0.0
		for id in battle.ship_ids:
			var ship: Dictionary = ship_by_id(str(id))
			ship.escort_enabled=false; ship.naval_order={"kind":"hold","point":position(ship)}
			if _military!=null: _military.clear_orders(str(id)),"Бой начался.")
	if status.ok and _main!=null:
		var autopilot: Node = _main.get("_active_route_autopilot")
		if autopilot!=null: autopilot.cancel()
	return status

func issue_order(id: String, point: Vector2, enemy_id: String = "") -> Dictionary:
	if not active() or not GameState.combat_state.naval_battle.ship_ids.has(id): return _result(false,"Корабль не участвует в бою.")
	var ship: Dictionary = ship_by_id(id)
	if float(ship.get("hull",0))<=0: return _result(false,"Корабль выведен из строя.")
	if enemy_id!="" and not GameState.combat_state.naval_battle.enemy_ids.has(enemy_id): return _result(false,"Цель не участвует в бою.")
	return _transaction(func():
		ship.naval_order={"kind":"move" if enemy_id=="" else "attack","point":point,"enemy_id":enemy_id}
		GameState.combat_state.naval_battle.notice="%s: %s" % [str(ship.name),"курс задан" if enemy_id=="" else "атака назначена · орудия перезаряжаются между залпами"]
		if _military!=null: _military.clear_orders(id),"Курс задан." if enemy_id=="" else "Цель назначена.")

func rally() -> Dictionary:
	if not active(): return _result(false,"Нет активного боя.")
	return _transaction(func():
		var battle: Dictionary = GameState.combat_state.naval_battle
		for ship in warships():
			if float(ship.get("hull",0))<=0: continue
			var id: String = str(ship.instance_id)
			if not battle.ship_ids.has(id):
				battle.ship_ids.append(id); battle.previous_escorts[id]=bool(ship.get("escort_enabled",false))
			ship.escort_enabled=false; ship.naval_order={"kind":"rally","point":vector(GameState.ship_state.position)}
			if _military!=null: _military.clear_orders(id),"Общий сбор: корабли следуют к флагману.")

func propose_truce() -> Dictionary:
	if not active(): return _result(false,"Бой уже завершён.")
	return _transaction(func():
		GameState.combat_state.naval_battle.truce_pending=true
		GameState.combat_state.naval_battle.truce_at=_clock+float(_rules.truce_response_seconds)
		GameState.combat_state.naval_battle.notice="Предложено перемирие. Ожидаем согласия противника.","Предложение отправлено противнику.")

func respond_truce(accepted: bool) -> Dictionary:
	if not active() or not bool(GameState.combat_state.naval_battle.get("truce_pending",false)): return _result(false,"Нет предложения перемирия.")
	if accepted: return _finish("Перемирие",{})
	return _transaction(func():
		GameState.combat_state.naval_battle.truce_pending=false
		GameState.combat_state.naval_battle.notice="Противник отклонил перемирие. Бой продолжается.","Противник отклонил перемирие.")

func surrender() -> Dictionary:
	if not active(): return _result(false,"Бой уже завершён.")
	var fraction: float = float(_rules.surrender_fraction)
	var losses: Dictionary = {"money":floor(maxf(0,float(GameState.player_state.money))*fraction),"magic_shards":floor(int(GameState.combat_state.get("magic_shards",0))*fraction),"resources":{}}
	var home: String = str(GameState.world_state.get("home_port_id",""))
	var inventory: Dictionary = GameState.port_state.get(home,{}).get("inventory",{})
	for resource in inventory:
		var available: int = maxi(0,int(inventory[resource])-_economy.reserved(GameState.economy_state,str(resource)))
		var lost: int = int(floor(available*fraction))
		if lost>0: losses.resources[resource]=lost
	return _finish("Сдача — поражение",losses)

func _finish(outcome: String, losses: Dictionary) -> Dictionary:
	if not active(): return _result(false,"Бой уже завершён.")
	var old_ports: Dictionary = GameState.port_state.duplicate(true)
	var result: Dictionary = _transaction(func():
		var battle: Dictionary = GameState.combat_state.naval_battle
		if not losses.is_empty():
			GameState.player_state.money -= float(losses.money)
			GameState.combat_state.magic_shards -= int(losses.magic_shards)
			var home: String = str(GameState.world_state.get("home_port_id",""))
			for resource in losses.resources: GameState.port_state[home].inventory[resource] -= int(losses.resources[resource])
		for id in battle.ship_ids:
			var ship: Dictionary = ship_by_id(str(id))
			if ship.is_empty(): continue
			ship.escort_enabled=bool(battle.previous_escorts.get(id,false)) and float(ship.hull)>0
			ship.naval_order={}
			if outcome=="Победа": _award_xp(ship,int(_rules.victory_xp))
			if _military!=null: _military.clear_orders(str(id))
		for id in battle.enemy_ids:
			if GameState.combat_state.naval_enemies.has(id): GameState.combat_state.naval_enemies[id].retreat_until=_clock+float(_rules.patrol_respawn_seconds)
		GameState.combat_state.naval_report={"outcome":outcome,"losses":losses,"time":_clock}
		GameState.combat_state.naval_battle={},outcome)
	if not result.ok: GameState.port_state=old_ports
	return result

func _award_xp(ship: Dictionary, amount: int) -> void:
	ship.experience=int(ship.get("experience",0))+amount
	var commander: Dictionary = ship.get("commander",{})
	if not commander.is_empty():
		commander.experience += amount
		while int(commander.level)<int(_rules.max_level) and int(commander.experience)>=int(commander.level)*int(_rules.commander_level_xp):
			commander.experience -= int(commander.level)*int(_rules.commander_level_xp)
			commander.level += 1; commander.skill_points += 1

func _process(delta: float) -> void:
	if _main==null: return
	var step: float = clampf(delta,0,.25)
	_clock+=step; _patrol_clock+=step; _save_clock+=step
	GameState.combat_state.naval_time=_clock
	if _patrol_clock>=1:
		_patrol_clock=0; _ensure_patrols(); _detect_hostile()
	if active(): _step_battle(step)
	if _save_clock>=15:
		_save_clock=0; SaveSystem.save_game()

func _ensure_patrols() -> void:
	var ports: Dictionary = _main.get("_navigation_world").get("ports",{})
	var player: Vector2 = vector(GameState.ship_state.position)
	var resolver = preload("res://systems/world/port_faction_resolver.gd").new()
	for key in ports:
		if str(key)==str(GameState.world_state.get("home_port_id","")): continue
		var port: Dictionary = ports[key]
		var center: Vector2 = vector(port.get("position",Vector2.ZERO))
		if center.distance_to(player)>alert_radius()*8: continue
		var id: String = "patrol_"+str(key)
		var enemies: Dictionary = GameState.combat_state.naval_enemies
		if enemies.has(id):
			if float(enemies[id].get("retreat_until",0))>_clock or active() and GameState.combat_state.naval_battle.enemy_ids.has(id): continue
			if float(enemies[id].get("hull",0))>0: continue
		var race: String = resolver.resolve(port,int(GameState.world_state.seed))
		var tier: int = 1+posmod(hash(id+str(GameState.world_state.seed)),2)
		var definition: Dictionary = GameData.get_ship("war_%s_%d" % [race,tier])
		var length: float = float(_visuals.get(definition.id,{}).get("display_length",5.1))/.04
		var point: Vector2 = _military._spawn_position(center,length,_military._obstacles(id))
		if not point.is_finite(): continue
		enemies[id]={"id":id,"ship_type_id":definition.id,"name":"Патруль · "+str(definition.name),"faction_id":race,"position":point,"heading":Vector2.UP,"hull":float(definition.hull_max),"hull_max":float(definition.hull_max),"level":1,"hostile":posmod(hash(id+":hostile"),3)==0,"warning":0.0,"cooldown":0.0,"retreat_until":0.0}

func _detect_hostile() -> void:
	var nearby: Array[Dictionary] = nearby_enemies()
	var ids: Array[String] = []
	for enemy in nearby: ids.append(str(enemy.id))
	for enemy in GameState.combat_state.naval_enemies.values():
		if ids.has(str(enemy.id)) and bool(enemy.get("hostile",false)):
			enemy.warning=float(enemy.get("warning",0))+1
			if float(enemy.warning)>=float(_rules.hostile_warning_seconds): begin_battle([str(enemy.id)],true); return
		else: enemy.warning=0.0

func _step_battle(delta: float) -> void:
	var battle: Dictionary = GameState.combat_state.naval_battle
	battle.elapsed=float(battle.get("elapsed",0.0))+delta
	_resolve_projectiles(battle, delta)
	_advance_sinking(battle,delta)
	var enemies: Array[Dictionary] = []
	for id in battle.enemy_ids:
		var enemy: Dictionary = GameState.combat_state.naval_enemies.get(id,{})
		if not enemy.is_empty() and _enemy_alive(enemy): enemies.append(enemy)
	if enemies.is_empty():
		var destroyed: bool = not battle.enemy_ids.is_empty()
		for id in battle.enemy_ids:
			var target: Dictionary = GameState.combat_state.naval_enemies.get(id,{})
			if target.is_empty() or float(target.get("hull",0))>0: destroyed=false
		if destroyed and _side_is_sinking(battle.enemy_ids,false):
			battle.notice="Противник уничтожен · корабли уходят под воду"
			return
		_finish("Победа" if destroyed else "Бой прерван: противник недоступен",{})
		return
	var allies: Array[Dictionary] = []
	for id in battle.ship_ids:
		var ship: Dictionary = ship_by_id(str(id))
		if not ship.is_empty() and float(ship.get("hull",0))>0:
			allies.append(ship)
			var order: Dictionary = ship.get("naval_order",{})
			if str(order.get("kind",""))=="rally": order.point=vector(GameState.ship_state.position)
			if str(order.get("kind",""))=="attack":
				var enemy: Dictionary = GameState.combat_state.naval_enemies.get(str(order.get("enemy_id","")),{})
				if not enemy.is_empty() and _enemy_alive(enemy):
					var enemy_point: Vector2 = vector(enemy.position)
					var dist: float = position(ship).distance_to(enemy_point)
					var broadside: bool = str(GameData.get_ship(str(ship.ship_type_id)).get("gun_mounting","broadside"))=="broadside"
					if broadside and dist<=_ship_range(ship)*.82:
						var heading: Vector2=vector(ship.get("escort_state",{}).get("heading",Vector2.UP))
						var toward_target: Vector2=position(ship).direction_to(enemy_point)
						var side_heading: Vector2=toward_target.orthogonal()
						if heading.normalized().dot(side_heading)<heading.normalized().dot(-side_heading): side_heading=-side_heading
						order["broadside_heading"]=side_heading
						order.erase("bow_heading")
						order.point=position(ship)
					elif not broadside and dist<=_ship_range(ship)*.82:
						order.erase("broadside_heading")
						order["bow_heading"]=position(ship).direction_to(enemy_point)
						order.point=position(ship)
					else:
						order.erase("broadside_heading")
						order.erase("bow_heading")
						order.point=enemy_point+enemy_point.direction_to(position(ship))*_ship_range(ship)*.72
			_fire_ship(ship,enemies,delta,battle)
	if allies.is_empty():
		if _side_is_sinking(battle.ship_ids,true):
			battle.notice="Флот уничтожен · корабли уходят под воду"
			return
		_finish("Поражение",{})
		return
	for enemy in enemies:
		if not _enemy_alive(enemy): continue
		var nearest: Dictionary = allies[0]
		for ship in allies:
			if position(ship).distance_to(vector(enemy.position))<position(nearest).distance_to(vector(enemy.position)): nearest=ship
		var from: Vector2 = vector(enemy.position)
		var to: Vector2 = position(nearest)
		var length: float = float(_visuals.get(str(enemy.ship_type_id),{}).get("display_length",5.1))/.04
		var enemy_definition: Dictionary=GameData.get_ship(str(enemy.get("ship_type_id","")))
		var enemy_broadside: bool=str(enemy_definition.get("gun_mounting","broadside"))=="broadside"
		if from.distance_to(to)<=float(_rules.enemy_standoff_range):
			var enemy_heading: Vector2=vector(enemy.get("heading",Vector2.UP)).normalized()
			var firing_heading: Vector2=from.direction_to(to)
			if enemy_broadside:
				firing_heading=firing_heading.orthogonal()
				if enemy_heading.dot(firing_heading)<enemy_heading.dot(-firing_heading): firing_heading=-firing_heading
			var turn_rate: float=clampf(95.0/maxf(80.0,length),.28,1.0)
			enemy.heading=enemy_heading.rotated(clampf(enemy_heading.angle_to(firing_heading),-delta*turn_rate,delta*turn_rate))
			enemy.speed=move_toward(float(enemy.get("speed",0)),0.0,clampf(3200.0/maxf(80.0,length),10,40)*delta)
		elif from.distance_to(to)>float(_rules.enemy_standoff_range):
			var heading: Vector2 = vector(enemy.get("heading",Vector2.UP)).normalized()
			var turn: float = clampf(heading.angle_to(from.direction_to(to)),-delta*clampf(95.0/length,.28,1.0),delta*clampf(95.0/length,.28,1.0))
			enemy.heading = heading.rotated(turn)
			enemy.speed = move_toward(float(enemy.get("speed",0)),float(_rules.enemy_move_speed),clampf(3200.0/length,10,40)*delta)
			var next: Vector2 = from+vector(enemy.heading)*float(enemy.speed)*delta
			if _military!=null and _military._clear_segment(from,next,length,_military._obstacles(str(enemy.id))): enemy.position=next
		enemy.cooldown=maxf(0,float(enemy.get("cooldown",0))-delta)
		var enemy_facing: Vector2=vector(enemy.get("heading",Vector2.UP)).normalized()
		var enemy_target_direction: Vector2=from.direction_to(to)
		var enemy_alignment: float=enemy_facing.dot(enemy_target_direction)
		var enemy_gun_aligned: bool=enemy_broadside and absf(enemy_alignment)<=.58 or not enemy_broadside and enemy_alignment>=.5
		if float(enemy.cooldown)<=0 and enemy_gun_aligned and from.distance_to(to)<float(_rules.enemy_attack_range) and (_military==null or not _military._guard.is_navigation_move_blocked(from,to)):
			enemy.cooldown=float(_rules.enemy_reload_seconds)
			var sequence: int = int(battle.get("enemy_shots", 0)) + 1
			battle.enemy_shots = sequence
			var hit: bool = float(posmod(hash(str(enemy.id)+str(sequence)),1000))/1000.0 < float(_rules.get("enemy_accuracy",0.72))
			var damage: float = float(_rules.training_enemy_damage) if bool(enemy.get("training",false)) else maxf(1,float(_rules.enemy_damage)-float(GameData.get_ship(str(nearest.ship_type_id)).get("armor",0)))
			var impact: Vector2 = _queue_projectile(battle, from, to, hit, "cannon", "ally", str(nearest.instance_id), damage, sequence, _military._length(nearest) if _military != null else 130.0)
			EventBus.naval_shot_fired.emit(from,impact,hit)
			EventBus.naval_shot_visual.emit(from,impact,hit,"cannon",vector(enemy.get("heading",Vector2.LEFT)),str(enemy.get("id","")))
	if bool(battle.get("truce_pending",false)) and _clock>=float(battle.get("truce_at",INF)):
		var consent: bool = true
		for enemy in enemies:
			if bool(enemy.hostile) and float(enemy.hull)>float(enemy.hull_max)*float(_rules.truce_hull_ratio): consent=false
		respond_truce(consent)

func _ship_range(ship: Dictionary) -> float:
	var result: float = float(_rules.minimum_gun_range)
	for gun in ship.get("guns",[]):
		if not gun.is_empty(): result=maxf(result,float(_rules.guns.get(str(gun.kind),{}).get("range",550)))
	return result

func _advance_sinking(battle: Dictionary, delta: float) -> void:
	for raw_id in battle.get("enemy_ids",[]):
		var enemy: Dictionary=GameState.combat_state.get("naval_enemies",{}).get(str(raw_id),{})
		_update_sinking_target(enemy,delta)
	for raw_id in battle.get("ship_ids",[]):
		_update_sinking_target(ship_by_id(str(raw_id)),delta)

func _update_sinking_target(target: Dictionary, delta: float) -> void:
	if target.is_empty() or float(target.get("hull",0))>0: return
	target["sinking"]=true
	target["sink_elapsed"]=minf(float(_rules.sinking_duration_seconds),float(target.get("sink_elapsed",0))+delta)

func _side_is_sinking(ids: Array, allies: bool) -> bool:
	for raw_id in ids:
		var target: Dictionary=ship_by_id(str(raw_id)) if allies else GameState.combat_state.get("naval_enemies",{}).get(str(raw_id),{})
		if not target.is_empty() and float(target.get("hull",0))<=0 and float(target.get("sink_elapsed",0))<float(_rules.sinking_duration_seconds): return true
	return false

func sinking_progress(target: Dictionary) -> float:
	if not bool(target.get("sinking",false)): return 0.0
	return clampf(float(target.get("sink_elapsed",0))/maxf(.1,float(_rules.sinking_duration_seconds)),0.0,1.0)

func _fire_ship(ship: Dictionary, enemies: Array[Dictionary], delta: float, battle: Dictionary) -> void:
	var order: Dictionary = ship.get("naval_order",{})
	if str(order.get("kind","hold"))!="attack": return
	var target_id: String = str(order.get("enemy_id",""))
	if target_id=="": return
	var origin: Vector2 = position(ship)
	var target: Dictionary = {}
	for enemy in enemies:
		if str(enemy.id)==target_id: target=enemy; break
	if target.is_empty() or not _enemy_alive(target): return
	var skills: Dictionary = ship.get("commander",{}).get("skills",{})
	var mounting: String=str(GameData.get_ship(str(ship.get("ship_type_id",""))).get("gun_mounting","broadside"))
	var heading: Vector2=vector(ship.get("escort_state",{}).get("heading",Vector2.UP)).normalized()
	var target_direction: Vector2=origin.direction_to(vector(target.position))
	var remaining: float = float(ship.get("naval_reload",-1.0))
	if remaining<0.0:
		remaining=0.0
		for loaded_gun in ship.get("guns",[]):
			if not loaded_gun.is_empty(): remaining=maxf(remaining,float(loaded_gun.get("cooldown",0.0)))
	ship.naval_reload=maxf(0.0,remaining-delta)
	for loaded_gun in ship.get("guns",[]):
		if not loaded_gun.is_empty(): loaded_gun.cooldown=ship.naval_reload
	if float(ship.naval_reload)>0.0: return
	var fired: int=0
	var volley_reload: float=0.0
	for gun in ship.get("guns",[]):
		if gun.is_empty(): continue
		var definition: Dictionary = _rules.guns.get(str(gun.kind),{})
		if definition.is_empty() or origin.distance_to(vector(target.position))>float(definition.range) or not _enemy_alive(target): continue
		var alignment: float=heading.dot(target_direction)
		if mounting=="bow" and alignment<0.5: continue
		if mounting!="bow" and absf(alignment)>0.58: continue
		if _military!=null and _military._guard.is_navigation_move_blocked(origin,vector(target.position)): continue
		var bonus: float = float(_rules.skill_bonus)
		volley_reload=maxf(volley_reload,float(definition.reload)/(1+bonus*int(skills.get("reload",0))))
		fired+=1
		battle.shots=int(battle.shots)+1
		var roll: float = float(posmod(hash(str(GameState.world_state.seed)+str(battle.shots)+str(ship.instance_id)),1000))/1000.0
		var hit: bool = roll<minf(float(_rules.maximum_accuracy),float(definition.accuracy)+bonus*int(skills.get("accuracy",0)))
		var damage: float = float(definition.damage)*(1+float(_rules.gun_damage_growth_per_level)*(int(gun.level)-1))*(1+bonus*int(skills.get("gunnery",0)))
		var armor: float = float(GameData.get_ship(str(target.ship_type_id)).get("armor",0))
		var length: float = float(_visuals.get(str(target.ship_type_id),{}).get("display_length",5.1))/.04
		var impact: Vector2 = _queue_projectile(battle, origin, vector(target.position), hit, str(gun.kind), "enemy", str(target.id), maxf(1,damage-armor), int(battle.shots), length, str(ship.instance_id), ship.guns.find(gun))
		EventBus.naval_shot_fired.emit(origin,impact,hit)
		EventBus.naval_shot_visual.emit(origin,impact,hit,str(gun.get("kind","cannon")),vector(ship.get("escort_state",{}).get("heading",Vector2.UP)),str(ship.get("instance_id","")))
	if fired>0:
		ship.naval_reload=volley_reload
		for loaded_gun in ship.get("guns",[]):
			if not loaded_gun.is_empty(): loaded_gun.cooldown=volley_reload
		battle.notice="%s: %s · перезарядка %d с" % [str(ship.name),"носовой залп на ходу" if mounting=="bow" else "бортовой залп",ceili(volley_reload)]

func _queue_projectile(battle: Dictionary, origin: Vector2, target: Vector2, hit: bool, kind: String, target_kind: String, target_id: String, damage: float, sequence: int, length: float, shooter_id: String = "", gun_slot: int = -1) -> Vector2:
	var artillery = preload("res://systems/combat/naval_artillery.gd")
	var impact: Vector2 = artillery.impact_point(origin,target,hit,sequence,length)
	if not battle.has("projectiles"): battle.projectiles = []
	battle.projectiles.append({"remaining":artillery.flight_seconds(origin,impact,kind),"impact":impact,"hit":hit,"damage":damage,"target_kind":target_kind,"target_id":target_id,"shooter_id":shooter_id,"gun_slot":gun_slot})
	return impact

func _resolve_projectiles(battle: Dictionary, delta: float) -> void:
	var pending: Array = battle.get("projectiles", [])
	for index in range(pending.size()-1,-1,-1):
		var shot: Dictionary = pending[index]
		shot.remaining = float(shot.remaining)-delta
		if float(shot.remaining)>0: continue
		pending.remove_at(index)
		if not bool(shot.hit): continue
		var target: Dictionary = ship_by_id(str(shot.target_id)) if str(shot.target_kind)=="ally" else GameState.combat_state.naval_enemies.get(str(shot.target_id),{})
		if target.is_empty() or float(target.get("hull",0))<=0: continue
		var floor_hull: float = 1.0 if bool(target.get("training",false)) and float(battle.get("elapsed",0))<float(_rules.training_minimum_seconds) else 0.0
		target.hull = maxf(floor_hull,float(target.hull)-float(shot.damage))
		if float(target.hull)<=0:
			target["sinking"]=true
			target["sink_elapsed"]=0.0
		var shooter: Dictionary = ship_by_id(str(shot.get("shooter_id","")))
		if shooter.is_empty(): continue
		var slot: int = int(shot.get("gun_slot",-1))
		if slot>=0 and slot<shooter.guns.size() and not shooter.guns[slot].is_empty():
			shooter.guns[slot].experience=int(shooter.guns[slot].get("experience",0))+int(_rules.shot_xp)
		_award_xp(shooter,int(_rules.shot_xp))

func get_enemy_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var battle: Dictionary = GameState.combat_state.get("naval_battle",{})
	var active_enemy_ids: Array = battle.get("enemy_ids",[]) if bool(battle.get("active",false)) else []
	for enemy in GameState.combat_state.get("naval_enemies",{}).values():
		# Once a target enters combat, keep it in both the world and tactical map
		# even if a stale patrol-retreat timer was saved before battle began.
		var participating: bool = active_enemy_ids.has(str(enemy.get("id","")))
		var sink: float=sinking_progress(enemy)
		if (float(enemy.get("hull",0))<=0 and (not participating or sink>=1.0)) or (not participating and not _enemy_alive(enemy)): continue
		result.append({"id":str(enemy.id),"name":str(enemy.name),"ship_type_id":str(enemy.ship_type_id),"position":vector(enemy.position),"heading":vector(enemy.get("heading",Vector2.UP)),"length":float(_visuals.get(str(enemy.ship_type_id),{}).get("display_length",5.1))/.04,"faction_id":str(enemy.faction_id),"kind":"naval_enemy","in_transit":active(),"color":Color("ff8464"),"hull":float(enemy.get("hull",0)),"hull_max":float(enemy.get("hull_max",1)),"sinking":bool(enemy.get("sinking",false)),"sink_progress":sink})
	return result

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
