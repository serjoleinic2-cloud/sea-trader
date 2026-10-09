extends "res://tests/test_base.gd"

var _system: Node
const TrainingScrolls = preload("res://systems/employees/training_scrolls.gd")

func before_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	_system = load("res://systems/employees/hiring_system.gd").new()
	add_child(_system)
	_system.initialize()

func after_each() -> void:
	_system.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_ship_staff_persists_and_gains_mastery_after_each_voyage() -> void:
	GameState.employee_state = [
		{"employee_instance_id": "temporary", "employment_type": "permanent", "contract_voyages_remaining": -1, "mastery_percent": 96},
		{"employee_instance_id": "officer", "employment_type": "permanent", "mastery_percent": 96, "experience": 0, "skills": [], "stats": {}}
	]
	var retained: Array = _system.complete_voyage(["temporary", "officer"])
	assert_eq(retained, ["temporary", "officer"])
	assert_eq(GameState.employee_state.size(), 2)
	assert_eq(GameState.employee_state[0].mastery_percent, 100)
	assert_eq(GameState.employee_state[0].experience, 1)

func test_legacy_crew_contracts_are_migrated_to_persistent_employees() -> void:
	GameState.employee_state = [{"employee_instance_id": "legacy", "employment_type": "contract", "contract_voyages_remaining": 2}]
	_system.initialize()
	assert_eq(GameState.employee_state[0].employment_type, "permanent")
	assert_eq(GameState.employee_state[0].contract_voyages_remaining, -1)

func test_permanent_employee_selects_and_develops_one_skill() -> void:
	GameState.employee_state = [{
		"employee_instance_id": "officer",
		"employment_type": "permanent",
		"rank": 3,
		"mastery_percent": 100,
		"experience": 0,
		"skills": [],
		"active_skill_id": "",
		"stats": {"speed": 2},
		"skill_stats": {}
	}]
	GameState.ship_state["crew"] = ["officer"]
	assert_true(_system.choose_skill("officer", "steady_course").ok)
	assert_false(_system.choose_skill("officer", "fuel_discipline").ok)
	for action in range(100):
		_system._award_action_progress("speed", 1)
	var employee: Dictionary = GameState.employee_state[0]
	assert_eq(employee.skills[0].progress, 100)
	assert_eq(employee.active_skill_id, "")
	assert_eq(_system.get_effective_stats(employee).speed, 7)

func test_candidate_board_offers_persistent_staff_with_strengths_and_flaws() -> void:
	var kinds: Dictionary = {}
	for candidate in _system.get_candidates():
		kinds[str(candidate.get("employment_type", ""))] = true
	assert_true(kinds.has("permanent"))
	assert_false(kinds.has("contract"))
	assert_true(str(_system.get_candidates()[0].get("strength_trait", "")) != "")
	assert_true(str(_system.get_candidates()[0].get("flaw_trait", "")) != "")

func test_market_hires_candidate_into_the_selected_docked_ship() -> void:
	GameState.ship_state["docked_port_id"] = "harbor"
	GameState.ship_state["crew"] = []
	GameState.player_state["money"] = 10000.0
	GameState.fleet_state = [{"instance_id": "freighter_1", "ship_type_id": "ship_freighter", "name": "Дальний", "current_port_id": "harbor", "crew": [], "autopilot": {}}]
	var candidates: Array = _system.get_candidates()
	var chosen: Dictionary = candidates[0]
	chosen["rank"] = 1
	GameState.company_state["hire_candidates"] = candidates
	var result: Dictionary = _system.hire(str(chosen.candidate_id), 2, "freighter_1")
	assert_true(result.ok)
	assert_eq(GameState.ship_state.crew, [])
	assert_eq(GameState.fleet_state[0].crew.size(), 1)
	assert_eq(GameState.employee_state[0].assigned_to, "freighter_1")
	assert_eq(GameState.employee_state[0].employment_type, "permanent")
	assert_eq(GameState.employee_state[0].contract_voyages_remaining, -1)

