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
    assert_eq(float(GameState.player_state.money), 49840.0, "the hiring fee is charged once")
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
    assert_true(bool(tower_result.get("ok", false)), "level two unlocks the first tower slot")
    assert_eq(_system.get_tower_slot_limit(), 1, "level two has one tower slot")
    job = GameState.combat_state.construction_job
    job["completes_at"] = int(Time.get_unix_time_from_system())
    GameState.combat_state["construction_job"] = job
    _system._process(0.0)
    assert_eq(_system.get_towers().size(), 1, "tower appears after its build timer")
    assert_eq(_system.get_tower_bonuses().defense, 0.0, "empty universal tower has no bonus before a crystal is installed")
    assert_false(_system.get_tower_bonuses().has("speed"), "towers have no speed crystal bonus")
    var victory: Dictionary = _system.resolve_hidden_attack(1, "Разбойники")
    assert_true(bool(victory.get("report", {}).get("won", false)), "a successful defense is a crystal source")
    assert_eq(_system.get_magic_shards(), 3, "the first victory grants three magic shards")
    assert_eq(int(_system.get_crystal_inventory().get("crystal_power", 0)), 0, "crystals must be made at the Mage Guild")
    GameState.port_state.home["buildings"] = {"mage_guild": {"level": 1, "status": "active"}}
    var crystal_result: Dictionary = _system.create_crystal("crystal_power")
    assert_true(bool(crystal_result.get("ok", false)), "the Mage Guild turns the victory shards into a crystal")
    var install_result: Dictionary = _system.set_tower_crystal(0, "crystal_power")
    assert_true(bool(install_result.get("ok", false)), "any owned crystal fits the island tower")
    assert_gt(_system.get_tower_bonuses().attack, 0.0, "a socketed crystal gives its defined bonus")
    var second_crystal_result: Dictionary = _system.create_crystal("crystal_luck")
    assert_false(bool(second_crystal_result.get("ok", false)), "each crystal recipe requires its own shards")
    GameState.combat_state["magic_shards"] = 3
    second_crystal_result = _system.create_crystal("crystal_luck")
    assert_true(bool(second_crystal_result.get("ok", false)), "luck crystals are crafted at the Mage Guild too")
    var luck_install: Dictionary = _system.set_tower_crystal(0, "crystal_luck")
    assert_true(bool(luck_install.get("ok", false)), "luck crystal can be installed in a tower")
    assert_gt(_system.get_tower_bonuses().luck, 0.0, "luck crystal improves the garrison luck contribution")
    assert_false(_system.get_tower_bonuses().has("speed"), "no crystal in a tower increases unit speed")

func test_mage_guild_creates_crystals_and_levels_all_existing_crystals() -> void:
    GameState.port_state.home["buildings"] = {"mage_guild": {"level": 1, "status": "active"}}
    GameState.combat_state["magic_shards"] = 6
    GameState.combat_state["mage_guild_starter_shards_awarded"] = true
    GameState.combat_state["towers"] = [{"type": "island", "crystal_id": "crystal_power"}]
    var starting_money: float = GameState.player_state.money
    var starting_parts: int = int(GameState.port_state.home.inventory.resource_parts)

    var created: Dictionary = _system.create_crystal("crystal_power")
    assert_true(bool(created.get("ok", false)), "the Mage Guild creates a crystal from parts and magic shards")
    assert_eq(int(_system.get_crystal_inventory().crystal_power), 1)
    assert_eq(_system.get_magic_shards(), 3)
    assert_eq(float(GameState.player_state.money), starting_money - 350.0)
    assert_eq(int(GameState.port_state.home.inventory.resource_parts), starting_parts - 4)
    assert_eq(float(_system.get_tower_bonuses().attack), 0.75, "guild level one gives each crystal its first level")

    GameState.port_state.home.buildings.mage_guild.level = 20
    assert_eq(int(_system.get_crystal_level()), 20, "guild upgrades raise existing and installed crystals together")
    assert_eq(float(_system.get_tower_bonuses().attack), 15.0, "level twenty crystal adds fifteen percent attack")
    GameState.port_state.home.buildings.mage_guild.level = 30
    GameState.combat_state.towers = [
        {"type": "island", "crystal_id": "crystal_power"},
        {"type": "island", "crystal_id": "crystal_power"}
    ]
    assert_eq(float(_system.get_tower_bonuses().attack), 40.0, "combined tower attack bonus is capped at forty percent")

