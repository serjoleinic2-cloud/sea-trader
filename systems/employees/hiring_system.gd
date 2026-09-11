extends Node

## Generates hire candidates and assigns them to player-controlled ships.

var _roles: Dictionary = {}
var _requirements: Dictionary = {}
var _stat_labels: Dictionary = {}
var _port_system: Node

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/employees/hiring_rules.json")
	_roles = catalog.get("roles", {})
	_stat_labels = catalog.get("stat_labels", {})
	var requirements: Dictionary = SaveSystem._read_json("res://data/ships/crew_requirements.json")
	_requirements = requirements.get("requirements", {})

func get_candidates() -> Array:
	_ensure_candidates()
	return GameState.company_state.get("hire_candidates", [])

func get_stat_labels() -> Dictionary:
	return _stat_labels

func get_active_ship_option() -> Dictionary:
	var crew: Array = GameState.ship_state.get("crew", [])
	var ship_id: String = str(GameState.ship_state.get("ship_id", "default"))
	var limits: Dictionary = _requirements.get(ship_id, _requirements.get("default", {}))
	return {
		"id": "active_ship",
		"name": "Текущий корабль",
		"crew_count": crew.size(),
		"max_crew": int(limits.get("max_crew", 1))
	}

func hire(candidate_id: String, voyages: int) -> Dictionary:
	if voyages < 1:
		return {"ok": false, "message": "Выберите число рейсов."}
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var docked_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if home_port_id == "" or docked_port_id != home_port_id:
		return {"ok": false, "message": "Нанимать персонал можно только в главном порту."}
	var candidates: Array = get_candidates()
	var selected: Dictionary = {}
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if str(candidate.get("candidate_id", "")) == candidate_id:
			selected = candidate
			break
	if selected.is_empty():
		return {"ok": false, "message": "Кандидат уже недоступен."}
	var ship: Dictionary = get_active_ship_option()
	if int(ship.get("crew_count", 0)) >= int(ship.get("max_crew", 1)):
		return {"ok": false, "message": "На текущем корабле нет места для экипажа."}
	var total_salary: float = float(selected.get("salary_per_voyage", 0.0)) * voyages
	if float(GameState.player_state.get("money", 0.0)) < total_salary:
		return {"ok": false, "message": "Недостаточно денег на контракт."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - total_salary
	var employee: Dictionary = selected.duplicate(true)
	employee["employee_instance_id"] = "employee_" + candidate_id
	employee["contract_voyages_total"] = voyages
	employee["contract_voyages_remaining"] = voyages
	employee["assigned_to"] = "active_ship"
	GameState.employee_state.append(employee)
	var crew: Array = GameState.ship_state.get("crew", [])
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
	return {"ok": true, "message": "Контракт оформлен. Сотрудник назначен на текущий корабль."}

func _ensure_candidates() -> void:
	var existing: Variant = GameState.company_state.get("hire_candidates", [])
	if existing is Array and not existing.is_empty():
		return
	var roles_order: Array[String] = ["captain", "sailor", "navigator", "mechanic", "dock_worker"]
	var names: Array[String] = ["Алексей Морозов", "Марина Ветрова", "Илья Кормин", "София Рей", "Виктор Грант", "Анна Ледова", "Павел Штиль", "Елена Ван", "Роман Маяк", "Никита Север"]
	var candidates: Array = []
	for index in range(names.size()):
		var role_id: String = roles_order[index % roles_order.size()]
		var role: Dictionary = _roles.get(role_id, {})
		var rank: int = 1 + (index % 3)
		var stats: Dictionary = {
			"speed": -2 + ((index * 3) % 7),
			"loading": -2 + ((index * 5) % 7),
			"fuel": -2 + ((index * 2) % 7),
			"repair": -2 + ((index * 4) % 7),
			"navigation": -2 + ((index * 6) % 7)
		}
		if role_id == "captain" and rank == 1:
			stats["speed"] = 3
			stats["loading"] = -2
		candidates.append({
			"candidate_id": "candidate_%02d" % index,
			"name": names[index],
			"role_id": role_id,
			"role_name": str(role.get("name", role_id)),
			"rank": rank,
			"portrait_id": index % 6,
			"stats": stats,
			"salary_per_voyage": float(role.get("base_salary_per_voyage", 10.0)) * (1.0 + (rank - 1) * 0.35)
		})
	GameState.company_state["hire_candidates"] = candidates
	SaveSystem.save_game()
