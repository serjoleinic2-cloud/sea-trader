# PROJECT STATE

> Update this file after every meaningful iteration.
> Last Updated: 2026-09-05

---

## Version
`0.4.0`

## Current Phase
`Phase 04 — Android Tilt Input (implemented, pending runtime sign-off on device)`

---

## Completed

### Phase 01 — Foundation
- [x] Godot 4.x project, autoloads, folder structure, placeholder JSON, tests
- [x] Runtime verified

### Phase 02 — World Generation
- [x] Deterministic world generator, renderer, 10 unit tests
- [x] Runtime verified

### Phase 03 — Ship Physics
- [x] ShipPhysics, ShipControl, SensorInput (stub), InputAdapter (keyboard debug)
- [x] Ship scene, Camera2D, debug HUD, collision foundation, 11 unit tests
- [x] GUT removed — custom TestBase, all tests passing in editor
- [x] Runtime sign-off pending (no blocking issues reported)

### Phase 04 — Android Tilt Input
- [x] `systems/input/sensor_input.gd` — full Android accelerometer implementation
  - OS.get_name() platform detection (Android/iOS vs desktop)
  - Raw accel read: Input.get_accelerometer() / 9.8 → normalized
  - Dead zone with smooth edge (no jump at boundary)
  - Per-axis clamp (pitch_clamp_raw, roll_clamp_raw)
  - Per-axis sensitivity (pitch_sensitivity, roll_sensitivity)
  - Output smoothing via lerp (smoothing_factor)
  - Steering inversion flag
  - Instant calibration: calibrate()
  - Averaged calibration: start_calibration() + background sampling
  - Auto-calibrate on start (configurable)
  - All tunable values loaded from data/input/input_config.json
- [x] `systems/input/input_adapter.gd` — updated
  - Sensitivity NOT re-applied (SensorInput handles it)
  - Keyboard ramp_speed loaded from input_config.json
  - Clean separation: tilt path via signal, keyboard path via _physics_process
- [x] `data/input/input_config.json` — new config file
  - All numeric parameters explicitly marked as TUNABLE/TBD
  - Sensitivity, dead zone, clamp, smoothing, calibration settings, keyboard ramp
- [x] `tests/unit/test_sensor_input.gd` — 11 tests (editor-runnable)
  - Android-only tests listed as NOT_VERIFIED (require physical device)
- [x] `tests/test_runner.gd` — updated TEST_FILES list

---

## Architecture: SensorInput signal flow

```
Android Accelerometer (hardware)
        |
        v
SensorInput._physics_process()
  1. Input.get_accelerometer() / 9.8
  2. subtract calibration baseline
  3. dead zone (smooth edge)
  4. clamp to raw range → normalize to −1..1
  5. apply sensitivity
  6. invert if configured
  7. lerp smoothing
        |
        v  (signal: tilt_updated)
InputAdapter._on_tilt_updated(pitch, roll)
        |  (direct call)
        v
ShipControl.send_control(throttle, steering)
        |  (direct call)
        v
ShipPhysics.apply_control(throttle, steering)
        |
        v
GameState.ship_state (position, velocity, fuel)
```

---

## Known Issues

- CollisionShape2D in ship.tscn still needs manual shape assignment in Godot Editor.
- World bounds clamping: hardcoded 4096×4096. Phase 05 cleanup.
- SaveSystem checksum not implemented (TODO).
- MAX_OFFLINE_SECONDS not defined (TBD).

---

## NOT VERIFIED (require physical Android device)

- Accelerometer produces correct values on real device tilt
- Dead zone prevents drift when phone held still
- Smoothing removes jitter in real conditions
- Calibration correctly zeros out neutral position
- Forward tilt → throttle positive (ship accelerates)
- Backward tilt → throttle negative (ship brakes)
- Left/right tilt → steering −1..1 (ship turns)
- Auto-calibration completes within expected time

---

## TBD (Pending Owner Decision)

- pitch_sensitivity final value (currently 1.8 — placeholder)
- roll_sensitivity final value (currently 1.6 — placeholder)
- dead_zone final value (currently 0.08 — placeholder)
- pitch_clamp_raw / roll_clamp_raw (currently 0.7 — placeholder)
- smoothing_factor (currently 0.25 — placeholder)
- calibration sample count and interval
- Exact Fuel / Supplies consumption formula
- Exact damage formulas
- Contract reward formula
- Maximum offline progress cap
- Port fee specifics
- Full resource/goods catalog
- Pirate encounter mechanics
- Protection mechanic
- Storm mechanics
- Employee bonus values
- Port level progression
- Company level milestones
- Reputation system
- Achievement list
- Starter Pack contents
- Premium vs No Ads
- Custom Company Logo
- Maximum fleet size cap
- Automated route formulas
- Fleet auto-route income formula

---

## Next

**Phase 05** — (to be defined by owner)

---

## Last Updated
2026-09-05 — Phase 04 Android Tilt Input implemented.
