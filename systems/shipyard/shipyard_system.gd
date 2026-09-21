extends Node

## Holds one active shipyard project and moves materials from the home warehouse.

var _fleet_system: Node
var _recipes: Dictionary = {}
var _goods: Dictionary = {}

func _ready() -> void:
	add_to_group("shipyard_system")

func initialize(fleet_system: Node) -> void:
	_fleet_system = fleet_system
	_recipes = GameData.get_ship_recipes()
	var goods_catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
	for raw_good in goods_catalog.get("resources", []):
		var good: Dictionary = raw_good
		_goods[str(good.get("id", ""))] = str(good.get("display_name", ""))

func get_project() -> Dictionary:
	var raw_project: Variant = GameState.company_state.get("shipyard_project", {})
	return raw_project if raw_project is Dictionary else {}

func get_goods_name(resource_id: String) -> String:
	return str(_goods.get(resource_id, resource_id))

func create_project(ship_type_id: String) -> Dictionary:
	if not _is_at_home():
		return {"ok": false, "message": "Проект можно открыть только на своей базе."}
	var ship_type: Dictionary = _fleet_system.get_ship_type(ship_type_id)
	if ship_type.is_empty() or not _recipes.has(ship_type_id):
		return {"ok": false, "message": "Проект корабля не найден."}
	var access: Dictionary = _fleet_system.get_ship_access(ship_type_id)
	if not bool(access.get("ok", false)):
		return {"ok": false, "message": str(access.get("message", "Недостаточный допуск к проекту."))}
	var old_project: Dictionary = get_project()
	if not old_project.is_empty() and str(old_project.get("ship_type_id", "")) != ship_type_id:
		return {"ok": false, "message": "Сначала достройте или отмените текущий проект."}
	if not old_project.is_empty():
		return {"ok": true, "message": "Проект уже открыт."}
	var recipe: Dictionary = _recipes.get(ship_type_id, {})
	GameState.company_state["shipyard_project"] = {
		"ship_type_id": ship_type_id,
		"name": str(recipe.get("default_name", ship_type.get("name", "Корабль"))) + " №" + str(GameState.fleet_state.size() + 1),
		"materials": {},
		"required_materials": recipe.get("materials", {}).duplicate(true)
	}
	SaveSystem.save_game()
	return {"ok": true, "message": "Проект открыт. Передайте материалы со склада."}

func set_project_name(project_name: String) -> Dictionary:
	var project: Dictionary = get_project()
	var cleaned: String = project_name.strip_edges()
	if project.is_empty() or cleaned == "":
		return {"ok": false, "message": "Укажите имя корабля."}
	project["name"] = cleaned.left(28)
	GameState.company_state["shipyard_project"] = project
	SaveSystem.save_game()
	return {"ok": true, "message": "Имя проекта изменено."}

func set_material_amount(resource_id: String, amount: int) -> Dictionary:
	if not _is_at_home():
		return {"ok": false, "message": "Материалы можно передавать только на базе."}
	var project: Dictionary = get_project()
	if project.is_empty():
		return {"ok": false, "message": "Сначала откройте проект."}
	var required: Dictionary = project.get("required_materials", {})
	if not required.has(resource_id):
		return {"ok": false, "message": "Этот материал не нужен проекту."}
	var materials: Dictionary = project.get("materials", {})
	var current: int = int(materials.get(resource_id, 0))
	var target: int = clampi(amount, 0, int(required.get(resource_id, 0)))
	var delta: int = target - current
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var inventory: Dictionary = port.get("inventory", {})
	var economy = preload("res://systems/economy/economy_model.gd").new()
	if delta > maxi(0, int(inventory.get(resource_id, 0)) - economy.reserved(GameState.economy_state, resource_id)):
		return {"ok": false, "message": "На складе недостаточно материала."}
	inventory[resource_id] = int(inventory.get(resource_id, 0)) - delta
	materials[resource_id] = target
	project["materials"] = materials
	port["inventory"] = inventory
	GameState.port_state[home_port_id] = port
	GameState.company_state["shipyard_project"] = project
	SaveSystem.save_game()
	return {"ok": true, "message": ""}

func finish_project() -> Dictionary:
	if not _is_at_home():
		return {"ok": false, "message": "Спуск на воду возможен только на базе."}
	var project: Dictionary = get_project()
	if project.is_empty():
		return {"ok": false, "message": "Нет активного проекта."}
	if not is_project_ready(project):
		return {"ok": false, "message": "Передайте все материалы в полном объёме."}
	var ship_type_id: String = str(project.get("ship_type_id", ""))
	var name: String = str(project.get("name", "Корабль"))
	var result: Dictionary = _fleet_system.complete_ship_from_shipyard(ship_type_id, name)
	if bool(result.get("ok", false)):
		GameState.company_state["shipyard_project"] = {}
	SaveSystem.save_game()
	return result

func cancel_project() -> Dictionary:
	var project: Dictionary = get_project()
	if project.is_empty():
		return {"ok": false, "message": "Нет проекта для отмены."}
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var inventory: Dictionary = port.get("inventory", {})
	var reserved_materials: Dictionary = project.get("materials", {})
	for resource_id in reserved_materials:
		inventory[resource_id] = int(inventory.get(resource_id, 0)) + int(reserved_materials.get(resource_id, 0))
	port["inventory"] = inventory
	GameState.port_state[home_port_id] = port
	GameState.company_state["shipyard_project"] = {}
	SaveSystem.save_game()
	return {"ok": true, "message": "Проект отменён, материалы возвращены на склад."}

func is_project_ready(project: Dictionary) -> bool:
	var required: Dictionary = project.get("required_materials", {})
	var materials: Dictionary = project.get("materials", {})
	if required.is_empty():
		return false
	for resource_id in required:
		if int(materials.get(resource_id, 0)) < int(required.get(resource_id, 0)):
			return false
	return true

func _is_at_home() -> bool:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or str(GameState.ship_state.get("docked_port_id", "")) != home_port_id:
		return false
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var buildings: Dictionary = port.get("buildings", {})
	var shipyard: Dictionary = buildings.get("shipyard", {})
	return int(shipyard.get("level", 0)) >= 1 and str(shipyard.get("status", "")) == "active"
