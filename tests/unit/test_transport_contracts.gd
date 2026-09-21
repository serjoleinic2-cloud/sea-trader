extends "res://tests/test_base.gd"

var _ship: Node2D
var _ports: Node
var _contracts: Node

func before_each() -> void:
	GameState.reset_to_defaults()
	SaveSystem.delete_save()
	_ship = load("res://scenes/game/ship/ship.tscn").instantiate()
	add_child(_ship)
	_ports = load("res://systems/ports/port_system.gd").new()
	add_child(_ports)
	_ports.initialize(_ship, {
		"home": {"name": "База", "position": Vector2(100, 100)},
		"remote": {"name": "Порт", "position": Vector2(500, 100)}
	})
	_ship.global_position = Vector2(100, 100)
	GameState.ship_state["position"] = _ship.global_position
	GameState.ship_state["docked_port_id"] = "home"
	GameState.ship_state["cargo"] = []
	GameState.world_state["home_port_id"] = "home"
	GameState.player_state["money"] = 100.0
	GameState.player_state["discovered_port_ids"] = ["home", "remote"]
	GameState.port_state = {"home": {"inventory": {}, "buildings": {}}, "remote": {"market_stock": {}, "buildings": {}}}
	_contracts = load("res://systems/contracts/transport_contract_system.gd").new()
	add_child(_contracts)
	_contracts.initialize(_ports)

func after_each() -> void:
	_contracts.free()
	_ports.free()
	_ship.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_accept_load_and_complete_manual_order() -> void:
	var offer: Dictionary = _contracts.offer()
	assert_true(bool(offer.get("ok", false)))
	assert_true(_contracts.accept().ok)
	assert_true(_contracts.load().ok)
	var active: Dictionary = _contracts.get_active()
	assert_true(bool(active.loaded))
	assert_eq(GameState.ship_state.cargo.size(), 1)
	assert_eq(str(GameState.ship_state.cargo[0].contract_id), str(active.id))
	GameState.ship_state["docked_port_id"] = str(active.destination_port_id)
	var money_before: float = float(GameState.player_state.money)
	assert_true(_contracts.complete().ok)
	assert_true(_contracts.get_active().is_empty())
	assert_true(GameState.ship_state.cargo.is_empty())
	assert_gt(GameState.player_state.money, money_before)
	assert_eq(GameState.player_state.stats.total_deliveries, 1)

func test_order_requires_known_second_port_and_honors_daily_limit() -> void:
	GameState.player_state["discovered_port_ids"] = ["home"]
	assert_false(_contracts.offer().ok)
	GameState.player_state["discovered_port_ids"] = ["home", "remote"]
	GameState.economy_state["transport_completed"] = {Time.get_date_string_from_system(): 3}
	assert_false(_contracts.offer().ok)

func test_sealed_cargo_cannot_be_sent_by_autopilot() -> void:
	assert_true(_contracts.accept().ok)
	assert_true(_contracts.load().ok)
	var pilot: Node = load("res://systems/navigation/active_route_autopilot.gd").new()
	add_child(pilot)
	GameState.known_routes_state = {"route": {"port_a_id": "home", "port_b_id": "remote"}}
	pilot.initialize(_ship, _ports)
	var result: Dictionary = pilot.validate_start("remote")
	assert_false(bool(result.ok))
	assert_true(str(result.message).contains("вручную"))
	pilot.free()