func test_first_mage_guild_unlock_grants_a_one_time_starter_crystal() -> void:
    GameState.port_state.home["buildings"] = {"mage_guild": {"level": 1, "status": "active"}}
    _system._process(0.0)
    assert_eq(_system.get_magic_shards(), 3, "the first guild level provides enough shards for one crystal")
    _system._process(0.0)
    assert_eq(_system.get_magic_shards(), 3, "the starter shards are granted only once")

func test_towers_unlock_at_garrison_levels_two_and_four() -> void:
    GameState.combat_state.garrison_level = 1
    assert_eq(_system.get_tower_slot_limit(), 0)
    GameState.combat_state.garrison_level = 2
    assert_eq(_system.get_tower_slot_limit(), 1)
    GameState.combat_state.garrison_level = 3
    assert_eq(_system.get_tower_slot_limit(), 1)
    GameState.combat_state.garrison_level = 4
    assert_eq(_system.get_tower_slot_limit(), 2)
    GameState.combat_state.garrison_level = 5
    assert_eq(_system.get_tower_slot_limit(), 2)

func test_unit_levels_use_approved_attribute_growth() -> void:
    GameState.combat_state.units.coast_guard.level = 5
    var coast_guard: Dictionary = _system.get_roster()[0]
    assert_eq(int(coast_guard.attack), 4, "attack grows ten percent per level")
    assert_eq(int(coast_guard.defense), 7, "defense grows ten percent per level")
    assert_eq(int(coast_guard.speed), 8, "speed grows five percent per level")
    assert_eq(int(coast_guard.luck), 7, "luck increases by one point per level")

func test_hidden_defense_writes_report_without_battle_scene_and_limits_loss() -> void:
    GameState.port_state.home.inventory = {"resource_timber": 100, "resource_parts": 100}
    var result: Dictionary = _system.resolve_hidden_attack(999, "Пираты")
    var report: Dictionary = result.get("report", {})
    assert_eq(str(report.get("outcome", "")), "Поражение", "strong enemy can defeat a weak garrison")
    assert_eq(GameState.combat_state.reports.size(), 1, "battle ends as a persistent report")
    assert_lt(float(GameState.combat_state.fort_integrity), 100.0, "loss damages base fortifications")
    var remaining: int = int(GameState.combat_state.units.coast_guard.count)
    assert_gte(remaining, 1, "a single attack cannot erase the last defenders")
    assert_lte(float(GameState.combat_state.fort_integrity), 97.0, "a home raid damages no more than three fort points")
    assert_lte(int(report.get("goods_lost", 0)), 8, "home raid inventory loss stays capped")
    var delay: int = int(GameState.combat_state.next_defense_at) - int(Time.get_unix_time_from_system())
    assert_gte(delay, 259200, "next home raid is at least 72 hours away")
    assert_lte(delay, 432000, "next home raid is no more than 120 hours away")

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

func test_legacy_wind_crystals_migrate_to_luck_without_losing_inventory() -> void:
    GameState.combat_state.crystals = {"crystal_wind": 2, "crystal_power": 1}
    GameState.combat_state.towers = [{"type": "wind", "crystal_id": "crystal_wind"}]
    _system._normalize_state()
    assert_eq(int(GameState.combat_state.crystals.get("crystal_luck", 0)), 2, "wind crystals become luck crystals without loss")
    assert_false(GameState.combat_state.crystals.has("crystal_wind"), "legacy speed crystal key is removed")
    assert_eq(str(GameState.combat_state.towers[0].crystal_id), "crystal_luck", "installed wind crystal becomes a luck crystal")
    assert_eq(str(GameState.combat_state.towers[0].type), "island", "legacy tower type is normalized")

func test_old_current_save_migrates_with_default_combat_state() -> void:
    var old_save: Dictionary = SaveSystem._serialize_game_state()
    old_save.erase("combat_state")
    old_save["version"] = "0.2.0"
    var migrated: Dictionary = SaveSystem._migrate(old_save, "0.2.0", SaveSystem.CURRENT_SAVE_VERSION)
    assert_true(migrated.has("combat_state"), "0.2.0 save gets safe default garrison state")
    assert_eq(migrated.combat_state.units.coast_guard.count, 8, "old save receives the starter guard")
    assert_true(SaveSystem._valid_save(migrated), "migrated save passes validation")
