extends Node

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("COMPANY ACTIVITY: " + message)

func frames(count: int = 6) -> void:
	for index in count: await get_tree().process_frame

func button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text: return child
		var result: Button = button(child, text)
		if result != null: return result
	return null

func capture(id: String) -> void:
	if OS.get_environment("SEA_TRADER_UI_CAPTURE") != "1": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://work/ui-checks")
	get_viewport().get_texture().get_image().save_png("res://work/ui-checks/company_" + id + ".png")

func has_tint(node: Node, tint: Color) -> bool:
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(index)
			if material is StandardMaterial3D and material.albedo_color.is_equal_approx(tint): return true
	for child in node.get_children():
		if has_tint(child, tint): return true
	return false

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1": get_tree().quit(2); return
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	GameState.reset_to_defaults(); SaveSystem.delete_save()
	GameState.player_state.origin_race_id = "humans"
	GameState.player_state.origin_race_confirmed = true
	GameState.world_state.seed = 42; SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate(); add_child(main)
	await frames(10)
	get_tree().paused = false
	main._career_system.set_process(false)
	main.get_node("CombatNotificationHUD")._story_root.hide()
	var clans: Node = main.get_node("ClanSystem")
	var activity: Node = main.get_node("CompanyProgression")
	var ui: Node = main.get_node("SocialWindow")
	var shop: Node = main.get_node("CompanyShop")
	var home: String = str(main.get_node("PortSystem").get_all_port_ids()[0])
	GameState.world_state.home_port_id = home; GameState.ship_state.docked_port_id = home
	GameState.player_state.money = 100000.0
	check(clans.perform("create", {"name": "Хранители горизонта"}).ok, "clan creation still works")
	GameState.player_state.stats.total_deliveries += 3; activity.sample()
	ui.show_page("clan"); ui._clan_tab = "Экспедиции"; ui._refresh(); await frames()
	var view: Node = ui._body.find_child("CompanyActivity_expeditions", true, false)
	check(view != null and view._rows.size() == 5, "five expedition objectives render")
	var key: String = "caravan:%d" % activity.week()
	check(not view._rows[key].action.disabled, "real completed deliveries unlock the reward")
	view._rows[key].action.pressed.emit(); await frames()
	check(int(clans.clan().base.expedition_resource) == 90, "UI claim grants clan resource once")
	ui._clan_tab = "Гавань"; ui._refresh(); await frames()
	view = ui._body.find_child("CompanyActivity_harbor", true, false)
	view._rows.beacon.action.pressed.emit(); await frames()
	check(is_instance_valid(ui._confirmation) and int(clans.clan().base.get("modules", {}).get("beacon", 0)) == 0, "harbor upgrade requires the priced confirmation")
	ui._confirmation._confirm_button.pressed.emit(); await frames()
	check(int(clans.clan().base.modules.beacon) == 1, "confirmed harbor upgrade changes the real base")
	check(clans.seed_test_members(5) == 5 and clans.clan().members.size() == 6, "five authorized local players join the test clan")
	ui._clan_tab = "Участники"; ui._refresh(); await frames()
	await capture("test_members_1280")
	ui._clan_tab = "Экспедиции"; ui._refresh(); await frames()
	view = ui._body.find_child("CompanyActivity_expeditions", true, false)
	var simulation_money: float = float(GameState.player_state.money)
	button(view, "Локальный тест · симулировать рейсы пяти капитанов").pressed.emit(); await frames()
	check(int(clans.clan().base.expedition_resource) == 340 and float(GameState.player_state.money) == simulation_money, "pseudo players earn shared signs without minting personal money")
	ui.show_page("shop"); await frames()
	var shop_view: Node = ui._body.find_child("CompanyShopView", true, false)
	shop_view._filters.cosmetic.pressed.emit(); await frames()
	check(shop_view._cards.size() == 4, "cosmetic category includes permanent bundles")
	shop_view._cards.night_sails.pressed.emit(); await frames()
	var before_money: float = float(GameState.player_state.money)
	var before_ship: Dictionary = GameState.ship_state.duplicate(true)
	shop_view._preview_button.pressed.emit(); await frames()
	var room: Node = ui._fitting
	check(is_instance_valid(room) and is_instance_valid(room._preview._model), "fitting loads the player's real ship model")
	check(room._preview._model.get_meta("company_appearance", []).has("sail_night"), "fitting applies the selected sail style")
	check(has_tint(room._preview._model, Color("354466")), "preview actually recolors the sail material")
	room._night.button_pressed = true; room._original.button_pressed = true; await frames()
	check(room._preview._environment.ambient_light_energy < 0.5, "night setting changes preview lighting")
	check(room._preview._model.get_meta("company_appearance", []).is_empty(), "comparison restores the original model materials")
	check(GameState.ship_state == before_ship and float(GameState.player_state.money) == before_money, "fitting never changes the ship, loadout or money")
	room._original.button_pressed = false
	await capture("fitting_ship_1280")
	button(room, "К покупке").pressed.emit(); await frames()
	check(is_instance_valid(ui._confirmation) and float(GameState.player_state.money) == before_money, "fitting purchase goes through the same price confirmation")
	ui._confirmation._confirm_button.pressed.emit(); await frames()
	check(activity.personal().owned_styles.has("sail_night") and float(GameState.player_state.money) == before_money - 4200, "confirmed style purchase grants permanent ownership")
	shop_view = ui._body.find_child("CompanyShopView", true, false)
	check(shop_view._buy.text == "Установить", "owned style changes purchase into free installation")
	shop_view._buy.pressed.emit(); await frames()
	check(str(activity.personal().equipped.sail) == "sail_night", "owned style installs from the shop")
	check(main.get_node("Approach3DView")._ship.get_meta("company_appearance", []).has("sail_night"), "installed style is visible in the sailing world")
	check(has_tint(main.get_node("Approach3DView")._ship, Color("354466")), "sailing world uses the purchased material rather than just ownership metadata")
	check(shop.purchase("empire_collection").ok, "season cosmetic track opens for ordinary game coins")
	check(activity.perform("season", {"index": 0, "premium": true}).ok, "earned seasonal cosmetic can be claimed")
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = screen; await frames()
		for page in ["season", "collection", "shop"]:
			ui.show_page(page); await frames()
			check(Rect2(Vector2.ZERO, Vector2(screen)).encloses(ui._panel.get_global_rect()), page + " fits " + str(screen))
			check(ui._panel.find_child("WorkspaceScroll", true, false) == null, "no nested workspace scroll in " + page)
			await capture("%s_%d" % [page, screen.x])
		for tab in ["Экспедиции", "Гавань"]:
			ui.show_page("clan"); ui._clan_tab = tab; ui._refresh(); await frames()
			check(ui._body.find_child("ActivityCatalogScroll", true, false) != null, "clan activity has one catalog scroll")
			await capture(("expeditions" if tab == "Экспедиции" else "harbor") + "_%d" % screen.x)
	ui.show_page("shop"); await frames()
	shop_view = ui._body.find_child("CompanyShopView", true, false)
	shop_view._filters.cosmetic.pressed.emit(); await frames()
	shop_view._cards.lantern_harbor.pressed.emit(); await frames()
	shop_view._preview_button.pressed.emit(); await frames()
	room = ui._fitting
	check(room._preview._ship_id == "harbor" and room._preview._model.get_child_count() > 5, "harbor fitting shows the current modular clan base")
	await capture("fitting_harbor_1920")
	room.queue_free(); await frames()
	check(SaveSystem.save_game() and SaveSystem.load_game(), "new progression and collection survive saving")
	check(activity.personal().owned_styles.has("sail_night") and int(clans.clan().base.modules.beacon) == 1, "ownership and base levels survive reload")
	print("COMPANY ACTIVITY checks=%d fail=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
