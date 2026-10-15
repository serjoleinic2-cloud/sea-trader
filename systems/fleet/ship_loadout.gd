extends RefCounted

## Shared ship equipment queries. UI and simulation read the same crew/boost values.
static var _boosts: Dictionary = {}
var _tree: SceneTree

func _init(tree: SceneTree = null) -> void:
	_tree = tree

static func vessel(id: String) -> Dictionary:
	if id == "active_ship": return GameState.ship_state
	for ship in GameState.fleet_state:
		if str(ship.get("instance_id", "")) == id: return ship
	return {}

static func definition(ship: Dictionary) -> Dictionary:
	return GameData.get_ship(str(ship.get("ship_type_id", ship.get("ship_id", ""))))

static func boost_catalog() -> Dictionary:
	if _boosts.is_empty(): _boosts = GameData.read("res://data/rewards/reward_catalog.json").get("boosts", {})
	return _boosts

static func boost_slots(ship: Dictionary) -> Array:
	var slots: Array = ship.get("boost_slots", []).duplicate(true)
	while slots.size() < 4: slots.append({})
	if ship == GameState.ship_state:
		var legacy: Dictionary = GameState.economy_state.get("rewards", {}).get("active_boost", {})
		if float(legacy.get("seconds_remaining", 0)) > 0 and slots[0].is_empty():
			slots[0] = legacy.duplicate(true)
			slots[0]["legacy"] = true
	return slots.slice(0, 4)

static func boost_bonus(ship: Dictionary, stat: String) -> float:
	return slots_bonus(boost_slots(ship),stat)

static func slots_bonus(slots: Array, stat: String, duration: float = 0.0) -> float:
	var value: float = 0.0
	for active in slots:
		var spec: Dictionary = boost_catalog().get(str(active.get("id", "")), {})
		var remaining: float = float(active.get("seconds_remaining",0))
		if remaining > 0 and str(spec.get("stat", "")) == stat:
			var coverage: float = minf(1.0,remaining/duration) if duration > 0 else 1.0
			value += float(spec.get("percent", 0)) * coverage
	return clampf(value, 0.0, 15.0)

static func crew_bonus(ship: Dictionary, stat: String) -> float:
	var value: float = 0.0
	for employee in GameState.employee_state:
		if not ship.get("crew", []).has(str(employee.get("employee_instance_id", ""))): continue
		if not preload("res://systems/employees/training_scrolls.gd").is_living(employee): continue
		value += float(employee.get("stats", {}).get(stat, 0)) + float(employee.get("skill_stats", {}).get(stat, 0))
	return value

static func crew_slots(id: String) -> Array[Dictionary]:
	var ship: Dictionary = vessel(id)
	if ship.is_empty(): return []
	var spec: Dictionary = definition(ship)
	var max_crew: int = int(spec.get("max_crew", 1))
	var order: Array = GameData.read("res://data/fleet/outfitting_rules.json").get("crew_role_order", [])
	var slots: Array[Dictionary] = []
	# The flagship's command chair is occupied by the player's canonical captain.
	if id == "active_ship": slots.append({"key":"player", "role":"captain", "player":true, "person":{}})
	for index in max_crew:
		var role: String = str(order[index % order.size()]) if not order.is_empty() else "sailor"
		if id == "active_ship": role = str(order[(index + 1) % order.size()])
		slots.append({"key":"crew_%d" % index, "role":role, "person":{}})
	var remaining: Array[Dictionary] = []
	for employee in GameState.employee_state:
		if ship.get("crew", []).has(str(employee.get("employee_instance_id", ""))): remaining.append(employee)
	for slot in slots:
		if bool(slot.get("player", false)): continue
		for person in remaining:
			if str(person.get("loadout_slot", "")) == str(slot.key):
				slot.person = person; remaining.erase(person); break
	for slot in slots:
		if bool(slot.get("player", false)) or not slot.person.is_empty(): continue
		for person in remaining:
			if str(person.get("role_id", "")) == str(slot.role):
				slot.person = person; remaining.erase(person); break
	if bool(spec.get("warship",false)) and not ship.get("commander",{}).is_empty():
		for slot in slots:
			if str(slot.role) == "captain" and slot.person.is_empty():
				var commander: Dictionary = ship.commander
				slot.person = {"name":str(commander.get("name","Командир")),"role_id":"captain","race_id":str(commander.get("race_id",GameState.player_state.get("origin_race_id","humans"))),"portrait_id":int(commander.get("portrait_variant",0)),"legacy_commander":true,"naval_commander":commander}
	# Preserve legacy crews instead of silently discarding an existing employee.
	for person in remaining:
		var placed: bool = false
		for slot in slots:
			if not bool(slot.get("player", false)) and slot.person.is_empty():
				slot.role = str(person.get("role_id", "sailor")); slot.person = person; placed = true; break
		if not placed: slots.append({"key":"legacy_" + str(person.get("employee_instance_id", "")), "role":str(person.get("role_id", "sailor")), "person":person})
	return slots

