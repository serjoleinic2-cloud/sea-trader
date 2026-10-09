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
	GameState.combat_state.merge({"naval_battle":{},"naval_enemies":{},"naval_arsenal":[],"naval_report":{},"naval_time":0.0,"next_pirate_at":0.0,"pirate_sequence":0},false)
	_clock = float(GameState.combat_state.naval_time)
	if float(GameState.combat_state.get("next_pirate_at",0.0))<=_clock:
		GameState.combat_state["next_pirate_at"]=_clock+_next_pirate_delay()
	_retire_training_encounter()
	for ship in warships(): normalize_ship(ship)

func _retire_training_encounter() -> void:
	# The temporary 3v3 button wrote its fixtures into the real save. Retire that
	# scenario once, keep one useful player warship only when no normal warship
	# already exists, and never touch ships the player built through the shipyard.
	var temporary: Array[Dictionary] = []
	var permanent_warship_exists: bool = false
	for ship in GameState.fleet_state:
		if str(ship.get("instance_id", "")).begins_with("debug_training_warship"):
			temporary.append(ship)
		elif bool(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("warship", false)):
			permanent_warship_exists = true
	var keeper: Dictionary = {}
	if not permanent_warship_exists and not temporary.is_empty():
		keeper = temporary[0]
		for ship in temporary:
			if float(ship.get("hull", 0)) > float(keeper.get("hull", 0)):
				keeper = ship
	var retained_fleet: Array = []
	for ship in GameState.fleet_state:
		if not temporary.has(ship):
			retained_fleet.append(ship)
	if not keeper.is_empty():
		keeper["instance_id"] = _unique_retained_warship_id(retained_fleet)
		keeper["name"] = "Боевой страж"
		keeper["status"] = "В сопровождении"
		keeper["escort_enabled"] = true
		keeper.erase("sinking")
		keeper.erase("sink_elapsed")
		retained_fleet.append(keeper)
	GameState.fleet_state = retained_fleet
	var enemies: Dictionary = GameState.combat_state.get("naval_enemies", {})
	for raw_id in enemies.keys():
		if str(raw_id).begins_with("debug_training_patrol"):
			enemies.erase(raw_id)
	var battle: Dictionary = GameState.combat_state.get("naval_battle", {})
	var legacy_battle: bool = false
	for raw_id in battle.get("ship_ids", []):
		legacy_battle = legacy_battle or str(raw_id).begins_with("debug_training_warship")
	for raw_id in battle.get("enemy_ids", []):
		legacy_battle = legacy_battle or str(raw_id).begins_with("debug_training_patrol")
	if legacy_battle:
		GameState.combat_state["naval_battle"] = {}
		GameState.combat_state["naval_report"] = {}

func _unique_retained_warship_id(fleet: Array) -> String:
	var used: Dictionary = {}
	for ship in fleet:
		used[str(ship.get("instance_id", ""))] = true
	var id: String = "fleet_warship_retained"
	var suffix: int = 2
	while used.has(id):
		id = "fleet_warship_retained_%d" % suffix
		suffix += 1
	return id

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
	var ids: Array = []
	for enemy in near:
		if enemy_ids.is_empty() or enemy_ids.has(str(enemy.id)): ids.append(str(enemy.id))
	var groups: Array[String] = []
	for id in ids:
		var group: String=str(GameState.combat_state.naval_enemies.get(id,{}).get("encounter_group",""))
		if group!="" and not groups.has(group): groups.append(group)
	for enemy in GameState.combat_state.naval_enemies.values():
		if groups.has(str(enemy.get("encounter_group",""))) and _enemy_alive(enemy) and vector(enemy.position).distance_to(vector(GameState.ship_state.position))<alert_radius()*2.0 and not ids.has(str(enemy.id)):
			ids.append(str(enemy.id))
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
	var losses: Dictionary = _losses_at_fraction(float(_rules.surrender_fraction),false,false)
	return _finish("Сдача — поражение",losses)

