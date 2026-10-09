extends RefCounted

## Typed, non-tradeable training items for living crew members.

const CATALOG_PATH := "res://data/employees/training_scrolls.json"

static func catalog() -> Dictionary:
	return GameData.read(CATALOG_PATH)

static func definitions() -> Dictionary:
	return catalog().get("types", {}).duplicate(true)

static func ordered_ids() -> Array:
	var result: Array = []
	for raw_id in catalog().get("legacy_distribution", []):
		var scroll_id: String = str(raw_id)
		if definitions().has(scroll_id): result.append(scroll_id)
	return result

static func migrate_legacy() -> Dictionary:
	var known: Dictionary = definitions()
	var inventory: Dictionary = GameState.progression_state.get("training_scroll_inventory", {}).duplicate(true)
	for scroll_id in known:
		inventory[scroll_id] = maxi(0, int(inventory.get(scroll_id, 0)))
	var legacy_count: int = maxi(0, int(GameState.progression_state.get("training_scrolls", 0)))
	var order: Array = ordered_ids()
	if legacy_count > 0 and not order.is_empty():
		for index in legacy_count:
			var scroll_id: String = str(order[index % order.size()])
			inventory[scroll_id] = int(inventory.get(scroll_id, 0)) + 1
	GameState.progression_state["training_scrolls"] = 0
	GameState.progression_state["training_scroll_inventory"] = inventory
	return inventory

static func inventory() -> Dictionary:
	return migrate_legacy().duplicate(true)

static func total() -> int:
	var result: int = 0
	for count in migrate_legacy().values(): result += maxi(0, int(count))
	return result

static func type_for_skill(skill: Dictionary) -> String:
	var stat_id: String = str(skill.get("stat", ""))
	for scroll_id in ordered_ids():
		if str(definitions().get(scroll_id, {}).get("stat", "")) == stat_id: return str(scroll_id)
	return ""

static func is_compatible(scroll_id: String, skill: Dictionary) -> bool:
	return scroll_id != "" and scroll_id == type_for_skill(skill)

static func is_living(unit: Dictionary) -> bool:
	if bool(unit.get("dead", false)) or not bool(unit.get("is_alive", true)): return false
	if unit.has("health") and float(unit.get("health", 0.0)) <= 0.0: return false
	return true

static func grant(scroll_id: String, amount: int = 1) -> bool:
	if not definitions().has(scroll_id) or amount <= 0: return false
	var current: Dictionary = migrate_legacy()
	current[scroll_id] = int(current.get(scroll_id, 0)) + amount
	GameState.progression_state["training_scroll_inventory"] = current
	return true

static func consume(scroll_id: String, amount: int = 1) -> bool:
	if amount <= 0: return false
	var current: Dictionary = migrate_legacy()
	if int(current.get(scroll_id, 0)) < amount: return false
	current[scroll_id] = int(current.get(scroll_id, 0)) - amount
	GameState.progression_state["training_scroll_inventory"] = current
	return true
