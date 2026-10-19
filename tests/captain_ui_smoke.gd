extends Node

## Full-scene checks for header alignment, uncropped portraits and ceremony replay.
var _checks := 0
var _failures := 0

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("CAPTAIN UI SMOKE: " + message)

func _frames() -> void:
	for frame in range(6):
		await get_tree().process_frame

func _capture(name: String) -> void:
	if OS.get_environment("SEA_TRADER_UI_CAPTURE") != "1":
		return
	await get_tree().create_timer(0.8, true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://work/ui-checks")
	get_viewport().get_texture().get_image().save_png("res://work/ui-checks/" + name + ".png")

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_to_defaults()
	GameState.player_state["origin_race_id"] = "nerids"
	GameState.player_state["origin_race_confirmed"] = true
	GameState.world_state.seed = 42
	SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await _frames()
	var career: Node = get_tree().get_first_node_in_group("career_system")
	career._career_reward_test_start_distance = float(GameState.player_state.stats.get("total_distance", 0.0))
	career._career_reward_test_distance = 2.0
	career._career_reward_test_pending = true
	GameState.player_state.stats["total_distance"] += 2.0
	career._process(0.5)
	var hud: Node = career.get_node("CareerNotificationHUD")
	var ceremony: Control = hud.get_node("RankCelebration")
	_check(ceremony.visible and get_tree().paused, "test distance opens a medal ceremony")
	_check(hud._ceremony_medal.texture != null, "promotion displays a medal")
	await _capture("rank_ceremony")
	hud._close_ceremony()
	await _frames()
	_check(not ceremony.visible and not career._career_reward_test_pending, "closing consumes the test")
	var cabinet: Node = main.get_node("CaptainCabinet")
	var coordinator: Node = main.get_node("WindowCoordinator")
	cabinet._open = true
	get_tree().root.content_scale_size = Vector2i.ZERO
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_tree().root.size = screen
		await _frames()
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var panel: Control = cabinet._panel
		_check(is_equal_approx(panel.position.y, coordinator._top_height), "cabinet starts below header at %s" % screen)
		_check(panel.scale == Vector2.ONE, "generic window scaling does not override cabinet")
		var resource_rect := Rect2(coordinator._resource_bar.position, coordinator._resource_bar.size * coordinator._resource_bar.scale)
		var menu_rect := Rect2(coordinator._toolbar.position, coordinator._toolbar.size * coordinator._toolbar.scale)
		_check(resource_rect.position.x >= 0 and resource_rect.end.x <= viewport_size.x - 11.0, "resources stay inside the right screen edge")
		_check(not menu_rect.intersects(resource_rect), "resources never overlap navigation")
		if resource_rect.position.y < menu_rect.end.y:
			_check(absf(menu_rect.get_center().y - resource_rect.get_center().y) < 1.0, "single-row header is vertically aligned")
		for race_id in ["nerids", "surr", "meridians", "aery", "crystari", "humans"]:
			GameState.player_state["origin_race_id"] = race_id
			await _frames()
			var art: TextureRect = cabinet._captain_portrait
			_check(cabinet._race_emblem.faction_id == race_id and cabinet._race_emblem._emblem == GameData.get_faction_emblem(race_id), "captain pennant shows the canonical own-race crest")
			_check(is_zero_approx(art.position.y), "portrait top is never cropped: %s %s" % [race_id, screen])
			_check(is_equal_approx(art.position.x + art.size.x, panel.size.x), "portrait stays on right frame")
			_check(is_equal_approx(art.size.x / art.size.y, art.texture.get_size().x / art.texture.get_size().y), "portrait retains its proportions")
		await _capture("captain_%dx%d" % [screen.x, screen.y])
	cabinet._show_rewards = true
	cabinet._refresh_rewards()
	await _frames()
	var surface := cabinet._rewards_overlay.get_theme_stylebox("panel") as StyleBoxFlat
	_check(surface != null and surface.bg_color.a == 1.0, "rewards window has an opaque background")
	_check(cabinet._medal_case_grid.get_child_count() == 5, "hall shows five large medals with ten degrees each")
	_check(cabinet._medal_case_art.texture != null, "all factions share the same brass-and-velvet medal case art")
	var fame_close := cabinet._panel.find_child("CloseHallOfFameButton", true, false) as Button
	var close_center: float = fame_close.get_global_rect().get_center().x
	_check(absf(close_center - cabinet._rewards_overlay.get_global_rect().get_center().x) < 1.0, "hall-of-fame close button stays centered")
	cabinet._set_rewards_view(true)
	await _frames()
	_check(cabinet._medal_case_view.visible and not cabinet._rewards_rows.visible, "hall-of-fame toggle switches from the list to the medal case")
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = screen
		await _frames()
		_check(not cabinet._rewards_scroll.visible and not cabinet._rewards_summary.visible, "hall hides the list scroll and places its summary on the artwork")
		var ancestor: Node = cabinet._medal_case_view.get_parent()
		var nested_scroll: bool = false
		while ancestor != null:
			nested_scroll = nested_scroll or ancestor is ScrollContainer
			ancestor = ancestor.get_parent()
		_check(not nested_scroll, "case is outside every scroll container")
		var body: Rect2 = cabinet._medal_case_view.get_global_rect()
		_check(body.encloses(cabinet._medal_case_info.get_global_rect()), "framed transparent summary fits the hall")
		_check(cabinet._medal_case_info.get_theme_stylebox("panel").bg_color.a < 1.0, "summary uses translucent ink over the case")
		for family in cabinet._medal_case_grid.get_children():
			var medal: TextureRect = family.get_node("EarnedMedal")
			_check(medal.visible and medal.size.y >= 80 and medal.size.x >= 100, "medal remains large and visible at " + str(screen))
			_check(body.encloses(family.get_global_rect()), "medal and all captions fit without scrolling")
			_check(family.find_child("Degrees", true, false).get_child_count() == 10, "all career degrees are displayed")
			_check(family.find_child("EmptyVelvetPillow", true, false) == null, "medal uses no individual cushion")
		for button in [cabinet._rewards_list_toggle, cabinet._rewards_case_toggle]:
			var original: Rect2 = button.get_global_rect()
			var motion := InputEventMouseMotion.new()
			motion.position = original.get_center()
			get_viewport().push_input(motion, true)
			await _frames()
			_check(button.get_global_rect() == original, "hover does not move or resize rewards tabs")
			var normal: StyleBoxTexture = button.get_theme_stylebox("normal")
			var hovered: StyleBoxTexture = button.get_theme_stylebox("hover_pressed")
			_check(normal.texture == hovered.texture and normal.get_minimum_size() == hovered.get_minimum_size() and normal.texture_margin_left == hovered.texture_margin_left, "pressed hover keeps exactly the same brass geometry")
		await _capture("captain_hall_%dx%d" % [screen.x, screen.y])
	var first_family: Node = cabinet._medal_case_grid.get_child(0)
	_check(bool(first_family.find_child("Degrees", true, false).get_child(1).get_meta("earned")), "received rank two is shown in its correct degree")
	_check(not bool(cabinet._medal_case_grid.get_child(4).find_child("Degrees", true, false).get_child(9).get_meta("earned")), "unearned final degree is never presented as received")
	cabinet._set_rewards_view(false)
	_check(cabinet._rewards_scroll.visible and not cabinet._medal_case_art.visible, "list restores its own scroll and opaque background")
	await _capture("captain_rewards")
	var money: float = GameState.player_state.money
	var rank: int = career.get_command_rank()
	var history_size: int = career.get_reward_history().size()
	for replay in range(3):
		cabinet._replay_reward_button.pressed.emit()
		_check(ceremony.visible and hud._active_rank_event.get("preview", false), "replay opens an explicitly marked ceremony")
		hud._close_ceremony()
		await _frames()
	_check(GameState.player_state.money == money and career.get_command_rank() == rank and career.get_reward_history().size() == history_size, "ceremony replay never grants money or ranks")
	print("CAPTAIN UI SMOKE checks=%d fail=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
