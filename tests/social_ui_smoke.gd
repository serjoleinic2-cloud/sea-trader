extends Node

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("SOCIAL UI: " + message)

func frames(count: int = 6) -> void:
	for index in count: await get_tree().process_frame

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1": get_tree().quit(2); return
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	GameState.reset_to_defaults(); SaveSystem.delete_save()
	GameState.player_state.origin_race_id = "humans"
	GameState.player_state.origin_race_confirmed = true
	GameState.world_state.seed = 42
	SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate(); add_child(main)
	await frames()
	get_tree().paused = false
	main._career_system.set_process(false)
	main.get_node("CombatNotificationHUD")._story_root.hide()
	var clans: Node = main.get_node("ClanSystem")
	var ui: Node = main.get_node("SocialWindow")
	var sidebar: Node = main.get_node("SocialSidebar")
	var orders: Node = main.get_node("TransportContractWindow")
	var contracts: Node = main.get_node("TransportContractSystem")
	var ports: Node = main.get_node("PortSystem")
	var ids: Array = ports.get_all_port_ids()
	GameState.world_state.home_port_id = str(ids[0])
	GameState.ship_state.docked_port_id = str(ids[0])
	GameState.player_state.discovered_port_ids = ids
	GameState.player_state.money = 100000.0
	GameState.economy_state.transport_contract = {}
	GameState.economy_state.transport_completed = {}
	GameState.ship_state.cargo_capacity = 50
	ui.show_page("clan"); await frames()
	check(ui._panel.visible and ui._body.find_child("ClanName", true, false) != null, "clan onboarding opens with a creation form")
	check(sidebar._menu.get_child_count() == 4 and not sidebar._menu.visible, "four icon buttons stay clear of fullscreen workspaces")
	check(bool(clans.perform("create", {"name": "Союз прибоя", "rules": "Помощь своим морякам"}).ok), "clan creation succeeds")
	await frames()
	check(main.get_node("Approach3DView").get("_scene_root").find_child("ClanHarbor3D", true, false) != null, "founder's base uses the procedural clan harbor")
	for tab in ["Обзор", "Участники", "Бусты", "Чат клана", "Управление"]:
		ui._clan_tab = tab; ui._refresh(); await frames()
		check(ui._body.get_child_count() >= 2, "clan page renders " + tab)
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = screen
		for page in ["clans", "shop", "chat"]:
			ui.show_page(page); await frames()
			check(Rect2(Vector2.ZERO, Vector2(screen)).encloses(ui._panel.get_global_rect()), page + " fits " + str(screen))
			check(ui._panel.position.y > 0 and ui._panel.size.y > float(screen.y) * 0.7, page + " fills screen below HUD")
			if OS.get_environment("SEA_TRADER_UI_CAPTURE") == "1" and page == "shop" and screen.x == 1280:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://work/ui-checks/company_shop.png")
		ui._open = false; orders.open(); await frames()
		check(contracts.get_offers().size() == 10 and orders._offer_list.get_child_count() == 11, "ten choices fill the job board")
		var offers: Array = contracts.get_offers()
		orders._accept_selected(str(offers[0].id)); await frames()
		check(orders._offer_scroll.visible and orders._offer_list.get_child_count() == 11, "active order keeps the other choices visible")
		if OS.get_environment("SEA_TRADER_UI_CAPTURE") == "1" and screen.x == 1280:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/ui-checks/transport_board.png")
		for row in orders._offer_list.get_children():
			if row is PanelContainer:
				var action: Button = row.get_child(0).get_child(4).get_child(0)
				check(action.disabled, "active order cannot be overwritten by another choice")
		GameState.economy_state.transport_contract = {}; orders._open = false
	ui._open = false; GameState.ship_state.docked_port_id = ""; await frames()
	check(sidebar._menu.visible, "sidebar returns while sailing")
	check(bool(clans.perform("boost", {"stat": "speed"}).ok), "leader can activate a boost")
	await frames()
	check(sidebar._boosts.visible and sidebar._boosts.text.contains("Попутный ветер"), "activated boost appears with a screen timer")
	if OS.get_environment("SEA_TRADER_UI_CAPTURE") == "1":
		ui.show_page("clan"); ui._clan_tab = "Обзор"; ui._refresh(); await frames()
		check(not main.get_node("NavigationHUD")._compass_panel.visible, "fullscreen workspace hides the sailing compass")
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://work/ui-checks")
		get_viewport().get_texture().get_image().save_png("res://work/ui-checks/clan_overview.png")
	print("SOCIAL UI checks=%d fail=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
