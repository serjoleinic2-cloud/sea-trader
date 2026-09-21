extends Node

## Read-only static definitions. Disk access remains in SaveSystem.
## Returned dictionaries are copies: consumers cannot mutate cached definitions.
const SHIPS: String = "res://data/ships/ship_catalog.json"
const GOODS: String = "res://data/resources/goods_catalog.json"
var _cache: Dictionary = {}

func read(path: String) -> Dictionary:
	if not path.begins_with("res://data/") or not path.ends_with(".json") or path.contains(".."):
		push_error("GameData: expected res://data/*.json: " + path)
		return {}
	if not _cache.has(path):
		_cache[path] = SaveSystem._read_json(path)
	var data: Dictionary = _cache[path]
	return data.duplicate(true)

func get_starter_ship_id() -> String:
	return str(read(SHIPS).get("starter_ship_id", ""))

func get_ships() -> Array:
	var catalog: Dictionary = read(SHIPS)
	var result: Array = []
	for raw_ship in catalog.get("ships", []):
		var ship: Dictionary = catalog.get("defaults", {}).duplicate(true)
		ship.merge(raw_ship, true)
		result.append(ship)
	return result

func get_ship(ship_id: String) -> Dictionary:
	for ship in get_ships():
		if str(ship.get("id", "")) == ship_id:
			return ship
	return {}

func get_crew_requirements() -> Dictionary:
	var result: Dictionary = {}
	for ship in get_ships():
		result[str(ship.id)] = {"min_crew": int(ship.min_crew), "max_crew": int(ship.max_crew)}
	return result

func get_ship_recipes() -> Dictionary:
	var result: Dictionary = {}
	for ship in get_ships():
		result[str(ship.id)] = {"materials": ship.build_materials.duplicate(true), "default_name": str(ship.name)}
	return result

func get_good(resource_id: String) -> Dictionary:
	for good in read(GOODS).get("resources", []):
		if str(good.get("id", "")) == resource_id:
			return good
	return {}

func validate() -> Array[String]:
	var validator: RefCounted = preload("res://core/config_validator.gd").new()
	var errors: Array[String] = validator.validate(
		read(SHIPS), read(GOODS), read("res://data/ports/building_catalog.json"),
		read("res://data/ports/production_recipes.json"))
	errors.append_array(validator.validate_rewards(read("res://data/challenges/challenge_rules.json"), read("res://data/rewards/reward_catalog.json")))
	errors.append_array(validator.validate_building_rules(read("res://data/ports/building_rules.json"), read("res://data/ports/building_catalog.json"), read(GOODS)))
	var required_positive: Dictionary = {
		"res://data/economy/market_rules.json": ["delivery_surcharge", "delivery_seconds"],
		"res://data/ports/service_rules.json": ["fuel_per_oil", "hull_per_parts", "price_per_fuel", "price_per_hull", "minimum_price_factor"],
		"res://data/economy/logistics_rules.json": ["autopilot_speed", "fuel_per_distance", "arrival_distance"]
	}
	for path in required_positive:
		var config: Dictionary = read(str(path))
		for field in required_positive[path]:
			validator.check_positive(config, str(field), str(path), errors)
	var balance: Dictionary = read("res://data/economy/balance_rules.json")
	for section in ["market", "fleet", "production", "recovery"]:
		if not balance.get(section) is Dictionary:
			errors.append("balance_rules: missing " + str(section))
			continue
		for field in balance[section]:
			validator.check_positive(balance[section], str(field), "balance_rules." + str(section), errors)
	if balance.has("market") and float(balance.market.get("bid_peak", 0)) <= float(balance.market.get("bid_floor", 0)):
		errors.append("balance_rules: bid_peak must exceed bid_floor")
	return errors
