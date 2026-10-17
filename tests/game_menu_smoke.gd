extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GAME MENU: " + message)

func frames() -> void:
	for frame in range(8):
		await get_tree().process_frame

func capture(label_value: String) -> void:
	if OS.get_environment("SEA_TRADER_UI_CAPTURE") == "1":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://menu_" + label_value + ".png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	GameState.reset_to_defaults()
	GameState.player_state.origin_race_id = "humans"
	GameState.player_state.origin_race_confirmed = true
	GameState.world_state.seed = 42
	SaveSystem.save_game()
	# This driver persists beside the real current scene, including after load.
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")
	await frames()
	var main: Node = get_tree().current_scene
	if main == null:
		check(false, "game scene starts")
		get_tree().quit(1)
		return
	main._career_system.set_process(false)
	get_tree().paused = false
	var coordinator: Node = main.get_node("WindowCoordinator")
	var menu: Node = coordinator.get_node("GameMenu")
	var port: Node = main.get_node("PortWindow")
	var home: String = str(main._navigation_world.ports.keys()[0])
	GameState.world_state.home_port_id = home
	GameState.ship_state.docked_port_id = home
	GameState.port_state[home] = {"level": 2, "inventory": {}, "buildings": {}}
	await frames()
	port._open_section("construction")
	coordinator._port_expanded = true
	await frames()
	check(port._details.get_parent() == port._construction_details_column, "building description remains on the left")
	check(port._leave_button.get_parent() == port._construction_details_column, "undock is under the description, outside the gallery")
	check(port._leave_button.size.x < 260, "undock is compact")
	check(port._building_grid.columns >= 2, "building gallery uses several columns")
	for button in port._root.find_children("*", "Button", true, false):
		check(button.text != "Сохранить игру", "save no longer consumes a construction row")
	var first_card: Control = port._building_grid.get_child(0)
	check(first_card.size.y < 290, "building cards do not reserve large empty panels")
	check(port._content_scroll.size.y > 300, "gallery receives the available window height")
	check(port._leave_button.get_global_rect().end.y < port._bottom_menu.get_global_rect().position.y, "bottom navigation does not cover the undock button")
	check(port._content_scroll.get_global_rect().end.y <= port._bottom_menu.get_global_rect().position.y, "gallery ends above the port navigation")
	await capture("construction")
	port._open_section("resources")
	await frames()
	check(port._leave_button.get_parent() == port._column, "other sections retain their undock action")
	port._open_section("construction")
	await frames()
	var navigation: Node = main.get_node("NavigationHUD")
	var known_port: String = str(main._navigation_world.ports.keys()[1])
	GameState.player_state.discovered_port_ids = [home, known_port]
	navigation._toggle_panel()
	await frames()
	var known_button: Button = navigation._destination_list.get_child(0)
	known_button.pressed.emit()
	await frames()
	check(str(GameState.world_state.get("destination_port_id", "")) == known_port, "known-port button really sets a course")
	check(navigation._is_open and navigation._panel.visible, "selecting a known port keeps the map open")
	navigation._set_home_destination()
	check(str(GameState.world_state.get("destination_port_id", "")) == home, "home button really changes the course")
	navigation._center_chart_on_ship()
	await frames()
	check(navigation._is_open and navigation._panel.visible, "home and center buttons keep the map open")
	navigation._toggle_panel()
	await frames()
	coordinator._open_game_menu()
	await frames()
	check(menu._is_open and get_tree().paused, "menu opens and pauses the existing world")
	check(coordinator._port_expanded, "closing menu can return to the construction workspace")
	var renderer: Node = main.get_node("Approach3DView")
	menu._show_section("graphics")
	var vsync: Button = menu._content.find_child("Setting_vsync", true, false)
	var antialiasing: Button = menu._content.find_child("Setting_antialiasing", true, false)
	var clouds: Button = menu._content.find_child("Setting_clouds_enabled", true, false)
	check(vsync != null and antialiasing != null and clouds != null, "VSync, edge smoothing, and clouds have visible game-styled toggles")
	if vsync != null:
		check(vsync.text in ["Вкл", "Выкл"] and vsync.get_theme_stylebox("hover") != null, "VSync toggle keeps its framed hover style")
	if antialiasing != null:
		check(antialiasing.text in ["Вкл", "Выкл"] and antialiasing.get_theme_stylebox("hover") != null, "edge-smoothing toggle keeps its framed hover style")
	check(not bool(GameState.settings_state.get("clouds_enabled", true)), "clouds remain off by default")
	if clouds != null:
		clouds.button_pressed = true
		clouds.toggled.emit(true)
		menu._apply_settings()
		check(bool(renderer._sky_material.get_shader_parameter("clouds_enabled")), "cloud toggle enables sky clouds")
		clouds.button_pressed = false
		clouds.toggled.emit(false)
		menu._apply_settings()
		check(not bool(renderer._sky_material.get_shader_parameter("clouds_enabled")), "cloud toggle disables sky clouds")
	var water: HSlider = menu._content.find_child("Setting_water_quality", true, false)
	water.value = 0
	water.value_changed.emit(0)
	var resolution: OptionButton = menu._content.find_child("Setting_render_scale", true, false)
	resolution.select(1)
	resolution.item_selected.emit(1)
	menu._apply_settings()
	var wake: OptionButton = menu._content.find_child("Setting_ship_wake_quality", true, false)
	check(wake!=null,"independent ship wake quality control exists")
	wake.select(0);wake.item_selected.emit(0);menu._apply_settings()
	check(renderer._wake._quality=="off","wake control switches the real renderer off")
	wake.select(2);wake.item_selected.emit(2);menu._apply_settings()
	check(renderer._wake._quality=="high","detailed wake applies without changing water")
	check(renderer._water.material_override is StandardMaterial3D, "simple ocean changes the actual water renderer")
	check(is_equal_approx(renderer._subviewport.scaling_3d_scale, 0.85), "3D resolution setting applies")
	water.value = 1
	menu._apply_settings()
	check(renderer._water.material_override == renderer._balanced_water_material, "medium selects the no-refraction wave shader")
	check(renderer._water.mesh.subdivide_width == 95, "medium uses a smaller wave grid")
	water.value = 2
	menu._apply_settings()
	check(renderer._water.material_override == renderer._water_material, "maximum restores refracted waves")
	check(renderer._water.mesh.subdivide_width == 127, "maximum uses the detailed wave grid")
	var distance: OptionButton = menu._content.find_child("Setting_view_distance", true, false)
	distance.select(0)
	distance.item_selected.emit(0)
	menu._apply_settings()
	check(is_equal_approx(renderer._view_distance, 320.0), "near view-distance profile is applied")
	check(renderer._environment.fog_enabled and renderer._environment.fog_depth_begin < renderer._environment.fog_depth_end, "depth haze has a gradual distance band")
	check(renderer._camera.far > renderer._environment.fog_depth_end, "far clipping occurs behind opaque horizon haze")
	check(not renderer._environment.volumetric_fog_enabled, "haze does not enable expensive volumetric fog")
	menu._show_section("sound")
	var volume: HSlider = menu._content.find_child("Setting_sfx_volume", true, false)
	volume.value = 0
	menu._apply_settings()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "effects slider really mutes the effects bus")
	check(is_equal_approx(float(GameState.settings_state.sfx_volume), 0.0), "sound setting is persistent state")
	menu._show_section("controls")
	check(menu._content.find_child("Setting_control_sensitivity", true, false) is HSlider, "input settings are available beside the keyboard guide")
	menu._show_section("graphics")
	menu._draft.water_quality = "high"
	menu._draft.render_scale = 1.0
	menu._draft.sfx_volume = 0.8
	menu._apply_settings()
	check(renderer._water.material_override is ShaderMaterial, "detailed ocean can be restored")
	menu._show_section("graphics")
	await capture("graphics")
	menu._show_section("save")
	GameState.player_state.money = 777
	menu._save_game()
	check(menu._status.text == "Игра сохранена.", "save acknowledges a successful write")
	GameState.player_state.money = 111
	menu._request_load()
	check(menu._content.find_child("ConfirmLoad", true, false) is Button, "load requires an explicit in-game confirmation")
	check(float(GameState.player_state.money) == 111, "opening confirmation does not replace current progress")
	menu._show_section("save")
	menu.close_menu()
	await frames()
	check(not menu._is_open and not get_tree().paused, "continue releases the pause")
	check(port._construction_workspace.visible, "construction stays usable after leaving settings")
	menu.open_menu()
	menu._request_load()
	# Keep this test driver alive while the real main scene is replaced.
	menu._load_game()
	await frames()
	await frames()
	var restored_main: Node = get_tree().current_scene
	check(is_instance_valid(restored_main) and restored_main != main, "confirming load rebuilds the actual game scene")
	check(float(GameState.player_state.money) == 777, "manual save restores the expected progress")
	check(str(GameState.settings_state.water_quality) == "high", "graphics settings survive save/load")
	check(str(GameState.settings_state.ship_wake_quality) == "high", "independent wake setting survives save/load")
	check(not get_tree().paused, "loading resumes the restored world")
	print("GAME MENU checks=%d fail=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