static func management_status(id: String) -> Dictionary:
	var ship: Dictionary = vessel(id)
	if ship.is_empty(): return {"ok":false,"message":"Корабль не найден."}
	if bool(GameState.combat_state.get("naval_battle", {}).get("active", false)): return {"ok":false,"message":"Оснащение недоступно во время боя."}
	var port: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port == "": return {"ok":false,"message":"Экипаж и орудия меняются после швартовки."}
	if id != "active_ship" and (str(ship.get("current_port_id", "")) != port or not ship.get("autopilot", {}).is_empty()):
		return {"ok":false,"message":"Дождитесь корабля в этом же порту."}
	return {"ok":true,"message":""}

static func statistics(id: String, navy: Node = null) -> Array[Dictionary]:
	var ship: Dictionary = vessel(id)
	if ship.is_empty(): return []
	var spec: Dictionary = definition(ship)
	var rules: Dictionary = GameData.read("res://data/fleet/outfitting_rules.json").get("statistics", {})
	var hull: float = float(spec.get("hull_max", 100))
	if navy != null and bool(spec.get("warship", false)): hull = navy.hull_max(ship)
	var speed: float = float(spec.get("base_speed", 120))
	var fuel: float = float(spec.get("fuel_per_second", 0.5))
	var values: Dictionary = {
		"speed":[speed, speed * maxf(0.25, 1.0 + (crew_bonus(ship,"speed") + boost_bonus(ship,"speed")) / 100.0)],
		"hull":[float(spec.get("hull_max",100)),hull],
		"cargo":[float(spec.get("cargo_capacity",0)),float(ship.get("cargo_capacity",spec.get("cargo_capacity",0)))],
		"fuel":[fuel,fuel * maxf(0.25,1.0-(crew_bonus(ship,"fuel") + boost_bonus(ship,"fuel"))/100.0)],
		"fuel_capacity":[float(spec.get("fuel_capacity",100)),float(spec.get("fuel_capacity",100))],
		"loading":[100.0,100.0 + crew_bonus(ship,"loading")],
		"repair":[100.0,100.0 + crew_bonus(ship,"repair")],
		"navigation":[100.0,100.0 + crew_bonus(ship,"navigation")],
		"maneuverability":[float(spec.get("base_maneuverability",0.85)),float(spec.get("base_maneuverability",0.85))]
	}
	if bool(spec.get("warship", false)) and navy != null:
		var damage: float = 0.0; var range_value: float = 0.0; var reload: float = 0.0; var accuracy: float = 0.0; var count: int = 0
		for gun in ship.get("guns", []):
			if gun.is_empty(): continue
			var stats: Dictionary = navy.gun_combat_stats(ship,gun)
			if stats.is_empty(): continue
			damage += float(stats.damage); range_value = maxf(range_value,float(stats.range)); reload += float(stats.reload); accuracy += float(stats.accuracy)*100.0; count += 1
		values["damage"] = [0.0,damage]; values["range"] = [0.0,range_value]
		values["reload"] = [0.0,reload / maxf(1.0,float(count))]; values["accuracy"] = [0.0,accuracy / maxf(1.0,float(count))]
	var result: Array[Dictionary] = []
	for key in values:
		var row: Dictionary = rules.get(key, {}).duplicate()
		row.merge({"id":key,"base":values[key][0],"value":values[key][1]},true)
		if float(row.value) > float(row.get("maximum",100)): row["maximum"] = ceilf(float(row.value)/10.0)*10.0
		result.append(row)
	return result

func _snapshot() -> Dictionary:
	return {"ship":GameState.ship_state.duplicate(true),"fleet":GameState.fleet_state.duplicate(true),"employees":GameState.employee_state.duplicate(true),"company":GameState.company_state.duplicate(true),"player":GameState.player_state.duplicate(true)}

func _finish(before: Dictionary, message: String) -> Dictionary:
	if not SaveSystem.save_game():
		GameState.ship_state=before.ship; GameState.fleet_state=before.fleet; GameState.employee_state=before.employees; GameState.company_state=before.company; GameState.player_state=before.player
		return {"ok":false,"message":"Не удалось сохранить оснащение. Изменение отменено."}
	return {"ok":true,"message":message}

func candidates(role: String) -> Array:
	var hiring: Node = _tree.get_first_node_in_group("hiring_system")
	return hiring.get_candidates_for_role(role) if hiring != null else []

func _find_slot(id: String, key: String) -> Dictionary:
	for slot in crew_slots(id):
		if str(slot.key) == key: return slot
	return {}

