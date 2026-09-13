extends Node

## Parallel, material-funded construction projects for home-port buildings.

const MAX_LEVEL: int = 30

var _catalog: Dictionary = {}
var _goods: Dictionary = {}

func _ready() -> void:
	add_to_group("building_project_system")

func initialize() -> void:
	var source: Dictionary = SaveSystem._read_json("res://data/ports/building_catalog.json")
	for raw_building in source.get("buildings", []):
		var building: Dictionary = raw_building
		_catalog[str(building.get("building_id", ""))] = building
	var goods_catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
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
	var projects: Array = []
	if legacy is Dictionary and not legacy.is_empty():
		projects.append(legacy)
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
	if current_level >= MAX_LEVEL:
		return {"ok": false, "message": "Здание уже достигло 30 уровня."}
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
	return 20 + level * 20

func _format_time(seconds: int) -> String:
	var minutes: int = int(seconds / 60)
	var rest_seconds: int = seconds % 60
	if minutes <= 0:
		return "%d сек." % rest_seconds
	return "%d мин. %02d сек." % [minutes, rest_seconds]

func _get_now_unix() -> int:
	return int(Time.get_unix_time_from_system())

func _make_requirements(building_id: String, level: int) -> Dictionary:
	var bases: Dictionary = {
		"dock": {"resource_timber": 16, "resource_nails": 8, "resource_rope": 5, "resource_paint": 2},
		"warehouse": {"resource_timber": 20, "resource_nails": 12, "resource_glass": 3, "resource_paint": 3},
		"workshop": {"resource_timber": 18, "resource_nails": 14, "resource_parts": 5, "resource_varnish": 3},
		"market": {"resource_timber": 16, "resource_nails": 8, "resource_fabric": 8, "resource_glass": 4},
		"shipyard": {"resource_timber": 30, "resource_nails": 18, "resource_fabric": 10, "resource_rope": 10, "resource_paint": 5},
		"harbor_office": {"resource_timber": 14, "resource_nails": 8, "resource_glass": 5, "resource_paint": 4},
		"fishing_wharf": {"resource_timber": 14, "resource_nails": 7, "resource_rope": 7, "resource_paint": 2},
		"timber_yard": {"resource_timber": 18, "resource_nails": 9, "resource_rope": 5, "resource_paint": 2}
	}
	var raw_base: Variant = bases.get(building_id, {})
	var base: Dictionary = raw_base if raw_base is Dictionary else {}
	var multiplier: float = pow(1.0 + 0.12 * float(level - 1), 2.0)
	var requirements: Dictionary = {}
	for resource_id in base:
		requirements[resource_id] = maxi(1, int(ceil(float(base[resource_id]) * multiplier)))
	if level >= 6:
		requirements["resource_fabric"] = int(requirements.get("resource_fabric", 0)) + int(ceil(4.0 * multiplier))
		requirements["resource_glass"] = int(requirements.get("resource_glass", 0)) + int(ceil(2.0 * multiplier))
	if level >= 11:
		requirements["resource_parts"] = int(requirements.get("resource_parts", 0)) + int(ceil(5.0 * multiplier))
		requirements["resource_varnish"] = int(requirements.get("resource_varnish", 0)) + int(ceil(3.0 * multiplier))
	if level >= 21:
		requirements["resource_oil"] = int(requirements.get("resource_oil", 0)) + int(ceil(6.0 * multiplier))
	return requirements

func _get_required_rank(level: int) -> int:
	if level <= 5:
		return 1
	if level <= 10:
		return 10
	if level <= 15:
		return 20
	if level <= 20:
		return 25
	if level <= 25:
		return 32
	return 40

func _get_required_ports(level: int) -> int:
	return 1 + int((level - 1) / 5)

func _get_command_rank() -> int:
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	if systems.is_empty():
		return 1
	return systems[0].get_command_rank()

func _is_at_home() -> bool:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	return home_port_id != "" and str(GameState.ship_state.get("docked_port_id", "")) == home_port_id
