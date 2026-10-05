extends Node

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1": get_tree().quit(2); return
	GameState.reset_to_defaults()
	GameState.player_state.origin_race_id = "meridians"
	GameState.player_state.origin_race_confirmed = true
	GameState.player_state.money = 5000
	GameState.world_state.seed = 42
	SaveSystem.save_game()
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280,720)
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await _frames(12)
	var ports: Node = main.get_node("PortSystem")
	var home: String = str(GameState.world_state.home_port_id)
	if home == "": home = str(ports.get_all_port_ids()[0])
	GameState.world_state.home_port_id = home
	ports.undock()
	main._ship.global_position = ports.get_port_position(home)
	GameState.ship_state.position = main._ship.global_position
	assert(ports.dock(home))
	await _frames(4)
	var coordinator: Node = main.get_node("WindowCoordinator")
	coordinator._close_all_workspaces()
	preload("res://systems/ui/ship_inspection_window.gd").show_ship(self,"ship_combat_cutter")
	await _frames(8)
	var viewer: Node = get_tree().get_first_node_in_group("ship_inspection_window")
	assert(viewer._model != null)
	await _capture("ship_inspection")
	for ship in GameData.get_ships():
		viewer.open_ship(str(ship.id))
		assert(viewer._model != null,"every catalog ship must have a real model")
		await _frames(1)
	viewer._close()
	assert(viewer._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	main.get_node("BuildingProjectWindow").open_for_building("warehouse")
	await _frames(8)
	await _capture("building_card")
	coordinator._close_all_workspaces()
	var foreign: String = ""
	for id in ports.get_all_port_ids():
		if str(id) != home: foreign=str(id); break
	assert(foreign != "")
	ports.undock()
	main._ship.global_position = ports.get_port_position(foreign)
	GameState.ship_state.position = main._ship.global_position
	assert(ports.dock(foreign))
	await _frames(4)
	var port: Node = main.get_node("PortWindow")
	coordinator._port_expanded = true
	port._market_view = "port"
	port._open_section("market")
	port._market_view = "port"
	GameState.port_state[foreign]["market_stock"] = {"resource_rope":20,"resource_fabric":12,"resource_nails":30,"resource_glass":8}
	port._rebuild_market_list(foreign)
	var test_good: String = ""
	for good in GameData.read("res://data/resources/goods_catalog.json").resources:
		if bool(main.get_node("TradeLineSystem").get_market_info(foreign,str(good.id)).accepted): test_good=str(good.id); break
	assert(test_good != "")
	GameState.port_state[foreign].market_stock[test_good] = 1
	port._select_market_resource(test_good)
	await _frames(4)
	var cargo_before: int = port._transfers.cargo_total()
	port._buy_one_unit()
	assert(port._transfers.cargo_total() == cargo_before+1,"buy control still works")
	port._market_view = "personal"
	GameState.port_state[foreign].market_stock[test_good] = 0
	port._sell_one_unit()
	assert(port._transfers.cargo_total() == cargo_before,"sell control still works")
	port._market_view = "port"
	port._rebuild_market_list(foreign)
	for race in ["humans","nerids","surr","meridians","aery","crystari"]:
		GameState.port_state[foreign]["owner_race_id"] = race
		await _frames(6)
		assert(port._merchant_art.texture != null)
		assert(port._merchant_race == race,"merchant follows port owner, not player")
		await _capture("trade_"+race)
	# Scrolling keeps the purchase/sale controls reachable at laptop resolution.
	port._port_scroll.scroll_vertical = 10000
	await _frames(3)
	await _capture("trade_controls")
	get_tree().root.size = Vector2i(1920,1080)
	await _frames(5)
	port._port_scroll.scroll_vertical = 0
	await _frames(3)
	await _capture("trade_1080")
	print("TRADE_SHIPS_PREVIEW_OK")
	get_tree().quit()

func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func _capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("SEA_TRADER_UI_OUTPUT")
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder.path_join(id+".png"))
