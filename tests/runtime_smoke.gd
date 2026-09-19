extends Node

## Full scene, actual frame ordering and UI signals, isolated from player saves.
var _failures: int = 0
var _checks: int = 0

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("SMOKE: " + message)

func _frames(count: int = 4) -> void:
	for index in range(count):
		await get_tree().process_frame

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	GameState.reset_to_defaults()
	SaveSystem.delete_save()
	GameState.world_state.seed = 42
	GameState.world_state.world_gen_version = "1"
	SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await _frames()
	_check(main._world_ready, "World initializes")
	var ports: Node = main._port_system
	var ids: Array = ports.get_all_port_ids()
	_check(ids.size() >= 2, "Deterministic fixture has two ports")
	if ids.size() < 2:
		get_tree().quit(1)
		return
	var home: String = str(ids[0])
	var destination: String = str(ids[1])
	for port_id in [home, destination, home]:
		ports.undock()
		main._ship.global_position = ports.get_port_position(port_id)
		GameState.ship_state.position = main._ship.global_position
		_check(ports.dock(port_id), "Fixture docks at " + port_id)
	await _frames()
	var port_window: Node = main.get_node("PortWindow")
	GameState.port_state[home]["inventory"] = {"resource_parts": 7}
	GameState.ship_state.cargo = []
	port_window._open_section("resources")
	port_window._select_transfer_resource("resource_parts")
	port_window._selected_quantity = 3
	await _frames()
	_check(port_window._load_button.visible and not port_window._load_button.disabled, "Imported spare parts can be loaded at base")
	var score: int = main._career_system.get_activity_score()
	port_window._load_button.pressed.emit()
	_check(GameState.port_state[home].inventory.resource_parts == 4, "Loading debits exact warehouse quantity")
	await _frames()
	port_window._unload_button.pressed.emit()
	_check(GameState.port_state[home].inventory.resource_parts == 7, "Unloading restores exact quantity")
	_check(main._career_system.get_activity_score() == score, "Warehouse transfers do not farm rank")
	GameState.ship_state.cargo = [{"resource_id": "resource_timber", "quantity": 5}]
	GameState.ship_state.fuel = 0.0
	var logistics: Node = main.get_node("LogisticsWindow")
	logistics.open()
	logistics._destination.select(logistics._port_ids.find(destination))
	logistics._goods.select(logistics._good_ids.find("resource_timber"))
	logistics._quantity.value = 5
	await _frames()
	_check(logistics._send_button.disabled, "UI blocks zero-fuel departure")
	_check(logistics._details.text.contains("Не хватает топлива"), "UI explains why departure is blocked")
	_check(not main.get_node("PortWindow").visible, "Port hidden behind workspace")
	_check(not main.get_node("ShipStatusHUD").visible, "No duplicate ship HUD in workspace")
	GameState.ship_state.fuel = 100.0
	await _frames()
	_check(not logistics._send_button.disabled, "Start button enabled for valid voyage")
	var before: Vector2 = GameState.ship_state.position
	logistics._send_button.pressed.emit()
	for index in range(60):
		await get_tree().physics_frame
	_check(GameState.ship_state.position.distance_to(before) > 50.0, "Ship moves after actual Start button signal")
	_check(not logistics._open, "Route window closes after successful departure")
	_check(bool(GameState.voyage_state.get("active_autopilot", false)), "Actual physics loop preserves autopilot")
	SaveSystem.save_game()
	before = GameState.ship_state.position
	main.free()
	await _frames()
	main = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	for index in range(30):
		await get_tree().physics_frame
	_check(GameState.ship_state.position.distance_to(before) > 20.0, "Full scene reload resumes saved voyage")
	main._active_route_autopilot.cancel()
	var coordinator: Node = main.get_node("WindowCoordinator")
	GameState.ship_state.cargo = []
	for good in main._logistics_system.get_goods():
		GameState.ship_state.cargo.append({"resource_id": str(good.id), "quantity": 1})
	await _frames()
	var ship_hud: Node = main.get_node("ShipStatusHUD")
	var cargo_scroll: ScrollContainer = ship_hud._panel.get_child(0).get_child(0)
	_check(cargo_scroll.get_v_scroll_bar().max_value > cargo_scroll.size.y, "Long cargo list scrolls inside HUD")
	_check(not main.get_node("CrewWindow")._button.visible, "No floating crew button over workspaces")
	for viewport_size in [Vector2i(1080, 1920), Vector2i(1280, 720)]:
		get_window().content_scale_size = viewport_size
		get_window().size = viewport_size
		for entry in coordinator._entries:
			var window: Node = entry.window
			if window.name == "MerchantOfferHUD":
				continue # Visibility depends on a timed offer; tested separately by its system.
			window.set(str(entry.flag), true)
			await _frames(6)
			var open_count: int = 0
			for other in coordinator._entries:
				if bool(other.window.get(str(other.flag))):
					open_count += 1
			_check(open_count == 1, "Only one workspace: " + str(window.name))
			var panel: Control = entry.panel
			var bounds: Rect2 = panel.get_global_rect()
			var viewport: Rect2 = get_viewport().get_visible_rect()
			_check(viewport.encloses(bounds), "Panel fits viewport: " + str(window.name) + " " + str(bounds))
			var close: Button = panel.get_child(0).get_child(0)
			_check(close.is_visible_in_tree() and bounds.encloses(close.get_global_rect()), "Close button stays inside " + str(window.name))
			close.pressed.emit()
			await _frames()
			_check(not bool(window.get(str(entry.flag))), "Close works for " + str(window.name))
	main.free()
	SaveSystem.delete_save()
	print("SMOKE checks=%d fail=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
