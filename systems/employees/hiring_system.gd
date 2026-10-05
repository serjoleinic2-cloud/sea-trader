extends Node

## Generates contract and permanent crew, owns their voyage progression.

var _roles: Dictionary = {}
var _requirements: Dictionary = {}
var _stat_labels: Dictionary = {}
var _employment_types: Dictionary = {}
var _skills: Dictionary = {}
var _progression: Dictionary = {}
var _travel_action_distance: float = 0.0
var _last_action_position: Vector2 = Vector2.ZERO
var _has_action_position: bool = false

func _ready() -> void:
	add_to_group("hiring_system")

func initialize(_unused_port_system: Node = null) -> void:
	var catalog: Dictionary = GameData.read("res://data/employees/hiring_rules.json")
	_roles = catalog.get("roles", {})
	_stat_labels = catalog.get("stat_labels", {})
	_employment_types = catalog.get("employment_types", {})
	_skills = catalog.get("skills", {})
	_progression = catalog.get("progression", {})
	_requirements = GameData.get_crew_requirements()
	for employee in GameState.employee_state:
		if str(employee.get("employment_type", "contract")) == "contract":
			employee["employment_type"] = "permanent"
			employee["employment_name"] = str(_employment_types.get("permanent", {}).get("name", "Постоянный"))
			employee["contract_voyages_total"] = 0
			employee["contract_voyages_remaining"] = -1
	for signal_name in ["ship_moved", "cargo_loaded", "cargo_delivered", "ship_repaired", "port_discovered"]:
		var callback: Callable = Callable(self, "_on_" + signal_name)
		if EventBus.has_signal(signal_name) and not EventBus.is_connected(signal_name, callback):
			EventBus.connect(signal_name, callback)

func get_candidates() -> Array:
	_ensure_candidates()
	var candidates: Array = GameState.company_state.get("hire_candidates", [])
	for candidate in candidates:
		candidate["employment_type"] = "permanent"
		candidate["employment_name"] = str(_employment_types.get("permanent", {}).get("name", "Постоянный"))
	GameState.company_state["hire_candidates"] = candidates
	return candidates

func get_stat_labels() -> Dictionary:
	return _stat_labels.duplicate(true)

func get_skill_catalog() -> Dictionary:
	return _skills.duplicate(true)

func get_employment_types() -> Dictionary:
	return _employment_types.duplicate(true)

func get_maximum_skill_slots(employee: Dictionary) -> int:
	return mini(int(_progression.get("maximum_skill_slots", 3)), 1 + int(int(employee.get("rank", 1)) / 2.0))

func get_hiring_rank_limit() -> int:
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	if systems.is_empty():
		return 1
	return systems[0].get_hiring_rank_limit()

func refresh_candidates() -> Dictionary:
	var refresh_index: int = int(GameState.company_state.get("hire_refresh_index", 0)) + 1
	GameState.company_state["hire_refresh_index"] = refresh_index
	GameState.company_state["hire_candidates"] = []
	_ensure_candidates()
	SaveSystem.save_game()
	return {"ok": true, "message": "Биржа труда обновлена. Пришли новые кандидаты."}

func get_active_ship_option() -> Dictionary:
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	var crew: Array = raw_crew if raw_crew is Array else []
	var ship_id: String = str(GameState.ship_state.get("ship_id", "default"))
	var limits: Dictionary = _requirements.get(ship_id, _requirements.get("default", {}))
	var definition: Dictionary = GameData.get_ship(ship_id)
	return {
		"id": "active_ship",
		"name": str(definition.get("name", "Текущий корабль")),
		"crew_count": crew.size(),
		"min_crew": maxi(0, int(limits.get("min_crew", 1)) - 1), # The player occupies the command position.
		"max_crew": int(limits.get("max_crew", 1)),
		"current_port_id": str(GameState.ship_state.get("docked_port_id", "")),
		"autopilot": {}
	}

func get_ship_options() -> Array:
	var result: Array = [get_active_ship_option()]
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		var definition: Dictionary = GameData.get_ship(str(ship.get("ship_type_id", "")))
		var raw_crew: Variant = ship.get("crew", [])
		var crew_count: int = raw_crew.size() if raw_crew is Array else 0
		result.append({
			"id": str(ship.get("instance_id", "")),
			"name": str(ship.get("name", definition.get("name", "Корабль"))),
			"crew_count": crew_count,
			"min_crew": int(definition.get("min_crew", 1)),
			"max_crew": int(definition.get("max_crew", 1)),
			"current_port_id": str(ship.get("current_port_id", "")),
			"autopilot": ship.get("autopilot", {})
		})
	return result

