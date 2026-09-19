extends Node

## Parallel, material-funded construction projects for home-port buildings.

var _catalog: Dictionary = {}
var _rules: Dictionary = {}
var _goods: Dictionary = {}

func _ready() -> void:
	add_to_group("building_project_system")

func initialize() -> void:
	_rules = GameData.read("res://data/ports/building_rules.json")
	var source: Dictionary = GameData.read("res://data/ports/building_catalog.json")
	for raw_building in source.get("buildings", []):
		var building: Dictionary = raw_building
		_catalog[str(building.get("building_id", ""))] = building
	var goods_catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
	for raw_good in goods_catalog.get("resources", []):
		var good: Dictionary = raw_good
		_goods[str(good.get("id", ""))] = str(good.get("display_name", ""))
	_migrate_legacy_project()

func _process(_delta: float) -> void:
	_complete_finished_projects()

func _migrate_legacy_project() -> void:
	var raw_projects: Variant = GameState.company_state.get("building_projects", [])
	if raw_projects is Array:
		return
	var legacy: Variant = GameState.company_state.get("building_project", {})
	var legacy_project: Dictionary = legacy if legacy is Dictionary else {}
	var projects: Array = []
	if not legacy_project.is_empty():
		projects.append(legacy_project)
	GameState.company_state["building_projects"] = projects
	GameState.company_state.erase("building_project")

func get_projects() -> Array:
	var raw_projects: Variant = GameState.company_state.get("building_projects", [])
	if raw_projects is Array:
		return raw_projects
	return []

func get_project(building_id: String = "") -> Dictionary:
	var projects: Array = get_projects()
	for raw_project in projects:
		var project: Dictionary = raw_project
		if building_id == "" or str(project.get("building_id", "")) == building_id:
			return project
	return {}

func get_building_name(building_id: String) -> String:
	var building: Dictionary = _catalog.get(building_id, {})
	return str(building.get("display_name", building_id))

func get_goods_name(resource_id: String) -> String:
	return str(_goods.get(resource_id, resource_id))

func get_building_level(building_id: String) -> int:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var buildings: Dictionary = port.get("buildings", {})
	var building: Dictionary = buildings.get(building_id, {})
	return int(building.get("level", 0))

func create_project(building_id: String) -> Dictionary:
	if not _is_at_home():
		return {"ok": false, "message": "Строительство доступно только на вашей базе."}
	if not _catalog.has(building_id):
		return {"ok": false, "message": "Неизвестное здание."}
	var existing: Dictionary = get_project(building_id)
	if not existing.is_empty():
		return {"ok": true, "message": "Проект этого здания уже подготовлен."}
	var current_level: int = get_building_level(building_id)
	var maximum: int = int(_catalog[building_id].get("max_level", 30))
	if current_level >= maximum:
		return {"ok": false, "message": "Здание уже достигло %d уровня." % maximum}
	var next_level: int = current_level + 1
	var projects: Array = get_projects()
	projects.append({
		"building_id": building_id,
		"target_level": next_level,
		"materials": {},
		"required_materials": _make_requirements(building_id, next_level),
		"required_rank": _get_required_rank(next_level),
		"required_ports": _get_required_ports(next_level),
		"started_at_unix": 0,
		"duration_sec": _get_build_duration(next_level)
	})
	_set_projects(projects)
	SaveSystem.save_game()
	return {"ok": true, "message": "Проект уровня %d подготовлен. Передайте материалы и запустите стройку." % next_level}

