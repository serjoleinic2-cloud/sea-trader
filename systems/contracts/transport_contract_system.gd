extends Node

## Early-game sealed delivery orders.  The cargo cannot be sold, unloaded or
## delegated to autopilot: the first runs remain a manual learning loop.

var _port_system: Node
var _rules: Dictionary = {}
var _goods: Array = []

func _ready() -> void:
	add_to_group("transport_contract_system")
	_rules = GameData.read("res://data/contracts/transport_contract_rules.json")
	_goods = GameData.read("res://data/resources/goods_catalog.json").get("resources", [])

func initialize(port_system: Node) -> void:
	_port_system = port_system

func get_active() -> Dictionary:
	var raw: Variant = GameState.economy_state.get("transport_contract", {})
	return raw if raw is Dictionary else {}

func offer() -> Dictionary:
	var origin_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if origin_id == "" or _port_system == null:
		return {"ok": false, "message": "Заказы доступны только у причала."}
	if not get_active().is_empty():
		return {"ok": false, "message": "Сначала завершите текущий заказ."}
	if _completed_today() >= int(_rules.get("daily_limit", 3)):
		return {"ok": false, "message": "На сегодня лимит заказов выполнен. Рынок и обычные рейсы остаются доступны."}
	var destination_id: String = _choose_destination(origin_id)
	if destination_id == "":
		return {"ok": false, "message": "Сначала вручную посетите ещё один порт — появятся заказы между известными портами."}
	var good: Dictionary = _choose_good(origin_id, destination_id)
	if good.is_empty():
		return {"ok": false, "message": "Нет подходящего товара для заказа."}
	var capacity: int = int(GameState.ship_state.get("cargo_capacity", 0))
	var minimum: int = int(_rules.get("min_quantity", 3))
	var maximum: int = mini(capacity, int(_rules.get("max_quantity", 8)))
	if maximum < minimum:
		return {"ok": false, "message": "Вместимость корабля недостаточна для заказа."}
	var quantity: int = clampi(minimum + posmod(abs(hash(origin_id + destination_id + str(_day_key()))), 4), minimum, maximum)
	var distance: float = _port_system.get_port_position(origin_id).distance_to(_port_system.get_port_position(destination_id))
	var reward: float = float(_rules.get("base_reward", 18)) + quantity * float(_rules.get("reward_per_unit", 4)) + floor(distance / 1000.0) * float(_rules.get("reward_per_1000_distance", 7))
	return {
		"ok": true,
		"id": "transport:%s:%s:%s" % [origin_id, destination_id, _day_key()],
		"origin_port_id": origin_id,
		"destination_port_id": destination_id,
		"origin_name": _port_system.get_port_name(origin_id),
		"destination_name": _port_system.get_port_name(destination_id),
		"resource_id": str(good.get("id", "")),
		"resource_name": str(good.get("display_name", "товар")),
		"quantity": quantity,
		"distance": distance,
		"reward": reward,
		"message": "Груз выдаётся после принятия и должен быть доставлен вручную."
	}

func accept() -> Dictionary:
	if not get_active().is_empty():
		return {"ok": false, "message": "Уже есть активный заказ."}
	var contract: Dictionary = offer()
	if not bool(contract.get("ok", false)):
		return contract
	contract["loaded"] = false
	contract["accepted_at"] = int(Time.get_unix_time_from_system())
	GameState.economy_state["transport_contract"] = contract
	_port_system.select_destination(str(contract.destination_port_id))
	SaveSystem.save_game()
	EventBus.contract_accepted.emit(str(contract.id))
	return {"ok": true, "message": "Заказ принят. Загрузите опечатанный груз в этом порту."}