func _reserve(id: String, slot: Dictionary) -> void:
	var ship: Dictionary = vessel(id)
	var person: Dictionary = slot.get("person",{})
	if person.is_empty(): return
	if bool(person.get("legacy_commander",false)):
		person = person.duplicate(true)
		person.erase("legacy_commander")
		person.employee_instance_id = "retained_commander_" + id
		person.employment_type = "permanent"
		GameState.employee_state.append(person)
	if str(slot.role) == "captain" and bool(definition(ship).get("warship",false)):
		person["naval_commander"] = ship.get("commander",{}).duplicate(true)
		ship["commander"] = {}
	ship.get("crew",[]).erase(str(person.get("employee_instance_id","")))
	person["assigned_to"] = "reserve"
	person.erase("loadout_slot")

func _assign(id: String, slot: Dictionary, person: Dictionary) -> void:
	var ship: Dictionary = vessel(id)
	person["assigned_to"] = id
	person["loadout_slot"] = str(slot.key)
	var crew: Array = ship.get("crew",[])
	var employee_id: String = str(person.employee_instance_id)
	if not crew.has(employee_id): crew.append(employee_id)
	ship["crew"] = crew
	if str(slot.role) == "captain" and bool(definition(ship).get("warship",false)):
		ship["commander"] = person.get("naval_commander",{"name":str(person.get("name","Командир")),"race_id":str(person.get("race_id","humans")),"portrait_variant":int(person.get("portrait_id",0)),"level":1,"experience":0,"skill_points":1,"skills":{"gunnery":0,"accuracy":0,"reload":0}}).duplicate(true)

func hire_into_slot(id: String, key: String, candidate_id: String) -> Dictionary:
	var status: Dictionary = management_status(id)
	if not bool(status.ok): return status
	var slot: Dictionary = _find_slot(id,key)
	if slot.is_empty() or bool(slot.get("player",false)): return {"ok":false,"message":"Эта ячейка недоступна для найма."}
	var person: Dictionary = {}
	for candidate in candidates(str(slot.role)):
		if str(candidate.get("candidate_id","")) == candidate_id: person=candidate; break
	if person.is_empty(): return {"ok":false,"message":"Нужен кандидат вашей расы и должности."}
	var before: Dictionary = _snapshot()
	_reserve(id,slot)
	var hiring: Node = _tree.get_first_node_in_group("hiring_system")
	var result: Dictionary = hiring.hire(candidate_id,1,id,false)
	if not bool(result.ok):
		# Restore both the replaced employee and ship if hiring was refused.
		GameState.ship_state=before.ship; GameState.fleet_state=before.fleet; GameState.employee_state=before.employees; GameState.company_state=before.company; GameState.player_state=before.player
		return result
	var hired: Dictionary = GameState.employee_state[-1]
	_assign(id,slot,hired)
	var outcome: Dictionary = _finish(before,"Сотрудник назначен. Заменённый специалист остаётся в резерве компании.")
	if bool(outcome.ok): EventBus.employee_hired.emit(str(hired.employee_instance_id),str(hired.role_id))
	return outcome

func assign_reserve(id: String, key: String, employee_id: String) -> Dictionary:
	var status: Dictionary = management_status(id)
	if not bool(status.ok): return status
	var slot: Dictionary = _find_slot(id,key)
	if slot.is_empty() or bool(slot.get("player",false)): return {"ok":false,"message":"Ячейка недоступна."}
	var person: Dictionary = {}
	for employee in GameState.employee_state:
		if str(employee.get("employee_instance_id","")) == employee_id: person=employee; break
	if person.is_empty() or str(person.get("assigned_to","")) != "reserve" or str(person.get("role_id","")) != str(slot.role) or str(person.get("race_id","")) != str(GameState.player_state.get("origin_race_id","humans")):
		return {"ok":false,"message":"Выберите живого специалиста нужной должности своей расы из резерва."}
	if bool(person.get("dead",false)) or float(person.get("health",1)) <= 0: return {"ok":false,"message":"Назначить можно только живого сотрудника."}
	var before: Dictionary = _snapshot()
	_reserve(id,slot); _assign(id,slot,person)
	return _finish(before,"Сотрудник из резерва назначен бесплатно.")

func remove_crew(id: String, key: String) -> Dictionary:
	var status: Dictionary = management_status(id)
	if not bool(status.ok): return status
	var slot: Dictionary = _find_slot(id,key)
	if slot.is_empty() or bool(slot.get("player",false)) or slot.person.is_empty(): return {"ok":false,"message":"Некого снять с этой должности."}
	var before: Dictionary = _snapshot()
	_reserve(id,slot)
	return _finish(before,"Сотрудник отправлен в резерв компании; повторно покупать его не нужно.")
