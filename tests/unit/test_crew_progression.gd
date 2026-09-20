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

func test_contract_expires_but_permanent_employee_gains_mastery() -> void:
	GameState.employee_state = [
		{"employee_instance_id": "temporary", "employment_type": "contract", "contract_voyages_remaining": 1},
		{"employee_instance_id": "officer", "employment_type": "permanent", "mastery_percent": 96, "experience": 0, "skills": [], "stats": {}}
	]
	var retained: Array = _system.complete_voyage(["temporary", "officer"])
	assert_eq(retained, ["officer"])
	assert_eq(GameState.employee_state.size(), 1)
	assert_eq(GameState.employee_state[0].mastery_percent, 100)
	assert_eq(GameState.employee_state[0].experience, 1)

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
	assert_true(_system.choose_skill("officer", "steady_course").ok)
	assert_false(_system.choose_skill("officer", "fuel_discipline").ok)
	for voyage in range(20):
		_system.complete_voyage(["officer"])
	var employee: Dictionary = GameState.employee_state[0]
	assert_eq(employee.skills[0].progress, 100)
	assert_eq(employee.active_skill_id, "")
	assert_eq(_system.get_effective_stats(employee).speed, 7)

func test_candidate_board_contains_both_employment_models() -> void:
	var kinds: Dictionary = {}
	for candidate in _system.get_candidates():
		kinds[str(candidate.get("employment_type", ""))] = true
	assert_true(kinds.has("contract"))
	assert_true(kinds.has("permanent"))