func test_ship_market_options_expose_larger_crew_cells_by_tier() -> void:
	GameState.fleet_state = [{"instance_id": "freighter_1", "ship_type_id": "ship_freighter", "name": "Дальний", "current_port_id": "", "crew": [], "autopilot": {}}]
	var options: Array = _system.get_ship_options()
	assert_eq(options[0].max_crew, 1)
	assert_eq(options[1].min_crew, 5)
	assert_eq(options[1].max_crew, 8)

func test_action_specific_skill_advances_slowly_and_only_for_matching_action() -> void:
	GameState.ship_state["crew"] = ["officer"]
	GameState.employee_state = [{"employee_instance_id": "officer", "employment_type": "permanent", "mastery_percent": 100,
		"active_skill_id": "steady_course", "skills": [{"id": "steady_course", "progress": 0}], "stats": {"speed": 0}, "skill_stats": {}}]
	_system._award_action_progress("repair", 10)
	assert_eq(GameState.employee_state[0].skills[0].progress, 0)
	_system._award_action_progress("speed", 1)
	assert_eq(GameState.employee_state[0].skills[0].progress, 1)
	assert_eq(_system.get_effective_stats(GameState.employee_state[0]).speed, 0)

func test_training_scroll_advances_selected_skill_by_two_points_in_port() -> void:
	GameState.ship_state["docked_port_id"] = "harbor"
	GameState.progression_state["training_scrolls"] = 3
	GameState.employee_state = [{"employee_instance_id": "officer", "employment_type": "permanent",
		"mastery_percent": 100, "active_skill_id": "steady_course",
		"skills": [{"id": "steady_course", "progress": 40}], "stats": {"speed": 0}, "skill_stats": {}}]
	var result: Dictionary = _system.use_training_scroll("officer", "steady_course")
	assert_true(bool(result.get("ok", false)))
	assert_eq(int(GameState.employee_state[0].skills[0].progress), 42)
	assert_eq(_system.get_training_scroll_total(), 2)
	assert_eq(int(_system.get_training_scroll_inventory().scroll_seafaring), 0)

func test_training_scroll_requires_port_and_cannot_raise_a_skill_past_100() -> void:
	GameState.progression_state["training_scrolls"] = 1
	GameState.employee_state = [{"employee_instance_id": "officer", "employment_type": "permanent",
		"skills": [{"id": "steady_course", "progress": 99}], "stats": {}, "skill_stats": {}}]
	var sailing_result: Dictionary = _system.use_training_scroll("officer", "steady_course")
	assert_false(bool(sailing_result.get("ok", false)))
	assert_eq(_system.get_training_scroll_total(), 1)
	GameState.ship_state["docked_port_id"] = "harbor"
	var port_result: Dictionary = _system.use_training_scroll("officer", "steady_course")
	assert_true(bool(port_result.get("ok", false)))
	assert_eq(int(GameState.employee_state[0].skills[0].progress), 100)
	assert_eq(str(GameState.employee_state[0].get("active_skill_id", "")), "")
	assert_eq(_system.get_training_scroll_total(), 0)
	var capped_result: Dictionary = _system.use_training_scroll("officer", "steady_course")
	assert_false(bool(capped_result.get("ok", false)))
	assert_eq(_system.get_training_scroll_total(), 0)

func test_training_scroll_type_must_match_and_living_unit_is_required() -> void:
	GameState.ship_state["docked_port_id"] = "harbor"
	GameState.progression_state["training_scroll_inventory"] = {"scroll_seafaring":1,"scroll_navigation":1}
	GameState.employee_state = [{"employee_instance_id":"officer","employment_type":"permanent","is_alive":true,
		"skills":[{"id":"steady_course","progress":10}],"stats":{},"skill_stats":{}}]
	var wrong: Dictionary = _system.use_training_scroll("officer", "steady_course", "scroll_navigation")
	assert_false(bool(wrong.get("ok",false)))
	assert_eq(_system.get_training_scroll_total(),2,"wrong type is not consumed")
	GameState.employee_state[0]["health"]=0
	var dead: Dictionary = _system.use_training_scroll("officer", "steady_course", "scroll_seafaring")
	assert_false(bool(dead.get("ok",false)))
	assert_eq(_system.get_training_scroll_total(),2,"a dead unit cannot consume a scroll")

