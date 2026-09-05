# PROJECT STATE

> Update this file after every meaningful iteration.
> Last Updated: 2026-09-05

---

## Version
`0.3.0`

## Current Phase
`Phase 03 — Ship Physics (implemented, pending runtime sign-off)`

---

## Completed

### Phase 01 — Foundation

- [x] Godot 4.x project created (`project.godot`)
- [x] Folder structure matches `ARCHITECTURE.md`
- [x] `GameState` autoload — all state classes from `DATA_SCHEMA.md`
- [x] `EventBus` autoload — all signals from `SYSTEM_MAP.md`
- [x] `SaveSystem` autoload — save/load/backup/migration, Vector2 serialization
- [x] Data folder structure with placeholder JSONs
- [x] `main.tscn` with autoload verification
- [x] `tests/` with GUT-compatible unit tests
- [x] All GDScript files pass static syntax checks
- [x] Runtime verified: project opens, autoloads load, no parser/runtime errors

### Phase 02 — World Generation

- [x] `data/world/world_gen_config.json` — expanded parameters
- [x] `systems/world/world_generator.gd` — deterministic generation
- [x] `systems/world/world_renderer.gd` — placeholder visualization
- [x] `scenes/game/world.tscn` — world scene
- [x] `scenes/game/main.tscn` — updated with World
- [x] `scripts/main.gd` — world initialization, seed, camera
- [x] `tests/unit/test_world_generation.gd` — 10 tests
- [x] Runtime verified: islands, ports, hazard zones visible

### Documentation Updates (2026-08-24)

- [x] `GAME_BIBLE.md` v0.2.0
- [x] `GAME_RULES.md` v0.2.0
- [x] `TRUTH.md`, `DATA_SCHEMA.md` v0.2.0, `SYSTEM_MAP.md` v0.2.0

### Phase 03 — Ship Physics

- [x] `systems/ship/ship_physics.gd` — momentum, inertia, turning, visual roll, fuel consumption
- [x] `systems/ship/ship_control.gd` — normalized command interface
- [x] `systems/input/sensor_input.gd` — Android accelerometer abstraction (stub, Phase 04 activates)
- [x] `systems/input/input_adapter.gd` — keyboard debug fallback + tilt path ready
- [x] `scenes/game/ship/ship.gd` — ship scene script, HUD, collision foundation
- [x] `scenes/game/ship/ship.tscn` — Polygon2D visual, Camera2D (follows ship), Area2D, DebugHUD
- [x] `scripts/main.gd` — updated: spawns Ship, Camera2D moved inside Ship
- [x] `scenes/game/main.tscn` — updated: removed standalone Camera2D
- [x] `autoloads/game_state.gd` — added `fuel_max`, `cargo_capacity` to ship_state
- [x] `data/ships/ship_sloop.json` — version bump to 2, `fuel_capacity` confirmed present
- [x] `tests/unit/test_ship_physics.gd` — 11 tests covering all required scenarios

---

## New Decisions (Owner-Approved)

**Travel & Navigation:**
- Two travel modes: Manual Voyage (primary) and Known Route automation (secondary)
- First passage on any route is ALWAYS manual
- Known Routes are bidirectional
- Fleet operates on Known Routes only

**Fuel / Supplies:**
- Confirmed as range-limiting resource stat
- Consumed during movement (placeholder rate: 0.5/s at full speed — TBD)
- Exact consumption formula: TBD

**Save During Voyage:**
- Voyage state saved on exit; ship restored on relaunch

---

## In Progress

- [ ] Phase 03 runtime sign-off (open Godot, run, verify ship movement)

---

## Next

1. Runtime sign-off for Phase 03
2. **Phase 04 — Sensors**
   - Activate `SensorInput` accelerometer reading
   - Calibration UI (basic)
   - Sensitivity configurable via `SettingsState`
   - Keyboard fallback preserved

---

## Known Issues

- GUT addon not included — install via Godot Asset Library. See `tests/README.md`.
- `ShipVisual` is a Polygon2D placeholder. Visual polish in Phase 05.
- `CollisionShape2D` in ship.tscn has no shape resource assigned — must be set in Godot editor (CircleShape2D radius ~14px recommended). Collision foundation is in place.
- Android sensor reading is stubbed (sensor_input.gd). Activates in Phase 04.
- Hazard zones are defined but inactive. Activation in Phase 15.
- SaveSystem checksum not implemented (TODO).
- MAX_OFFLINE_SECONDS not defined (TBD).
- World bounds clamping uses hardcoded 4096×4096 — should read from world_gen_config. Noted for Phase 05 cleanup.

---

## TBD (Pending Owner Decision)

- Exact Fuel / Supplies consumption formula
- Exact damage formulas
- Contract reward formula (time-bonus)
- Maximum offline progress cap
- Port fee specifics
- Full resource/goods catalog
- Pirate encounter mechanics
- Protection mechanic
- Storm mechanics detail
- Exact employee bonus values per role
- Port level progression path
- Company level milestones
- Reputation system specifics
- Achievement list
- Starter Pack contents
- Premium vs No Ads (same or separate?)
- Custom Company Logo mechanic
- Maximum fleet size cap
- Exact automated route risk/duration formulas
- Fleet auto-route income formula
- Multiplayer (out of scope)

---

## Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Godot 4.x over Unity | Lighter, free, native Android sensor API, better for 2D offline |
| GDScript primary | Simple syntax, good for AI-assisted development |
| GameState as autoload | Single source of truth |
| EventBus for decoupling | Prevents circular dependencies |
| Direct calls allowed | EventBus not mandatory where coupling is obvious |
| JSON for game data | Designer-editable, no recompile |
| Versioned saves from v1 | Migration path available from day one |
| GUT for tests | Standard Godot |
| No ship autopilot | Manual control is core fantasy |
| No pay-to-win | Monetization only cosmetic/convenience |
| Known Routes for automation | Exploration first, automation as reward |
| Save during voyage | Respects player time |
| Camera2D inside Ship scene | Follows ship automatically; no manual camera management |
| SensorInput stub in Phase 03 | Abstraction complete; activation deferred to Phase 04 |
| Polygon2D for ship visual | Lightweight placeholder; supports rotation for heading + roll |

---

## Last Updated
2026-09-05 — Phase 03 implemented. Ship physics, control, sensor abstraction, debug HUD, collision foundation, 11 unit tests. Gameplay: Phase 01-02 infrastructure 100%, Phase 03 ship pending runtime sign-off.
