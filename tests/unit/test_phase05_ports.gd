extends "res://tests/test_base.gd"

var _system: Node
var _ship: Node2D
var _world_ports: Dictionary = {
	"test_port": {"id": "test_port", "name": "Test Port", "position": Vector2i(100, 100),
		"level": 1, "buildings": {}}
}

func before_each() -> void:
	GameState.reset_to_defaults()
	_system = load("res://systems/ports/port_system.gd").new()
	_ship = Node2D.new()
	add_child(_ship)
	_ship.global_position = Vector2(100, 100)
	_system.initialize(_ship, _world_ports)

func after_each() -> void:
	_system.free()
	_ship.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_discovery_records_both_knowledge_fields_without_geometry() -> void:
	_system._process(0.016)
	assert_true(GameState.port_state.test_port.discovered)
	assert_eq(GameState.player_state.discovered_port_ids, ["test_port"])
	assert_false(GameState.port_state.test_port.has("position"))
	assert_false(GameState.port_state.test_port.has("x"))
	assert_true(GameState.known_routes_state.is_empty(), "discovery is not a known route")
	assert_false(_world_ports.test_port.has("discovered"), "world data stays independent")

func test_initialize_does_not_populate_empty_saved_knowledge() -> void:
	assert_true(GameState.port_state.is_empty())
	assert_true(GameState.player_state.discovered_port_ids.is_empty())

func test_outside_range_does_not_discover() -> void:
	_ship.global_position = Vector2(900, 900)
	_system._process(0.016)
	assert_true(GameState.port_state.is_empty())

func test_saved_discovery_emits_entered_and_preserves_progress() -> void:
	GameState.port_state.test_port = {"discovered": true, "level": 4,
		"buildings": {"dock": {"level": 3, "damage_hp": 65}}}
	GameState.player_state.discovered_port_ids = ["test_port"]
	var snapshot: Dictionary = GameState.port_state.duplicate(true)
	var signals_received: Array = []
	var on_discovered := func(id: String): signals_received.append("discovered:" + id)
	var on_entered := func(id: String): signals_received.append("entered:" + id)
	var on_exited := func(id: String): signals_received.append("exited:" + id)
	EventBus.port_discovered.connect(on_discovered)
	EventBus.port_entered.connect(on_entered)
	EventBus.port_exited.connect(on_exited)
	_system._process(0.016)
	_system._process(0.016)
	_ship.global_position = Vector2(900, 900)
	_system._process(0.016)
	EventBus.port_discovered.disconnect(on_discovered)
	EventBus.port_entered.disconnect(on_entered)
	EventBus.port_exited.disconnect(on_exited)
	assert_eq(signals_received, ["entered:test_port", "exited:test_port"])
	assert_eq(GameState.port_state, snapshot)

func test_discovery_save_load() -> void:
	_system._process(0.016)
	GameState.reset_to_defaults()
	assert_true(SaveSystem.load_game())
	assert_true(GameState.port_state.test_port.discovered)
	assert_eq(GameState.player_state.discovered_port_ids, ["test_port"])