func load() -> Dictionary:
	var contract: Dictionary = get_active()
	if contract.is_empty():
		return {"ok": false, "message": "Нет активного заказа."}
	if bool(contract.get("loaded", false)):
		return {"ok": false, "message": "Опечатанный груз уже в трюме."}
	if str(GameState.ship_state.get("docked_port_id", "")) != str(contract.get("origin_port_id", "")):
		return {"ok": false, "message": "Груз выдают только в порту отправления."}
	var used: int = 0
	for raw_item in GameState.ship_state.get("cargo", []):
		var item: Dictionary = raw_item
		used += int(item.get("quantity", 0))
	if used + int(contract.get("quantity", 0)) > int(GameState.ship_state.get("cargo_capacity", 0)):
		return {"ok": false, "message": "Освободите место в трюме для заказа."}
	var cargo: Array = GameState.ship_state.get("cargo", []).duplicate(true)
	cargo.append({"resource_id": str(contract.resource_id), "quantity": int(contract.quantity), "contract_id": str(contract.id)})
	GameState.ship_state["cargo"] = cargo
	contract["loaded"] = true
	GameState.economy_state["transport_contract"] = contract
	SaveSystem.save_game()
	EventBus.cargo_loaded.emit(str(contract.resource_id), int(contract.quantity))
	return {"ok": true, "message": "Груз опечатан и загружен. Ведите корабль вручную в «%s»." % str(contract.destination_name)}

func complete() -> Dictionary:
	var contract: Dictionary = get_active()
	if contract.is_empty():
		return {"ok": false, "message": "Нет активного заказа."}
	if not bool(contract.get("loaded", false)):
		return {"ok": false, "message": "Сначала загрузите груз в порту отправления."}
	if str(GameState.ship_state.get("docked_port_id", "")) != str(contract.get("destination_port_id", "")):
		return {"ok": false, "message": "Сдать груз можно только в порту назначения."}
	if not _remove_sealed_cargo(str(contract.id), int(contract.quantity)):
		return {"ok": false, "message": "Опечатанный груз не найден в трюме."}
	var reward: float = float(contract.get("reward", 0.0))
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + reward
	var stats: Dictionary = GameState.player_state.get("stats", {})
	stats["total_deliveries"] = int(stats.get("total_deliveries", 0)) + 1
	stats["cargo_units_moved"] = int(stats.get("cargo_units_moved", 0)) + int(contract.get("quantity", 0))
	stats["total_earned"] = float(stats.get("total_earned", 0.0)) + reward
	GameState.player_state["stats"] = stats
	var completed: Dictionary = GameState.economy_state.get("transport_completed", {})
	completed[_day_key()] = _completed_today() + 1
	GameState.economy_state["transport_completed"] = completed
	GameState.economy_state["transport_contract"] = {}
	var completed_ids: Array = GameState.economy_state.get("completed_contract_ids", [])
	completed_ids.append(str(contract.id))
	GameState.economy_state["completed_contract_ids"] = completed_ids
	SaveSystem.save_game()
	EventBus.cargo_delivered.emit(str(contract.resource_id), int(contract.quantity))
	EventBus.contract_completed.emit(str(contract.id), reward)
	return {"ok": true, "message": "Заказ сдан: %s × %d. Получено %.0f." % [str(contract.resource_name), int(contract.quantity), reward]}

func _choose_destination(origin_id: String) -> String:
	var ids: Array[String] = []
	for raw_id in GameState.player_state.get("discovered_port_ids", []):
		var port_id: String = str(raw_id)
		if port_id != "" and port_id != origin_id:
			ids.append(port_id)
	ids.sort()
	return ids[posmod(abs(hash(origin_id + _day_key())), ids.size())] if not ids.is_empty() else ""

func _choose_good(origin_id: String, destination_id: String) -> Dictionary:
	if _goods.is_empty():
		return {}
	return _goods[posmod(abs(hash(origin_id + destination_id + _day_key())), _goods.size())]

func _remove_sealed_cargo(contract_id: String, quantity: int) -> bool:
	var cargo: Array = GameState.ship_state.get("cargo", [])
	var retained: Array = []
	var removed: int = 0
	for raw_item in cargo:
		var item: Dictionary = raw_item
		if str(item.get("contract_id", "")) == contract_id:
			removed += int(item.get("quantity", 0))
		else:
			retained.append(item)
	if removed != quantity:
		return false
	GameState.ship_state["cargo"] = retained
	return true

func _day_key() -> String:
	return Time.get_date_string_from_system()

func _completed_today() -> int:
	var completed: Dictionary = GameState.economy_state.get("transport_completed", {})
	return int(completed.get(_day_key(), 0))
