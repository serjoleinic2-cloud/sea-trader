# Persistent world / player knowledge — 2026-09-08

Status: implemented, awaiting Godot verification. No gameplay-complete claim.

## A. Files changed

- State and I/O: autoloads/game_state.gd, autoloads/save_system.gd,
  autoloads/event_bus.gd.
- Launch/ship: scripts/main.gd, scenes/game/ship/ship.gd,
  systems/ship/ship_physics.gd.
- World/ports: systems/world/world_generator.gd,
  systems/world/world_renderer.gd, systems/rendering/world_renderer.gd,
  systems/ports/port_system.gd, data/ports/port_template.json.
- Tests: tests/test_runner.gd, tests/run_tests.sh, tests/README.md,
  tests/unit/test_persistence.gd, tests/unit/test_phase05_ports.gd,
  tests/unit/test_save_system.gd, tests/unit/test_world_generation.gd.
- Documentation: rules/PROJECT_STATE.md, rules/SESSION_CONTEXT.md,
  rules/DATA_SCHEMA.md, rules/VERSION.json, this report.

## B. What was fixed

- Removed the remaining empty-PortState repopulation path and load-time
  position/region reset. The older handoff overstated the actual baseline bug:
  port initialization was already conditional and PortSystem already existed.
- Added schema-defined known routes and voyage persistence.
- Replaced reset-on-migration with additive migration for 0.0.0/0.1.0 saves.
  Unknown formats stop loading. Missing/corrupt primary can use backup.
- Separated generated port geometry from persisted player knowledge; preserved
  progression fields and recovered legacy discovered IDs from port flags.
- Ship restoration no longer initializes full fuel/health or zero velocity.
- Added initial, pause and normal-close saving; timestamp precedes serialization.
- Integrated missing port entry/exit signals and existing port tests.
- Active renderer queries saved discovery. The obsolete renderer implementation
  was replaced by a compatibility wrapper, recoverable from the parent commit.

## C. New Game behavior

Only absence of both primary and backup save creates a new seed. Generation
version comes from the existing config. Ship receives the existing quarter-world
spawn position. Player knowledge starts empty; it is not generated world data.
Initial save occurs after ship initialization.

## D. Load Existing Game behavior

Successful load restores the saved seed, including zero. World geometry is
regenerated with matching generation version. Empty saved PortState stays empty.
Ship, region, world position, routes and voyage are not reset during launch.
Failed load or unsupported versions stop startup without automatically saving
a replacement game. Legacy migrations are in memory until the next successful save.

## E. Data guaranteed to persist

Implementation covers seed/version, discovered IDs, explored regions, PortState
progression, known routes, every approved VoyageState field, ship position and
velocity, fuel, condition, cargo, and all existing GameState sections.

**Runtime guarantee is pending:** these paths are implemented and tested in source,
but the tests have not been executed in Godot here. No claim is made for abrupt
process termination, hardware/storage failure or future undocumented schemas.

## F. Tests

- PASS: whitespace/conflict check with git diff --check.
- PASS: bash syntax check for isolated test launcher.
- PASS: tracked JSON parsing and resource-path existence checks.
- BLOCKED: Godot import/parse, runtime, headless suite and keyboard playtest.
  No Godot executable installed; download did not receive network approval.
  The attempted launcher exited 127: godot: command not found.
- Added regression cases for new game, full JSON round trip, real launch,
  empty knowledge, zero seed, deterministic world, non-mutating generation,
  legacy migration, corrupt/backup-only saves, unknown versions and pause save.
- Existing port tests now use separate world fixtures and mutable signal capture;
  test runner includes them. No GUT dependency or replacement framework added.

## G. Remaining problems

- Run Godot before merging this work into the playable baseline.
- Heading while stationary is not in the approved state schema; moving heading
  is restored from velocity. No new field was invented in this task.
- Atomic crash-safe writes, periodic autosave, complete nested save validation
  and future migrations need separate work.
- Existing collision setup, hardcoded world bounds and placeholder physics/fuel
  balance remain. Device tilt is unchanged and not verified.
- Full route recording, voyage gameplay, economy, contracts, progression and
  fleet automation are not implemented by this iteration.
- Long-term retention is a design/playtesting goal, not something this patch can
  guarantee. The approved explore/discover/trade/expand progression is unchanged.

## H. Recommended next task

First run tests/run_tests.sh with an approved Godot 4.x binary and test actual
save/relaunch. Fix any parse/runtime failures and obtain sign-off. Then implement
KnownRoutesSystem as a bounded task: only a completed manual segment creates one
normalized bidirectional route; discovery alone and adjacent segments never
grant an untraveled direct route. Graphics and final design remain deferred.
