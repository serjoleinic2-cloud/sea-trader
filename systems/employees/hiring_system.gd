extends Node

## Generates contract and permanent crew, owns their voyage progression.

var _roles: Dictionary = {}
var _requirements: Dictionary = {}
var _stat_labels: Dictionary = {}
var _employment_types: Dictionary = {}
var _skills: Dictionary = {}
var _progression: Dictionary = {}

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

func get_candidates() -> Array:
	_ensure_candidates()
	return GameState.company_state.get("hire_candidates", [])

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
	return {
		"id": "active_ship",
		"name": "Текущий корабль",
		"crew_count": crew.size(),
		"max_crew": int(limits.get("max_crew", 1))
	}

func hire(candidate_id: String, voyages: int) -> Dictionary:
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
	var employment_type: String = str(selected.get("employment_type", "contract"))
	if employment_type == "contract" and voyages < 1:
		return {"ok": false, "message": "Выберите число рейсов."}
	if int(selected.get("rank", 1)) > get_hiring_rank_limit():
		return {"ok": false, "message": "Ваш допуск пока не позволяет нанять сотрудника такого ранга."}
	var ship: Dictionary = get_active_ship_option()
	if int(ship.get("crew_count", 0)) >= int(ship.get("max_crew", 1)):
		return {"ok": false, "message": "На текущем корабле нет места для экипажа."}
	var total_price: float = float(selected.get("hire_price", 0.0)) if employment_type == "permanent" else float(selected.get("salary_per_voyage", 0.0)) * voyages
	if float(GameState.player_state.get("money", 0.0)) < total_price:
		return {"ok": false, "message": "Недостаточно денег для найма."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - total_price
	var employee: Dictionary = selected.duplicate(true)
	employee["employee_instance_id"] = "employee_" + candidate_id
	employee["assigned_to"] = "active_ship"
	employee["base_stats"] = employee.get("stats", {}).duplicate(true)
	employee["skill_stats"] = {}
	employee["skills"] = []
	employee["active_skill_id"] = ""
	employee["experience"] = 0
	if employment_type == "permanent":
		employee["contract_voyages_total"] = 0
		employee["contract_voyages_remaining"] = -1
	else:
		employee["mastery_percent"] = 0
		employee["contract_voyages_total"] = voyages
		employee["contract_voyages_remaining"] = voyages
	GameState.employee_state.append(employee)
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	var crew: Array = raw_crew if raw_crew is Array else []
	crew.append(str(employee.get("employee_instance_id", "")))
	GameState.ship_state["crew"] = crew
	var remaining_candidates: Array = []
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if str(candidate.get("candidate_id", "")) != candidate_id:
			remaining_candidates.append(candidate)
	GameState.company_state["hire_candidates"] = remaining_candidates
	EventBus.employee_hired.emit(str(employee.get("employee_instance_id", "")), str(employee.get("role_id", "")))
	SaveSystem.save_game()
	var message: String = "Постоянный сотрудник принят в компанию." if employment_type == "permanent" else "Контракт оформлен на %d рейс." % voyages
	return {"ok": true, "message": message + " Сотрудник назначен на текущий корабль."}

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
		return
	var active_skill_id: String = str(employee.get("active_skill_id", ""))
	if active_skill_id == "":
		return
	var learned: Array = employee.get("skills", [])
	for entry in learned:
		if str(entry.get("id", "")) == active_skill_id:
			entry["progress"] = mini(100, int(entry.get("progress", 0)) + int(_progression.get("skill_progress_per_voyage", 5)))
			if int(entry.get("progress", 0)) >= 100:
				employee["active_skill_id"] = ""
			break
	employee["skills"] = learned
	_rebuild_skill_stats(employee)

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
	var roles_order: Array[String] = ["captain", "sailor", "navigator", "mechanic", "bosun", "quartermaster", "dock_worker"]
	var names: Array[String] = ["Алексей Морозов", "Марина Ветрова", "Илья Кормин", "София Рей", "Виктор Грант", "Анна Ледова", "Павел Штиль", "Елена Ван", "Роман Маяк", "Никита Север"]
	var candidates: Array = []
	for index in range(names.size()):
		var serial: int = index + refresh_index * 7
		var role_id: String = roles_order[serial % roles_order.size()]
		var role: Dictionary = _roles.get(role_id, {})
		var rank: int = 1 + (serial % maxi(3, get_hiring_rank_limit()))
		var employment_type: String = "permanent" if serial % 3 == 0 else "contract"
		var stats: Dictionary = {
			"speed": -3 + ((serial * 3) % 9),
			"loading": -3 + ((serial * 5) % 9),
			"fuel": -3 + ((serial * 2) % 9),
			"repair": -3 + ((serial * 4) % 9),
			"navigation": -3 + ((serial * 6) % 9)
		}
		if role_id == "captain" and rank == 1:
			stats["speed"] = 3
			stats["loading"] = -2
		var salary: float = float(role.get("base_salary_per_voyage", 10.0)) * (1.0 + (rank - 1) * 0.35)
		candidates.append({
			"candidate_id": "candidate_%02d_%02d" % [refresh_index, index],
			"name": names[index],
			"role_id": role_id,
			"role_name": str(role.get("name", role_id)),
			"rank": rank,
			"portrait_id": index % 6,
			"stats": stats,
			"employment_type": employment_type,
			"employment_name": str(_employment_types.get(employment_type, {}).get("name", employment_type)),
			"mastery_percent": 45 + (serial * 7) % 31 if employment_type == "permanent" else 0,
			"salary_per_voyage": salary,
			"hire_price": round(salary * float(role.get("permanent_price_multiplier", 12.0)))
		})
	GameState.company_state["hire_candidates"] = candidates
	SaveSystem.save_game()
