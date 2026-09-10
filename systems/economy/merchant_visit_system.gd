extends Node

## Rotating visiting merchant offers. Purchased goods are delivered to the home warehouse.

var _offer_duration_seconds: int = 1200
var _next_offer_delay_seconds: int = 1200
var _offer_templates: Array = []

func _ready() -> void:
	add_to_group("merchant_visit_system")
	var config: Dictionary = SaveSystem._read_json("res://data/economy/merchant_visits.json")
	_offer_duration_seconds = int(config.get("offer_duration_seconds", 1200))
	_next_offer_delay_seconds = int(config.get("next_offer_delay_seconds", 1200))
	_offer_templates = config.get("offers", [])

func _process(_delta: float) -> void:
	_update_offer()

func get_active_offer() -> Dictionary:
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	var raw_offer: Variant = merchant.get("active_offer", {})
	if raw_offer is Dictionary:
		return raw_offer
	return {}

func purchase(quantity: int) -> Dictionary:
	var offer: Dictionary = get_active_offer()
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if offer.is_empty() or home_port_id == "" or not GameState.port_state.has(home_port_id):
		return {"ok": false, "message": "Предложение уже недоступно."}
	var available_quantity: int = int(offer.get("quantity_available", 0))
	var unit_price: float = float(offer.get("unit_price", 0.0))
	if quantity < 1 or quantity > available_quantity:
		return {"ok": false, "message": "Укажите доступное количество."}
	var total_price: float = unit_price * quantity
	var money: float = float(GameState.player_state.get("money", 0.0))
	if money < total_price:
		return {"ok": false, "message": "Недостаточно денег."}
	GameState.player_state["money"] = money - total_price
	var port: Dictionary = GameState.port_state[home_port_id]
	var raw_inventory: Variant = port.get("inventory", {})
	var inventory: Dictionary = raw_inventory if raw_inventory is Dictionary else {}
	var resource_id: String = str(offer.get("resource_id", ""))
	inventory[resource_id] = int(inventory.get(resource_id, 0)) + quantity
	port["inventory"] = inventory
	GameState.port_state[home_port_id] = port
	offer["quantity_available"] = available_quantity - quantity
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	merchant["active_offer"] = offer
	GameState.economy_state["merchant"] = merchant
	SaveSystem.save_game()
	return {"ok": true, "message": "Товар доставлен на склад базы."}

func _update_offer() -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or _offer_templates.is_empty():
		return
	var now: int = int(Time.get_unix_time_from_system())
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	if merchant.is_empty():
		merchant = {
			"active_offer": {},
			"next_offer_at": now,
			"offer_index": 0
		}
	var raw_offer: Variant = merchant.get("active_offer", {})
	var active_offer: Dictionary = raw_offer if raw_offer is Dictionary else {}
	if not active_offer.is_empty():
		if now < int(active_offer.get("expires_at", 0)):
			return
		merchant["active_offer"] = {}
		merchant["next_offer_at"] = now + _next_offer_delay_seconds
	if now < int(merchant.get("next_offer_at", now)):
		GameState.economy_state["merchant"] = merchant
		return
	var offer_index: int = int(merchant.get("offer_index", 0)) % _offer_templates.size()
	var template: Dictionary = _offer_templates[offer_index]
	merchant["active_offer"] = {
		"resource_id": str(template.get("resource_id", "")),
		"quantity_available": int(template.get("quantity", 0)),
		"unit_price": float(template.get("unit_price", 0.0)),
		"expires_at": now + _offer_duration_seconds
	}
	merchant["offer_index"] = offer_index + 1
	merchant["next_offer_at"] = now + _offer_duration_seconds + _next_offer_delay_seconds
	GameState.economy_state["merchant"] = merchant
	SaveSystem.save_game()
