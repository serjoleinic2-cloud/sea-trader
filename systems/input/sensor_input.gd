extends Node

## SensorInput — единственный файл, работающий с Android Accelerometer API.
## Phase 04: реальное чтение акселерометра активировано.
## Эмитирует нормализованный (−1..1) pitch/roll после dead zone и сглаживания.
## ShipPhysics не знает о платформе. InputAdapter не знает об Android API.
## See ARCHITECTURE.md, TRUTH.md, SYSTEM_MAP.md.

signal tilt_updated(pitch: float, roll: float)

# ============================================================================
# Config (loaded from data/input/input_config.json)
# ============================================================================

## Multiplier applied to raw pitch after dead zone. TUNABLE / TBD.
var _pitch_sensitivity: float = 1.8

## Multiplier applied to raw roll after dead zone. TUNABLE / TBD.
var _roll_sensitivity: float = 1.6

## Raw tilt values below this threshold are treated as zero (no movement).
## Prevents ship drift from hand tremor. TUNABLE / TBD.
var _dead_zone: float = 0.08

## Raw pitch is clamped to ±this before sensitivity is applied.
## Maps physical tilt range to full −1..1 control range. TUNABLE / TBD.
var _pitch_clamp_raw: float = 0.7

## Raw roll is clamped to ±this before sensitivity is applied. TUNABLE / TBD.
var _roll_clamp_raw: float = 0.7

## Lerp factor for output smoothing (0 = no smoothing, 1 = instant).
## Removes jitter from high-frequency sensor noise. TUNABLE / TBD.
var _smoothing_factor: float = 0.25

## Flip left/right steering direction. Configurable per player preference.
var _invert_steering: bool = false

## Whether to auto-calibrate on _ready(). Loaded from config.
var _auto_calibrate_on_start: bool = true

## Number of samples to average during calibration. TUNABLE / TBD.
var _calibration_samples: int = 8

## Interval between calibration samples (seconds). TUNABLE / TBD.
var _calibration_sample_interval: float = 0.05

# ============================================================================
# Runtime state
# ============================================================================

## Neutral position recorded during calibration.
var _calibration_pitch: float = 0.0
var _calibration_roll:  float = 0.0

## Whether calibration has been completed at least once.
var _calibrated: bool = false

## Whether Android accelerometer is available on this device.
var _sensors_available: bool = false

## Smoothed output values (carried between frames).
var _smoothed_pitch: float = 0.0
var _smoothed_roll:  float = 0.0

## Calibration accumulator state.
var _calibrating: bool = false
var _cal_samples_collected: int = 0
var _cal_pitch_sum: float = 0.0
var _cal_roll_sum:  float = 0.0
var _cal_timer: float = 0.0

# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	_load_config()
	_detect_and_enable_sensors()

	if _sensors_available and _auto_calibrate_on_start:
		# Start background auto-calibration; ship won't move until done.
		start_calibration()


func _load_config() -> void:
	var path: String = "res://data/input/input_config.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SensorInput: cannot open %s — using defaults" % path)
		return

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if not parsed is Dictionary:
		push_warning("SensorInput: invalid JSON in %s — using defaults" % path)
		return

	var tilt: Dictionary = parsed.get("tilt", {})
	_pitch_sensitivity          = float(tilt.get("pitch_sensitivity",  _pitch_sensitivity))
	_roll_sensitivity           = float(tilt.get("roll_sensitivity",   _roll_sensitivity))
	_dead_zone                  = float(tilt.get("dead_zone",          _dead_zone))
	_pitch_clamp_raw            = float(tilt.get("pitch_clamp_raw",    _pitch_clamp_raw))
	_roll_clamp_raw             = float(tilt.get("roll_clamp_raw",     _roll_clamp_raw))
	_smoothing_factor           = float(tilt.get("smoothing_factor",   _smoothing_factor))
	_invert_steering            = bool(tilt.get("invert_steering",     _invert_steering))

	var cal: Dictionary = parsed.get("calibration", {})
	_auto_calibrate_on_start    = bool(cal.get("auto_calibrate_on_start", _auto_calibrate_on_start))
	_calibration_samples        = int(cal.get("samples",             _calibration_samples))
	_calibration_sample_interval = float(cal.get("sample_interval_sec", _calibration_sample_interval))

	# Also apply player-overridden sensitivity from SettingsState if set.
	var settings_sens: float = float(GameState.settings_state.get("control_sensitivity", 0.0))
	if settings_sens > 0.0:
		_pitch_sensitivity *= settings_sens
		_roll_sensitivity  *= settings_sens

	var settings_inv: bool = bool(GameState.settings_state.get("control_inversion", false))
	if settings_inv:
		_invert_steering = not _invert_steering


func _detect_and_enable_sensors() -> void:
	## Godot 4 on Android: Input.get_accelerometer() returns non-zero when
	## sensors are present. On desktop/editor it always returns Vector3.ZERO
	## (gravity not applied), which we use as the detection heuristic.
	##
	## We cannot call Input.set_accelerometer_enabled() in Godot 4 —
	## the accelerometer is always active on Android. The check here is
	## purely a platform-detection guard so keyboard fallback works in editor.

	# OS.get_name() returns "Android" on device, "Windows"/"macOS"/"Linux" in editor.
	var platform: String = OS.get_name()
	if platform == "Android" or platform == "iOS":
		_sensors_available = true
		print("SensorInput: accelerometer enabled on %s" % platform)
	else:
		_sensors_available = false
		print("SensorInput: no accelerometer on %s — keyboard fallback active" % platform)


