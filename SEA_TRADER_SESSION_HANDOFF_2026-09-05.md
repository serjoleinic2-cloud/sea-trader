# SEA TRADER — SESSION HANDOFF / MASTER CONTEXT
Updated: 2026-09-05

## 1. PROJECT
Sea Trader — offline-first mobile game being developed in Godot 4.x.

Local project:
D:\sea-trader

IMPORTANT:
- This is a Godot project, NOT Vite/Capacitor.
- There is currently NO `package.json` and NO `android` folder in D:\sea-trader.
- Do NOT run `npx vite build`, `npx cap sync`, or similar web/Capacitor commands for this project.
- Android testing/export should be done through Godot/Android tooling.
- User is a non-programmer and needs concrete, step-by-step instructions.
- Current workflow: User → ChatGPT → Claude/Kimi → ZIP/files → user replaces files locally → Godot check → GitHub Desktop commit/push.
- OpenCode is currently not used.

## 2. CORE GAME IDEA
Top-down 2D mobile trading game on a sea map.

Player controls a small cargo ship.
Main mobile control:
- tilt forward = accelerate
- tilt backward = brake/decelerate
- tilt left = steer left
- tilt right = steer right

Desktop/Godot debug:
- W/S/A/D emulate the same control.
- Keyboard input should be smooth/ramped, not instant.

Ship:
- speed / max speed
- acceleration
- deceleration / braking
- turn speed
- inertia
- hull / hull_max
- fuel / fuel_max
- cargo capacity
- visual roll/lean when steering (simple 2D visual effect, not full 3D physics)

Camera:
- Camera2D follows the ship.
- Current camera framing/zoom is not important now; polish later.
- Priority is gameplay logic, not visual polish.

## 3. WORLD
World is a sea, not a river.
Procedurally generated islands and ports.
World generation must be deterministic by seed:
- same seed → same world
- seed belongs to WorldState
- seed must persist through save/load.

Player should NOT immediately see the entire trading network.
The player explores the sea and discovers ports/resources/opportunities/danger zones.

Ports:
- id
- name
- region
- level
- available resources
- discovered state
- later: economy, trade, repairs, contracts, development

Long routes can contain intermediary ports:
A → B → C → D
Intermediary ports may later allow refuel, repair, trade, cargo changes, contracts.

## 4. ROUTES / TRAVEL
Two travel modes:

1. Manual Voyage — PRIMARY
- player personally controls ship
- exploration
- speed bonuses may exist later
- hazards/pirates later
- fuel/supplies consumed
- damage later

2. Automated / Known Route — SECONDARY
- only available after route has been manually completed
- known routes are bidirectional
- automation/fleet use only Known Routes
- exact duration/risk/income formulas are TBD
- automated travel should not punish the player merely for closing the app

First passage of a new route is always manual.

## 5. SAVE / EXIT RULE
NON-NEGOTIABLE:
If player closes the app during a Manual Voyage:
- ship must NOT be destroyed
- progress must NOT be lost just because app was closed
- voyage state must save
- on next launch player can continue
- save should preserve relevant voyage data such as route, position, cargo, fuel, hull, voyage state, etc.

Closing the app is never itself a punishment.

## 6. FUEL / EMERGENCY IDEA
Fuel is a range resource.
Fuel is replenished in ports.
Fuel capacity can later be upgraded.
Exact fuel formula is TBD.

Current temporary formula from Phase 03:
0.5 * speed_ratio * delta

Current desired behavior when fuel reaches 0:
- engine stops / no further powered acceleration
- ship can continue briefly by inertia and gradually slow
- player gets clear warning
- later possibility: Emergency Generator / reserve generator
- generator should be optional purchasable equipment, not a forced purchase
- exact generator speed, duration, price, etc. are TBD
- do NOT implement final balance now

## 7. OTHER PLANNED SYSTEMS
Future:
- resources / goods
- trade
- contracts
- urgent contracts / speed bonus
- repair
- pirates
- storms
- cannons/obstacles
- protective escort boat
- XP / progression
- reputation
- achievements
- own port and port development
- NPC trade
- employees and salaries
- company
- fleet
- automated routes
- taxes / recurring costs
- skins / company logo
- ads / No Ads
- Premium day/week/month
- possible starter offer

