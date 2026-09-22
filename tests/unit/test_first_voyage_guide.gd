extends "res://tests/test_base.gd"

var _ship: Node2D
var _ports: Node
var _contracts: Node
var _guide: Node

func before_each() -> void:
	GameState.reset_to_defaults()
	SaveSystem.delete_save()
	_ship = Node2D.new()
	add_child(_ship)
	_ship.global_position = Vector2(100, 100)
	GameState.ship_state["position"] = _ship.global_position
	GameState.ship_state["docked_port_id"] = "home"
	GameState.world_state["home_port_id"] = "home"
	_ports = load("res://systems/ports/port_system.gd").new()
	add_child(_ports)
	_ports.initialize(_ship, {
		"home": {"name": "База", "position": Vector2(100, 100)},
		"remote": {"name": "Порт", "position": Vector2(500, 100)}
	})
	GameState.player_state["discovered_port_ids"] = ["home"]
	GameState.player_state["visited_port_ids"] = ["home"]
	_contracts = load("res://systems/contracts/transport_contract_system.gd").new()
	add_child(_contracts)
	_contracts.initialize(_ports)
	_guide = load("res://systems/ui/first_voyage_guide.gd").new()
	add_child(_guide)
	_guide.initialize(_ports, _contracts, null)

func after_each() -> void:
	_guide.free()
	_contracts.free()
	_ports.free()
	_ship.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_guide_sets_manual_course_to_nearest_unknown_port() -> void:
	assert_eq(_guide.get_guide_state().phase, "explore")
	_guide._perform_action()
	assert_eq(GameState.world_state.destination_port_id, "remote")
	assert_false(bool(GameState.voyage_state.get("active_autopilot", false)))

func test_guide_advances_from_discovery_to_contract_delivery() -> void:
	GameState.player_state["discovered_port_ids"] = ["home", "remote"]
	GameState.player_state["visited_port_ids"] = ["home", "remote"]
	assert_eq(_guide.get_guide_state().phase, "accept")
	GameState.economy_state["transport_contract"] = {"loaded": false, "destination_port_id": "remote"}
	assert_eq(_guide.get_guide_state().phase, "load")
	GameState.economy_state["transport_contract"] = {"loaded": true, "destination_port_id": "remote"}
	assert_eq(_guide.get_guide_state().phase, "deliver")
	GameState.ship_state["docked_port_id"] = "remote"
	assert_eq(_guide.get_guide_state().phase, "complete_contract")
	GameState.player_state.stats.total_deliveries = 1
	assert_eq(_guide.get_guide_state().phase, "complete")
