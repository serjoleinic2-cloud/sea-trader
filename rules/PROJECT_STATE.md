# PROJECT STATE

> Update this file after every meaningful iteration.
> Last Updated: 2026-09-05

---

## Version
`0.4.1`

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

### Phase 04 — Android Tilt Input
- [x] SensorInput — full accelerometer implementation, dead zone, calibration, smoothing
- [x] InputAdapter — clean separation tilt/keyboard paths
- [x] data/input/input_config.json — all tunable values in config
- [x] test_sensor_input.gd — 11 tests

### Documentation Update — World Permanence + Player Knowledge
- [x] **TRUTH.md** — added rules 9, 10, 11 (World Seed permanent, World ≠ Player Knowledge, first passage = Known Route)
- [x] **ARCHITECTURE.md** — added "World Identity and Player Knowledge" section; KnownRoutesSystem spec; WorldGenerator critical rule; SaveSystem critical rule; FleetManager critical rule
- [x] **DATA_SCHEMA.md** — added `world_gen_version` to WorldState; KnownRoutesState schema with bidirectionality rules; PortState and KnownRoutesState marked as Player Knowledge; save/load table; route_key normalization rule
- [x] **GAME_RULES.md** — added rules 11–15 (World Seed permanent, World ≠ Player Knowledge, Discovered Port ≠ Known Route, bidirectionality, segment-based knowledge)
- [x] **GAME_BIBLE.md** — added "World Seed is Permanent" section, "World ≠ Player Knowledge" section, "Discovered Port ≠ Known Route" flow, "Segment-based Knowledge" section, "Social Trading" as TBD/future
- [x] **SYSTEM_MAP.md** — added World Load Flow, New Game Flow, Port Discovery vs Known Route diagram, Segment-based Knowledge example, updated Save/Load and World Generation flows with Player Knowledge annotations

---

## Architecture Decisions (new, 2026-09-05)

| Decision | Rationale |
|----------|-----------|
| World Seed is permanent | Same seed = same world on every load; player's world is stable |
| World data regenerated on load | No need to save island/port geometry; seed + algorithm = deterministic |
| Player Knowledge saved separately | Discovery and routes are irreplaceable player progress |
| Discovered Port ≠ Known Route | Discovery gives visibility; route requires manual passage |
| Known Routes bidirectional | One record covers both directions; simpler and consistent |
| Route key alphabetically normalized | "port_a--port_b" always same regardless of travel direction |
| KnownRoutesSystem validates before automation | Fleet/autopilot cannot use unknown routes |
| world_gen_version in WorldState | Enables safe migration if generation algorithm evolves |
| Social trading = future/TBD | Does not conflict with offline-first or deterministic world |

---

## Consistency Check: Current Code vs New Architecture

### ✅ Already Compliant

| File | Status |
|------|--------|
| `systems/world/world_generator.gd` | Seed-based, deterministic, does not overwrite PortState |
| `autoloads/game_state.gd` | Has `world_state.seed`, `player_state.discovered_port_ids`, `port_state` |
| `autoloads/save_system.gd` | Saves/restores world_state (including seed), port_state, player_state |
| `scripts/main.gd` | `_get_or_create_seed()` correctly loads existing seed or creates new one |

### ⚠️ Not Yet Implemented (code gaps, no violation of current state)

| # | File | Issue | Required Change |
|---|------|-------|-----------------|
| 1 | `autoloads/game_state.gd` | `KnownRoutesState` not present as a top-level state variable | Add `known_routes_state: Dictionary = {}` |
| 2 | `autoloads/game_state.gd` | `VoyageState` not present | Add `voyage_state: Dictionary` |
| 3 | `autoloads/game_state.gd` | `WorldState` missing `world_gen_version` field | Add `"world_gen_version": ""` |
| 4 | `autoloads/save_system.gd` | `known_routes_state` not serialized/deserialized | Add to `_serialize_game_state()` and `_deserialize_game_state()` |
| 5 | `autoloads/save_system.gd` | `voyage_state` not serialized | Add to serialize/deserialize |
| 6 | `scripts/main.gd` | After load, `WorldGenerator.generate()` is called but `PortState` is immediately overwritten with fresh world data: `GameState.port_state = world_data.ports.duplicate(true)` | **This is the main conflict.** On load (not new game), must NOT overwrite PortState. Must use loaded PortState. Only set on new game. |
| 7 | `systems/world/` | `KnownRoutesSystem` does not exist yet | Create in Phase 05 |
| 8 | `systems/world/` | `PortSystem` discovery logic not yet implemented (Phase 05) | Create in Phase 05 |

### ⚠️ Critical Conflict (item 6 above — detail)

In `scripts/main.gd`, `_initialize_world()`:
```gdscript
GameState.port_state = world_data.ports.duplicate(true)  # ← THIS LINE
```
This runs on every launch, including after load. It replaces the loaded `PortState` (with discovery data) with freshly generated ports (all `discovered: false`). This destroys player discovery progress on every reload.

**Fix required (in a future code task, not this documentation task):**
```gdscript
if _is_new_game:
    GameState.port_state = world_data.ports.duplicate(true)
# else: keep loaded PortState, only use world_data for geometry queries
```

---

## Known Issues

- **CRITICAL:** `scripts/main.gd` overwrites `PortState` on every launch, destroying discovery state. Fix in Phase 05.
- `KnownRoutesState` not yet in GameState or SaveSystem.
- `VoyageState` not yet in GameState.
- `WorldState.world_gen_version` not yet in schema.
- CollisionShape2D in ship.tscn needs manual shape assignment in Godot Editor.
- World bounds clamping: hardcoded 4096×4096. Phase 05 cleanup.
- SaveSystem checksum not implemented.
- MAX_OFFLINE_SECONDS not defined (TBD).

---

## TBD (Pending Owner Decision)

- pitch_sensitivity / roll_sensitivity / dead_zone / smoothing_factor final values
- Exact Fuel consumption formula
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
- Rules for multi-hop automated navigation (A→B→C chain)
- Discovery range for ports (trigger distance)
- Social trading mechanics

---

## Next

**Phase 05** — (to be defined by owner)
Likely includes: WorldRenderer full, PortSystem discovery, KnownRoutesSystem foundation, fix for PortState overwrite issue.

---

## Last Updated
2026-09-05 — Documentation update: World Permanence + Player Knowledge architecture fixed in all rules/*.md files. Consistency check completed.