func _losses_at_fraction(fraction: float, include_home: bool, include_cargo: bool) -> Dictionary:
	var losses: Dictionary = {"money":floor(maxf(0,float(GameState.player_state.money))*fraction),"magic_shards":0,"resources":{},"cargo":{}}
	if include_home:
		losses.magic_shards=floor(int(GameState.combat_state.get("magic_shards",0))*fraction)
	var home: String = str(GameState.world_state.get("home_port_id",""))
	var inventory: Dictionary = GameState.port_state.get(home,{}).get("inventory",{})
	if include_home:
		for resource in inventory:
			var available: int = maxi(0,int(inventory[resource])-_economy.reserved(GameState.economy_state,str(resource)))
			var lost: int = int(floor(available*fraction))
			if lost>0: losses.resources[resource]=lost
	if include_cargo:
		for raw_item in GameState.ship_state.get("cargo",[]):
			var item: Dictionary=raw_item
			if item.has("contract_id"): continue
			var quantity: int=maxi(0,int(item.get("quantity",0)))
			var lost: int=mini(quantity,maxi(1,int(ceil(quantity*fraction)))) if quantity>0 else 0
			if lost>0:
				var resource_id: String=str(item.get("resource_id",""))
				losses.cargo[resource_id]=int(losses.cargo.get(resource_id,0))+lost
	return losses

func _battle_has_pirates(battle: Dictionary) -> bool:
	for id in battle.get("enemy_ids",[]):
		if str(GameState.combat_state.get("naval_enemies",{}).get(str(id),{}).get("kind",""))=="pirate": return true
	return false

func _apply_losses(losses: Dictionary) -> void:
	if losses.is_empty(): return
	GameState.player_state.money=float(GameState.player_state.money)-float(losses.get("money",0))
	GameState.combat_state.magic_shards=int(GameState.combat_state.get("magic_shards",0))-int(losses.get("magic_shards",0))
	var home: String=str(GameState.world_state.get("home_port_id",""))
	if GameState.port_state.has(home):
		for resource in losses.get("resources",{}):
			GameState.port_state[home].inventory[resource]=maxi(0,int(GameState.port_state[home].inventory.get(resource,0))-int(losses.resources[resource]))
	if not losses.get("cargo",{}).is_empty():
		var remaining_to_take: Dictionary=losses.cargo.duplicate(true)
		var retained_cargo: Array=[]
		for raw_item in GameState.ship_state.get("cargo",[]):
			var item: Dictionary=raw_item.duplicate(true)
			if not item.has("contract_id"):
				var resource_id: String=str(item.get("resource_id",""))
				var take: int=mini(int(item.get("quantity",0)),int(remaining_to_take.get(resource_id,0)))
				item.quantity=int(item.get("quantity",0))-take
				remaining_to_take[resource_id]=int(remaining_to_take.get(resource_id,0))-take
			if int(item.get("quantity",0))>0: retained_cargo.append(item)
		GameState.ship_state["cargo"]=retained_cargo

