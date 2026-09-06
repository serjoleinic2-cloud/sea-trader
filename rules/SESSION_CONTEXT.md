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

## COMPLETED PHASES

- **Phase 01:** Foundation — autoloads, folder structure, tests (verified)
- **Phase 02:** World Generation — deterministic seed, renderer (verified)
- **Phase 03:** Ship Physics — movement, inertia, visual roll, Camera2D, debug HUD, TestBase (verified in editor)
- **Phase 04:** Android Tilt Input — SensorInput with accelerometer, dead zone, calibration, smoothing; input_config.json (pending device sign-off)

---

## CURRENT STATUS

**Phase 04 done. Phase 05 not yet defined.**

**Documentation update completed 2026-09-05:**
All rules/*.md files updated with World Permanence + Player Knowledge architecture.

---

## KEY ARCHITECTURE DECISIONS (must know before coding)

### 1. World Seed is Permanent
```
New game → generate seed → save it → NEVER change it again
Load game → read seed → regenerate same world from same seed
```

### 2. World ≠ Player Knowledge
```
World Data (from seed):
  island positions, port IDs/positions, hazard zones
  → regenerated on every load, not stored as geometry

Player Knowledge (saved separately):
  PortState (discovered, level, buildings)
  KnownRoutesState (known routes)
  PlayerState.discovered_port_ids
  → must survive every load
```

### 3. Discovered Port ≠ Known Route
```
Port B discovered → visible on map, can set as destination
                    BUT auto-travel not yet available

Known Route A↔B → player sailed A→B manually at least once
                   → auto-travel and fleet assignment now available
```

### 4. Known Routes bidirectional, segment-based
```
A→B manual → KnownRoute(A,B) = KnownRoute(B,A) ✓
B→C manual → KnownRoute(B,C) = KnownRoute(C,B) ✓
A→C direct known route? ✗ (only if sailed A→C directly)
```

---

## CRITICAL BUG IN CURRENT CODE (fix in Phase 05)

**File:** `scripts/main.gd`, function `_initialize_world()`

**Problem:**
```gdscript
GameState.port_state = world_data.ports.duplicate(true)  # ← runs on EVERY launch
```
This overwrites loaded PortState (with player discovery data) with fresh generated ports (all undiscovered). Player loses all discovery progress on every reload.

**Required fix:**
Only set `port_state` from `world_data` on **new game**. On load, use the persisted `port_state`.

**Do not fix this here.** Fix in the Phase 05 code task.

---

## MISSING FROM GAMESTATE (add in Phase 05 code task)

```gdscript
# In game_state.gd — not yet present:
var known_routes_state: Dictionary = {}   # KnownRoutesState
var voyage_state: Dictionary = {}         # VoyageState

# In world_state — missing field:
"world_gen_version": ""                   # for future migration
```

```gdscript
# In save_system.gd — not yet serialized/deserialized:
known_routes_state
voyage_state
```

---

## INPUT CHAIN (Phase 04)

```
Phone accelerometer
     ↓
SensorInput (ONLY file with Android API)
  - platform detection, dead zone, clamp, sensitivity, smoothing, calibration
     ↓ signal: tilt_updated(pitch, roll)
InputAdapter
  - forward to ShipControl (tilt)
  - keyboard fallback (editor only)
     ↓
ShipControl → ShipPhysics → GameState.ship_state
```

---

## TUNABLE / TBD (data/input/input_config.json)

All placeholder values, tune after device playtesting:
- pitch_sensitivity: 1.8
- roll_sensitivity: 1.6
- dead_zone: 0.08
- pitch_clamp_raw / roll_clamp_raw: 0.7
- smoothing_factor: 0.25
- calibration.samples: 8

---

## DEVELOPMENT RULES

- **Offline-first.** No network calls.
- **World Seed permanent.** Never randi() on load.
- **Player Knowledge separate.** PortState, KnownRoutesState, discovered_port_ids are player progress — never overwrite from world generation.
- **SensorInput only.** Android API only in `systems/input/sensor_input.gd`.
- **No game logic in UI.**
- **SaveSystem = единая точка I/O.**
- **Не решать TBD.** Фиксировать в KNOWN ISSUES.
- **Не переходить к следующей Phase без sign-off.**

---

*Last Updated: 2026-09-05 | Phase 04 done. Documentation: World Permanence + Player Knowledge.*
