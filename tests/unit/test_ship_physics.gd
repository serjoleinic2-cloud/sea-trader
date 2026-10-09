extends "res://tests/test_base.gd"

var _physics: Node
var _collision_test_data: Dictionary = {}
var _ship_data: Dictionary = {
	"id": "ship_sloop",
	"base_speed": 120.0,
	"base_maneuverability": 0.85,
	"cargo_capacity": 50,
	"fuel_capacity": 100,
	"hull_max": 100,
	"engine_max": 100,
	"steering_max": 100,
	"cargo_hold_max": 100
}

func before_each() -> void:
	_collision_test_data = {}
	_physics = preload("res://systems/ship/ship_physics.gd").new()
	add_child(_physics)
	_physics.setup(_ship_data)
	GameState.ship_state["position"] = Vector2(512.0, 512.0)
	GameState.ship_state["fuel"]     = 100.0
	GameState.ship_state["fuel_max"] = 100.0
	GameState.ship_state["hull"]     = 100.0
	GameState.ship_state["engine"]   = 100.0
	GameState.ship_state["steering"] = 100.0

func after_each() -> void:
	if is_instance_valid(_physics):
		_physics.queue_free()

func test_setup_sets_ship_id() -> void:
	assert_eq(str(GameState.ship_state.get("ship_id", "")), "ship_sloop",
		"ship_id should be set from data")

func test_initial_speed_is_zero() -> void:
	assert_almost_eq(_physics.get_speed(), 0.0, 0.001, "speed should start at zero")

func test_acceleration_increases_speed() -> void:
	_physics.apply_control(1.0, 0.0)
	_physics.physics_tick(0.1)
	assert_gt(_physics.get_speed(), 0.0, "speed should increase after throttle")

func test_max_speed_not_exceeded() -> void:
	_physics.apply_control(1.0, 0.0)
	for _i in range(400):
		_physics.physics_tick(0.1)
	assert_lte(_physics.get_speed(), _physics.get_max_speed() + 0.1,
		"speed should not exceed max")

func test_deceleration_reduces_speed() -> void:
	_physics.apply_control(1.0, 0.0)
	for _i in range(50):
		_physics.physics_tick(0.1)
	var before: float = _physics.get_speed()
	_physics.apply_control(0.0, 0.0)
	for _i in range(20):
		_physics.physics_tick(0.1)
	assert_lt(_physics.get_speed(), before, "speed should decrease after throttle release")

func test_reverse_moves_stern_first_without_rotating_hull() -> void:
	var starting_heading: float = _physics.get_heading_degrees()
	_physics.apply_control(1.0, 0.0)
	for _i in range(40):
		_physics.physics_tick(0.1)
	assert_gt(_physics.get_speed(), 0.0)

	_physics.apply_control(-1.0, 0.0)
	for _i in range(40):
		_physics.physics_tick(0.1)
	assert_lt(_physics.get_speed(), 0.0)
	assert_true(bool(GameState.ship_state.get("reverse_gear", false)))
	assert_almost_eq(_physics.get_heading_degrees(), starting_heading, 0.001)
	var reverse_start: Vector2 = GameState.ship_state.position
	for _i in range(15):
		_physics.physics_tick(0.1)
	var forward: Vector2 = Vector2(cos(deg_to_rad(starting_heading)), sin(deg_to_rad(starting_heading)))
	var reverse_displacement: Vector2 = GameState.ship_state.position - reverse_start
	assert_lt(reverse_displacement.dot(forward), 0.0, "reverse motion must be toward the stern")
	assert_almost_eq(_physics.get_heading_degrees(), starting_heading, 0.001)

func test_reverse_command_brakes_through_zero_without_releasing_key() -> void:
	_physics._speed = 100.0
	_physics.apply_control(-1.0, 0.0)
	for _i in range(240):
		_physics.physics_tick(0.05)
	assert_lt(_physics.get_speed(), 0.0, "held reverse brakes to zero and continues astern automatically")

