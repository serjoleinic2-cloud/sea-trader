extends Node

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("SOCIAL UI: " + message)

func frames(count: int = 6) -> void:
	for index in count: await get_tree().process_frame

func button_with_text(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text: return child
		var found: Button = button_with_text(child, text)
		if found != null: return found
	return null

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
	ui._body.find_child("ClanName", true, false).text = "Союз прибоя"
	ui._body.find_child("ClanRules", true, false).text = "Помощь своим морякам"
	button_with_text(ui._body, "Создать клан").pressed.emit()
	await frames()
	var confirmation: Node = ui._confirmation
	check(is_instance_valid(confirmation) and confirmation.layer > 130, "creation confirmation opens above the HUD")
	check(float(GameState.player_state.money) == 100000.0 and clans.clan().is_empty(), "opening confirmation does not charge or create a clan")
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = screen; await frames()
		check(Rect2(Vector2.ZERO, Vector2(screen)).encloses(confirmation._panel.get_global_rect()), "confirmation fits " + str(screen))
		check(confirmation._title.get_global_rect().end.y <= confirmation._message.get_global_rect().position.y, "title does not overlap confirmation text")
		check(confirmation._message.get_global_rect().end.y <= confirmation._confirm_button.get_global_rect().position.y, "confirmation text stays above its actions")
		check(not confirmation._cancel_button.get_global_rect().intersects(confirmation._confirm_button.get_global_rect()), "confirmation buttons do not overlap")
		if OS.get_environment("SEA_TRADER_UI_CAPTURE") == "1" and screen.x == 1280:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://work/ui-checks")
			get_viewport().get_texture().get_image().save_png("res://work/ui-checks/clan_confirmation.png")
	confirmation._cancel_button.pressed.emit(); await frames()
	check(float(GameState.player_state.money) == 100000.0 and clans.clan().is_empty(), "cancel preserves the treasury and clan state")
	button_with_text(ui._body, "Создать клан").pressed.emit(); await frames()
	confirmation = ui._confirmation
	confirmation._confirm_button.pressed.emit()
	confirmation._confirm_button.pressed.emit()
	await frames()
	check(not clans.clan().is_empty() and float(GameState.player_state.money) == 95000.0, "confirm creates the clan and charges once, including a repeated click")
	ui._confirm("Проверка отмены клавишей Esc", func() -> void: check(false, "Escape must never confirm")); await frames()
	var escape := InputEventKey.new(); escape.pressed = true; escape.keycode = KEY_ESCAPE
	get_viewport().push_input(escape, true); await frames()
	check(not is_instance_valid(ui._confirmation) and ui._open, "Escape closes the confirmation while keeping the clan page open")
	check(main.get_node("Approach3DView").get("_scene_root").find_child("ClanHarbor3D", true, false) != null, "founder's base uses the procedural clan harbor")
	for tab in ["Обзор", "Участники", "Бусты", "Чат клана", "Управление"]:
		ui._clan_tab = tab; ui._refresh(); await frames()
		check(ui._body.get_child_count() >= 2, "clan page renders " + tab)
		if tab == "Бусты":
			var grid: GridContainer = ui._body.find_child("ClanBoostTiles", true, false)
			check(grid != null and grid.get_child_count() == 5, "five clan boosts use illustrated tiles")
			for tile in grid.get_children():
				check(tile._image.texture != null and tile._image.texture.resource_path.contains("painted_v1"), "tile has transparent painted artwork")
				check(tile._action.size.x < tile.size.x and tile._action.get_theme_font("font") == preload("res://systems/ui/game_ui_theme.gd").button_font(), "tile action is compact and uses the HUD font")
			var fuel: Node = grid.get_children().filter(func(tile): return str(tile.get_meta("boost_id")) == "fuel")[0]
			check(fuel._effect.text.begins_with("-"), "reduced fuel consumption is displayed with a minus sign")
			if OS.get_environment("SEA_TRADER_UI_CAPTURE") == "1":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://work/ui-checks/clan_boost_tiles.png")
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = screen
		for page in ["clans", "shop", "chat"]:
			ui.show_page(page); await frames()
			check(Rect2(Vector2.ZERO, Vector2(screen)).encloses(ui._panel.get_global_rect()), page + " fits " + str(screen))
			check(ui._panel.position.y > 0 and ui._panel.size.y > float(screen.y) * 0.7, page + " fills screen below HUD")
			if page == "shop":
				var view: Node = ui._body.find_child("CompanyShopView", true, false)
				var balance: float = float(GameState.player_state.money)
				check(view != null and view._cards.size() == main.get_node("CompanyShop").catalog().size() and view._filters.size() == 8, "shop separates categories, catalog and preview")
				check(ui._panel.find_child("WorkspaceScroll", true, false) == null, "shop has no outer nested workspace scroll")
				check(view._buy.get_global_rect().end.y <= float(screen.y) - 8, "purchase action stays visible at " + str(screen))
				view._filters.boost_pack.pressed.emit(); await frames()
				check(view._cards.size() == 2 and view._cards.has("voyage_scrolls") and view._cards.has("artillery_scrolls"), "boost category filters the real catalog")
				view._cards.artillery_scrolls.pressed.emit(); await frames()
				check(view._detail_title.text == "Набор артиллериста" and view._detail_image.texture.resource_path.ends_with("damage.png"), "selection updates the matching large artwork")
				check(float(GameState.player_state.money) == balance, "category and product selection never spend money")
				view._filters.local_model.pressed.emit(); await frames()
				check(view._cards.size() == 2 and view._buy.disabled and view._detail_reason.visible, "uninstalled local models cannot be purchased")
				view._filters.all.pressed.emit(); await frames()
				view._cards.voyage_scrolls.pressed.emit(); await frames()
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
	ui.show_page("shop"); await frames()
	var shop_view: Node = ui._body.find_child("CompanyShopView", true, false)
	shop_view._cards.voyage_scrolls.pressed.emit(); await frames()
	var before_buy: float = float(GameState.player_state.money)
	var before_scrolls: int = int(GameState.economy_state.get("rewards", {}).get("boosts", {}).get("fair_wind", 0))
	shop_view._buy.pressed.emit(); await frames()
	check(is_instance_valid(ui._confirmation) and float(GameState.player_state.money) == before_buy, "shop opens a confirmation before charging")
	ui._confirmation._cancel_button.pressed.emit(); await frames()
	check(float(GameState.player_state.money) == before_buy, "cancelled shop purchase preserves money")
	shop_view._buy.pressed.emit(); await frames()
	ui._confirmation._confirm_button.pressed.emit(); await frames()
	check(float(GameState.player_state.money) == before_buy - 1040.0, "confirmed purchase charges the displayed price once")
	check(int(GameState.economy_state.rewards.boosts.fair_wind) == before_scrolls + 2, "confirmed pack grants the catalog contents")
	check(ui._body.find_child("CompanyShopView", true, false)._selected == "voyage_scrolls", "purchase refresh preserves the selected product")
	var font_ok: bool = true
	for button in main.find_children("*", "Button", true, false):
		font_ok = font_ok and button.get_theme_font("font") == preload("res://systems/ui/game_ui_theme.gd").button_font()
	check(font_ok, "all existing buttons share the upper-menu sans font, including portrait cards")
	var styling := preload("res://systems/ui/game_ui_theme.gd").new()
	for control in [Button.new(), OptionButton.new(), CheckButton.new(), CheckBox.new(), MenuButton.new()]:
		control.text = "Проверка"
		control.set_meta("preserve_art_style", true)
		control.add_theme_font_override("font", SystemFont.new())
		styling.apply_control(control)
		check(control.get_theme_font("font") == styling.button_font(), "button variants share the HUD font even with preserved artwork")
		control.free()
	check(styling.get_theme().get_font("font", "PopupMenu") == styling.button_font(), "dropdown entries use the shared font")
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
	ui._open = false
	var challenges: Node = main.get_node("ChallengeWindow")
	challenges.open(); await frames()
	var reward_grid: GridContainer = challenges._content.find_child("RewardBoostTiles", true, false)
	check(reward_grid != null and reward_grid.get_child_count() == 5, "reward inventory uses five illustrated boost tiles")
	var wind: Node = reward_grid.get_child(0)
	check(wind._action.disabled == false, "purchased wind scroll is available for activation")
	wind._action.pressed.emit(); await frames()
	check(float(GameState.economy_state.rewards.active_boost.seconds_remaining) > 0, "reward tile activates the real timed effect")
	reward_grid = challenges._content.find_child("RewardBoostTiles", true, false)
	var grid_id: int = reward_grid.get_instance_id()
	GameState.economy_state.rewards.active_boost.seconds_remaining -= 3.0
	challenges._process(1.1); await frames()
	check(challenges._content.find_child("RewardBoostTiles", true, false).get_instance_id() == grid_id, "countdown updates keep the existing tiles and scroll position")
	check(reward_grid.get_child(0)._action.disabled and reward_grid.get_child(0)._action.text == "Действует", "active scroll shows its running state and blocks repeat activation")
	print("SOCIAL UI checks=%d fail=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
