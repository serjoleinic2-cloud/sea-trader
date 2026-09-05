extends Node

## SensorInput — ONLY file that touches Android accelerometer API.
## Emits normalized pitch/roll values to InputAdapter.
## Phase 03: sensor reading stubbed; real implementation in Phase 04.
## See ARCHITECTURE.md — "SensorInput is the only file that touches Android API."

signal tilt_updated(pitch: float, roll: float)

# Calibration baseline — set on calibrate()
var _calibration_pitch: float = 0.0
var _calibration_roll: float = 0.0

# Whether sensors are available on this device
var _sensors_available: bool = false

# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	_detect_sensors()


func _detect_sensors() -> void:
	# Phase 04 will enable actual sensor reading.
	# Input.is_action_pressed requires sensor to be enabled first.
	# On desktop/editor: sensors are not available — debug fallback handles input.
	_sensors_available = false
	# TODO Phase 04: enable accelerometer
	# Input.set_accelerometer_enabled(true)
	# _sensors_available = true


func _physics_process(_delta: float) -> void:
	if not _sensors_available:
		return
	# TODO Phase 04: read real accelerometer
	# var accel: Vector3 = Input.get_accelerometer()
	# var raw_pitch: float = accel.x
	# var raw_roll: float  = accel.z
	# var pitch: float = clampf(raw_pitch - _calibration_pitch, -1.0, 1.0)
	# var roll: float  = clampf(raw_roll  - _calibration_roll,  -1.0, 1.0)
	# tilt_updated.emit(pitch, roll)
	pass

# ============================================================================
# Calibration
# ============================================================================

func calibrate() -> void:
	"""Record current device orientation as neutral.
	Call when player presses calibration button or on game start.
	Phase 04: reads actual accelerometer for baseline."""
	_calibration_pitch = 0.0
	_calibration_roll = 0.0
	# TODO Phase 04: _calibration_pitch = Input.get_accelerometer().x
	#               _calibration_roll  = Input.get_accelerometer().z

# ============================================================================
# Query
# ============================================================================

func is_available() -> bool:
	return _sensors_available
