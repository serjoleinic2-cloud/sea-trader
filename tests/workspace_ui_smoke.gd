extends Node

## Exercise the real fleet/market services through the new interface.
## Run only in an isolated project/profile, never against a player's save.
var _checks := 0
var _failed := 0

func check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed += 1
		push_error("WORKSPACE UI: " + message)

func frames() -> void:
	for index in range(8):
		await get_tree().process_frame

func capture(name_value: String) -> void:
	if OS.get_environment("SEA_TRADER_UI_CAPTURE") != "1":
		return
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://workspace_" + name_value + ".png")

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	GameState.reset_to_defaults()
	GameState.player_state.origin_race_id = "crystari"
	GameState.player_state.origin_race_confirmed = true
	GameState.world_state.seed = 42
	SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await frames()
	var career: Node = get_tree().get_first_node_in_group("career_system")
	career._career_reward_test_pending = false
	career.set_process(false)
	get_tree().paused = false
	var ports: Node = main.get_node("PortSystem")
	var home: String = str(ports.get_all_port_ids()[0])
	GameState.world_state.home_port_id = home
	GameState.port_state[home] = {"inventory": {}, "buildings": {}, "level": 4, "discovered": true}
	for port_id in ports.get_all_port_ids():
		if str(port_id) != home:
			GameState.player_state.discovered_port_ids.append(str(port_id))
			GameState.port_state[str(port_id)] = {"market_stock": {"resource_timber": 10, "resource_fish": 10}, "inventory": {}, "buildings": {}, "level": 1, "discovered": true}
	GameState.ship_state.docked_port_id = home
	GameState.player_state.money = 100000
	GameState.progression_state.career = {"highest_rank": 29, "highest_rewarded_rank": 29, "rank_floor_activity": 460, "last_activity": 479}
	GameState.port_state[home]["buildings"] = GameState.port_state[home].get("buildings", {})
	GameState.port_state[home]["buildings"]["shipyard"] = {"level": 4, "status": "active"}
	for good in GameData.read("res://data/resources/goods_catalog.json").resources:
		GameState.port_state[home].inventory[str(good.id)] = 10000
	await frames()
	var coordinator: Node = main.get_node("WindowCoordinator")
	var fleet: Node = main.get_node("FleetWindow")
	var garage: Node = fleet._garage
	var shipyard: Node = get_tree().get_first_node_in_group("shipyard_system")
	coordinator._open_fleet_hub()
	await frames()
	check(fleet._is_open and not coordinator._port_expanded, "fleet hub opens fleet workspace at home")
	garage.open_construction()
	garage._set_category("combat")
	garage._select("war_crystari_1")
	check(garage._carousel.get_child_count() == 5, "five own-race cannon ships are directly listed")
	check(shipyard.get_project().is_empty(), "selecting a model never opens a blocking project")
	check(not garage._build.disabled, "rank-one combat ship can be built")
	var opened: Dictionary = shipyard.create_project("ship_sloop")
	check(bool(opened.ok), "existing-project fixture opens")
	garage.refresh()
	check(garage._build.disabled and garage._availability.text.contains("Верфь занята"), "occupied yard explains its restriction visibly")
	check(garage._cancel.visible, "cancel existing project is directly available")
	garage._cancel_project()
	check(shipyard.get_project().is_empty() and not garage._build.disabled, "cancel frees the yard without hidden navigation")
	garage._name_input.text = "Проверка артиллерийского корабля"
	var ship_count: int = GameState.fleet_state.size()
	var timber_before: int = int(GameState.port_state[home].inventory.resource_timber)
	garage._build_ship()
	check(GameState.fleet_state.size() == ship_count + 1, "primary action builds one combat ship")
	var built: Dictionary = fleet._get_selected_ship()
	check(str(built.get("ship_type_id", "")) == "war_crystari_1", "newly built cannon ship is selected")
	check(str(built.get("name", "")) == "Проверка артиллерийского корабля".left(28), "ship name is saved with its length limit")
	check(int(GameState.port_state[home].inventory.resource_timber) == timber_before - 70, "ship materials charged exactly once")
	check(shipyard.get_project().is_empty(), "successful launch leaves yard available")
	await frames()
	var action_buttons: Array[Node] = garage._owned_footer.find_children("*", "Button", true, false)
	check(action_buttons.size() >= 5, "combat ship keeps escort, repair, upgrades, crew and guns outside the detail scroll")
	for action in action_buttons:
		check(action.get_global_rect().end.y <= fleet._panel.get_global_rect().end.y, "primary ship action is visible without scrolling: " + str(action.text))
	await capture("owned_fleet")
	fleet._open_personnel(str(built.instance_id), "military")
	await frames()
	var hiring: Node = main.get_node("HiringWindow")
	var back: Button = hiring._panel.find_child("WorkspaceBackButton", true, false)
	check(hiring._is_open and not fleet._is_open, "crew opens from the selected ship")
	check(back.visible and back.text.contains("Флот"), "crew shows a direct return to fleet")
	back.pressed.emit()
	await frames()
	check(fleet._is_open and not hiring._is_open, "back restores the fleet instead of opening a second window")
	check(str(fleet._get_selected_ship().instance_id) == str(built.instance_id), "back preserves the selected ship")
	garage._set_mode("build")
	garage._set_category("transport")
	check(garage._carousel.get_child_count() == 1, "army transport has its own explicit category")
	garage._set_category("combat")
	garage._select("war_crystari_4")
	check(garage._build.disabled and garage._availability.text.contains("31"), "locked cruiser still shows model and rank requirement")
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.content_scale_size = Vector2i.ZERO
		get_tree().root.size = screen
		await frames()
		check(fleet._panel.scale == Vector2.ONE, "garage layout is not shrunk as a whole")
		check(garage._carousel.get_global_rect().end.y <= screen.y, "ship carousel stays inside the screen")
		check(garage._build.get_global_rect().end.y <= screen.y, "build action remains inside the screen")
		var upgrade: Button = garage._actions.find_children("*", "Button", true, false)[0]
		check(upgrade.size.x >= 100 and upgrade.size.x < garage._actions.size.x, "yard upgrade uses a readable compact button")
		await capture("fleet_%d" % screen.x)
	fleet._is_open = false
	get_tree().root.size = Vector2i(1280, 720)
	var market_checks_before: int = _checks
	var market_failures_before: int = _failed
	var port: Node = main.get_node("PortWindow")
	coordinator._market_button.pressed.emit()
	await frames()
	var market: Node = port._market_workspace
	check(coordinator._port_expanded and port._current_section == "market", "top market button opens trading in one click")
	var market_close: Button = market.get_parent().find_child("MarketCloseButton", true, false)
	check(market_close.get_global_rect().end.x > port._sheet.get_global_rect().end.x - 65, "market close button stays at the fullscreen frame edge")
	check(market.visible and not port._port_scroll.visible, "market replaces the legacy stacked form: %s" % str([port._current_section, market.visible, port._port_scroll.visible]))
	market._set_mode("sell")
	market._choose("resource_fish")
	market._set_quantity(10)
	check(not market._primary.disabled and market._primary.text == "ВЫСТАВИТЬ ЗАЯВКУ", "home sale is explicitly a merchant order")
	var merchant: Node = port._get_merchant_system()
	var reserved_before: int = merchant.get_reserved_quantity("resource_fish")
	market._transact()
	check(merchant.get_reserved_quantity("resource_fish") == reserved_before + 10, "sale order reserves the chosen quantity")
	check(market._receipt.visible and market._notice.text.contains("ЗАЯВКА РАЗМЕЩЕНА") and market._notice.text.contains("10"), "sale order confirms its quantity and waits for the merchant")
	await frames()
	check(market._receipt.get_global_rect().end.y <= 720 and market._notice.size.y >= market._notice.get_minimum_size().y, "sale order receipt fits a small screen without clipping text: %s label=%s minimum=%s" % [market._receipt.get_global_rect(), market._notice.size, market._notice.get_minimum_size()])
	market._set_mode("orders")
	check(market._products.get_child_count() > 0 and not market._primary.visible, "orders are accessible in the same market")
	var orders: Array = merchant.get_sell_orders()
	market._cancel_order(str(orders[orders.size() - 1].id))
	check(merchant.get_reserved_quantity("resource_fish") == reserved_before, "cancel restores merchant-order stock")
	check(market._receipt.is_visible_in_tree(), "order cancellation feedback remains visible in the compact layout")
	market._set_mode("buy")
	var supply: Node = main.get_node("SupplyOrderSystem")
	var purchasable := ""
	for good in supply.get_available_goods():
		if bool(supply.get_quote(str(good.id)).get("ok", false)):
			purchasable = str(good.id)
			break
	check(purchasable != "", "fixture has a known supplier")
	if purchasable != "":
		market._choose(purchasable)
		market._set_quantity(2)
		var money_before: float = float(GameState.player_state.money)
		var quote: Dictionary = supply.get_quote(purchasable, 2)
		var delivery_count: int = supply.get_active_orders().size()
		check(not market._primary.disabled, "delivery can be placed without a second window: " + market._reason.text)
		await capture("home_market")
		market._transact()
		check(supply.get_active_orders().size() == delivery_count + 1, "base purchase schedules delivery")
		check(is_equal_approx(float(GameState.player_state.money), money_before - float(quote.delivery_price) * 2), "delivery quote matches money charged")
		check(market._receipt.visible and market._notice.text.contains("ДОСТАВКА ОПЛАЧЕНА") and market._notice.text.contains("× 2"), "base purchase shows a delivery receipt for the selected quantity")
		check(market._notice.text.contains("Списано: %.0f" % (float(quote.delivery_price) * 2)) and market._notice.text.contains("На склад базы"), "delivery receipt explains the actual charge and destination")
		await frames()
		check(market._receipt.get_global_rect().end.y <= 720 and market._notice.size.y >= market._notice.get_minimum_size().y, "long delivery receipt fits a small screen without clipping text")
		var foreign: String = str(quote.source_port_id)
		GameState.ship_state.docked_port_id = foreign
		await frames()
		port._open_section("market")
		coordinator._port_expanded = true
		await frames()
		market._choose(purchasable)
		market._set_quantity(2)
		var cargo_before: int = port._get_sellable_cargo_quantity(purchasable)
		money_before = float(GameState.player_state.money)
		var purchase: Dictionary = port._transfers._market.quote_purchase(foreign, purchasable, 2)
		check(not market._primary.disabled, "foreign-port purchase is immediately available")
		market._transact()
		check(port._get_sellable_cargo_quantity(purchasable) == cargo_before + 2, "purchased cargo enters the ship")
		check(is_equal_approx(float(GameState.player_state.money), money_before - float(purchase.unit_price) * 2), "purchase charges the service quote")
		check(market._receipt.visible and market._notice.text.contains("КУПЛЕНО") and market._notice.text.contains("× 2"), "foreign purchase visibly confirms what was bought")
		check(market._notice.text.contains("Списано: %.0f" % (float(purchase.unit_price) * 2)) and market._notice.text.contains("в трюме"), "purchase receipt uses the charged amount and confirms cargo location")
		await frames()
		check(market._receipt.get_global_rect().end.y <= 720, "successful purchase receipt fits a small screen")
		var receipt: String = market._notice.text
		market._refresh_products()
		check(market._notice.text == receipt and market._receipt.visible, "automatic refresh preserves the transaction receipt")
		market._set_mode("sell")
		market._choose(purchasable)
		market._set_quantity(2)
		money_before = float(GameState.player_state.money)
		var sale: Dictionary = port._transfers._market.quote_sale(foreign, purchasable, 2)
		check(not market._primary.disabled, "sell action is available on the same screen")
		market._transact()
		check(port._get_sellable_cargo_quantity(purchasable) == cargo_before, "sale removes exactly the selected cargo")
		check(is_equal_approx(float(GameState.player_state.money), money_before + float(sale.revenue)), "sale pays the service quote")
		check(market._notice.text.contains("ПРОДАНО") and market._notice.text.contains("Получено: %.0f" % float(sale.revenue)), "sale receipt reports the actual payment")
		market._set_mode("buy")
		market._choose(purchasable)
		GameState.player_state.money = 0
		market._refresh_details()
		check(market._primary.disabled and market._reason.text.contains("монет"), "insufficient funds has a visible reason")
		market._transact()
		check(market._receipt.visible and market._notice.text.contains("НЕ ВЫПОЛНЕНА") and float(GameState.player_state.money) == 0, "rejected purchase gives an explicit failure receipt")
		GameState.player_state.money = 100000
		market._refresh_details()
		for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			get_tree().root.size = screen
			await frames()
			check(market._primary.get_global_rect().end.y <= port._sheet.get_global_rect().end.y, "market action fits inside its unclipped panel")
			check(market._receipt.get_global_rect().end.y <= port._sheet.get_global_rect().end.y, "transaction feedback stays visible without scrolling")
			check(market._primary.get_global_rect().end.x <= screen.x, "market action stays inside the right edge")
			check(market._transaction_panel.get_global_rect().end.x <= screen.x * 0.65, "compact market leaves the merchant side unobstructed")
			var previous_y := -1.0
			for product in market._products.get_children():
				if product is Button:
					var name_width: float = product.get_theme_font("font").get_string_size(product.text.get_slice("\n", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, product.get_theme_font_size("font_size")).x
					var chrome: float = product.get_theme_stylebox("normal").get_minimum_size().x + (28 + product.get_theme_constant("h_separation") if product.icon != null else 0)
					check(product.position.y > previous_y and is_zero_approx(product.position.x), "goods form one vertical column")
					check(product.size.x >= name_width + chrome, "long resource names fit their compact buttons")
					previous_y = product.position.y
			await capture("market_%d" % screen.x)
	print("MARKET UI checks=%d fail=%d" % [_checks - market_checks_before, _failed - market_failures_before])
	GameState.ship_state.docked_port_id = ""
	fleet._is_open = false
	coordinator._open_fleet_hub()
	check(fleet._is_open, "same fleet workspace opens at sea")
	await frames()
	check(coordinator._market_button.disabled, "market at sea explains docking rather than opening an empty market")
	garage.open_construction()
	garage._select("war_crystari_1")
	check(garage._build.disabled and garage._availability.text.contains("швартовка"), "construction at sea retains catalog and shows docking requirement")
	GameState.ship_state.docked_port_id = home
	await frames()
	port._open_ship_card("ship_sloop")
	await frames()
	check(fleet._is_open and garage.mode == "build" and garage.selected_type == "ship_sloop", "legacy ship links route to the same garage and keep their model")
	check(shipyard.get_project().is_empty(), "legacy navigation does not create a project")
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = screen
		await frames()
		for entry in coordinator._entries:
			var window: Node = entry.window
			coordinator._close_all_workspaces()
			window.set(str(entry.flag), true)
			await frames()
			var panel: Control = entry.panel
			check(is_equal_approx(panel.position.x, 0) and is_equal_approx(panel.size.x, screen.x), "window fills screen width: " + str(window.name))
			check(is_equal_approx(panel.position.y, coordinator._top_height) and is_equal_approx(panel.get_global_rect().end.y, screen.y), "window fits below HUD without clipping: %s %s minimum=%s" % [window.name, panel.get_global_rect(), panel.get_combined_minimum_size()])
			if screen.x == 1280 and str(window.name) in ["HiringWindow", "BuildingProjectWindow", "GarrisonWindow"]:
				await capture(str(window.name).to_lower())
		coordinator._close_all_workspaces()
		coordinator._encyclopedia.open()
		await frames()
		check(coordinator._encyclopedia._panel.size.x == screen.x and coordinator._encyclopedia._panel.get_global_rect().end.y == screen.y, "encyclopedia uses the same fullscreen bounds")
		coordinator._encyclopedia.close_window()
		coordinator._open_fleet_hub()
		await frames()
		fleet._open_armament(str(built.instance_id))
		await frames()
		check(fleet._armament_window._panel.size.x == screen.x and fleet._armament_window._panel.get_global_rect().end.y == screen.y, "ship guns and storage open fullscreen below the HUD")
		fleet._armament_window._close()
		coordinator._close_all_workspaces()
	print("WORKSPACE UI checks=%d fail=%d" % [_checks, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
