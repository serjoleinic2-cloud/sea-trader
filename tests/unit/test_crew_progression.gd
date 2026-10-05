extends "res://tests/test_base.gd"

var _system: Node

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

func test_hiring_and_crew_screens_show_portraits_and_empty_crew_cells() -> void:
	var candidate: Dictionary = _system.get_candidates()[0]
	candidate["rank"] = 1
	GameState.company_state["hire_candidates"] = [candidate]
	var market: Node = load("res://systems/ui/hiring_window.gd").new()
	add_child(market)
	market.initialize(_system)
	market.open()
	market._refresh_details()
	assert_true(market._portrait.texture is AtlasTexture)
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