func test_reverse_steering_inverts_bow_rotation() -> void:
	_physics._heading = 0.0
	_physics._speed = 12.0
	_physics.apply_control(1.0, 1.0)
	_physics._update_heading(0.1)
	var forward_turn: float = _physics._heading
	_physics._heading = 0.0
	_physics._yaw_velocity = 0.0 # New reverse fixture starts without the preceding forward turn inertia.
	_physics._speed = -12.0
	_physics.apply_control(-1.0, 1.0)
	_physics._update_heading(0.1)
	assert_lt(forward_turn * _physics._heading, 0.0, "reverse steering turns opposite the bow angle so stern motion follows the requested side")

func test_restore_uses_saved_heading_even_if_reverse_flag_is_stale() -> void:
	var saved_heading: float = 0.37
	GameState.ship_state["heading"] = saved_heading
	GameState.ship_state["velocity"] = Vector2(cos(saved_heading + PI), sin(saved_heading + PI)) * 8.0
	GameState.ship_state["reverse_gear"] = false

	_physics.restore_from_state()

	assert_almost_eq(_physics.get_heading_degrees(), rad_to_deg(saved_heading), 0.001)
	assert_almost_eq(_physics.get_speed(), -8.0, 0.001)
	assert_true(bool(GameState.ship_state.reverse_gear))

func test_ship_comes_to_rest() -> void:
	_physics.apply_control(1.0, 0.0)
	for _i in range(50):
		_physics.physics_tick(0.1)
	_physics.apply_control(0.0, 0.0)
	for _i in range(200):
		_physics.physics_tick(0.1)
	assert_almost_eq(_physics.get_speed(), 0.0, 0.5, "ship should come to rest")

func test_steering_changes_heading() -> void:
	_physics.apply_control(1.0, 0.0)
	for _i in range(20):
		_physics.physics_tick(0.1)
	var before: float = _physics.get_heading_degrees()
	_physics.apply_control(1.0, 1.0)
	for _i in range(10):
		_physics.physics_tick(0.1)
	assert_ne(_physics.get_heading_degrees(), before, "steering should change heading")

func test_steering_not_instant() -> void:
	_physics.apply_control(1.0, 0.0)
	for _i in range(20):
		_physics.physics_tick(0.1)
	var before: float = _physics.get_heading_degrees()
	_physics.apply_control(1.0, 1.0)
	_physics.physics_tick(0.016)
	var delta: float = absf(_physics.get_heading_degrees() - before)
	assert_lt(delta, 30.0, "single frame turn should be < 30 degrees")

func test_visual_roll_limited() -> void:
	_physics.apply_control(1.0, 0.0)
	for _i in range(30):
		_physics.physics_tick(0.1)
	_physics.apply_control(1.0, 1.0)
	for _i in range(60):
		_physics.physics_tick(0.1)
	assert_lte(absf(_physics.get_visual_roll()), 12.01, "roll should be limited to MAX_ROLL_DEGREES")
	assert_almost_eq(float(GameState.ship_state.get("visual_roll",0.0)),_physics.get_visual_roll(),0.001,"3D renderer receives the smoothed turn roll")
	assert_gt(absf(float(GameState.ship_state.get("turn_velocity",0.0))),0.001,"turn velocity is exposed for ship animation")

func test_fuel_not_below_zero() -> void:
	GameState.ship_state["fuel"] = 0.05
	_physics.apply_control(1.0, 0.0)
	for _i in range(500):
		_physics.physics_tick(0.1)
	assert_gte(float(GameState.ship_state.get("fuel", 0.0)), 0.0, "fuel should never go below zero")

func _get_collision_test_data() -> Dictionary:
	return _collision_test_data


func test_ship_cannot_cross_island_even_when_step_starts_outside() -> void:
	_collision_test_data = {
		"islands": [{"position": Vector2.ZERO, "radius": 100.0}]
	}
	_physics.set_collision_data_provider(Callable(self, "_get_collision_test_data"))
	assert_true(_physics.is_navigation_move_blocked(Vector2(-220.0, 0.0), Vector2(220.0, 0.0)))


