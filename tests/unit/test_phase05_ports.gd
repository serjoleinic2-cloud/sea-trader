extends "res://tests/test_base.gd"

# test_phase05_ports.gd — Phase 05
# Тесты для PortSystem и WorldRenderer.
# Использует существующий test_base / test_runner.

# ---------------------------------------------------------------------------
# TEST A: WorldRenderer инициализируется без ошибок
# ---------------------------------------------------------------------------
func test_world_renderer_initializes() -> void:
	var renderer = load("res://systems/rendering/world_renderer.gd").new()
	assert_not_null(renderer, "WorldRenderer should instantiate")
	renderer.queue_free()


# ---------------------------------------------------------------------------
# TEST B: PortSystem определяет вход в радиус порта
# ---------------------------------------------------------------------------
func test_port_system_detects_range() -> void:
	var port_id := "test_port_001"
	GameState.port_state[port_id] = {
		"id": port_id,
		"name": "Test Port",
		"x": 100.0,
		"y": 100.0,
		"discovered": false,
		"discovery_radius": 150.0
	}

	var port_system = load("res://systems/ports/port_system.gd").new()

	# Имитируем корабль внутри радиуса
	var fake_ship := Node2D.new()
	fake_ship.global_position = Vector2(100.0, 100.0)  # прямо в центре порта
	port_system.initialize(fake_ship)

	# Вызываем _process вручную
	port_system._process(0.016)

	var discovered: bool = GameState.port_state[port_id].get("discovered", false)
	assert_true(discovered, "Port should be discovered when ship enters range")

	# Cleanup
	GameState.port_state.erase(port_id)
	port_system.queue_free()
	fake_ship.queue_free()


# ---------------------------------------------------------------------------
# TEST C: После входа в радиус discovered == true
# ---------------------------------------------------------------------------
func test_port_becomes_discovered_on_enter() -> void:
	var port_id := "test_port_002"
	GameState.port_state[port_id] = {
		"id": port_id,
		"name": "Hidden Cove",
		"x": 0.0,
		"y": 0.0,
		"discovered": false,
		"discovery_radius": 200.0
	}

	var port_system = load("res://systems/ports/port_system.gd").new()
	var fake_ship := Node2D.new()
	fake_ship.global_position = Vector2(50.0, 50.0)
	port_system.initialize(fake_ship)
	port_system._process(0.016)

	assert_true(
		GameState.port_state[port_id].get("discovered", false),
		"Port discovered flag must be true after entering range"
	)

	# Cleanup
	GameState.port_state.erase(port_id)
	port_system.queue_free()
	fake_ship.queue_free()


# ---------------------------------------------------------------------------
# TEST D: После Load Game discovered порты остаются discovered
# ---------------------------------------------------------------------------
func test_discovered_ports_survive_save_load() -> void:
	var port_id := "test_port_003"
	GameState.port_state[port_id] = {
		"id": port_id,
		"name": "Old Town",
		"x": 500.0,
		"y": 500.0,
		"discovered": true,
		"discovery_radius": 150.0
	}

	SaveSystem.save_game()
	# Сбрасываем в памяти
	GameState.port_state[port_id]["discovered"] = false
	# Загружаем
	SaveSystem.load_game()

	assert_true(
		GameState.port_state.get(port_id, {}).get("discovered", false),
		"Discovered port must remain discovered after save/load"
	)

	GameState.port_state.erase(port_id)


# ---------------------------------------------------------------------------
# TEST E: Повторный вход в discovered порт → port_entered, не port_discovered
# ---------------------------------------------------------------------------
func test_already_discovered_port_emits_entered_not_discovered() -> void:
	var port_id := "test_port_004"
	GameState.port_state[port_id] = {
		"id": port_id,
		"name": "Known Harbor",
		"x": 0.0,
		"y": 0.0,
		"discovered": true,    # уже открыт
		"discovery_radius": 200.0
	}

	var port_system = load("res://systems/ports/port_system.gd").new()
	var fake_ship := Node2D.new()
	fake_ship.global_position = Vector2(10.0, 10.0)
	port_system.initialize(fake_ship)

	var discovered_signal_fired := false
	var entered_signal_fired    := false

	EventBus.port_discovered.connect(func(_id): discovered_signal_fired = true)
	EventBus.port_entered.connect(func(_id): entered_signal_fired = true)

	port_system._process(0.016)

	assert_false(discovered_signal_fired, "port_discovered must NOT fire for already-discovered port")
	assert_true(entered_signal_fired,     "port_entered must fire for already-discovered port")

	# Cleanup
	GameState.port_state.erase(port_id)
	port_system.queue_free()
	fake_ship.queue_free()
