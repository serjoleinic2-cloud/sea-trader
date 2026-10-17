extends Node

const Loadout = preload("res://systems/fleet/ship_loadout.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("TRADE SLOTS: " + message)

func frames(count: int = 3) -> void:
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

func close_picker(view: Node) -> void:
	var buttons: Array = view._picker.find_children("*", "Button", true, false).filter(func(button): return button.has_meta("brass_close"))
	check(not buttons.is_empty(), "picker has a close button")
	if not buttons.is_empty():
		await click(buttons[0])
	check(not view._picker.visible, "close button returns to ship")

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	if OS.get_environment("SEA_TRADER_SLOT_AUDIT_EXISTING") != "1":
		GameState.reset_to_defaults()
		GameState.world_state.seed = 42
		GameState.player_state.origin_race_id = "crystari"
		GameState.player_state.origin_race_confirmed = true
		SaveSystem.save_game()
	var main: Node = preload("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	await frames(10)
	main._career_system.set_process(false)
	get_tree().paused = false
	# Old unread combat reports are separate modals, outside the fleet audit.
	main.get_node("CombatNotificationHUD")._story_root.hide()
	var home: String = str(GameState.world_state.home_port_id)
	GameState.ship_state.docked_port_id = home
	GameState.player_state.money = 200000.0
	var fixture: Dictionary = {"instance_id": "slot_audit_trade", "ship_type_id": "ship_freighter", "name": "Проверка торгового экипажа", "current_port_id": home, "crew": [], "autopilot": {}, "cargo": []}
	GameState.fleet_state.append(fixture)
	var fleet: Node = main.get_node("FleetWindow")
	for ship_id in ["active_ship", "slot_audit_trade"]:
		print("TRADE SLOT AUDIT ship=", ship_id)
		fleet._is_open = true
		fleet._garage.category = "all"
		fleet._selected_ship_id = ship_id
		fleet._refresh()
		await frames(5)
		var view: Node = fleet._garage._outfitting
		for slot in Loadout.crew_slots(ship_id):
			if bool(slot.get("player", false)):
				check(view._crew.find_child("CrewSlot_player", true, false).disabled, "player captain slot cannot be replaced")
				continue
			print("TRADE SLOT AUDIT crew=", slot.key, " role=", slot.role)
			var button: Button = view._crew.find_child("CrewSlot_" + str(slot.key), true, false)
			check(button != null, "crew button exists: " + str(slot.key))
			if button == null:
				continue
			var crew_scroll: ScrollContainer = view._crew.get_parent()
			crew_scroll.ensure_control_visible(button)
			await frames()
			await click(button)
			await frames()
			check(view._picker.visible, "trade crew picker stays open")
			if not view._picker.visible:
				get_tree().quit(1)
				return
			var portraits: Array = view._choices.find_children("*", "Button", true, false).filter(func(item): return item.has_meta("crew_portrait_card"))
			check(not portraits.is_empty(), "role has candidates of the player's race")
			if not portraits.is_empty():
				await click(portraits[0])
				await frames()
				check(view._detail_art.texture != null, "candidate opens a large portrait")
			await close_picker(view)
		for index in 4:
			print("TRADE SLOT AUDIT boost=", index)
			await click(view._right.find_child("BoostSlot_%d" % index, true, false))
			await frames()
			check(view._picker.visible, "trade boost picker stays open")
			await close_picker(view)
		check(fleet._is_open, "slot selection keeps the fleet window open")
		check(view._right.find_child("GunSlot_0", true, false) == null, "trade ship has no combat gun slots")
		view._open_boost(0)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		get_viewport().push_input(escape, true)
		await frames()
		check(not view._picker.visible and fleet._is_open, "Escape closes only the equipment picker")
		if ship_id == "slot_audit_trade":
			# Exercise the complete trade-captain assignment path, not just opening.
			view._crew.find_child("CrewSlot_crew_0", true, false).pressed.emit()
			await frames()
			var candidates: Array = main._hiring_system.get_candidates_for_role("captain")
			var candidate: Dictionary = candidates[0]
			candidate.rank = 1
			var portrait: Button = view._choices.find_children("*", "Button", true, false).filter(func(item): return str(item.get_meta("crew_portrait_card", "")) == str(candidate.candidate_id))[0]
			await click(portrait)
			await click(view._detail_actions.get_child(0))
			await frames()
			check(not view._picker.visible and fixture.crew.size() == 1, "trade captain is hired through the large card")
			view._crew.find_child("CrewSlot_crew_0", true, false).pressed.emit()
			await frames()
			check(view._detail_heading.text == str(candidate.name), "occupied slot shows its assigned employee")
			await click(view._detail_actions.get_child(0))
			await frames()
			check(fixture.crew.is_empty(), "trade captain can move into company reserve")
			view._crew.find_child("CrewSlot_crew_0", true, false).pressed.emit()
			await frames()
			var reserve: Button = view._choices.find_children("*", "Button", true, false).filter(func(item): return item.text == "Назначить из резерва")[0]
			await click(reserve)
			await frames()
			check(fixture.crew.size() == 1, "reserved employee can return to the trade ship")
			view._crew.find_child("CrewSlot_crew_0", true, false).pressed.emit()
			await frames()
			var refresh: Button = view._choices.find_children("*", "Button", true, false).filter(func(item): return item.text == "Обновить кандидатов")[0]
			# This action is below the candidate list; scroll it into view.
			var scroll: ScrollContainer = view._choices.get_parent()
			scroll.ensure_control_visible(refresh)
			await frames()
			await click(refresh)
			await frames()
			check(view._picker.visible, "candidate refresh keeps the trade picker open")
			await close_picker(view)
			view._open_boost(99)
			check(view._choices.get_child_count() == 1, "invalid boost slot gives a safe explanation")
			fleet._close()
			await frames()
			check(not view._picker.visible, "closing fleet removes its modal immediately")
	print("TRADE SLOTS checks=%d fail=%d" % [checks, failures])
	SaveSystem.delete_save()
	get_tree().quit(0 if failures == 0 else 1)