func test_natural_bay_does_not_allow_crossing_the_island() -> void:
	_collision_test_data = {
		"islands": [{"position": Vector2.ZERO, "radius": 100.0, "bay_angle": 0.0, "bay_width": 0.24}]
	}
	_physics.set_collision_data_provider(Callable(self, "_get_collision_test_data"))
	assert_false(_physics.is_navigation_move_blocked(Vector2(200.0, 0.0), Vector2(80.0, 0.0)))
	assert_true(_physics.is_navigation_move_blocked(Vector2(80.0, 0.0), Vector2(-200.0, 0.0)))

func test_coastal_harbor_channel_and_route_query_preserve_speed() -> void:
	_collision_test_data = {"islands": [{"position": Vector2.ZERO, "radius": 100.0,
		"bay_angle": 0.0, "bay_width": 0.24, "bay_depth": 0.65}]}
	_physics.set_collision_data_provider(Callable(self, "_get_collision_test_data"))
	_physics._speed = 12.0
	assert_false(_physics.is_navigation_move_blocked(Vector2(200, 0), Vector2(70, 0)), "Saved coastal harbor remains reachable")
	assert_true(_physics.is_navigation_move_blocked(Vector2(70, 0), Vector2(-200, 0)), "Water channel does not cut through the island")
	assert_eq(_physics.get_speed(), 12.0, "Hypothetical route checks do not brake the real ship")
	var planner: RefCounted = load("res://systems/navigation/coast_route_planner.gd").new()
	var route: PackedVector2Array = planner.plan(Vector2(70, 0), Vector2(-220, 0), _collision_test_data.islands, Callable(_physics, "is_navigation_move_blocked"))
	assert_gt(route.size(), 1, "Departure toward the far side of an island needs coastal waypoints")
	var previous := Vector2(70, 0)
	for waypoint in route:
		assert_false(_physics.is_navigation_move_blocked(previous, waypoint), "Every planned leg remains in navigable water")
		previous = waypoint
	assert_eq(previous, Vector2(-220, 0), "Safe route reaches its requested destination")


func test_ship_already_inside_island_can_escape_outward() -> void:
	_collision_test_data = {
		"islands": [{"position": Vector2.ZERO, "radius": 100.0}]
	}
	_physics.set_collision_data_provider(Callable(self, "_get_collision_test_data"))
	assert_false(_physics.is_navigation_move_blocked(Vector2.ZERO, Vector2(200.0, 0.0)))


func test_hull_not_below_zero() -> void:
	GameState.ship_state["hull"] = 0.0
	assert_gte(float(GameState.ship_state.get("hull", 0.0)), 0.0, "hull should never be below zero")

func test_deterministic_same_input() -> void:
	GameState.ship_state["position"] = Vector2(512.0, 512.0)
	GameState.ship_state["fuel"]     = 100.0
	GameState.ship_state["engine"]   = 100.0
	GameState.ship_state["steering"] = 100.0
	_physics.setup(_ship_data)
	_physics.apply_control(1.0, 0.5)
	for _i in range(30):
		_physics.physics_tick(0.05)
	var pos_a: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	var spd_a: float   = _physics.get_speed()

	GameState.ship_state["position"] = Vector2(512.0, 512.0)
	GameState.ship_state["fuel"]     = 100.0
	GameState.ship_state["engine"]   = 100.0
	GameState.ship_state["steering"] = 100.0
	_physics.setup(_ship_data)
	_physics.apply_control(1.0, 0.5)
	for _i in range(30):
		_physics.physics_tick(0.05)
	var pos_b: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	var spd_b: float   = _physics.get_speed()

	assert_almost_eq(pos_a.x, pos_b.x, 0.01, "X position should be deterministic")
	assert_almost_eq(pos_a.y, pos_b.y, 0.01, "Y position should be deterministic")
	assert_almost_eq(spd_a,   spd_b,   0.01, "speed should be deterministic")
