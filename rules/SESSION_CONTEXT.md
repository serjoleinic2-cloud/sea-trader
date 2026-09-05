# SEA TRADER — SESSION CONTEXT

> Short handoff document for new AI sessions.
> Read this first, then rules/*. Do not start coding before reading.
> Last Updated: 2026-09-05

---

## PROJECT

| Field | Value |
|-------|-------|
| Название | Sea Trader |
| Жанр | Offline top-down 2D maritime trading simulation |
| Платформа | Android primary, iOS secondary |
| Engine | Godot 4.x (GDScript) |
| Offline/Online | Offline-first. No backend. Ever. |

---

## CURRENT PHASE

**Phase 04 — Android Tilt Input (DONE, pending device sign-off)**

---

## COMPLETED

- Phase 01: Foundation (verified)
- Phase 02: World Generation (verified)
- Phase 03: Ship Physics, keyboard debug, test_base/test_runner без GUT (verified in editor)
- Phase 04: Android Tilt Input — SensorInput полностью реализован:
  - Платформо-детекция, акселерометр, dead zone, clamp, sensitivity, smoothing, calibration
  - input_config.json — все параметры вынесены, помечены TBD
  - Keyboard fallback сохранён (editor/desktop)
  - test_sensor_input.gd — 11 тестов, editor-runnable

---

## ARCHITECTURE: INPUT CHAIN

```
Phone accelerometer
     ↓
SensorInput (единственный файл с Android API)
  - платформо-детекция
  - dead zone, clamp, sensitivity, smoothing
  - calibration (instant + averaged)
     ↓ signal: tilt_updated(pitch, roll)
InputAdapter
  - forward to ShipControl (tilt)
  - keyboard fallback (editor only)
     ↓
ShipControl → ShipPhysics → GameState.ship_state
```

---

## IMPORTANT: SensorInput ONLY

`SensorInput` — единственный файл с `Input.get_accelerometer()`.
Ни один другой файл не должен обращаться к Android Sensor API.

---

## NOT VERIFIED (требует физического Android устройства)

- Акселерометр даёт правильные значения при наклоне
- Dead zone устраняет дрейф при неподвижном телефоне
- Calibration обнуляет нейтральное положение
- Наклон вперёд → ускорение; назад → торможение; лево/право → поворот

---

## TUNABLE / TBD PARAMETERS

В `data/input/input_config.json`, все помечены как placeholder:
- pitch_sensitivity: 1.8
- roll_sensitivity: 1.6
- dead_zone: 0.08
- pitch_clamp_raw: 0.7
- roll_clamp_raw: 0.7
- smoothing_factor: 0.25
- calibration.samples: 8

---

## KNOWN ISSUES

- CollisionShape2D в ship.tscn: назначить CircleShape2D radius ~14 в Godot Editor
- World bounds clamping: хардкод 4096×4096 (Phase 05 cleanup)
- SaveSystem checksum: TODO

---

## DEVELOPMENT RULES

- Offline-first. Детерминированный мир. Data-driven.
- SensorInput only: Android API только в systems/input/sensor_input.gd
- Не решать TBD. Не добавлять фичи вне текущей Phase.
- Не переходить к Phase 05 без sign-off.

---

*Last Updated: 2026-09-05 | Phase 04 — Android Tilt Input*
