# PROJECT STATE

> Update this file after every meaningful iteration.
> Last Updated: 2026-08-24

---

## Version
`0.2.0`

## Current Phase
`Phase 02 -- World Generation (implemented, pending runtime sign-off)`

---

## Completed

### Phase 01 -- Foundation

- [x] Godot 4.x project created (`project.godot`)
- [x] Folder structure matches `ARCHITECTURE.md`
- [x] `GameState` autoload -- all 12 state classes from `DATA_SCHEMA.md`
- [x] `EventBus` autoload -- all signals from `SYSTEM_MAP.md`
- [x] `SaveSystem` autoload -- save/load/backup/migration, Vector2 serialization
- [x] Data folder structure with placeholder JSONs
- [x] `main.tscn` with autoload verification
- [x] `tests/` with GUT-compatible unit tests
- [x] All GDScript files pass static syntax checks (no inferred-type :=, balanced brackets)
- [x] Runtime verified: project opens, autoloads load, no parser/runtime errors

### Phase 02 -- World Generation

- [x] `data/world/world_gen_config.json` -- expanded parameters
- [x] `systems/world/world_generator.gd` -- deterministic generation
- [x] `systems/world/world_renderer.gd` -- placeholder visualization
- [x] `scenes/game/world.tscn` -- world scene
- [x] `scenes/game/main.tscn` -- updated with World + Camera2D
- [x] `scripts/main.gd` -- world initialization, seed, camera
- [x] `tests/unit/test_world_generation.gd` -- 10 tests
- [x] Runtime verified: islands, ports, hazard zones visible; camera WASD + zoom works

### Documentation Updates (2026-08-24)

- [x] `GAME_BIBLE.md` v0.2.0 -- added: Two Travel Modes, Route Discovery, Fuel/Supplies, Intermediary Ports, Risk Levels, Save during voyage
- [x] `GAME_RULES.md` v0.2.0 -- added non-negotiable: Manual Voyage primary, Known Route automation only, Save on exit, No punishment for closing app, Fuel limits range
- [x] `TRUTH.md` -- added principles: No punishment for closing app, Known Routes only for automation
- [x] `DATA_SCHEMA.md` v0.2.0 -- added: KnownRoutesState, VoyageState, fuel/fuel_max in ShipState
- [x] `SYSTEM_MAP.md` v0.2.0 -- added flows: Route Discovery, Known Route Automation, Manual Voyage Save/Resume

---

## New Decisions (Owner-Approved)

**Travel & Navigation:**
- Two travel modes: Manual Voyage (primary) and Known Route automation (secondary)
- First passage on any route is ALWAYS manual
- Known Routes are bidirectional: A --[manual]--> B becomes A <--[known]--> B
- Fleet operates on Known Routes only
- Player gradually builds trading network through exploration

**Fuel / Supplies:**
- Confirmed as range-limiting resource stat
- Consumed by both manual and automated travel
- Refuelable at ports
- Upgradeable capacity
- Exact consumption formula: TBD

**Save During Voyage:**
- Voyage state (position, cargo, fuel, hull, route, elapsed time) saved on exit
- Player can continue voyage on next launch
- No punishment for closing app (ship does not sink, cargo not lost)

**Risk Levels:**
- LOW / MEDIUM / HIGH risk zones
- Affects pirate encounter probability
- Exact probabilities: TBD

**Intermediary Ports:**
- Long routes may pass through multiple ports
- Intermediary ports allow: refuel, repair, trade, new contracts, continue expedition

---

## In Progress

- [ ] Phase 02 runtime sign-off (seed persistence check pending)

---

## Next

1. Confirm Phase 02 runtime sign-off (seed persistence)
2. **Phase 03 -- Ship Physics**
   - `ShipPhysics` -- momentum, inertia, turning radius, visual tilt
   - `ShipControl` -- normalized command input (-1..1)
   - Keyboard WASD for testing (tilt -- Phase 04)
   - Ship scene with tilt animation
   - Update `ShipState.position/velocity`

---

## Known Issues

- GUT addon not included -- must be installed via Godot Asset Library. Documented in `tests/README.md`.
- WorldRenderer uses placeholder graphics (colored circles). Visual polish in Phase 05.
- Hazard zones are defined but inactive (no gameplay effect). Activation in Phase 15.
- Camera controls are keyboard-only debug. Tilt controls in Phase 04.
- No ship, no physics, no port interaction -- all out of Phase 02 scope.
- SaveSystem checksum not implemented (TODO).
- MAX_OFFLINE_SECONDS not defined (TBD per GAME_RULES.md).
- `port_template.json` lacks version field -- intentional minimal placeholder.

---

## TBD (Pending Owner Decision)

- Exact Fuel / Supplies consumption formula
- Exact damage formulas (how much does hull damage reduce speed?)
- Contract reward formula (exact time-bonus calculation)
- Maximum offline progress cap
- Port fee specifics
- Full resource/goods catalog
- Pirate encounter mechanics (frequency, behavior, combat or avoidance?)
- Protection mechanic (defense ships, hired guards?)
- Storm mechanics detail
- Exact employee bonus values per role
- Port level progression path (which buildings, in what order?)
- Company level milestones
- Reputation system specifics (how earned, how spent?)
- Achievement list
- Starter Pack contents
- Whether "Premium" and "No Ads" are the same product or separate
- Custom Company Logo mechanic
- Maximum fleet size cap
- Exact automated route risk formula
- Exact automated route duration formula
- Exact speed bonus formula for urgent contracts
- Fleet auto-route income formula
- Multiplayer (explicitly out of scope for now)

---

## Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Godot 4.x over Unity | Lighter, free, native Android sensor API, better for 2D offline |
| GDScript primary | Simple syntax, good for AI-assisted development |
| GameState as autoload | Single source of truth, avoids scattered state |
| EventBus for decoupling | Prevents circular dependencies between systems |
| Direct calls allowed | EventBus not mandatory where coupling is obvious and local |
| JSON for game data | Designer-editable, no recompile needed, AI-readable |
| Versioned saves from v1 | Migration path available from day one |
| Dictionary-based state (Phase 01-02) | Flexibility, later can be typed Resources |
| GUT for tests | Standard Godot, not custom system |
| No ship autopilot | Manual control is core fantasy |
| No pay-to-win | Monetization only cosmetic/convenience |
| Known Routes for automation | Exploration first, automation as reward |
| Save during voyage | Respects player time, no punishment for exit |

---

## Last Updated
2026-08-24 -- Phase 02 implemented. New travel/navigation/fuel decisions documented and synchronized across all rules files. Gameplay: 0%. Infrastructure: Phase 01 100%, Phase 02 implementation complete.
