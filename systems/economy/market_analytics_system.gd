extends Node

## Local market intelligence for ports the captain has personally discovered.

var _ports: Node
var _trade: Node
var _goods: Array = []
var _snapshot_seconds: int = 30
var _max_snapshots: int = 24
var _last_snapshot_at: int = 0

func _ready() -> void:
	add_to_group("market_analytics_system")

func initialize(port_system: Node, trade_line_system: Node) -> void:
	_ports = port_system
	_trade = trade_line_system
	var config: Dictionary = GameData.read("res://data/economy/market_analytics_rules.json")
	_snapshot_seconds = int(config.get("snapshot_seconds", 30))
	_max_snapshots = int(config.get("max_snapshots_per_good", 24))
	_goods = _trade.get_goods() if _trade != null else []
	call_deferred("record_snapshot")

func _process(_delta: float) -> void:
	if _trade == null or _ports == null:
		return
	if _now() - _last_snapshot_at >= _snapshot_seconds:
		record_snapshot()

func get_known_ports() -> Array:
	return _trade.get_known_ports() if _trade != null else []

func get_goods() -> Array:
	return _goods.duplicate(true)

func record_snapshot() -> void:
	if _trade == null:
		return
	var now: int = _now()
	if now == _last_snapshot_at:
		return
	_last_snapshot_at = now
	var history: Dictionary = GameState.economy_state.get("market_history", {})
	for raw_port in get_known_ports():
		var port: Dictionary = raw_port
		var port_id: String = str(port.get("id", ""))
		if port_id == "":
			continue
		var port_history: Dictionary = history.get(port_id, {})
		for raw_good in _goods:
			var good: Dictionary = raw_good
			var resource_id: String = str(good.get("id", ""))
			if resource_id == "":
				continue
			var info: Dictionary = _trade.get_market_info(port_id, resource_id)
			var port_state: Dictionary = GameState.port_state.get(port_id, {})
			var stock: int = int(port_state.get("market_stock", {}).get(resource_id, 0))
			var points: Array = port_history.get(resource_id, [])
			points.append({
				"at": now,
				"price": get_price(port_id, resource_id),
				"demand": int(info.get("demand", 0)),
				"stock": stock,
				"accepted": bool(info.get("accepted", false))
			})
			while points.size() > _max_snapshots:
				points.pop_front()
			port_history[resource_id] = points
		history[port_id] = port_history
	GameState.economy_state["market_history"] = history

func get_snapshot(port_id: String, resource_id: String) -> Dictionary:
	if _trade == null or port_id == "" or resource_id == "":
		return {}
	var info: Dictionary = _trade.get_market_info(port_id, resource_id)
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var history: Dictionary = GameState.economy_state.get("market_history", {})
	var points: Array = history.get(port_id, {}).get(resource_id, [])
	return {
		"port_id": port_id,
		"resource_id": resource_id,
		"price": get_price(port_id, resource_id),
		"demand": int(info.get("demand", 0)),
		"stock": int(port.get("market_stock", {}).get(resource_id, 0)),
		"accepted": bool(info.get("accepted", false)),
		"restores_in": int(info.get("restores_in", 0)),
		"history": points.duplicate(true)
	}

func get_price(port_id: String, resource_id: String) -> float:
	if _trade == null:
		return 0.0
	return _trade.get_sell_price(port_id, resource_id)

func _now() -> int:
	return int(Time.get_unix_time_from_system())
