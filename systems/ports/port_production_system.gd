extends Node

## Produces goods from active production buildings into the home-port inventory.

var _cycle_seconds: float = 10.0
var _elapsed: float = 0.0
var _recipes: Array = []

func _ready() -> void:
	add_to_group("port_production_system")
	var config: Dictionary = GameData.read("res://data/ports/production_recipes.json")
	_cycle_seconds = float(config.get("cycle_seconds", 10.0))
	_recipes = config.get("recipes", [])
	EventBus.building_activated.connect(_on_building_activated)
	EventBus.production_output_requested.connect(_on_production_output_requested)
	# Existing working buildings from an older save receive their first visible batch on launch.
	call_deferred("_restore_starter_batches")

func _restore_starter_batches() -> void:
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	for recipe in _recipes:
		_issue_starter_batch(home_id, str(recipe.get("building_id", "")))

func _process(delta: float) -> void:
	_elapsed += delta
	while _elapsed >= _cycle_seconds:
		_elapsed -= _cycle_seconds
		_produce_cycle()

func _on_building_activated(port_id: String, building_id: String) -> void:
	_issue_starter_batch(port_id, building_id)

func _on_production_output_requested(port_id: String, building_id: String) -> void:
	_issue_starter_batch(port_id, building_id)

func get_production_control(building_id: String) -> Dictionary:
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_id, {})
	var building: Dictionary = port.get("buildings", {}).get(building_id, {})
	return {
		"mode": str(building.get("production_mode", "auto")),
		"cap": int(building.get("production_cap", 0)),
		"active": int(building.get("level", 0)) >= 1 and str(building.get("status", "")) == "active"
	}

func set_production_mode(building_id: String, mode: String, cap: int = 0) -> Dictionary:
	if mode not in ["auto", "capped", "paused"]:
		return {"ok": false, "message": "Неизвестный режим производства."}
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_id == "" or str(GameState.ship_state.get("docked_port_id", "")) != home_id:
		return {"ok": false, "message": "Управление производством доступно только на базе."}
	var port: Dictionary = GameState.port_state.get(home_id, {})
	var buildings: Dictionary = port.get("buildings", {})
	if not buildings.has(building_id):
		return {"ok": false, "message": "Производственное здание не найдено."}
	var building: Dictionary = buildings[building_id]
	if int(building.get("level", 0)) < 1 or str(building.get("status", "")) != "active":
		return {"ok": false, "message": "Сначала постройте и активируйте это здание."}
	if mode == "capped" and cap < 1:
		return {"ok": false, "message": "Лимит склада должен быть больше нуля."}
	building["production_mode"] = mode
	building["production_cap"] = cap if mode == "capped" else 0
	buildings[building_id] = building
	port["buildings"] = buildings
	GameState.port_state[home_id] = port
	SaveSystem.save_game()
	var text: String = "Производство остановлено." if mode == "paused" else ("Производство идёт до запаса %d." % cap if mode == "capped" else "Производство работает без лимита.")
	return {"ok": true, "message": text}

func _issue_starter_batch(port_id: String, building_id: String) -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if port_id == "" or port_id != home_port_id or not GameState.port_state.has(port_id):
		return
	var port: Dictionary = GameState.port_state[port_id]
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary):
		return
	var buildings: Dictionary = raw_buildings
	if not buildings.has(building_id):
		return
	var building: Dictionary = buildings[building_id]
	if bool(building.get("starter_batch_issued", false)):
		return
	if int(building.get("level", 0)) < 1 or str(building.get("status", "")) != "active":
		return
	if not _can_produce(port, recipe_for_building(building_id)):
		return
	for raw_recipe in _recipes:
		var recipe: Dictionary = raw_recipe
		if str(recipe.get("building_id", "")) == building_id:
			building["starter_batch_issued"] = true
			buildings[building_id] = building
			port["buildings"] = buildings
			port = _add_recipe_output(port, recipe)
			GameState.port_state[port_id] = port
			SaveSystem.save_game()
			return

func _produce_cycle() -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or not GameState.port_state.has(home_port_id):
		return
	var port: Dictionary = GameState.port_state[home_port_id]
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary):
		return
	var buildings: Dictionary = raw_buildings
	for raw_recipe in _recipes:
		var recipe: Dictionary = raw_recipe
		var building_id: String = str(recipe.get("building_id", ""))
		if not buildings.has(building_id):
			continue
		var building: Dictionary = buildings[building_id]
		var required_level: int = int(recipe.get("required_building_level", 1))
		if int(building.get("level", 0)) < required_level:
			continue
		if str(building.get("status", "")) != "active":
			continue
		if not _can_produce(port, recipe):
			continue
		port = _add_recipe_output(port, recipe)
	GameState.port_state[home_port_id] = port

func _add_recipe_output(port: Dictionary, recipe: Dictionary) -> Dictionary:
	var raw_inventory: Variant = port.get("inventory", {})
	var inventory: Dictionary = raw_inventory if raw_inventory is Dictionary else {}
	var resource_id: String = str(recipe.get("resource_id", ""))
	var building_id: String = str(recipe.get("building_id", ""))
	var buildings: Dictionary = port.get("buildings", {})
	var building: Dictionary = buildings.get(building_id, {})
	var quantity: int = int(recipe.get("quantity_per_cycle", 0)) * maxi(1, int(building.get("level", 1)))
	if resource_id == "" or quantity <= 0:
		return port
	inventory[resource_id] = int(inventory.get(resource_id, 0)) + quantity
	port["inventory"] = inventory
	return port

func recipe_for_building(building_id: String) -> Dictionary:
	for raw_recipe in _recipes:
		var recipe: Dictionary = raw_recipe
		if str(recipe.get("building_id", "")) == building_id:
			return recipe
	return {}

func _can_produce(port: Dictionary, recipe: Dictionary) -> bool:
	if recipe.is_empty():
		return false
	var building_id: String = str(recipe.get("building_id", ""))
	var building: Dictionary = port.get("buildings", {}).get(building_id, {})
	var mode: String = str(building.get("production_mode", "auto"))
	if mode == "paused":
		return false
	if mode != "capped":
		return true
	var inventory: Dictionary = port.get("inventory", {})
	var resource_id: String = str(recipe.get("resource_id", ""))
	return int(inventory.get(resource_id, 0)) < int(building.get("production_cap", 0))