func _finish(outcome: String, losses: Dictionary) -> Dictionary:
	if not active(): return _result(false,"Бой уже завершён.")
	var old_ports: Dictionary = GameState.port_state.duplicate(true)
	var result: Dictionary = _transaction(func():
		var battle: Dictionary = GameState.combat_state.naval_battle
		_apply_losses(losses)
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
	if not active(): _step_world_patrols(step)
	if _patrol_clock>=1:
		_patrol_clock=0; _ensure_patrols(); _ensure_pirates(); _detect_hostile()
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
		var group_id: String = "patrol_"+str(key)
		var enemies: Dictionary = GameState.combat_state.naval_enemies
		var race: String = resolver.resolve(port,int(GameState.world_state.seed))
		var player_race: String=str(GameState.player_state.get("origin_race_id","humans"))
		if race==player_race:
			var factions: Array=GameData.get_factions()
			var at: int=factions.find_custom(func(faction): return str(faction.get("id",""))==race)
			race=str(factions[(maxi(0,at)+1)%factions.size()].id) if not factions.is_empty() else "surr"
		var minimum: int=int(_rules.get("patrol_group_min",1))
		var maximum: int=maxi(minimum,int(_rules.get("patrol_group_max",3)))
		var count: int=minimum+posmod(hash(group_id+str(GameState.world_state.seed)),maximum-minimum+1)
		var cycle: int=floori(_clock/maxf(1.0,float(_rules.patrol_respawn_seconds)))
		var attack_roll: float=float(posmod(hash(group_id+":hostile:"+str(cycle)),10000))/10000.0
		var hostile: bool=attack_roll<float(_rules.get("patrol_attack_chance",.12))
		for index in count:
			var id: String=group_id if index==0 else "%s_%d" % [group_id,index+1]
			if enemies.has(id):
				if float(enemies[id].get("retreat_until",0))>_clock or active() and GameState.combat_state.naval_battle.enemy_ids.has(id): continue
				if float(enemies[id].get("hull",0))>0: continue
			var tier: int=1+posmod(hash(id+str(GameState.world_state.seed)),3)
			var definition: Dictionary=GameData.get_ship("war_%s_%d" % [race,tier])
			var length: float=float(_visuals.get(definition.id,{}).get("display_length",5.1))/.04
			var point: Vector2=_military._spawn_position(center,length,_military._obstacles(id)) if _military!=null else center+Vector2.RIGHT*length*(index+1)
			if not point.is_finite(): continue
			enemies[id]={"id":id,"ship_type_id":definition.id,"name":"Патруль · "+str(definition.name),"faction_id":race,"kind":"faction_patrol","encounter_group":group_id,"position":point,"patrol_center":point,"roam_phase":float(posmod(hash(id+":phase"),628))/100.0,"heading":Vector2.UP,"turn_velocity":0.0,"speed":0.0,"hull":float(definition.hull_max),"hull_max":float(definition.hull_max),"level":1,"hostile":hostile,"warning":0.0,"cooldown":0.0,"retreat_until":0.0}

func _next_pirate_delay() -> float:
	var minimum: float=float(_rules.get("pirate_spawn_min_seconds",300))
	var maximum: float=maxf(minimum,float(_rules.get("pirate_spawn_max_seconds",600)))
	var sequence: int=int(GameState.combat_state.get("pirate_sequence",0))
	var roll: float=float(posmod(hash(str(GameState.world_state.get("seed",0))+":pirate:"+str(sequence)),10000))/10000.0
	return lerpf(minimum,maximum,roll)

func _ensure_pirates() -> void:
	if _clock<float(GameState.combat_state.get("next_pirate_at",INF)): return
	if active() or str(GameState.ship_state.get("docked_port_id",""))!="":
		GameState.combat_state["next_pirate_at"]=_clock+60.0
		return
	for enemy in GameState.combat_state.naval_enemies.values():
		if str(enemy.get("kind",""))=="pirate" and _enemy_alive(enemy):
			GameState.combat_state["next_pirate_at"]=_clock+60.0
			return
	var sequence: int=int(GameState.combat_state.get("pirate_sequence",0))+1
	GameState.combat_state["pirate_sequence"]=sequence
	var maximum: int=maxi(1,int(_rules.get("pirate_group_max",2)))
	var count: int=1+posmod(hash(str(GameState.world_state.get("seed",0))+":pirate_count:"+str(sequence)),maximum)
	var player: Vector2=vector(GameState.ship_state.get("position",Vector2.ZERO))
	var direction: Vector2=Vector2.from_angle(float(posmod(hash("pirate_bearing:"+str(sequence)),628))/100.0)
	var group_id: String="pirates_%d" % sequence
	for index in count:
		var id: String="%s_%d" % [group_id,index+1]
		var tier: int=1+posmod(hash(id),3)
		var definition: Dictionary=GameData.get_ship("war_humans_%d" % tier)
		var length: float=float(_visuals.get(definition.id,{}).get("display_length",5.1))/.04
		var desired: Vector2=player+direction.rotated((index-(count-1)*.5)*.18)*alert_radius()*1.55
		var point: Vector2=_military._spawn_position(desired,length,_military._obstacles(id)) if _military!=null else desired
		if not point.is_finite(): continue
		GameState.combat_state.naval_enemies[id]={"id":id,"ship_type_id":definition.id,"name":"Пираты · Чёрный корсар","faction_id":"pirates","kind":"pirate","encounter_group":group_id,"position":point,"patrol_center":point,"roam_phase":0.0,"heading":point.direction_to(player),"turn_velocity":0.0,"speed":0.0,"hull":float(definition.hull_max),"hull_max":float(definition.hull_max),"level":tier,"hostile":true,"warning":0.0,"cooldown":0.0,"retreat_until":0.0}
	GameState.combat_state["next_pirate_at"]=_clock+_next_pirate_delay()

func _step_world_patrols(delta: float) -> void:
	var player: Vector2=vector(GameState.ship_state.get("position",Vector2.ZERO))
	var docked: bool=str(GameState.ship_state.get("docked_port_id",""))!=""
	for enemy in GameState.combat_state.get("naval_enemies",{}).values():
		if not _enemy_alive(enemy): continue
		var current: Vector2=vector(enemy.get("position",Vector2.ZERO))
		var pirate: bool=str(enemy.get("kind",""))=="pirate"
		var target: Vector2
		if pirate and not docked:
			target=player
		else:
			var center: Vector2=vector(enemy.get("patrol_center",current))
			var phase: float=float(enemy.get("roam_phase",0.0))+_clock*.08
			target=center+Vector2.from_angle(phase)*float(_rules.get("patrol_roam_radius",140))
		var direction: Vector2=current.direction_to(target)
		if direction.length_squared()<.01: continue
		var heading: Vector2=vector(enemy.get("heading",direction)).normalized()
		var turn_rate: float=.42 if pirate else .28
		var turn: float=clampf(heading.angle_to(direction),-turn_rate*delta,turn_rate*delta)
		var steer: Vector2=heading.rotated(turn).normalized()
		var cruise: float=float(_rules.get("patrol_cruise_speed",26))*(1.45 if pirate else 1.0)
		if pirate and current.distance_to(player)<alert_radius()*.72: cruise=0.0
		var speed: float=move_toward(float(enemy.get("speed",0.0)),cruise,18.0*delta)
		var next: Vector2=current+steer*speed*delta
		var length: float=float(_visuals.get(str(enemy.get("ship_type_id","")),{}).get("display_length",5.1))/.04
		if _world_patrol_segment_clear(str(enemy.id),current,next,length):
			enemy.position=next
			enemy.heading=steer
			enemy.speed=speed
			enemy.turn_velocity=turn/maxf(.001,delta)
		else:
			enemy.heading=heading.rotated(turn_rate*delta)
			enemy.speed=0.0
			enemy.roam_phase=float(enemy.get("roam_phase",0.0))+1.2

func _world_patrol_segment_clear(id: String, from: Vector2, to: Vector2, length: float) -> bool:
	# World patrols move every frame. Avoid rebuilding renderer snapshot lists here;
	# coast checks plus the small naval-enemy dictionary are enough and keep ports smooth.
	if _military!=null and _military._blocked(from,to,length): return false
	var obstacles: Array[Dictionary]=[{"id":"player","position":vector(GameState.ship_state.get("position",Vector2.ZERO)),"length":float(_visuals.get(str(GameState.ship_state.get("ship_id","ship_sloop")),{}).get("display_length",3.48))/.04}]
	for other in GameState.combat_state.get("naval_enemies",{}).values():
		if str(other.get("id",""))!=id and _enemy_alive(other):
			obstacles.append({"id":str(other.get("id","")),"position":vector(other.get("position",Vector2.ZERO)),"length":float(_visuals.get(str(other.get("ship_type_id","")),{}).get("display_length",5.1))/.04})
	for other in obstacles:
		var center: Vector2=vector(other.position)
		var gap: float=(length+float(other.length))*.72
		var distance: float=center.distance_to(Geometry2D.get_closest_point_to_segment(center,from,to))
		if from.distance_to(center)<gap and to.distance_to(center)>from.distance_to(center): continue
		if distance<gap: return false
	return true

func _detect_hostile() -> void:
	var nearby: Array[Dictionary] = nearby_enemies()
	var ids: Array[String] = []
	for enemy in nearby: ids.append(str(enemy.id))
	for enemy in GameState.combat_state.naval_enemies.values():
		var pirate: bool=str(enemy.get("kind",""))=="pirate"
		var unescorted_pirate: bool=pirate and not ready_for_battle() and str(GameState.ship_state.get("docked_port_id",""))=="" and _enemy_alive(enemy) and vector(enemy.position).distance_to(vector(GameState.ship_state.position))<=alert_radius()*.72
		if unescorted_pirate:
			enemy.warning=float(enemy.get("warning",0))+1
			if float(enemy.warning)>=float(_rules.hostile_warning_seconds):
				_resolve_unescorted_piracy(enemy)
				return
			continue
		if ids.has(str(enemy.id)) and bool(enemy.get("hostile",false)):
			enemy.warning=float(enemy.get("warning",0))+1
			if float(enemy.warning)>=float(_rules.hostile_warning_seconds): begin_battle([str(enemy.id)],true); return
		else: enemy.warning=0.0

func _resolve_unescorted_piracy(enemy: Dictionary) -> void:
	var losses: Dictionary=_losses_at_fraction(float(_rules.get("pirate_unescorted_loot_fraction",.05)),false,true)
	var old_cargo: Array=GameState.ship_state.get("cargo",[]).duplicate(true)
	var old_money: float=float(GameState.player_state.money)
	var result: Dictionary=_transaction(func():
		_apply_losses(losses)
		enemy.retreat_until=_clock+float(_rules.patrol_respawn_seconds)
		enemy.warning=0.0
		GameState.combat_state.naval_report={"outcome":"Пираты ограбили незащищённый корабль","losses":losses,"time":_clock},"Пираты забрали часть груза и скрылись.")
	if not bool(result.get("ok",false)):
		GameState.ship_state["cargo"]=old_cargo
		GameState.player_state.money=old_money

func _step_battle(delta: float) -> void:
	if not active(): return
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
		var pirate_defeat: bool=_battle_has_pirates(battle)
		var defeat_losses: Dictionary=_losses_at_fraction(float(_rules.pirate_loot_fraction),false,true) if pirate_defeat else {}
		_finish("Поражение от пиратов — часть груза разграблена" if pirate_defeat else "Поражение",defeat_losses)
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
			var damage: float = maxf(1,float(_rules.enemy_damage)-float(GameData.get_ship(str(nearest.ship_type_id)).get("armor",0)))
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
		target.hull = maxf(0.0,float(target.hull)-float(shot.damage))
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
		var pirate: bool=str(enemy.get("kind",""))=="pirate"
		result.append({"id":str(enemy.id),"name":str(enemy.name),"ship_type_id":str(enemy.ship_type_id),"position":vector(enemy.position),"heading":vector(enemy.get("heading",Vector2.UP)),"length":float(_visuals.get(str(enemy.ship_type_id),{}).get("display_length",5.1))/.04,"faction_id":str(enemy.faction_id),"kind":"naval_enemy","enemy_kind":str(enemy.get("kind","faction_patrol")),"in_transit":active(),"speed":float(enemy.get("speed",0)),"turn_velocity":float(enemy.get("turn_velocity",0)),"color":Color("17191f") if pirate else Color("ff8464"),"hull":float(enemy.get("hull",0)),"hull_max":float(enemy.get("hull_max",1)),"sinking":bool(enemy.get("sinking",false)),"sink_progress":sink})
	return result

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
