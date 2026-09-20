extends "res://tests/test_base.gd"

var _merchant: Node
var _production: Node

func before_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	GameState.world_state["home_port_id"] = "home"
	GameState.ship_state["docked_port_id"] = "home"
	GameState.player_state["money"] = 0.0
	GameState.port_state = {
		"home": {
			"inventory": {"resource_timber": 20, "resource_fish": 0},
			"buildings": {"fishing_wharf": {"level": 1, "status": "active"}}
		}
	}
	_merchant = load("res://systems/economy/merchant_visit_system.gd").new()
	add_child(_merchant)
	_production = load("res://systems/ports/port_production_system.gd").new()
	add_child(_production)

func after_each() -> void:
	_merchant.free()
	_production.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_sell_order_reserves_goods_and_buyer_pays() -> void:
	var created: Dictionary = _merchant.create_sell_order("resource_timber", 8, 10.0)
	assert_true(bool(created.get("ok", false)))
	assert_eq(_merchant.get_reserved_quantity("resource_timber"), 8)
	assert_eq(_merchant.get_available_home_inventory("resource_timber"), 12)
	var order: Dictionary = _merchant.get_sell_orders()[0]
	var merchant_state: Dictionary = GameState.economy_state["merchant"]
	merchant_state["active_offer"] = {
		"direction": "buyer", "order_id": str(order.get("id", "")), "resource_id": "resource_timber",
		"quantity_available": 5, "unit_price": 10.0
	}
	GameState.economy_state["merchant"] = merchant_state
	var result: Dictionary = _merchant.sell_to_merchant(5)
	assert_true(bool(result.get("ok", false)))
	assert_eq(GameState.port_state["home"]["inventory"]["resource_timber"], 15)
	assert_eq(GameState.player_state["money"], 50.0)
	assert_eq(_merchant.get_reserved_quantity("resource_timber"), 3)
	assert_true(bool(_merchant.cancel_sell_order(str(order.get("id", ""))).get("ok", false)))
	assert_eq(_merchant.get_reserved_quantity("resource_timber"), 0)

func test_production_pause_and_cap_prevent_overflow() -> void:
	assert_true(bool(_production.set_production_mode("fishing_wharf", "paused").get("ok", false)))
	_production._produce_cycle()
	assert_eq(GameState.port_state["home"]["inventory"]["resource_fish"], 0)
	assert_true(bool(_production.set_production_mode("fishing_wharf", "capped", 2).get("ok", false)))
	_production._produce_cycle()
	_production._produce_cycle()
	_production._produce_cycle()
	assert_eq(GameState.port_state["home"]["inventory"]["resource_fish"], 2)
