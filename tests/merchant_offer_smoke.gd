extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MERCHANT UI: " + message)

func frames(count: int = 5) -> void:
	for index in count:
		await get_tree().process_frame

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	await frames(1)
	var hovered: Control = get_viewport().gui_get_hovered_control()
	check(hovered == button or (hovered != null and button.is_ancestor_of(hovered)), "mouse reaches " + str(button.name))
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
		await frames(2)

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	GameState.reset_to_defaults()
	GameState.player_state.origin_race_id = "crystari"
	GameState.player_state.origin_race_confirmed = true
	GameState.world_state.seed = 42
	SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await frames(10)
	main._career_system.set_process(false)
	get_tree().paused = false
	main.get_node("CombatNotificationHUD")._story_root.hide()
	var merchant: Node = main.get_node("MerchantVisitSystem")
	merchant.set_process(false)
	var hud: Node = main.get_node("MerchantOfferHUD")
	var coordinator: Node = main.get_node("WindowCoordinator")
	var home: String = str(main.get_node("PortSystem").get_all_port_ids()[0])
	GameState.world_state.home_port_id = home
	GameState.ship_state.docked_port_id = home
	GameState.player_state.money = 1000.0
	GameState.port_state[home] = {"inventory": {"resource_parts": 10, "resource_timber": 20}, "buildings": {}}
	var now: int = int(Time.get_unix_time_from_system())
	GameState.economy_state.merchant = {"active_offer": {}, "next_offer_at": now + 1200, "offer_index": 0, "sell_orders": []}
	await frames()
	check(hud._button.is_visible_in_tree() and not hud._button.get_meta("offer_active"), "passive badge is visible without a merchant")
	check(not hud._panel.visible, "offer never opens automatically")
	await click(hud._button)
	check(hud._panel.visible and hud._label.text.contains("Следующее предложение"), "passive badge explains the waiting time")
	check(not hud._buy_button.visible, "waiting panel cannot buy a missing offer")
	await click(hud._close_button)
	var listed: Dictionary = merchant.create_sell_order("resource_timber", 8, 10.0)
	check(bool(listed.ok), "sell-order fixture is reserved")
	GameState.economy_state.merchant.active_offer = merchant._make_supplier_offer(0, now)
	await frames()
	check(hud._button.get_meta("offer_active") and hud._button.text.contains("Есть предложение"), "new offer activates the persistent badge")
	check(not hud._panel.visible, "new merchant leaves the sea view unobstructed")
	coordinator._toggle_extra_resources()
	await frames()
	check(hud.layer < coordinator.layer, "resource dropdown opens above the merchant badge")
	coordinator._toggle_extra_resources()
	await frames()
	check(hud.layer > coordinator.layer, "badge returns above normal workspaces after closing the dropdown")
	coordinator._open_market()
	await frames()
	var market_close: Button = main.get_node("PortWindow")._market_workspace.get_parent().find_child("MarketCloseButton", true, false)
	check(not hud._button.get_global_rect().intersects(market_close.get_global_rect()), "persistent badge leaves the market close button accessible: badge=%s close=%s" % [hud._button.get_global_rect(), market_close.get_global_rect()])
	await click(hud._button)
	check(hud._panel.visible and coordinator._port_expanded, "merchant opens above the market without closing it")
	check(hud._label.text.contains("Запчасти") and hud._label.text.contains("45"), "offer clearly names the goods and unit price")
	hud._slider.value = 2
	await frames()
	await click(hud._buy_button)
	check(is_equal_approx(float(GameState.player_state.money), 910.0), "purchase charges the selected quantity once")
	check(GameState.port_state[home].inventory.resource_parts == 12, "merchant delivers purchased goods to the home warehouse")
	check(hud._notice_label.text.contains("× 2") and hud._notice_label.text.contains("90"), "purchase leaves a clear receipt")
	var offer_after_purchase: Dictionary = merchant.get_active_offer().duplicate(true)
	await click(hud._close_button)
	check(merchant.get_active_offer() == offer_after_purchase, "closing the window preserves the offer")
	await click(hud._button)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	get_viewport().push_input(escape, true)
	await frames()
	check(not hud._panel.visible and coordinator._port_expanded, "Escape closes only the offer, keeping the market open")
	await click(hud._button)
	await click(hud._decline_button)
	check(merchant.get_active_offer().is_empty() and not hud._panel.visible, "decline clears the current offer and closes its panel")
	check(not hud._button.get_meta("offer_active") and hud._button.is_visible_in_tree(), "decline returns the badge to its passive state")
	check(is_equal_approx(float(GameState.player_state.money), 910.0) and GameState.port_state[home].inventory.resource_parts == 12, "decline changes neither money nor warehouse stock")
	check(merchant.get_reserved_quantity("resource_timber") == 8, "decline keeps the player's sell orders")
	check(SaveSystem.load_game() and merchant.get_active_offer().is_empty(), "declined offer stays declined after loading")
	check(int(merchant.get_next_offer_at()) > now and merchant.get_reserved_quantity("resource_timber") == 8, "waiting time and reservations survive loading")
	check(not bool(merchant.decline_offer().ok), "an absent offer cannot be declined twice")
	var market: Node = main.get_node("TradeLineSystem")
	var destination := "merchant_buyer"
	while not market._port_accepts(destination, "resource_timber"):
		destination += "x"
	GameState.port_state[destination] = {"market_stock": {}}
	var order: Dictionary = merchant.get_sell_orders()[0]
	order["destination_port_id"] = destination
	GameState.economy_state.merchant.active_offer = merchant._make_buyer_offer(order, 2, now)
	await frames()
	await click(hud._button)
	check(hud._buy_button.text == "Продать торговцу", "buyer offer uses a sale action instead of a misleading buy action")
	hud._slider.value = 2
	await frames()
	var timber_before: int = int(GameState.port_state[home].inventory.resource_timber)
	var money_before: float = float(GameState.player_state.money)
	await click(hud._buy_button)
	check(is_equal_approx(float(GameState.player_state.money), money_before + 20) and int(GameState.port_state[home].inventory.resource_timber) == timber_before - 2, "buyer pays for and removes the selected goods")
	check(merchant.get_reserved_quantity("resource_timber") == 6, "buyer reduces the existing reservation")
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = screen
		await frames()
		var bounds := Rect2(Vector2.ZERO, Vector2(screen))
		check(bounds.encloses(hud._panel.get_global_rect()), "offer fits viewport " + str(screen))
		check(hud._button.position.y >= coordinator._top_height, "badge stays below the main menu")
		check(hud._panel.get_global_rect().encloses(hud._decline_button.get_global_rect()) and hud._panel.get_global_rect().encloses(hud._buy_button.get_global_rect()), "both actions fit inside the offer")
		if OS.get_environment("SEA_TRADER_UI_CAPTURE") == "1" and screen.x == 1280:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://work/ui-checks")
			get_viewport().get_texture().get_image().save_png("res://work/ui-checks/merchant_offer.png")
	hud._selected_quantity = 4
	GameState.economy_state.merchant.active_offer = merchant._make_supplier_offer(1, now + 1)
	await frames()
	check(hud._selected_quantity == 1, "a new merchant resets the selected quantity")
	GameState.player_state.money = 0
	await frames()
	check(hud._buy_button.disabled, "unaffordable purchase is disabled")
	GameState.economy_state.merchant.active_offer.expires_at = now - 1
	await frames()
	check(not hud._button.get_meta("offer_active") and not hud._buy_button.visible, "expired offer returns to passive state with no purchase action")
	GameState.player_state.money = 1000
	GameState.economy_state.merchant.active_offer = merchant._make_supplier_offer(0, now + 2)
	await frames()
	hud._slider.value = 5
	await frames()
	await click(hud._buy_button)
	check(not hud.has_active_offer() and hud._notice_label.is_visible_in_tree() and hud._notice_label.text.contains("× 5"), "buying the entire offer keeps the receipt visible while the badge becomes passive")
	print("MERCHANT UI checks=%d fail=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
