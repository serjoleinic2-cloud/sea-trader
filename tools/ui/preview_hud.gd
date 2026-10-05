extends Node

## Render the real scene using isolated saves. Never run against player saves.
func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	GameState.reset_to_defaults()
	GameState.player_state["origin_race_id"] = "humans"
	GameState.player_state["origin_race_confirmed"] = true
	GameState.world_state.seed = 42
	SaveSystem.save_game()
	get_tree().root.content_scale_size = Vector2i.ZERO
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await _frames(30)
	var coordinator: Node = main.get_node("WindowCoordinator")
	var output: String = OS.get_environment("SEA_TRADER_UI_OUTPUT")
	if output.is_empty():
		output = "res://outputs/ui"
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(720, 960)]:
		get_tree().root.size = resolution
		await _frames(8)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("hud_%dx%d.png" % [resolution.x, resolution.y]))
		var menu: HBoxContainer = coordinator._toolbar
		var stock: HBoxContainer = coordinator._resource_bar
		var menu_rect := Rect2(menu.position, menu.size * menu.scale)
		var stock_rect := Rect2(stock.position, stock.size * stock.scale)
		assert(not menu_rect.intersects(stock_rect), "Top menu and resources overlap")
		assert(menu_rect.end.x <= resolution.x and stock_rect.end.x <= resolution.x, "HUD overflows viewport")
	get_tree().root.size = Vector2i(1280, 720)
	coordinator._toolbar.get_node("Menu_CaptainCabinet").pressed.emit()
	await _frames(8)
	assert(bool(main.get_node("CaptainCabinet").get("_open")), "Captain button opens cabinet")
	var cabinet: Node = main.get_node("CaptainCabinet")
	assert(cabinet._panel.get_global_rect().encloses(cabinet._left_panel.get_global_rect()), "Captain text panel fits cabin art")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("captain_1280x720.png"))
	coordinator._close_all_workspaces()
	coordinator._toolbar.get_node("Menu_TransportContractWindow").pressed.emit()
	await _frames(8)
	assert(bool(main.get_node("TransportContractWindow").get("_open")), "Tasks button opens contracts")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("tasks_1280x720.png"))
	print("HUD_PREVIEW_OK ", output)
	get_tree().quit()

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame
