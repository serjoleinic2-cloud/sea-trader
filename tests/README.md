# Tests

The project uses its own TestBase / TestRunner, not GUT. No test plugin is needed.

## Safe Linux run

Install a Godot 4.x executable appropriate for this project, then:

```bash
GODOT_BIN=/absolute/path/to/godot bash tests/run_tests.sh
```

The wrapper sets XDG_DATA_HOME to a newly created temporary directory before
starting Godot. Player saves are not used. Temporary test data is retained for
diagnosis. The runner refuses to run without SEA_TRADER_ISOLATED_TESTS=1;
do not set that variable for a normal player-data directory.

The wrapper first imports the project in headless editor mode, then runs
tests/test_runner.tscn. Assertion failures return exit code 1. Inspect engine
output for parse/runtime errors as well; an assertion count alone is not proof
that every script executed successfully.

The persistence suite deliberately exercises rejected/corrupt saves; warnings
and errors for those specific negative cases are expected.

## Coverage added for persistence

- New game seed and generator version, saved on initial launch.
- JSON round trip of every GameState section.
- Real main-scene launch preserving port progress, routes, voyage and ship.
- Empty saved knowledge and seed zero.
- Full generated-world equality and no mutation of player state.
- Non-destructive legacy migration and discovery-list repair.
- Corrupt main file recovery, backup-only launch and backup preservation.
- Refusal of unknown save/world versions and invalid save files.
- Background/pause save.
- Port discovery, re-entry/exit events and world/knowledge separation.

## Verification status (2026-09-08)

NOT RUN in Godot in the implementation environment: no engine was installed,
and engine download did not receive network approval. The test command exited
127 (godot: command not found). Do not treat these tests as passing yet.

Existing Android tilt/device tests still require a physical device.
