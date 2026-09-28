extends "res://tests/test_base.gd"

var _system: Node

func before_each() -> void:
    SaveSystem.delete_save()
    GameState.reset_to_defaults()
    GameState.world_state.seed = 42
    GameState.world_state.home_port_id = "home"
    GameState.ship_state.docked_port_id = "home"
    GameState.player_state.money = 50000.0
    GameState.port_state = {"home": {"inventory": {"resource_timber": 500, "resource_parts": 300}}}
    _system = load("res://systems/combat/combat_system.gd").new()
    add_child(_system)
    _system.initialize()

func after_each() -> void:
    if is_instance_valid(_system):
        _system.free()
    SaveSystem.delete_save()
    GameState.reset_to_defaults()

func test_new_game_has_a_small_starter_garrison() -> void:
    assert_eq(int(GameState.combat_state.units.coast_guard.count), 8, "new captain can defend the base before recruiting")
    assert_eq(_system.get_roster().size(), 6, "locked troop branches are visible in the roster")
    assert_gt(_system.get_defense_power(), 0, "starter defenders provide actual defense")

func test_recruitment_finishes_and_persists() -> void:
    var result: Dictionary = _system.recruit("coast_guard", 2)
    assert_true(bool(result.get("ok", false)), "recruiting an unlocked unit starts training")
    var job: Dictionary = GameState.combat_state.recruitment
    job["completes_at"] = int(Time.get_unix_time_from_system())
    GameState.combat_state["recruitment"] = job
    _system._process(0.0)
    assert_eq(int(GameState.combat_state.units.coast_guard.count), 10, "trained squad joins home roster")
    assert_true(GameState.combat_state.recruitment.is_empty(), "training slot becomes free after completion")

func test_garrison_levels_unlock_units_and_towers_affect_defense() -> void:
    var upgrade_result: Dictionary = _system.upgrade_garrison()
    assert_true(bool(upgrade_result.get("ok", false)), "upgrade consumes materials and starts timed construction")
    assert_eq(_system.get_garrison_level(), 1, "new unit tier stays locked during construction")
    var job: Dictionary = GameState.combat_state.construction_job
    job["completes_at"] = int(Time.get_unix_time_from_system())
    GameState.combat_state["construction_job"] = job
    _system._process(0.0)
    assert_eq(_system.get_garrison_level(), 2, "garrison progression is saved")
    assert_true(_system.can_recruit("rune_spearman", 1), "medium infantry unlocks at level two")
    var tower_result: Dictionary = _system.build_tower("guard")
    assert_true(bool(tower_result.get("ok", false)), "level two supports two tower slots")
    job = GameState.combat_state.construction_job
    job["completes_at"] = int(Time.get_unix_time_from_system())
    GameState.combat_state["construction_job"] = job
    _system._process(0.0)
    assert_eq(_system.get_towers().size(), 1, "tower appears after its build timer")
    assert_gt(_system.get_tower_bonuses().defense, 0.0, "defensive tower gives its stated bonus")

func test_hidden_defense_writes_report_without_battle_scene_and_limits_loss() -> void:
    GameState.port_state.home.inventory = {"resource_timber": 100, "resource_parts": 100}
    var result: Dictionary = _system.resolve_hidden_attack(999, "Пираты")
    var report: Dictionary = result.get("report", {})
    assert_eq(str(report.get("outcome", "")), "Поражение", "strong enemy can defeat a weak garrison")
    assert_eq(GameState.combat_state.reports.size(), 1, "battle ends as a persistent report")
    assert_lt(float(GameState.combat_state.fort_integrity), 100.0, "loss damages base fortifications")
    var remaining: int = int(GameState.combat_state.units.coast_guard.count)
    assert_gte(remaining, 1, "a single attack cannot erase the last defenders")
    assert_lte(int(report.get("goods_lost", 0)), 4, "inventory loss remains capped for this test stock")

func test_player_raid_exposes_progress_then_report() -> void:
    var started: Dictionary = _system.start_player_raid("Пиратский лагерь", 1, 60)
    assert_true(bool(started.get("ok", false)), "player can start the schematic hidden raid flow")
    var progress: Dictionary = _system.get_player_raid_status()
    assert_has(progress, "percent", "active raid exposes progress instead of a battle scene")
    var raid: Dictionary = GameState.combat_state.active_raid
    raid["completes_at"] = int(Time.get_unix_time_from_system())
    GameState.combat_state["active_raid"] = raid
    _system._process(0.0)
    assert_true(_system.get_player_raid_status().is_empty(), "active operation clears on result")
    assert_eq(GameState.combat_state.reports.size(), 1, "result appears in combat log")

func test_old_current_save_migrates_with_default_combat_state() -> void:
    var old_save: Dictionary = SaveSystem._serialize_game_state()
    old_save.erase("combat_state")
    old_save["version"] = "0.2.0"
    var migrated: Dictionary = SaveSystem._migrate(old_save, "0.2.0", SaveSystem.CURRENT_SAVE_VERSION)
    assert_true(migrated.has("combat_state"), "0.2.0 save gets safe default garrison state")
    assert_eq(migrated.combat_state.units.coast_guard.count, 8, "old save receives the starter guard")
    assert_true(SaveSystem._valid_save(migrated), "migrated save passes validation")