extends Node

## Seeds port markets for every catalog resource and maintains rotating base shortages.

var _port_system: Node
var _goods: Array = []
var _last_home_port_id: String = ""

func _ready() -> void:
	add_to_group("market_distribution_system")

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	var raw_goods: Variant = catalog.get("resources", [])
	if raw_goods is Array:
		_goods = raw_goods
	_seed_remote_markets()

func _process(_delta: float) -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id != _last_home_port_id:
		_last_home_port_id = home_port_id
		_seed_remote_markets()
		_refresh_base_deficits()
	if home_port_id != "":
		_refresh_base_deficits()

func _seed_remote_markets() -> void:
	if _port_system == null:
		return
	var port_ids: Array = _port_system.get_all_port_ids()
	for port_index in range(port_ids.size()):
		var port_id: String = str(port_ids[port_index])
		var state: Dictionary = GameState.port_state.get(port_id, {})
		if state.is_empty():
			state = {"discovered": false, "level": 1, "buildings": {}}
		var stock: Dictionary = state.get("market_stock", {})
		for goods_index in range(_goods.size()):
			var good: Dictionary = _goods[goods_index]
			var resource_id: String = str(good.get("id", ""))
			if resource_id == "" or stock.has(resource_id):
				continue
			# Each good has several ports of origin. Stocks remain finite after a purchase.
			if posmod(port_index + goods_index * 2, 3) != 0:
				stock[resource_id] = 5 + posmod(port_index * 3 + goods_index, 9)
		state["market_stock"] = stock
		GameState.port_state[port_id] = state
	SaveSystem.save_game()

func _refresh_base_deficits() -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or not GameState.port_state.has(home_port_id):
		return
	var home_port: Dictionary = GameState.port_state[home_port_id]
	var inventory: Dictionary = home_port.get("inventory", {})
	var existing_raw: Variant = GameState.economy_state.get("base_deficits", [])
	var active: Array = existing_raw if existing_raw is Array else []
	var retained: Array = []
	for raw_demand in active:
		var demand: Dictionary = raw_demand
		var target: int = int(demand.get("target_quantity", 1))
		var current: int = int(inventory.get(str(demand.get("resource_id", "")), 0))
		if current < int(ceil(float(target) * 0.70)):
			retained.append(demand)
	var desired_count: int = maxi(1, int(ceil(float(_goods.size()) * 0.30)))
	var priority_ids: Array[String] = ["resource_parts", "resource_nails", "resource_fabric", "resource_rope", "resource_paint", "resource_varnish", "resource_glass", "resource_timber", "resource_oil", "resource_fish"]
	for resource_id in priority_ids:
		if retained.size() >= desired_count:
			break
		var already_active: bool = false
		for raw_demand in retained:
			if str((raw_demand as Dictionary).get("resource_id", "")) == resource_id:
				already_active = true
				break
		if already_active:
			continue
		retained.append({"resource_id": resource_id, "target_quantity": _get_target_quantity(resource_id), "purpose": "Стратегический запас базы"})
	GameState.economy_state["base_deficits"] = retained

func _get_target_quantity(resource_id: String) -> int:
	if resource_id == "resource_timber":
		return 40
	if resource_id in ["resource_nails", "resource_fabric", "resource_rope"]:
		return 24
	if resource_id in ["resource_paint", "resource_varnish", "resource_glass"]:
		return 12
	return 18