func set_material_amount(building_id: String, resource_id: String, amount: int) -> Dictionary:
	if not _is_at_home():
		return {"ok": false, "message": "Материалы можно передавать только на базе."}
	var project: Dictionary = get_project(building_id)
	if project.is_empty():
		return {"ok": false, "message": "Нет такого проекта."}
	if is_project_started(project):
		return {"ok": false, "message": "Стройка уже запущена: материалы закреплены."}
	var required: Dictionary = project.get("required_materials", {})
	if not required.has(resource_id):
		return {"ok": false, "message": "Материал не нужен этому проекту."}
	var reserved: Dictionary = project.get("materials", {})
	var current: int = int(reserved.get(resource_id, 0))
	var target: int = clampi(amount, 0, int(required.get(resource_id, 0)))
	var delta: int = target - current
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var inventory: Dictionary = port.get("inventory", {})
	if delta > int(inventory.get(resource_id, 0)):
		return {"ok": false, "message": "На складе недостаточно материала."}
	inventory[resource_id] = int(inventory.get(resource_id, 0)) - delta
	reserved[resource_id] = target
	project["materials"] = reserved
	_replace_project(project)
	port["inventory"] = inventory
	GameState.port_state[home_port_id] = port
	SaveSystem.save_game()
	return {"ok": true, "message": ""}

func start_project(building_id: String) -> Dictionary:
	if not _is_at_home():
		return {"ok": false, "message": "Запуск строительства возможен только на вашей базе."}
	var project: Dictionary = get_project(building_id)
	if project.is_empty():
		return {"ok": false, "message": "Нет такого проекта."}
	if is_project_started(project):
		return {"ok": false, "message": "Строительство уже идёт."}
	if not is_project_ready(project):
		return {"ok": false, "message": "Передайте все материалы в полном объёме."}
	if _get_command_rank() < int(project.get("required_rank", 1)):
		return {"ok": false, "message": "Недостаточный допуск капитана."}
	if GameState.player_state.discovered_port_ids.size() < int(project.get("required_ports", 1)):
		return {"ok": false, "message": "Нужно открыть больше портов для такой стройки."}
	project["started_at_unix"] = _get_now_unix()
	_replace_project(project)
	SaveSystem.save_game()
	return {"ok": true, "message": "Строительство запущено. Оно продолжится и вне игры."}

func cancel_project(building_id: String) -> Dictionary:
	var project: Dictionary = get_project(building_id)
	if project.is_empty():
		return {"ok": false, "message": "Нет проекта для отмены."}
	if is_project_started(project):
		return {"ok": false, "message": "Стройка уже запущена, материалы закреплены до завершения."}
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var inventory: Dictionary = port.get("inventory", {})
	var reserved: Dictionary = project.get("materials", {})
	for resource_id in reserved:
		inventory[resource_id] = int(inventory.get(resource_id, 0)) + int(reserved.get(resource_id, 0))
	port["inventory"] = inventory
	GameState.port_state[home_port_id] = port
	_remove_project(building_id)
	SaveSystem.save_game()
	return {"ok": true, "message": "Проект отменён, материалы возвращены на склад."}

func is_project_ready(project: Dictionary) -> bool:
	var required: Dictionary = project.get("required_materials", {})
	var reserved: Dictionary = project.get("materials", {})
	if required.is_empty():
		return false
	for resource_id in required:
		if int(reserved.get(resource_id, 0)) < int(required.get(resource_id, 0)):
			return false
	return true

func is_project_started(project: Dictionary) -> bool:
	return int(project.get("started_at_unix", 0)) > 0

func get_project_time_left(project: Dictionary) -> int:
	if not is_project_started(project):
		return int(project.get("duration_sec", 0))
	var passed: int = maxi(0, _get_now_unix() - int(project.get("started_at_unix", 0)))
	return maxi(0, int(project.get("duration_sec", 0)) - passed)

func get_project_status(project: Dictionary) -> String:
	if is_project_started(project):
		return "Строительство идёт: осталось %s." % _format_time(get_project_time_left(project))
	if is_project_ready(project):
		return "Материалы собраны. Можно запустить стройку: %s." % _format_time(int(project.get("duration_sec", 0)))
	return "Соберите материалы, затем запустите стройку (%s)." % _format_time(int(project.get("duration_sec", 0)))

