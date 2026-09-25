extends "res://tests/test_base.gd"

var _ship: Node2D
var _system: Node

func before_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	_ship = Node2D.new()
	add_child(_ship)
	GameState.ship_state["position"] = Vector2.ZERO
	GameState.ship_state["hull"] = 100.0
	GameState.ship_state["engine"] = 100.0
	GameState.ship_state["steering"] = 100.0
	GameState.ship_state["fuel"] = 100.0
	_system = load("res://systems/events/world_event_system.gd").new()
	add_child(_system)

func after_each() -> void:
	_system.free()
	_ship.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func _set_zone(zone_type: String, position: Vector2 = Vector2(100.0, 0.0)) -> void:
	_system.initialize(_ship, {"hazard_zones": [{
		"id": "hazard_test",
		"type": zone_type,
		"position": position,
		"radius": 20.0,
		"active": true
	}]})

func _enter_zone(position: Vector2 = Vector2(90.0, 0.0)) -> void:
	GameState.ship_state["position"] = position
	_system._process(0.016)

func test_tornado_damages_once_per_entry_and_shows_warning() -> void:
	_set_zone("tornado")
	_enter_zone()
	assert_eq(GameState.ship_state.hull, 91.0)
	assert_eq(GameState.ship_state.steering, 95.0)
	assert_true(str(_system.get_active_event().get("message", "")).contains("Смерч"))
	_system._process(0.016)
	assert_eq(GameState.ship_state.hull, 91.0, "remaining inside must not repeat the hit each frame")
	GameState.ship_state.position = Vector2(200.0, 0.0)
	_system._process(0.016)
	_enter_zone()
	assert_eq(GameState.ship_state.hull, 91.0, "re-entry cooldown prevents rapid repeated damage")

func test_pirates_cannot_take_sealed_contract_cargo() -> void:
	_set_zone("pirate")
	GameState.ship_state["cargo"] = [
		{"resource_id": "resource_parts", "quantity": 4, "contract_id": "sealed_order"},
		{"resource_id": "resource_fish", "quantity": 3}
	]
	_enter_zone()
	assert_eq(GameState.ship_state.cargo[0].quantity, 4)
	assert_eq(GameState.ship_state.cargo[1].quantity, 2)
	assert_eq(GameState.ship_state.hull, 96.0)

func test_hazard_damage_keeps_emergency_repairs_possible() -> void:
	_set_zone("anomaly")
	GameState.ship_state["engine"] = 12.0
	_enter_zone()
	assert_eq(GameState.ship_state.engine, 10.0)
	assert_eq(GameState.ship_state.fuel, 100.0, "hazards cannot consume fuel needed to reach port")
