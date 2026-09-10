extends Node

## Produces goods from active production buildings into the home-port inventory.

var _cycle_seconds: float = 10.0
var _elapsed: float = 0.0
var _recipes: Array = []

func _ready() -> void:
	var config: Dictionary = SaveSystem._read_json("res://data/ports/production_recipes.json")
	_cycle_seconds = float(config.get("cycle_seconds", 10.0))
	_recipes = config.get("recipes", [])
	EventBus.building_activated.connect(_on_building_activated)
	# Existing working buildings from an older save receive their first visible batch on launch.
	call_deferred("_produce_cycle")

func _process(delta: float) -> void:
	_elapsed += delta
	while _elapsed >= _cycle_seconds:
		_elapsed -= _cycle_seconds
		_produce_cycle()

func _on_building_activated(port_id: String, building_id: String) -> void:
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
	if int(building.get("level", 0)) < 1 or str(building.get("status", "")) != "active":
		return
	for raw_recipe in _recipes:
		var recipe: Dictionary = raw_recipe
		if str(recipe.get("building_id", "")) == building_id:
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
		port = _add_recipe_output(port, recipe)
	GameState.port_state[home_port_id] = port

func _add_recipe_output(port: Dictionary, recipe: Dictionary) -> Dictionary:
	var raw_inventory: Variant = port.get("inventory", {})
	var inventory: Dictionary = raw_inventory if raw_inventory is Dictionary else {}
	var resource_id: String = str(recipe.get("resource_id", ""))
	var quantity: int = int(recipe.get("quantity_per_cycle", 0))
	if resource_id == "" or quantity <= 0:
		return port
	inventory[resource_id] = int(inventory.get(resource_id, 0)) + quantity
	port["inventory"] = inventory
	return port