func hire(candidate_id: String, voyages: int, target_ship_id: String = "active_ship") -> Dictionary:
	if str(GameState.ship_state.get("docked_port_id", "")) == "":
		return {"ok": false, "message": "Найм доступен в любом порту после швартовки."}
	var candidates: Array = get_candidates()
	var selected: Dictionary = {}
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if str(candidate.get("candidate_id", "")) == candidate_id:
			selected = candidate
			break
	if selected.is_empty():
		return {"ok": false, "message": "Кандидат уже недоступен."}
	# Crew hired from the labor exchange are company employees. Legacy saved
	# candidates may still say "contract", but newly hired crew are permanent.
	var employment_type: String = "permanent"
	if int(selected.get("rank", 1)) > get_hiring_rank_limit():
		return {"ok": false, "message": "Ваш допуск пока не позволяет нанять сотрудника такого ранга."}
	var ship: Dictionary = {}
	for option in get_ship_options():
		if str(option.get("id", "")) == target_ship_id:
			ship = option
			break
	if ship.is_empty():
		return {"ok": false, "message": "Выбранный корабль не найден."}
	if target_ship_id != "active_ship":
		if not Dictionary(ship.get("autopilot", {})).is_empty():
			return {"ok": false, "message": "Нанять экипаж можно, когда корабль стоит в порту."}
		if str(ship.get("current_port_id", "")) != str(GameState.ship_state.get("docked_port_id", "")):
			return {"ok": false, "message": "Корабль должен стоять в этом же порту, чтобы принять экипаж."}
	if int(ship.get("crew_count", 0)) >= int(ship.get("max_crew", 1)):
		return {"ok": false, "message": "На текущем корабле нет места для экипажа."}
	var total_price: float = float(selected.get("hire_price", 0.0))
	if float(GameState.player_state.get("money", 0.0)) < total_price:
		return {"ok": false, "message": "Недостаточно денег для найма."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - total_price
	var employee: Dictionary = selected.duplicate(true)
	employee["employee_instance_id"] = "employee_" + candidate_id
	employee["assigned_to"] = target_ship_id
	employee["base_stats"] = employee.get("stats", {}).duplicate(true)
	employee["skill_stats"] = {}
	employee["skills"] = []
	employee["active_skill_id"] = ""
	employee["experience"] = 0
	employee["employment_type"] = "permanent"
	employee["employment_name"] = str(_employment_types.get("permanent", {}).get("name", "Постоянный"))
	employee["contract_voyages_total"] = 0
	employee["contract_voyages_remaining"] = -1
	employee["mastery_percent"] = int(employee.get("mastery_percent", 0))
	GameState.employee_state.append(employee)
	var raw_crew: Variant = GameState.ship_state.get("crew", []) if target_ship_id == "active_ship" else []
	if target_ship_id != "active_ship":
		for index in range(GameState.fleet_state.size()):
			var vessel: Dictionary = GameState.fleet_state[index]
			if str(vessel.get("instance_id", "")) == target_ship_id:
				raw_crew = vessel.get("crew", [])
				break
	var crew: Array = raw_crew if raw_crew is Array else []
	crew.append(str(employee.get("employee_instance_id", "")))
	if target_ship_id == "active_ship":
		GameState.ship_state["crew"] = crew
	else:
		for index in range(GameState.fleet_state.size()):
			var vessel: Dictionary = GameState.fleet_state[index]
			if str(vessel.get("instance_id", "")) == target_ship_id:
				vessel["crew"] = crew
				GameState.fleet_state[index] = vessel
				break
	var remaining_candidates: Array = []
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if str(candidate.get("candidate_id", "")) != candidate_id:
			remaining_candidates.append(candidate)
	GameState.company_state["hire_candidates"] = remaining_candidates
	EventBus.employee_hired.emit(str(employee.get("employee_instance_id", "")), str(employee.get("role_id", "")))
	SaveSystem.save_game()
	var message: String = "Постоянный сотрудник принят в компанию." if employment_type == "permanent" else "Контракт оформлен на %d рейс." % voyages
	return {"ok": true, "message": message + " Сотрудник назначен на «%s»." % str(ship.get("name", "корабль"))}

func dismiss(employee_id: String) -> Dictionary:
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	var crew_ids: Array = raw_crew if raw_crew is Array else []
	if not crew_ids.has(employee_id):
		return {"ok": false, "message": "Сотрудник не назначен на этот корабль."}
	var retained_employees: Array = []
	var found: bool = false
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		if str(employee.get("employee_instance_id", "")) == employee_id:
			found = true
			continue
		retained_employees.append(employee)
	if not found:
		return {"ok": false, "message": "Сотрудник не найден."}
	crew_ids.erase(employee_id)
	GameState.employee_state = retained_employees
	GameState.ship_state["crew"] = crew_ids
	EventBus.employee_fired.emit(employee_id)
	SaveSystem.save_game()
	return {"ok": true, "message": "Сотрудник уволен, место освобождено."}

func choose_skill(employee_id: String, skill_id: String) -> Dictionary:
	if not _skills.has(skill_id):
		return {"ok": false, "message": "Неизвестный навык."}
	for index in range(GameState.employee_state.size()):
		var employee: Dictionary = GameState.employee_state[index]
		if str(employee.get("employee_instance_id", "")) != employee_id:
			continue
		if _employment_type(employee) != "permanent":
			return {"ok": false, "message": "Контрактный персонал не получает постоянные навыки."}
		if int(employee.get("mastery_percent", 0)) < 100:
			return {"ok": false, "message": "Сначала доведите владение профессией до 100%."}
		if str(employee.get("active_skill_id", "")) != "":
			return {"ok": false, "message": "Сначала завершите изучение выбранного навыка."}
		var learned: Array = employee.get("skills", [])
		var maximum_slots: int = get_maximum_skill_slots(employee)
		if learned.size() >= maximum_slots:
			return {"ok": false, "message": "Все доступные ячейки навыков заняты."}
		for entry in learned:
			if str(entry.get("id", "")) == skill_id:
				return {"ok": false, "message": "Этот навык уже изучается или изучен."}
		learned.append({"id": skill_id, "progress": 0})
		employee["skills"] = learned
		employee["active_skill_id"] = skill_id
		GameState.employee_state[index] = employee
		SaveSystem.save_game()
		return {"ok": true, "message": "Выбран навык «%s». Он развивается в рейсах." % str(_skills[skill_id].get("name", skill_id))}
	return {"ok": false, "message": "Сотрудник не найден."}

func complete_voyage(crew_ids: Array) -> Array:
	var retained_employees: Array = []
	var retained_crew_ids: Array = []
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		var employee_id: String = str(employee.get("employee_instance_id", ""))
		if not crew_ids.has(employee_id):
			retained_employees.append(employee)
			continue
		if _employment_type(employee) == "permanent":
			_progress_permanent_employee(employee)
			retained_employees.append(employee)
			retained_crew_ids.append(employee_id)
			continue
		var remaining: int = int(employee.get("contract_voyages_remaining", 0)) - 1
		if remaining > 0:
			employee["contract_voyages_remaining"] = remaining
			retained_employees.append(employee)
			retained_crew_ids.append(employee_id)
	GameState.employee_state = retained_employees
	return retained_crew_ids

func get_effective_stats(employee: Dictionary) -> Dictionary:
	var result: Dictionary = employee.get("stats", {}).duplicate(true)
	var skill_stats: Dictionary = employee.get("skill_stats", {})
	for stat_id in skill_stats:
		result[stat_id] = int(result.get(stat_id, 0)) + int(skill_stats.get(stat_id, 0))
	return result

func _progress_permanent_employee(employee: Dictionary) -> void:
	employee["experience"] = int(employee.get("experience", 0)) + 1
	if int(employee.get("mastery_percent", 0)) < 100:
		employee["mastery_percent"] = mini(100, int(employee.get("mastery_percent", 0)) + int(_progression.get("mastery_per_voyage", 4)))

func _on_ship_moved(position: Vector2, _velocity: Vector2) -> void:
	if not _has_action_position:
		_last_action_position = position
		_has_action_position = true
		return
	_travel_action_distance += _last_action_position.distance_to(position)
	_last_action_position = position
	while _travel_action_distance >= 100.0:
		_travel_action_distance -= 100.0
		_award_action_progress("speed", 1)
		_award_action_progress("fuel", 1)
		_award_action_progress("navigation", 1)

func _on_cargo_loaded(_resource_id: String, quantity: int) -> void:
	_award_action_progress("loading", clampi(int(ceil(sqrt(float(maxi(1, quantity))))), 1, 4))

func _on_cargo_delivered(_resource_id: String, quantity: int) -> void:
	_award_action_progress("loading", clampi(int(ceil(sqrt(float(maxi(1, quantity))))), 1, 4))

func _on_ship_repaired(_component: String, _amount: float) -> void:
	_award_action_progress("repair", 1)

func _on_port_discovered(_port_id: String) -> void:
	_award_action_progress("navigation", 2)

func _award_action_progress(stat_id: String, points: int) -> void:
	var crew: Array = GameState.ship_state.get("crew", [])
	for index in range(GameState.employee_state.size()):
		var employee: Dictionary = GameState.employee_state[index]
		if not crew.has(str(employee.get("employee_instance_id", ""))) or _employment_type(employee) != "permanent":
			continue
		var action_points: Dictionary = employee.get("action_points", {})
		action_points[stat_id] = int(action_points.get(stat_id, 0)) + points
		employee["action_points"] = action_points
		GameState.employee_state[index] = employee
		var skill_id: String = str(employee.get("active_skill_id", ""))
		if skill_id == "":
			continue
		var skill: Dictionary = _skills.get(skill_id, {})
		if str(skill.get("stat", "")) != stat_id:
			continue
		var learned: Array = employee.get("skills", [])
		for entry in learned:
			if str(entry.get("id", "")) != skill_id:
				continue
			entry["progress"] = mini(100, int(entry.get("progress", 0)) + points)
			if int(entry.get("progress", 0)) >= 100:
				employee["active_skill_id"] = ""
			break
		employee["skills"] = learned
		_rebuild_skill_stats(employee)

func record_crew_voyage_actions(crew_ids: Array, action_stats: Array[String]) -> void:
	for stat_id in action_stats:
		_award_action_progress_for_ids(stat_id, 1, crew_ids)

func _award_action_progress_for_ids(stat_id: String, points: int, crew_ids: Array) -> void:
	var current: Array = GameState.ship_state.get("crew", [])
	var original: Variant = GameState.ship_state.get("crew", [])
	GameState.ship_state["crew"] = crew_ids
	_award_action_progress(stat_id, points)
	GameState.ship_state["crew"] = current if original is Array else []

func _rebuild_skill_stats(employee: Dictionary) -> void:
	var bonuses: Dictionary = {}
	for entry in employee.get("skills", []):
		var definition: Dictionary = _skills.get(str(entry.get("id", "")), {})
		if definition.is_empty():
			continue
		var stat_id: String = str(definition.get("stat", ""))
		var effective: int = int(floor(float(definition.get("max_bonus", 0)) * float(entry.get("progress", 0)) / 100.0))
		bonuses[stat_id] = int(bonuses.get(stat_id, 0)) + effective
	employee["skill_stats"] = bonuses

func _employment_type(employee: Dictionary) -> String:
	return str(employee.get("employment_type", "contract"))

func _ensure_candidates() -> void:
	var existing: Variant = GameState.company_state.get("hire_candidates", [])
	if existing is Array and not existing.is_empty():
		return
	var refresh_index: int = int(GameState.company_state.get("hire_refresh_index", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:hire_market" % [str(GameState.world_state.get("seed", 0)), refresh_index])
	var roles_order: Array[String] = ["captain", "captain", "sailor", "navigator", "mechanic", "bosun", "quartermaster", "dock_worker", "navigator", "mechanic"]
	for role_index in range(roles_order.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, role_index)
		var swap := roles_order[role_index]
		roles_order[role_index] = roles_order[swap_index]
		roles_order[swap_index] = swap
	var names: Array[String] = ["Алексей Морозов", "Марина Ветрова", "Илья Кормин", "София Рей", "Виктор Грант", "Анна Ледова", "Павел Штиль", "Елена Ван", "Роман Маяк", "Никита Север"]
	var factions: Array = GameData.get_factions()
	var faction_order: Array = []
	for faction in factions:
		faction_order.append(faction)
	for race_index in range(faction_order.size() - 1, 0, -1):
		var race_swap_index := rng.randi_range(0, race_index)
		var race_swap: Variant = faction_order[race_index]
		faction_order[race_index] = faction_order[race_swap_index]
		faction_order[race_swap_index] = race_swap
	var names_by_race: Dictionary = {
		"nerids": ["Лиара Вей", "Наэр Таласс", "Сейрин Мора"], "surr": ["Караш Вулкан", "Рук Тарн", "Вера Кальд"],
		"meridians": ["Элиан Восс", "Савен Рей", "Мира Келл"], "aery": ["Ириэль Тар", "Фенна Крыл", "Орэн Вейл"],
		"crystari": ["Тарен Гранит", "Шаара Кварц", "Рем Крист"], "humans": ["Алексей Морозов", "Марина Ветрова", "Илья Кормин"]
	}
	var stat_ids: Array[String] = ["speed", "loading", "fuel", "repair", "navigation"]
	var bonus_names: Dictionary = {"speed": "Лёгкий ход", "loading": "Слаженная команда", "fuel": "Экономичный двигатель", "repair": "Руки мастера", "navigation": "Память берегов"}
	var flaw_names: Dictionary = {"speed": "Нетерпеливый ход", "loading": "Медлительная команда", "fuel": "Прожорливый двигатель", "repair": "Неаккуратный мастер", "navigation": "Слабое чутьё на отмели"}
	var candidates: Array = []
	var portrait_variants: Dictionary = {}
	for index in range(names.size()):
		var serial: int = index + refresh_index * 7
		var role_id: String = roles_order[index % roles_order.size()]
		var role: Dictionary = _roles.get(role_id, {})
		var rank: int = rng.randi_range(1, maxi(1, get_hiring_rank_limit()))
		var employment_type: String = "permanent"
		var stats: Dictionary = {
			"speed": rng.randi_range(-3, 3),
			"loading": rng.randi_range(-3, 3),
			"fuel": rng.randi_range(-3, 3),
			"repair": rng.randi_range(-3, 3),
			"navigation": rng.randi_range(-3, 3)
		}
		var bonus_stat: String = stat_ids[rng.randi_range(0, stat_ids.size() - 1)]
		var flaw_options: Array[String] = []
		for stat_id in stat_ids:
			if stat_id != bonus_stat:
				flaw_options.append(stat_id)
		var flaw_stat: String = flaw_options[rng.randi_range(0, flaw_options.size() - 1)]
		stats[bonus_stat] = int(stats[bonus_stat]) + rng.randi_range(4, 9)
		stats[flaw_stat] = int(stats[flaw_stat]) - rng.randi_range(3, 7)
		var salary: float = float(role.get("base_salary_per_voyage", 10.0)) * (1.0 + (rank - 1) * 0.35)
		var race: Dictionary = faction_order[index % faction_order.size()] if not faction_order.is_empty() else {"id": "humans", "name": "Люди"}
		var race_names: Array = names_by_race.get(str(race.get("id", "humans")), names)
		var candidate_name: String = str(race_names[rng.randi_range(0, race_names.size() - 1)])
		var race_id: String = str(race.get("id", "humans"))
		var portrait_id: int = posmod(int(portrait_variants.get(race_id, 0)) + refresh_index, 3)
		portrait_variants[race_id] = int(portrait_variants.get(race_id, 0)) + 1
		candidates.append({
			"candidate_id": "candidate_%02d_%02d" % [refresh_index, index],
			"name": candidate_name,
			"role_id": role_id,
			"role_name": str(role.get("name", role_id)),
			"rank": rank,
			"portrait_id": portrait_id,
			"race_id": race_id,
			"race_name": str(race.get("name", "Люди")),
			"stats": stats,
			"strength_trait": str(bonus_names[bonus_stat]),
			"strength_stat": bonus_stat,
			"flaw_trait": str(flaw_names[flaw_stat]),
			"flaw_stat": flaw_stat,
			"employment_type": employment_type,
			"employment_name": str(_employment_types.get(employment_type, {}).get("name", employment_type)),
			"mastery_percent": 45 + (serial * 7) % 31 if employment_type == "permanent" else 0,
			"salary_per_voyage": salary,
			"hire_price": round(salary * float(role.get("permanent_price_multiplier", 12.0)))
		})
	GameState.company_state["hire_candidates"] = candidates
	SaveSystem.save_game()
