extends Node

## InputAdapter — converts SensorInput values to ship control commands.
## Debug mode: reads keyboard (W/S/A/D) when sensors unavailable.
## Keyboard input is ONLY for debug/testing. Primary control = tilt (Phase 04).
## See ARCHITECTURE.md, SYSTEM_MAP.md.

var _sensor_input: Node   # SensorInput
var _ship_control: Node   # ShipControl

# Sensitivity multiplier for tilt input. Configurable via SettingsState.
# TUNABLE — final value TBD.
const TILT_SENSITIVITY: float = 1.0

# Keyboard ramp speed (how fast keyboard input ramps to full). TUNABLE.
const KB_RAMP_SPEED: float = 4.0

# Current smoothed keyboard values (for gradual ramp)
var _kb_throttle: float = 0.0
var _kb_steering: float = 0.0

# ============================================================================
# Public API
# ============================================================================

func setup(sensor: Node, control: Node) -> void:
	"""Link dependencies. Call once during scene init."""
	_sensor_input = sensor
	_ship_control = control

	if _sensor_input != null:
		_sensor_input.tilt_updated.connect(_on_tilt_updated)


func _physics_process(delta: float) -> void:
	if _ship_control == null:
		return

	if _sensor_input != null and _sensor_input.is_available():
		# Tilt path — handled by _on_tilt_updated signal
		return

	# Debug keyboard fallback
	_process_keyboard(delta)


# ============================================================================
# Tilt path (Phase 04)
# ============================================================================

func _on_tilt_updated(pitch: float, roll: float) -> void:
	"""Called by SensorInput when real tilt data is available.
	pitch: forward/back tilt (-1 back .. 1 forward)
	roll:  left/right tilt  (-1 left .. 1 right)"""
	var sensitivity: float = float(GameState.settings_state.get("control_sensitivity", TILT_SENSITIVITY))
	var invert: bool = bool(GameState.settings_state.get("control_inversion", false))

	var throttle: float = clampf(pitch * sensitivity, -1.0, 1.0)
	var steering: float = clampf(roll * sensitivity, -1.0, 1.0)

	if invert:
		steering = -steering

	_ship_control.send_control(throttle, steering)


# ============================================================================
# Debug keyboard path
# ============================================================================

func _process_keyboard(delta: float) -> void:
	var target_throttle: float = 0.0
	var target_steering: float = 0.0

	if Input.is_key_pressed(KEY_W):
		target_throttle = 1.0
	elif Input.is_key_pressed(KEY_S):
		target_throttle = -1.0

	if Input.is_key_pressed(KEY_A):
		target_steering = -1.0
	elif Input.is_key_pressed(KEY_D):
		target_steering = 1.0

	# Smooth ramp so keyboard doesn't feel instant either
	_kb_throttle = lerpf(_kb_throttle, target_throttle, KB_RAMP_SPEED * delta)
	_kb_steering = lerpf(_kb_steering, target_steering, KB_RAMP_SPEED * delta)

	_ship_control.send_control(_kb_throttle, _kb_steering)