func get_effect_text(building_id: String, level: int) -> String:
	match building_id:
		"fishing_wharf":
			return "Рыба: %d ед. каждые 10 сек." % level
		"timber_yard":
			return "Древесина: %d ед. каждые 10 сек." % level
		"warehouse":
			return "Будущий лимит склада: %d ед." % (100 + level * 100)
		"dock":
			return "Причал: подготовка к %d местам для кораблей." % (1 + int(level / 5))
		"workshop":
			return "Мастерская: откроет ремонт и улучшения, уровень %d." % level
		"shipyard":
			return "Верфь: строительство кораблей, уровень %d." % level
		"market":
			return "Рынок: будущая скидка и контракты, уровень %d." % level
	return "Уровень здания: %d." % level

func _complete_finished_projects() -> void:
	var projects: Array = get_projects()
	if projects.is_empty():
		return
	var remaining: Array = []
	var changed: bool = false
	for raw_project in projects:
		var project: Dictionary = raw_project
		if is_project_started(project) and get_project_time_left(project) <= 0:
			_finalize_project(project)
			changed = true
		else:
			remaining.append(project)
	if changed:
		_set_projects(remaining)
		SaveSystem.save_game()

func _finalize_project(project: Dictionary) -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var buildings: Dictionary = port.get("buildings", {})
	var building_id: String = str(project.get("building_id", ""))
	buildings[building_id] = {"level": int(project.get("target_level", 1)), "status": "active"}
	port["buildings"] = buildings
	GameState.port_state[home_port_id] = port
	EventBus.building_activated.emit(home_port_id, building_id)

func _replace_project(updated_project: Dictionary) -> void:
	var building_id: String = str(updated_project.get("building_id", ""))
	var projects: Array = get_projects()
	for index in range(projects.size()):
		var project: Dictionary = projects[index]
		if str(project.get("building_id", "")) == building_id:
			projects[index] = updated_project
			break
	_set_projects(projects)

func _remove_project(building_id: String) -> void:
	var projects: Array = get_projects()
	var remaining: Array = []
	for raw_project in projects:
		var project: Dictionary = raw_project
		if str(project.get("building_id", "")) != building_id:
			remaining.append(project)
	_set_projects(remaining)

func _set_projects(projects: Array) -> void:
	GameState.company_state["building_projects"] = projects

func _get_build_duration(level: int) -> int:
	return int(_rules.get("duration_base_seconds", 20)) + level * int(_rules.get("duration_per_level_seconds", 20))

func _format_time(seconds: int) -> String:
	var minutes: int = int(seconds / 60)
	var rest_seconds: int = seconds % 60
	if minutes <= 0:
		return "%d сек." % rest_seconds
	return "%d мин. %02d сек." % [minutes, rest_seconds]

func _get_now_unix() -> int:
	return int(Time.get_unix_time_from_system())

func _make_requirements(building_id: String, level: int) -> Dictionary:
	var base: Dictionary = _rules.get("base_materials", {}).get(building_id, {})
	var multiplier: float = pow(1.0 + float(_rules.get("growth_per_level", 0.12)) * float(level - 1), float(_rules.get("growth_exponent", 2.0)))
	var requirements: Dictionary = {}
	for resource_id in base:
		requirements[resource_id] = maxi(1, int(ceil(float(base[resource_id]) * multiplier)))
	for addition in _rules.get("additional_materials", []):
		if level >= int(addition.from_level):
			for resource_id in addition.materials:
				requirements[resource_id] = int(requirements.get(resource_id, 0)) + int(ceil(float(addition.materials[resource_id]) * multiplier))
	return requirements

func _get_required_rank(level: int) -> int:
	for gate in _rules.get("rank_gates", []):
		if level <= int(gate.through_level):
			return int(gate.rank)
	return 40

func _get_required_ports(level: int) -> int:
	return 1 + int((level - 1) / maxi(1, int(_rules.get("ports_per_level_step", 5))))

func _get_command_rank() -> int:
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	if systems.is_empty():
		return 1
	return systems[0].get_command_rank()

func _is_at_home() -> bool:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	return home_port_id != "" and str(GameState.ship_state.get("docked_port_id", "")) == home_port_id