These are future systems unless explicitly assigned to the current phase.

## 8. ARCHITECTURE / RULES
Core principle:
Static Data → JSON
Runtime State → State models
Systems → modify state through controlled methods
Presentation/UI → display state

Do not force every system to communicate only through EventBus; use EventBus where appropriate.

Rules folder currently contains:
- AI_DEVELOPMENT_RULES.md
- ARCHITECTURE.md
- DATA_SCHEMA.md
- DEVELOPMENT_PHASES.md
- GAME_BIBLE.md
- GAME_RULES.md
- Master Game Bible.md
- PROJECT_STATE.md
- SYSTEM_MAP.md
- TRUTH.md
- VERSION.json
- SESSION_CONTEXT.md (created/updated during recent work)

Important:
- Read rules before significant changes.
- Do not create duplicate systems.
- Do not silently change game concept.
- Do not decide TBD formulas without instruction.
- No backend/online system.
- Update PROJECT_STATE / SESSION_CONTEXT after significant work.
- Do not automatically advance to the next phase.

## 9. FOUNDATION — PHASE 01
Foundation created by Kimi.

Main files/systems include:
- project.godot
- autoloads/game_state.gd
- autoloads/event_bus.gd
- autoloads/save_system.gd
- data/ships/ship_sloop.json
- data/ports/port_template.json
- data/resources/goods_catalog.json
- data/upgrades/upgrades_catalog.json
- data/employees/roles_catalog.json
- data/achievements/achievements.json
- data/world/world_gen_config.json
- data/contracts/contract_templates.json
- scenes/game/main.tscn
- scripts/main.gd
- scripts/constants.gd
- tests/
- systems/*/

Phase 01 static verification was reported as complete.
A previous Variant warning was fixed; user confirmed there were no errors after that fix.

## 10. PHASE 02 — WORLD GENERATION
World generation was implemented.
Observed in Godot:
- sea
- procedural islands
- port names
- large translucent circles / debug-like areas were visible

A separate diagnostic question was raised about those circles:
- what they represent
- what creates them
- gameplay or debug
- why they overlap
- whether they belong in final game

Do not assume they are final gameplay until verified.

Seed persistence was the remaining sign-off item in Phase 02 documentation.

Important future TBD:
- World bounds currently hardcoded 4096×4096.
- Phase 05 should determine whether bounds should come from `world_gen_config.json`.
Do not fix this casually during another phase.

## 11. PHASE 03 — SHIP PHYSICS
Claude implemented the ship foundation.

Architecture:
SensorInput → InputAdapter → ShipControl → ShipPhysics → GameState.ship_state

Implemented/reported:
- separate acceleration / deceleration / brake
- inertia using move_toward
- visual roll using lerp with MAX_ROLL_DEGREES and return to neutral
- Camera2D child of Ship
- Fuel cannot go below 0
- fuel consumption proportional to speed
- ship parameters loaded from ship_sloop.json, not hardcoded
- keyboard debug has smooth ramp
- collision foundation exists
- CollisionShape2D still requires assigning a shape in Godot Editor (CircleShape2D around 14 px was suggested)
- debug HUD / state visibility exists

Not verified at that time:
- runtime in Godot Editor
- real Android tilt
- CollisionShape2D shape assignment

User later confirmed:
- no visible errors
- ship IS visible when the game is run in a separate/full game window
- camera currently looks extremely high / too zoomed out
- this is considered a cosmetic issue for later
- left/top debug indicators react to keyboard input

PRIORITY RULE:
Do not spend time polishing camera, ship appearance, navigation UI, etc. until core gameplay logic is built.

## 12. PHASE 04 — ANDROID TILT INPUT
Claude implemented/reported:

Files:
- systems/input/sensor_input.gd — rewritten from stub to working Phase 04
- systems/input/input_adapter.gd — updated
- data/input/input_config.json — created
- tests/unit/test_sensor_input.gd — created
- tests/test_runner.gd — updated
- rules/PROJECT_STATE.md — updated
- rules/SESSION_CONTEXT.md — updated

ShipPhysics and ShipControl were NOT touched.

Android sensor chain:
OS.get_name() checks Android/iOS.
On mobile:
Input.get_accelerometer()
→ divide by 9.8
→ subtract calibration baseline
→ dead zone with smoothed edge
→ clamp raw values
→ normalize to [-1,1]
→ sensitivity
→ lerp smoothing
→ emit pitch/roll
→ InputAdapter
→ ShipControl
→ ShipPhysics

Calibration:
- calibrate() = immediate baseline snapshot
- start_calibration() = collects N samples and averages them
- during calibration emits (0,0)
- auto_calibrate_on_start = true

Current conditional/TBD values in data/input/input_config.json:
- pitch_sensitivity = 1.8
- roll_sensitivity = 1.6
- dead_zone = 0.08
- pitch_clamp_raw = 0.7
- roll_clamp_raw = 0.7
- smoothing_factor = 0.25
- calibration.samples = 8

These are NOT final; tune only after device playtesting.

Cannot be fully verified without physical Android device:
- actual accelerometer direction
- dead-zone drift behavior
- jitter/smoothing
- calibration behavior
- end-to-end tilt → ship movement

## 13. TEST SYSTEM ISSUE
There was a GUT dependency problem.

Godot showed:
Could not find base class "GutTest"
for:
- tests/unit/test_event_bus.gd
- tests/unit/test_game_state.gd
- tests/unit/test_save_system.gd
- tests/unit/test_ship_physics.gd
- tests/unit/test_world_generation.gd

Claude said GUT was removed and replaced with:
- tests/test_base.gd
- tests/test_runner.gd
and rewrote tests to extend test_base.

However, Godot later still reported the old `GutTest` errors, indicating the actual files did not match Claude's reported state, or old versions remained.

User said Claude's tokens had run out.
DO NOT assume the test migration is actually fixed.
When Claude/Kimi is available again, inspect the actual files before making further claims.
Do not blindly rewrite them.

## 14. ANDROID TESTING CONFUSION — IMPORTANT
A mistaken instruction previously told user to run:
npx vite build
npx cap sync android
and open D:\sea-trader\android.

This was WRONG for Sea Trader.

Confirmed:
- D:\sea-trader has no package.json
- D:\sea-trader has no android folder
- Sea Trader is a Godot project.

Correct direction:
- Android testing/export should be done through Godot and its Android export/deployment setup.
- Do NOT run Vite/Capacitor commands for this project.

## 15. CURRENT STATUS
As of 2026-09-05:
- Phase 01 Foundation: implemented, basic runtime issue previously fixed.
- Phase 02 World Generation: implemented; seed persistence sign-off was pending.
- Phase 03 Ship Physics: implemented conditionally.
- Phase 04 Android Tilt Input: implemented conditionally.
- User has not yet completed real physical Android testing.
- Main priority is now continuing the game's CORE LOGIC.
- Cosmetic polish is explicitly deferred.

The user wants:
“сейчас делаем все условно”
and
“все мелочи потом главное всю основную логику игры, украшательства потом”.

Therefore:
- use placeholder visuals
- use placeholder formulas
- use simple debug UI
- focus on complete gameplay systems
- do not over-polish
- do not prematurely balance

## 16. FUTURE PHASE DIRECTION
After Phase 04, proceed through major gameplay systems in logical dependency order.

Likely next major area:
- Phase 05 World/Navigation/Ports foundation, but check the project's actual DEVELOPMENT_PHASES.md / PROJECT_STATE.md before deciding exact phase scope.

Do not invent a phase plan if the repository documentation defines it differently.

## 17. WORK STYLE
User prefers:
- concise answers
- exact ready-to-send prompts for Claude/Kimi
- minimal theory
- no exaggerated praise
- dry, practical evaluation
- assistant should spend reasoning internally and give actionable task text
- do not ask user to manually edit code unless necessary
- when using Claude/Kimi, give a bounded task with explicit exclusions
- after each task, user will report what the agent changed; then evaluate it