func test_legacy_scrolls_migrate_without_loss_into_five_types() -> void:
	GameState.progression_state["training_scroll_inventory"]={}
	GameState.progression_state["training_scrolls"]=7
	var inventory: Dictionary=TrainingScrolls.migrate_legacy()
	assert_eq(TrainingScrolls.total(),7)
	assert_eq(int(inventory.scroll_seafaring),2)
	assert_eq(int(inventory.scroll_navigation),2)
	assert_eq(int(inventory.scroll_engineering),1)
	assert_eq(int(GameState.progression_state.training_scrolls),0)

func test_port_crew_window_offers_scroll_for_reserve_employee() -> void:
	GameState.ship_state["docked_port_id"] = "harbor"
	GameState.ship_state["crew"] = []
	GameState.progression_state["training_scrolls"] = 2
	GameState.employee_state = [{"employee_instance_id": "reserve", "employment_type": "permanent", "name": "Лоцман",
		"role_id": "navigator", "race_id": "humans", "rank": 1, "mastery_percent": 100, "skills": [{"id": "coastal_memory", "progress": 20}],
		"active_skill_id": "coastal_memory", "stats": {"navigation": 0}, "skill_stats": {}}]
	var crew_ui: Node = load("res://systems/ui/crew_window.gd").new()
	add_child(crew_ui)
	crew_ui.initialize(_system)
	crew_ui._refresh()
	var has_scroll_action: bool = false
	for button in crew_ui.find_children("*", "Button", true, false):
		if str(button.text).begins_with("Применить"):
			has_scroll_action = true
	assert_true(has_scroll_action, "the port crew window exposes training for employees in reserve")
	assert_eq(crew_ui._scroll_list.get_child_count(),7,"right column shows its heading, hint and five scroll cards")
	var scroll_icons: Array=crew_ui.find_children("*", "TextureRect", true, false).filter(func(node): return node.has_meta("training_scroll_icon"))
	assert_eq(scroll_icons.size(),5)
	for icon in scroll_icons: assert_true(icon.texture is Texture2D,"every scroll type has its own image")
	crew_ui.free()

func test_hiring_and_crew_screens_show_portraits_and_empty_crew_cells() -> void:
	var candidate: Dictionary = _system.get_candidates()[0]
	candidate["rank"] = 1
	GameState.company_state["hire_candidates"] = [candidate]
	var market: Node = load("res://systems/ui/hiring_window.gd").new()
	add_child(market)
	market.initialize(_system)
	market.open()
	market._refresh_details()
	assert_true(market._portrait.texture is Texture2D) # hiring now uses approved per-race images
	assert_eq(market._ship_selector.item_count, 1)
	market.free()
	var crew_ui: Node = load("res://systems/ui/crew_window.gd").new()
	add_child(crew_ui)
	crew_ui.initialize(_system)
	crew_ui._refresh()
	assert_ne(crew_ui._crew_portrait_atlas, null)
	assert_gt(crew_ui._list.get_child_count(), 1, "the ship crew layout should include a captain and vacant hireable cells")
	crew_ui.free()

func test_crew_transfer_uses_open_slots_and_requires_both_ships_in_same_port() -> void:
	GameState.ship_state["docked_port_id"] = "harbor"
	GameState.employee_state = [{"employee_instance_id": "officer", "name": "Лоцман", "assigned_to": "active_ship"}]
	GameState.ship_state["crew"] = ["officer"]
	GameState.fleet_state = [{"instance_id": "aux_1", "ship_type_id": "ship_sloop", "current_port_id": "remote", "crew": [], "autopilot": {}}]
	var fleet: Node = load("res://systems/fleet/fleet_system.gd").new()
	add_child(fleet)
	fleet.initialize(null)
	assert_false(fleet.assign_employee("officer", "aux_1").ok)
	GameState.fleet_state[0]["current_port_id"] = "harbor"
	assert_true(fleet.assign_employee("officer", "aux_1").ok)
	assert_eq(GameState.ship_state.crew, [])
	assert_eq(GameState.fleet_state[0].crew, ["officer"])
	fleet.free()
