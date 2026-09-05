extends Node

## InputAdapter — converts SensorInput values to ship control commands.
## On Android: uses tilt from SensorInput.
## In editor/desktop: uses keyboard W/S/A/D (debug only).
## Keyboard is NEVER the primary control. Primary = tilt.
## See ARCHITECTURE.md, SYSTEM_MAP.md.

var _sensor_input: Node   # SensorInput
var _ship_control: Node   # ShipControl

# Keyboard ramp speed — loaded from input_config.json. TUNABLE / TBD.
var _kb_ramp_speed: float = 4.0

# Current smoothed keyboard values
var _kb_throttle: float = 0.0
var _kb_steering: float = 0.0

# ============================================================================
# Public API
# ============================================================================

func setup(sensor: Node, control: Node) -> void:
	"""Link dependencies. Call once during scene init."""
	_sensor_input = sensor
	_ship_control = control

	_load_kb_config()

	if _sensor_input != null:
		_sensor_input.tilt_updated.connect(_on_tilt_updated)


func _load_kb_config() -> void:
	var path: String = "res://data/input/input_config.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var kb: Dictionary = parsed.get("debug_keyboard", {})
		_kb_ramp_speed = float(kb.get("ramp_speed", _kb_ramp_speed))


func _physics_process(delta: float) -> void:
	if _ship_control == null:
		return

	# If tilt sensors are active, the tilt_updated signal handles control.
	# Only run keyboard when sensors are unavailable (editor/desktop).
	if _sensor_input != null and _sensor_input.is_available():
		return

	_process_keyboard(delta)


# ============================================================================
# Tilt path — called by SensorInput.tilt_updated signal
# ============================================================================

func _on_tilt_updated(pitch: float, roll: float) -> void:
	"""Receives already-normalized, dead-zone-applied, smoothed values from SensorInput.
	pitch: −1 (tilt back = brake) .. +1 (tilt forward = accelerate)
	roll:  −1 (tilt left = steer left) .. +1 (tilt right = steer right)"""
	# InputAdapter does NOT re-apply sensitivity — SensorInput already did.
	# Just forward to ShipControl.
	_ship_control.send_control(pitch, roll)


# ============================================================================
# Debug keyboard path (editor / desktop only)
# ============================================================================

func _process_keyboard(delta: float) -> void:
	var target_throttle: float = 0.0
	var target_steering: float = 0.0

	if Input.is_key_pressed(KEY_W):
		target_throttle =  1.0
	elif Input.is_key_pressed(KEY_S):
		target_throttle = -1.0

	if Input.is_key_pressed(KEY_A):
		target_steering = -1.0
	elif Input.is_key_pressed(KEY_D):
		target_steering =  1.0

	# Gradual ramp — prevents keyboard from feeling instant compared to tilt
	_kb_throttle = lerpf(_kb_throttle, target_throttle, _kb_ramp_speed * delta)
	_kb_steering = lerpf(_kb_steering, target_steering, _kb_ramp_speed * delta)

	_ship_control.send_control(_kb_throttle, _kb_steering)
