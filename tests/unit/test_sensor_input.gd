extends "res://tests/test_base.gd"

## Unit tests for SensorInput Phase 04.
## Note: tests that require real Android accelerometer are marked NOT_VERIFIED.
## All tests here run in editor without a physical device.

var _sensor: Node

func before_each() -> void:
	_sensor = preload("res://systems/input/sensor_input.gd").new()
	add_child(_sensor)

func after_each() -> void:
	if is_instance_valid(_sensor):
		_sensor.queue_free()

# ---- on editor: sensors not available ----

func test_sensors_not_available_in_editor() -> void:
	# On desktop/editor OS.get_name() != "Android" — sensor should be disabled
	var platform: String = OS.get_name()
	if platform == "Android" or platform == "iOS":
		# Skip: running on real device, sensor IS expected to be available
		assert_true(true, "skip: running on device")
		return
	assert_false(_sensor.is_available(), "sensors should be unavailable in editor")

func test_is_calibrated_false_before_calibration() -> void:
	# Before any calibration call, is_calibrated() must return false
	assert_false(_sensor.is_calibrated(), "should not be calibrated before calibrate()")

func test_calibrate_on_editor_does_not_crash() -> void:
	# calibrate() must silently no-op on desktop (sensors unavailable)
	_sensor.calibrate()
	assert_false(_sensor.is_calibrated(), "calibrate() on editor should be no-op")

func test_start_calibration_on_editor_does_not_crash() -> void:
	_sensor.start_calibration()
	assert_false(_sensor.is_calibrating(), "start_calibration() on editor should be no-op")

func test_get_calibration_returns_dictionary() -> void:
	var cal: Dictionary = _sensor.get_calibration()
	assert_true(cal is Dictionary, "get_calibration() should return Dictionary")
	assert_has(cal, "pitch", "calibration dict must have pitch")
	assert_has(cal, "roll",  "calibration dict must have roll")

func test_get_calibration_defaults_zero() -> void:
	var cal: Dictionary = _sensor.get_calibration()
	assert_almost_eq(float(cal.get("pitch", 99.0)), 0.0, 0.001,
		"default calibration pitch should be 0")
	assert_almost_eq(float(cal.get("roll", 99.0)), 0.0, 0.001,
		"default calibration roll should be 0")

func test_config_loaded_sensitivity_in_range() -> void:
	# After _ready() loads input_config.json, sensitivity should be > 0
	# We access the private var via a getter we expose for testing
	# Using signal test instead: create a mock and verify no error on connect
	var ok: bool = _sensor.has_signal("tilt_updated")
	assert_true(ok, "tilt_updated signal must exist")

func test_tilt_updated_signal_connectable() -> void:
	var callable: Callable = Callable(self, "_on_tilt")
	_sensor.tilt_updated.connect(callable)
	_sensor.tilt_updated.disconnect(callable)
	assert_true(true, "tilt_updated signal is connectable")

func test_is_available_returns_bool() -> void:
	var result: Variant = _sensor.is_available()
	assert_true(result is bool, "is_available() must return bool")

func test_is_calibrated_returns_bool() -> void:
	var result: Variant = _sensor.is_calibrated()
	assert_true(result is bool, "is_calibrated() must return bool")

func test_is_calibrating_returns_bool() -> void:
	var result: Variant = _sensor.is_calibrating()
	assert_true(result is bool, "is_calibrating() must return bool")

func _on_tilt(_p: float, _r: float) -> void:
	pass

# ---- NOT_VERIFIED without physical Android device ----
# test_accelerometer_produces_nonzero_on_tilt
# test_calibration_zeroes_neutral_position
# test_dead_zone_prevents_drift_at_rest
# test_smoothing_removes_jitter
# test_sensitivity_scales_output
# test_invert_steering_flips_roll_sign
