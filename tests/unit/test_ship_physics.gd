extends "res://tests/test_base.gd"

var _physics: Node
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

func test_fuel_not_below_zero() -> void:
	GameState.ship_state["fuel"] = 0.05
	_physics.apply_control(1.0, 0.0)
	for _i in range(500):
		_physics.physics_tick(0.1)
	assert_gte(float(GameState.ship_state.get("fuel", 0.0)), 0.0, "fuel should never go below zero")

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