# ============================================================================
# Per-frame: read sensor, process, emit
# ============================================================================

func _physics_process(delta: float) -> void:
	if not _sensors_available:
		return

	# ---------- 1. Read raw accelerometer ----------
	# Input.get_accelerometer() returns a Vector3 in m/s²:
	#   x: lateral (left/right tilt)  — positive = right side down
	#   y: longitudinal (fwd/back)    — positive = top down (nose down)
	#   z: vertical (face up/down)    — ~9.8 when flat on table
	#
	# We use:
	#   pitch control ← accel.y  (forward/back tilt)
	#   roll  control ← accel.x  (left/right tilt)
	#
	# Raw values are in m/s² with gravity (~9.8 max at 90°).
	# We normalise by dividing by 9.8 before applying clamp/sensitivity,
	# so _clamp_raw values are in the 0..1 natural range.

	var accel: Vector3 = Input.get_accelerometer()
	var GRAVITY: float = 9.8

	var raw_pitch: float = accel.y / GRAVITY   # forward/back
	var raw_roll:  float = accel.x / GRAVITY   # left/right

	# ---------- 2. Subtract calibration baseline ----------
	raw_pitch -= _calibration_pitch
	raw_roll  -= _calibration_roll

	# ---------- 3. Handle ongoing calibration sampling ----------
	if _calibrating:
		_collect_calibration_sample(raw_pitch + _calibration_pitch,
		                            raw_roll  + _calibration_roll,
		                            delta)
		# Emit zero while calibrating so ship stays still.
		tilt_updated.emit(0.0, 0.0)
		return

	# ---------- 4. Dead zone ----------
	if absf(raw_pitch) < _dead_zone:
		raw_pitch = 0.0
	else:
		# Shift value toward zero by dead_zone amount (so edge of dead zone = 0, not jump)
		raw_pitch = sign(raw_pitch) * (absf(raw_pitch) - _dead_zone) / (1.0 - _dead_zone)

	if absf(raw_roll) < _dead_zone:
		raw_roll = 0.0
	else:
		raw_roll = sign(raw_roll) * (absf(raw_roll) - _dead_zone) / (1.0 - _dead_zone)

	# ---------- 5. Clamp raw range to configured physical tilt range ----------
	raw_pitch = clampf(raw_pitch, -_pitch_clamp_raw, _pitch_clamp_raw) / _pitch_clamp_raw
	raw_roll  = clampf(raw_roll,  -_roll_clamp_raw,  _roll_clamp_raw)  / _roll_clamp_raw

	# ---------- 6. Apply sensitivity ----------
	var pitch: float = clampf(raw_pitch * _pitch_sensitivity, -1.0, 1.0)
	var roll:  float = clampf(raw_roll  * _roll_sensitivity,  -1.0, 1.0)

	# ---------- 7. Invert steering if configured ----------
	if _invert_steering:
		roll = -roll

	# ---------- 8. Smooth output ----------
	_smoothed_pitch = lerpf(_smoothed_pitch, pitch, _smoothing_factor)
	_smoothed_roll  = lerpf(_smoothed_roll,  roll,  _smoothing_factor)

	# ---------- 9. Emit ----------
	tilt_updated.emit(_smoothed_pitch, _smoothed_roll)


# ============================================================================
# Calibration
# ============================================================================

func calibrate() -> void:
	"""One-shot immediate calibration: reads current accelerometer position
	and sets it as neutral baseline. No averaging. Fast, can be called
	by a button press at any time."""
	if not _sensors_available:
		return

	var accel: Vector3 = Input.get_accelerometer()
	var GRAVITY: float = 9.8
	_calibration_pitch = accel.y / GRAVITY
	_calibration_roll  = accel.x / GRAVITY
	_calibrated = true
	_smoothed_pitch = 0.0
	_smoothed_roll  = 0.0
	print("SensorInput: instant calibration — pitch_base=%.3f roll_base=%.3f" % [
		_calibration_pitch, _calibration_roll
	])


func start_calibration() -> void:
	"""Begin averaged calibration. Collects _calibration_samples readings
	over time, then sets the average as baseline. Ship emits 0,0 during sampling."""
	if not _sensors_available:
		return
	_calibrating = true
	_cal_samples_collected = 0
	_cal_pitch_sum = 0.0
	_cal_roll_sum  = 0.0
	_cal_timer     = 0.0
	print("SensorInput: starting averaged calibration (%d samples)..." % _calibration_samples)


func _collect_calibration_sample(raw_pitch: float, raw_roll: float, delta: float) -> void:
	_cal_timer += delta
	if _cal_timer < _calibration_sample_interval:
		return

	_cal_timer = 0.0
	_cal_pitch_sum += raw_pitch
	_cal_roll_sum  += raw_roll
	_cal_samples_collected += 1

	if _cal_samples_collected >= _calibration_samples:
		_calibration_pitch = _cal_pitch_sum / float(_calibration_samples)
		_calibration_roll  = _cal_roll_sum  / float(_calibration_samples)
		_calibrated = true
		_calibrating = false
		_smoothed_pitch = 0.0
		_smoothed_roll  = 0.0
		print("SensorInput: calibration done — pitch_base=%.3f roll_base=%.3f" % [
			_calibration_pitch, _calibration_roll
		])


# ============================================================================
# Query
# ============================================================================

func is_available() -> bool:
	return _sensors_available

func is_calibrated() -> bool:
	return _calibrated

func is_calibrating() -> bool:
	return _calibrating

func get_calibration() -> Dictionary:
	return {
		"pitch": _calibration_pitch,
		"roll":  _calibration_roll
	}
