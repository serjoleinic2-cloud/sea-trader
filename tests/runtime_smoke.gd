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

func _close_button(panel: Control) -> Button:
	return panel.find_child("CloseButton", true, false) as Button

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	GameState.reset_to_defaults()
	SaveSystem.delete_save()
	GameState.player_state["origin_race_id"] = "nerids"
	GameState.player_state["origin_race_confirmed"] = true
	GameState.world_state.seed = 42
	GameState.world_state.world_gen_version = str(int(GameData.read("res://data/world/world_gen_config.json").version))
	SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await _frames()
	_check(main._world_ready, "World initializes")
	_check(not main.get_node("ShipStatusHUD").visible and not main.get_node("FirstVoyageGuide").visible, "Startup keeps the sea clear of expanded information panels")
	_check(main.get_node("WindowCoordinator/TopReadouts").is_visible_in_tree(), "Sailing indicators remain in the top menu")
	var cabinet_panel: Control = main.get_node("CaptainCabinet").get("_panel")
	_check(cabinet_panel.find_child("FullWindowCaptainCabinArt", true, false) != null and cabinet_panel.find_child("DecoratedWindowEdge", true, false) == null, "Captain cabin art stays full-bleed without the extra ornamental top frame")
	var stale_user_island_model: bool = false
	for island in main._navigation_world.get("islands", []):
		if str(island.get("world_asset_identity", "")) == "iland_obstacle":
			stale_user_island_model = true
	_check(not stale_user_island_model, "Removed user-supplied island model is not assigned in the world")
	var resource_bar: HBoxContainer = main.get_node("WindowCoordinator/TopResourceBar")
	_check(resource_bar.get_child_count() == 6 and resource_bar.get_node("MoreResourcesButton").visible == false, "Top bar pins five core resources and reserves an overflow menu")
	GameState.player_state["money"] = 1234
	var home_stock: Dictionary = GameState.port_state.get(str(GameState.world_state.get("home_port_id", "")), {})
	var inventory: Dictionary = home_stock.get("inventory", {})
	inventory["resource_timber"] = 42
	inventory["resource_parts"] = 13
	inventory["resource_fish"] = 8
	home_stock["inventory"] = inventory
	GameState.port_state[str(GameState.world_state.get("home_port_id", ""))] = home_stock
	GameState.combat_state["magic_shards"] = 7
	await _frames()
	var resource_labels: Array[String] = []
	for chip_index in range(5):
		var chip: Control = resource_bar.get_child(chip_index)
		resource_labels.append(str(chip.get_child(0).get_child(1).text))
	_check(resource_labels == ["КАЗНА\n1234", "ДЕРЕВО\n42", "ДЕТАЛИ\n13", "РЫБА\n8", "ОСКОЛКИ\n7"], "Top resource counts track current player and home storage values")
	inventory["resource_oil"] = 6
	home_stock["inventory"] = inventory
	GameState.port_state[str(GameState.world_state.get("home_port_id", ""))] = home_stock
	await _frames()
	var extra_resources: Button = resource_bar.get_node("MoreResourcesButton")
	_check(extra_resources.visible and extra_resources.text == "ЕЩЁ  +1", "Newly produced resource appears in the overflow menu without changing pinned slots")
	main.get_node("WindowCoordinator/MoreResourcesPanel").show()
	await _frames()
	var extra_label: Label = main.get_node("WindowCoordinator/MoreResourcesPanel/ResourceScroll/ResourceList/Resource_resource_oil")
	_check(extra_label.text == "Масло  6", "Overflow resource uses catalog name and current stock")
	if not main._world_ready:
		get_tree().quit(1)
		return
	var ports: Node = main._port_system
	var ids: Array = ports.get_all_port_ids()
	_check(ids.size() >= 2, "Deterministic fixture has two ports")
	if ids.size() < 2:
		get_tree().quit(1)
		return
	var home: String = str(ids[0])
	var destination: String = str(ids[1])
	var guide: Node = main.get_node("FirstVoyageGuide")
	GameState.player_state["visited_port_ids"] = [home, destination]
	var guide_destination_name: String = ports.get_port_name(destination)
	GameState.economy_state["transport_contract"] = {
		"origin_port_id": home,
		"destination_port_id": destination,
		"destination_name": guide_destination_name,
		"loaded": true
	}
	guide._process(0.0)
	var guide_text: String = str(guide.get("_text").text)
	_check(guide_text.contains(guide_destination_name), "Delivery guide names the destination port (" + str(guide.get_guide_state()) + "; " + guide_text + ")")
	GameState.economy_state["transport_contract"] = {}
	main._ship.global_position = ports.get_port_position(home)
	GameState.ship_state["position"] = main._ship.global_position
	main._ship._update_anchor_prompt()
	var anchor_prompt: Label = main._ship.get_node("AnchorPromptLayer/AnchorPrompt")
	_check(anchor_prompt.visible and anchor_prompt.text.contains("E") and anchor_prompt.text.contains(ports.get_port_name(home)), "Anchor prompt appears above the ship with the nearby port name")
	for port_id in [home, destination, home]:
		ports.undock()
		main._ship.global_position = ports.get_port_position(port_id)
		GameState.ship_state.position = main._ship.global_position
		_check(ports.dock(port_id), "Fixture docks at " + port_id)
	await _frames()
	var port_window: Node = main.get_node("PortWindow")
	_check(not port_window.visible, "Docking does not automatically cover the sea with the port menu")
	# The first delivery guide legitimately opens the contract workspace.
	# Close it as a player would before interacting with the warehouse.
	for entry in main.get_node("WindowCoordinator")._entries:
		if bool(entry.window.get(str(entry.flag))):
			var close_button: Button = _close_button(entry.panel)
			if close_button != null:
				close_button.pressed.emit()
	await _frames()
	GameState.port_state[home]["inventory"] = {"resource_parts": 7}
	_check(not main.get_node("FirstVoyageGuide").visible, "Order guide cannot overlap docked port menu")
	GameState.ship_state.cargo = []
	port_window._open_section("resources")
	main.get_node("WindowCoordinator")._port_button.pressed.emit()
	port_window._select_transfer_resource("resource_parts")
	port_window._selected_quantity = 3
	await _frames()
	var load_button: Button = port_window._building_list.find_child("Transfer_resource_parts", true, false)
	_check(load_button != null and load_button.is_visible_in_tree() and not load_button.disabled, "Imported spare parts can be loaded at base")
	var score: int = main._career_system.get_activity_score()
	if load_button != null:
		load_button.pressed.emit()
	_check(GameState.port_state[home].inventory.resource_parts == 4, "Loading debits exact warehouse quantity")
	port_window._set_cargo_action("unload")
	port_window._selected_quantity = 3
	await _frames()
	var unload_button: Button = port_window._building_list.find_child("Transfer_resource_parts", true, false)
	_check(unload_button != null and unload_button.is_visible_in_tree(), "Cargo tab offers the actual unload button")
	if unload_button != null:
		unload_button.pressed.emit()
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
	_check(not main.get_node("FirstVoyageGuide").visible, "Order guide cannot overlap an open workspace")
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
	var challenge_window: Node = main.get_module("ChallengeWindow")
	_check(not coordinator._more_panel.visible, "Additional navigation is closed by default")
	_check(coordinator._more_list.get_node_or_null("More_FleetWindow") == null and coordinator._toolbar.get_node_or_null("Menu_FleetShipyard") != null, "Fleet and shipyard use the top navigation entry without a duplicate in More")
	var captain_window: Node = main.get_module("CaptainCabinet")
	captain_window._open = true
	await _frames()
	coordinator._more_button.pressed.emit()
	await _frames()
	_check(coordinator._more_panel.visible, "More menu stays above an open workspace")
	for button in coordinator._more_list.get_children():
		if button is Button and button.text == "Челленджи":
			button.pressed.emit()
	await _frames()
	_check(challenge_window._open, "More menu opens challenge navigation")
	var accepted: bool = false
	for button in challenge_window._content.get_children():
		if button is Button and button.text == "Принять задание":
			button.pressed.emit()
			accepted = true
			break
	_check(accepted and GameState.economy_state.get("challenges", {}).get("slots", {}).has("short"), "Challenge can be accepted through full-scene UI")
	challenge_window._open = false
	await _frames()
	GameState.ship_state.cargo = []
	for good in main._logistics_system.get_goods():
		GameState.ship_state.cargo.append({"resource_id": str(good.id), "quantity": 1})
	await _frames()
	var ship_hud: Node = main.get_node("ShipStatusHUD")
	var cargo_scroll: ScrollContainer = ship_hud._cargo_scroll
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
			var close: Button = _close_button(panel)
			_check(close != null and close.is_visible_in_tree() and bounds.encloses(close.get_global_rect()), "Close button stays inside " + str(window.name) + " panel=" + str(bounds) + " close=" + str(close.get_global_rect() if close != null else Rect2()) + " visible=" + str(close.is_visible_in_tree() if close != null else false))
			if close != null:
				close.pressed.emit()
				await _frames()
				_check(not bool(window.get(str(entry.flag))), "Close works for " + str(window.name))
	main.free()
	SaveSystem.delete_save()
	print("SMOKE checks=%d fail=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
