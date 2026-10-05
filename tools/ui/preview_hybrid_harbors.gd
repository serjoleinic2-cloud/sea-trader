extends Node

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	GameState.reset_to_defaults()
	GameState.player_state.origin_race_id = "humans"
	GameState.player_state.origin_race_confirmed = true
	GameState.world_state.seed = 42
	GameState.world_state.world_gen_version = str(int(GameData.read("res://data/world/world_gen_config.json").version))
	SaveSystem.save_game()
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280,720)
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await _frames(15)
	var coordinator: Node = main.get_node("WindowCoordinator")
	var ports: Node = main.get_node("PortSystem")
	var town: Node = main.get_node("HarborTownView")
	var home: String = str(GameState.world_state.home_port_id)
	if home == "": home = str(ports.get_all_port_ids()[0])
	ports.undock()
	main._ship.global_position = ports.get_port_position(home)
	GameState.ship_state.position = main._ship.global_position
	GameState.ship_state.velocity = Vector2.ZERO
	assert(ports.dock(home))
	await _frames(6)
	coordinator._close_all_workspaces()
	assert(town.visible)
	assert(not main._ship._anchor_prompt.visible)
	GameState.port_state[home].buildings = {}
	town._construction = true
	town._signature = ""
	await _frames(4)
	for site in town._sites:
		assert(not site.sprite.visible and site.plot.visible)
	await _capture("town_empty")
	for level in [1,11,21]:
		for id in town.BUILDINGS:
			GameState.port_state[home].buildings[id] = {"level":level,"status":"active"}
		town._construction = false
		town._signature = ""
		await _frames(4)
		for site in town._sites:
			assert(site.sprite.visible and not site.plot.visible)
			assert(site.annex.visible == (level >= 11))
			assert(site.tower.visible == (level >= 21))
		await _capture("town_level_%d"%level)
	town._construction = true
	town._activate(1)
	await _frames(4)
	assert(bool(main.get_node("BuildingProjectWindow").get("_is_open")))
	coordinator._close_all_workspaces()
	town._construction = false
	town._activate(3)
	await _frames(4)
	assert(main.get_node("PortWindow").visible)
	assert(main.get_node("PortWindow")._current_section == "market")
	coordinator._port_expanded = false
	ports.undock()
	await _frames(3)
	assert(not town.visible)
	# Capture actual 3D sailing at the same entrance, from behind the vessel.
	var island: Dictionary = {}
	for entry in main._navigation_world.islands:
		if bool(entry.get("home_city",false)): island=entry
	assert(not island.is_empty())
	var forward := Vector2.from_angle(float(island.bay_angle))
	var approach: Node = main._approach_view
	GameState.ship_state.position = ports.get_port_position(home)+forward*450
	main._ship.global_position = GameState.ship_state.position
	GameState.ship_state.heading = (-forward).angle()
	main._ship._physics._heading = (-forward).angle()
	approach._manual_close_view = true
	approach._transition_factor = 1.0
	approach._camera_initialized = false
	approach._day_clock = 85.0
	await _frames(35)
	await _capture("approach_day")
	approach._day_clock = 270.0
	await _frames(10)
	await _capture("approach_night")
	print("HYBRID_PREVIEW_OK")
	get_tree().quit()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("SEA_TRADER_UI_OUTPUT")
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder.path_join(name+".png"))

func _frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame
