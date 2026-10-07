extends Node

## Offline-first, text-only combat simulation. Battle outcomes live in GameState.
const CATALOG_PATH := "res://data/combat/unit_catalog.json"
const MAGE_GUILD_RULES_PATH := "res://data/combat/mage_guild_rules.json"

var _catalog: Dictionary = {}
var _mage_guild_rules: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    add_to_group("combat_system")
    _rng.randomize()

func initialize() -> void:
    _catalog = GameData.read(CATALOG_PATH)
    _mage_guild_rules = GameData.read(MAGE_GUILD_RULES_PATH)
    _normalize_state()
    var state: Dictionary = GameState.combat_state
    if int(state.get("next_defense_at", 0)) <= 0:
        state["next_defense_at"] = _now() + int(_rules().get("passive_attack_interval_seconds", 21600))

func _process(_delta: float) -> void:
    if _catalog.is_empty():
        return
    _normalize_state()
    _award_mage_guild_starter_shards()
    _complete_recruitment()
    _complete_construction()
    _complete_player_raid()
    _process_tribute_income()
    var state: Dictionary = GameState.combat_state
    if _now() >= int(state.get("next_defense_at", 0)) and not bool(state.get("active_raid", {}).get("active", false)):
        var home_power: int = maxi(1, get_defense_power())
        var enemy_power: int = _rng.randi_range(maxi(1, int(float(home_power) * 0.45)), maxi(2, int(float(home_power) * 0.60)))
        resolve_hidden_attack(enemy_power, "Пиратский отряд")

func _normalize_state() -> void:
    var state: Dictionary = GameState.combat_state
    state.merge(GameState.default_combat_state(), false)
    for slot_key in ["commander", "deputy_commander"]:
        var assigned: Variant = state.get(slot_key, {})
        if not assigned is Dictionary: state[slot_key] = {}; continue
        if not assigned.is_empty() and str(assigned.get("id", "")) == "":
            assigned["id"] = str(assigned.get("race_id", "humans")) + ("_marshal" if slot_key == "commander" else "_deputy")
    if not state.get("units", {}) is Dictionary:
        state["units"] = {}
    if not state.get("towers", []) is Array:
        state["towers"] = []
    if not state.get("recruitment", {}) is Dictionary:
        state["recruitment"] = {}
    if not state.get("construction_job", {}) is Dictionary:
        state["construction_job"] = {}
    if not state.get("reports", []) is Array:
        state["reports"] = []
    if not state.get("commander", {}) is Dictionary:
        state["commander"] = {}
    if not state.get("crystals", {}) is Dictionary:
        state["crystals"] = {}
    state["magic_shards"] = maxi(0, int(state.get("magic_shards", 0)))
    var crystal_inventory: Dictionary = state.get("crystals", {})
    var old_wind_count: int = maxi(0, int(crystal_inventory.get("crystal_wind", 0)))
    if old_wind_count > 0:
        crystal_inventory["crystal_luck"] = maxi(0, int(crystal_inventory.get("crystal_luck", 0))) + old_wind_count
    crystal_inventory.erase("crystal_wind")
    for crystal_id in _catalog.get("crystals", {}).keys():
        crystal_inventory[crystal_id] = maxi(0, int(crystal_inventory.get(crystal_id, 0)))
    state["crystals"] = crystal_inventory
    var legacy_crystals: Dictionary = {"power": "crystal_power", "guard": "crystal_guard", "wind": "crystal_luck"}
    var towers: Array = state.get("towers", [])
    for index in range(towers.size()):
        var tower: Dictionary = towers[index]
        var old_type: String = str(tower.get("type", "island"))
        var crystal_id: String = str(tower.get("crystal_id", ""))
        if crystal_id == "crystal_wind":
            crystal_id = "crystal_luck"
        elif legacy_crystals.has(old_type) and crystal_id == "":
            crystal_id = str(legacy_crystals[old_type])
        if old_type in ["power", "guard", "wind"]:
            tower["type"] = "island"
        if crystal_id != str(tower.get("crystal_id", "")):
            tower["crystal_id"] = crystal_id
        towers[index] = tower
    state["towers"] = towers
    if int(state.get("battle_victories", -1)) < 0:
        state["battle_victories"] = 0
    if int(state.get("next_crystal_reward", -1)) < 0:
        state["next_crystal_reward"] = 0
    if int(state.get("defense_schedule_version", 0)) < 1:
        state["next_defense_at"] = _now() + _next_home_raid_delay()
        state["defense_schedule_version"] = 1
    var units: Dictionary = state.units
    if not units.has("coast_guard"):
        units["coast_guard"] = {"count": 8, "level": 1, "experience": 0}
    state["units"] = units
    GameState.combat_state = state

func _rules() -> Dictionary:
    return _catalog.get("rules", {})

func _now() -> int:
    return int(Time.get_unix_time_from_system())

func _next_home_raid_delay() -> int:
    var base: int = int(_rules().get("passive_attack_interval_seconds", 259200))
    var jitter: int = int(_rules().get("passive_attack_jitter_seconds", 172800))
    return base + _rng.randi_range(0, maxi(0, jitter))

func get_home_port_id() -> String:
    return str(GameState.world_state.get("home_port_id", ""))

func is_at_home() -> bool:
    var home_id: String = get_home_port_id()
    return home_id != "" and str(GameState.ship_state.get("docked_port_id", "")) == home_id

func get_catalog() -> Dictionary:
    return _catalog.duplicate(true)

func get_garrison_level() -> int:
    return int(GameState.combat_state.get("garrison_level", 1))

func get_commander(slot: int = 0) -> Dictionary:
    if slot not in [0, 1]: return {}
    return GameState.combat_state.get("commander" if slot == 0 else "deputy_commander", {}).duplicate(true)

func get_commander_bonuses() -> Dictionary:
    var result: Dictionary = {"attack": 0.0, "defense": 0.0, "expenses": 0.0}
    for slot in [0, 1]:
        var commander: Dictionary = get_commander(slot)
        for stat in result:
            result[stat] += float(commander.get(str(stat) + "_bonus", 0.0))
    return result

func get_unit_command_effect(unit_id: String) -> Dictionary:
    var definition: Dictionary = _catalog.get("units", {}).get(unit_id, {})
    var saved: Dictionary = GameState.combat_state.get("units", {}).get(unit_id, {"count":0,"level":1})
    var bonuses: Dictionary = get_commander_bonuses()
    var base_attack: float = _unit_stat(definition, saved, "attack")
    var base_defense: float = _unit_stat(definition, saved, "defense")
    return {"base_attack":base_attack,"base_defense":base_defense,
        "attack":base_attack*(1.0+float(bonuses.attack)/100.0),
        "defense":base_defense*(1.0+float(bonuses.defense)/100.0),
        "attack_percent":float(bonuses.attack),"defense_percent":float(bonuses.defense),
        "count":int(saved.get("count",0)),"level":int(saved.get("level",1))}

func hire_commander(candidate: Dictionary, slot: int = 0) -> Dictionary:
    if slot not in [0, 1]: return _result(false, "Выберите один из двух слотов.")
    if not is_at_home():
        return _result(false, "Командиров можно назначать только в главном порту.")
    if not get_commander(slot).is_empty():
        return _result(false, "Командир уже назначен. Сначала освободите его место.")
    var race_id := str(GameState.player_state.get("origin_race_id", ""))
    if race_id == "" or str(candidate.get("race_id", "")) != race_id:
        return _result(false, "Можно нанять только командира вашей расы.")
    var other: Dictionary = get_commander(1 - slot)
    if not other.is_empty() and str(other.get("id", other.get("name", ""))) == str(candidate.get("id", candidate.get("name", ""))):
        return _result(false, "Этот командир уже занимает другой слот.")
    var cost := maxi(0, int(candidate.get("cost", 610)))
    if float(GameState.player_state.get("money", 0.0)) < cost:
        return _result(false, "Не хватает монет: требуется %d." % cost)
    var old_state: Dictionary = GameState.combat_state.duplicate(true)
    var old_money := float(GameState.player_state.get("money", 0.0))
    var appointed := candidate.duplicate(true)
    appointed["hired_at"] = _now()
    appointed["attack_bonus"] = float(candidate.get("attack_bonus", candidate.get("attack", 0.0)))
    appointed["defense_bonus"] = float(candidate.get("defense_bonus", candidate.get("defense", 0.0)))
    appointed["expenses_bonus"] = float(candidate.get("expenses_bonus", candidate.get("expenses", 0.0)))
    appointed.erase("cost")
    appointed.erase("attack")
    appointed.erase("defense")
    appointed.erase("expenses")
    GameState.player_state["money"] = old_money - cost
    GameState.combat_state["commander" if slot == 0 else "deputy_commander"] = appointed
    if not SaveSystem.save_game():
        GameState.player_state["money"] = old_money
        GameState.combat_state = old_state
        return _result(false, "Не удалось сохранить назначение командира.")
    return _result(true, "%s назначен в командование гарнизона." % str(appointed.get("name", "Командир")))

func dismiss_commander(slot: int = 0) -> Dictionary:
    if slot not in [0, 1]: return _result(false, "Выберите один из двух слотов.")
    if not is_at_home():
        return _result(false, "Снять командира можно только в главном порту.")
    if get_commander(slot).is_empty():
        return _result(false, "Командир не назначен.")
    var old_state: Dictionary = GameState.combat_state.duplicate(true)
    GameState.combat_state["commander" if slot == 0 else "deputy_commander"] = {}
    if not SaveSystem.save_game():
        GameState.combat_state = old_state
        return _result(false, "Не удалось сохранить изменение гарнизона.")
    return _result(true, "Командир снят с должности. Оплата за найм не возвращается.")

func get_recruitment_cost(unit_id: String, amount: int = 1) -> int:
    var base_cost := int(_catalog.get("units", {}).get(unit_id, {}).get("hire_cost", 0)) * maxi(0, amount)
    var expenses := float(get_commander_bonuses().get("expenses", 0.0))
    return int(ceil(float(base_cost) * (1.0 + expenses / 100.0)))

func get_roster() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var units: Dictionary = GameState.combat_state.get("units", {})
    var unit_defs: Dictionary = _catalog.get("units", {})
    for raw_id in _catalog.get("unit_order", []):
        var unit_id: String = str(raw_id)
        var definition: Dictionary = unit_defs.get(unit_id, {})
        if definition.is_empty():
            continue
        var saved: Dictionary = units.get(unit_id, {"count": 0, "level": 1, "experience": 0})
        var unlocked: bool = get_garrison_level() >= int(definition.get("unlock_level", 1))
        result.append({
            "id": unit_id,
            "name": str(definition.get("name", unit_id)),
            "branch": str(definition.get("branch", "")),
            "count": int(saved.get("count", 0)),
            "level": int(saved.get("level", 1)),
            "experience": int(saved.get("experience", 0)),
            "next_level_experience": int(saved.get("level", 1)) * 100,
            "experience_percent": clampi(int(float(saved.get("experience", 0)) / maxf(1.0, float(int(saved.get("level", 1)) * 100)) * 100.0), 0, 100),
            "unlock_level": int(definition.get("unlock_level", 1)),
            "unlocked": unlocked,
            "attack": int(round(_unit_stat(definition, saved, "attack"))),
            "defense": int(round(_unit_stat(definition, saved, "defense"))),
            "speed": int(round(_unit_stat(definition, saved, "speed"))),
            "luck": int(round(_unit_stat(definition, saved, "luck"))),
            "hire_cost": int(definition.get("hire_cost", 0))
        })
    return result

func get_unit_name(unit_id: String) -> String:
    return str(_catalog.get("units", {}).get(unit_id, {}).get("name", unit_id))

func get_tower_name(tower_type: String) -> String:
    var normalized_type: String = _normalize_tower_type(tower_type)
    return str(_catalog.get("towers", {}).get(normalized_type, {}).get("name", normalized_type))

func _normalize_tower_type(tower_type: String) -> String:
    if tower_type in ["power", "guard", "wind"]:
        return "island"
    return tower_type

func get_crystal_definitions() -> Dictionary:
    return _mage_guild_rules.get("crystal_recipes", {}).duplicate(true)

func get_crystal_order() -> Array:
    return _catalog.get("crystal_order", []).duplicate()

func get_crystal_inventory() -> Dictionary:
    return GameState.combat_state.get("crystals", {}).duplicate(true)

func get_crystal_name(crystal_id: String) -> String:
    return str(_mage_guild_rules.get("crystal_recipes", {}).get(crystal_id, {}).get("name", crystal_id))

func get_mage_guild_level() -> int:
    var port: Dictionary = GameState.port_state.get(get_home_port_id(), {})
    var buildings: Dictionary = port.get("buildings", {})
    var guild: Dictionary = buildings.get("mage_guild", {})
    if str(guild.get("status", "active")) != "active":
        return 0
    return clampi(int(guild.get("level", 0)), 0, int(_mage_guild_rules.get("max_level", 30)))

func get_crystal_level() -> int:
    return maxi(int(_mage_guild_rules.get("crystal_level_minimum", 1)), get_mage_guild_level())

func get_magic_shards() -> int:
    return maxi(0, int(GameState.combat_state.get("magic_shards", 0)))

func _award_mage_guild_starter_shards() -> void:
    var state: Dictionary = GameState.combat_state
    if bool(state.get("mage_guild_starter_shards_awarded", false)) or get_mage_guild_level() < 1:
        return
    state["magic_shards"] = maxi(0, int(state.get("magic_shards", 0))) + 3
    state["mage_guild_starter_shards_awarded"] = true
    GameState.combat_state = state
    SaveSystem.save_game()

func get_crystal_recipe(crystal_id: String) -> Dictionary:
    var recipe: Dictionary = _mage_guild_rules.get("crystal_recipes", {}).get(crystal_id, {}).duplicate(true)
    if recipe.is_empty():
        return {}
    var level: int = maxi(1, get_mage_guild_level())
    var growth: Dictionary = _mage_guild_rules.get("recipe_growth", {})
    recipe["money"] = int(recipe.get("money", 0)) + (level - 1) * int(growth.get("money_per_guild_level_after_first", 0))
    var decade_steps: int = int((level - 1) / 10)
    recipe["resource_parts"] = int(recipe.get("resource_parts", 0)) + decade_steps * int(growth.get("parts_per_ten_guild_levels", 0))
    recipe["magic_shards"] = int(recipe.get("magic_shards", 0)) + decade_steps * int(growth.get("shards_per_ten_guild_levels", 0))
    return recipe

func can_create_crystal(crystal_id: String) -> bool:
    if not is_at_home() or get_mage_guild_level() < 1:
        return false
    var recipe: Dictionary = get_crystal_recipe(crystal_id)
    if recipe.is_empty() or float(GameState.player_state.get("money", 0.0)) < float(recipe.get("money", 0)):
        return false
    var port: Dictionary = GameState.port_state.get(get_home_port_id(), {})
    var inventory: Dictionary = port.get("inventory", {})
    return int(inventory.get("resource_parts", 0)) >= int(recipe.get("resource_parts", 0)) and get_magic_shards() >= int(recipe.get("magic_shards", 0))

func create_crystal(crystal_id: String) -> Dictionary:
    if not is_at_home():
        return _result(false, "Создавать кристаллы можно только в главном порту.")
    if get_mage_guild_level() < 1:
        return _result(false, "Сначала постройте гильдию магов.")
    var recipe: Dictionary = get_crystal_recipe(crystal_id)
    if recipe.is_empty():
        return _result(false, "Неизвестный рецепт кристалла.")
    if not can_create_crystal(crystal_id):
        return _result(false, "Не хватает монет, запчастей или осколков магии.")
    var old_combat: Dictionary = GameState.combat_state.duplicate(true)
    var old_money: float = float(GameState.player_state.get("money", 0.0))
    var old_port: Dictionary = GameState.port_state.get(get_home_port_id(), {}).duplicate(true)
    var port: Dictionary = old_port.duplicate(true)
    var inventory: Dictionary = port.get("inventory", {})
    GameState.player_state["money"] = old_money - float(recipe.get("money", 0))
    inventory["resource_parts"] = int(inventory.get("resource_parts", 0)) - int(recipe.get("resource_parts", 0))
    port["inventory"] = inventory
    GameState.port_state[get_home_port_id()] = port
    var crystals: Dictionary = GameState.combat_state.get("crystals", {}).duplicate(true)
    crystals[crystal_id] = int(crystals.get(crystal_id, 0)) + 1
    GameState.combat_state["crystals"] = crystals
    GameState.combat_state["magic_shards"] = get_magic_shards() - int(recipe.get("magic_shards", 0))
    if not SaveSystem.save_game():
        GameState.combat_state = old_combat
        GameState.player_state["money"] = old_money
        GameState.port_state[get_home_port_id()] = old_port
        return _result(false, "Не удалось сохранить создание кристалла.")
    return _result(true, "%s создан %d уровня." % [get_crystal_name(crystal_id), get_crystal_level()])

func get_crystal_effect(crystal_id: String) -> Dictionary:
    var per_level: Dictionary = _mage_guild_rules.get("effects_per_level", {}).get(crystal_id, {})
    var result: Dictionary = {}
    var level: int = get_crystal_level()
    for effect_id in per_level:
        result[effect_id] = float(per_level[effect_id]) * float(level)
    return result

func get_crystal_effect_text(crystal_id: String) -> String:
    var effect: Dictionary = get_crystal_effect(crystal_id)
    if effect.has("attack_percent"):
        return "+%.1f%% к атаке" % float(effect.attack_percent)
    if effect.has("defense_percent"):
        return "+%.1f%% к броне" % float(effect.defense_percent)
    if effect.has("luck_chance_percentage_points"):
        return "+%.1f п.п. к шансу удачного удара" % float(effect.luck_chance_percentage_points)
    return "Эффект не задан"

func get_tower_slot_limit() -> int:
    var slots: Array = _rules().get("tower_slots_by_garrison_level", [])
    var level: int = clampi(get_garrison_level(), 1, int(_rules().get("max_garrison_level", 5)))
    return int(slots[level]) if level < slots.size() else 0

func set_tower_crystal(tower_index: int, crystal_id: String) -> Dictionary:
    if not is_at_home():
        return _result(false, "Кристаллы можно менять только в главном порту.")
    var towers: Array = GameState.combat_state.get("towers", []).duplicate(true)
    if tower_index < 0 or tower_index >= towers.size():
        return _result(false, "Башня не найдена.")
    if crystal_id != "" and not _catalog.get("crystals", {}).has(crystal_id):
        return _result(false, "Неизвестный кристалл.")
    var tower: Dictionary = towers[tower_index]
    var previous_id: String = str(tower.get("crystal_id", ""))
    if previous_id == crystal_id:
        return _result(true, "Эта башня уже настроена так.")
    var inventory: Dictionary = get_crystal_inventory()
    if crystal_id != "" and int(inventory.get(crystal_id, 0)) <= 0:
        return _result(false, "Такого кристалла нет в гарнизоне.")
    if previous_id != "":
        inventory[previous_id] = int(inventory.get(previous_id, 0)) + 1
    if crystal_id != "":
        inventory[crystal_id] = int(inventory.get(crystal_id, 0)) - 1
    tower["crystal_id"] = crystal_id
    towers[tower_index] = tower
    var old_state: Dictionary = GameState.combat_state.duplicate(true)
    GameState.combat_state["towers"] = towers
    GameState.combat_state["crystals"] = inventory
    if not SaveSystem.save_game():
        GameState.combat_state = old_state
        return _result(false, "Не удалось сохранить установку кристалла.")
    var message: String = "Кристалл снят и возвращён в запас." if crystal_id == "" else "%s установлен в башню." % get_crystal_name(crystal_id)
    return _result(true, message)

func can_recruit(unit_id: String, amount: int) -> bool:
    var definition: Dictionary = _catalog.get("units", {}).get(unit_id, {})
    if definition.is_empty() or get_garrison_level() < int(definition.get("unlock_level", 1)):
        return false
    if _total_units() + amount > get_garrison_level() * 30:
        return false
    return float(GameState.player_state.get("money", 0.0)) >= get_recruitment_cost(unit_id, amount)

func get_towers() -> Array:
    return GameState.combat_state.get("towers", []).duplicate(true)

func get_tower_bonuses() -> Dictionary:
    var result: Dictionary = {"attack": 0.0, "defense": 0.0, "luck": 0.0}
    for raw_tower in get_towers():
        var tower: Dictionary = raw_tower
        var effect: Dictionary = get_crystal_effect(str(tower.get("crystal_id", "")))
        result["attack"] += float(effect.get("attack_percent", 0.0))
        result["defense"] += float(effect.get("defense_percent", 0.0))
        result["luck"] += float(effect.get("luck_chance_percentage_points", 0.0))
    var caps: Dictionary = _mage_guild_rules.get("effect_caps", {})
    result["attack"] = minf(float(result.attack), float(caps.get("attack_percent", 40.0)))
    result["defense"] = minf(float(result.defense), float(caps.get("defense_percent", 40.0)))
    result["luck"] = minf(float(result.luck), float(caps.get("luck_chance_percentage_points", 24.0)))
    return result

func get_defense_power() -> int:
    var total: float = 0.0
    var units: Dictionary = GameState.combat_state.get("units", {})
    var defs: Dictionary = _catalog.get("units", {})
    var bonuses: Dictionary = get_tower_bonuses()
    for unit_id in units:
        var saved: Dictionary = units[unit_id]
        var definition: Dictionary = defs.get(str(unit_id), {})
        var luck_power: float = _unit_stat(definition, saved, "luck") * 0.3
        var defense_stat: float = _unit_stat(definition, saved, "defense")
        if str(unit_id) == "coast_guard":
            defense_stat *= 1.15
        total += float(saved.get("count", 0)) * (defense_stat + luck_power)
    var integrity: float = float(GameState.combat_state.get("fort_integrity", 100.0)) / 100.0
    var commander: Dictionary = get_commander_bonuses()
    return maxi(0, int(round(total * (1.0 + (float(bonuses.defense) + float(commander.defense)) / 100.0) * integrity)))

func get_attack_power(roster: Variant = null) -> int:
    var total: float = 0.0
    var units: Dictionary = GameState.combat_state.get("units", {}) if roster == null else roster
    var defs: Dictionary = _catalog.get("units", {})
    var bonuses: Dictionary = get_tower_bonuses()
    for unit_id in units:
        var saved: Dictionary = units[unit_id]
        var definition: Dictionary = defs.get(str(unit_id), {})
        var luck_power: float = _unit_stat(definition, saved, "luck") * 0.3
        var attack_stat: float = _unit_stat(definition, saved, "attack")
        if str(unit_id) == "wind_rider":
            attack_stat *= 1.12
        total += float(saved.get("count", 0)) * (attack_stat + luck_power)
    var commander: Dictionary = get_commander_bonuses()
    return maxi(0, int(round(total * (1.0 + (float(bonuses.attack) + float(commander.attack)) / 100.0))))

func get_average_speed() -> float:
    var weighted_speed: float = 0.0
    var count: int = 0
    for unit in GameState.combat_state.get("units", {}).keys():
        var saved: Dictionary = GameState.combat_state.units[unit]
        var unit_count: int = int(saved.get("count", 0))
        var definition: Dictionary = _catalog.get("units", {}).get(str(unit), {})
        weighted_speed += _unit_stat(definition, saved, "speed") * unit_count
        count += unit_count
    if count <= 0:
        return 0.0
    return weighted_speed / float(count)

func _unit_stat(definition: Dictionary, saved: Dictionary, stat: String) -> float:
    var level: int = int(saved.get("level", 1))
    var growth_levels: int = maxi(0, level - 1)
    match stat:
        "attack", "defense":
            return float(definition.get(stat, 0.0)) * (1.0 + 0.10 * float(growth_levels))
        "speed":
            return float(definition.get(stat, 0.0)) * (1.0 + 0.05 * float(growth_levels))
        "luck":
            return float(definition.get(stat, 0.0)) + float(growth_levels)
    return float(definition.get(stat, 0.0))

func get_garrison_upgrade_cost() -> Dictionary:
    var costs: Array = _catalog.get("garrison_upgrade_costs", [])
    var next_level: int = get_garrison_level() + 1
    if next_level > int(_rules().get("max_garrison_level", 5)) or next_level > costs.size():
        return {}
    return costs[next_level - 1].duplicate(true)

func get_construction_status() -> Dictionary:
    var job: Dictionary = GameState.combat_state.get("construction_job", {})
    if job.is_empty():
        return {}
    var started: int = int(job.get("started_at", _now()))
    var completes: int = int(job.get("completes_at", started))
    var total: float = maxf(1.0, float(completes - started))
    var action: String = "Уровень гарнизона %d" % int(job.get("target_level", 0))
    if str(job.get("kind", "")) == "tower_build":
        action = "Башня: " + get_tower_name(str(job.get("tower_type", "")))
    return {"action": action, "percent": clampf(float(_now() - started) / total * 100.0, 0.0, 100.0), "seconds_left": maxi(0, completes - _now())}

func can_upgrade_garrison() -> bool:
    return is_at_home() and GameState.combat_state.get("construction_job", {}).is_empty() and _can_pay_cost(get_garrison_upgrade_cost())

func _tower_slot_limit() -> int:
    return get_tower_slot_limit()

func can_build_tower(tower_type: String) -> bool:
    var towers: Array = GameState.combat_state.get("towers", [])
    var limit: int = _tower_slot_limit()
    return is_at_home() and GameState.combat_state.get("construction_job", {}).is_empty() and _catalog.get("towers", {}).has(_normalize_tower_type(tower_type)) and towers.size() < limit and _can_pay_cost(_rules().get("tower_cost", {}))

func _can_pay_cost(cost: Dictionary) -> bool:
    if cost.is_empty() or float(GameState.player_state.get("money", 0.0)) < float(cost.get("money", 0)):
        return false
    var port: Dictionary = GameState.port_state.get(get_home_port_id(), {})
    var inventory: Dictionary = port.get("inventory", {})
    for resource_id in cost:
        if resource_id == "money":
            continue
        if int(inventory.get(resource_id, 0)) < int(cost[resource_id]):
            return false
    return true

func get_recruitment_status() -> Dictionary:
    var job: Dictionary = GameState.combat_state.get("recruitment", {})
    if job.is_empty():
        return {}
    var started: int = int(job.get("started_at", _now()))
    var completes: int = int(job.get("completes_at", started))
    var total: float = maxf(1.0, float(completes - started))
    return {
        "unit_id": str(job.get("unit_id", "")),
        "amount": int(job.get("amount", 0)),
        "percent": clampf(float(_now() - started) / total * 100.0, 0.0, 100.0),
        "seconds_left": maxi(0, completes - _now())
    }

func recruit(unit_id: String, amount: int = 1) -> Dictionary:
    if not is_at_home():
        return _result(false, "Найм доступен только в главном порту.")
    if not GameState.combat_state.get("recruitment", {}).is_empty():
        return _result(false, "Дождитесь окончания текущего обучения.")
    var definition: Dictionary = _catalog.get("units", {}).get(unit_id, {})
    if definition.is_empty() or get_garrison_level() < int(definition.get("unlock_level", 1)):
        return _result(false, "Этот отряд откроется после улучшения гарнизона.")
    amount = clampi(amount, 1, int(_rules().get("max_recruitment_batch", 20)))
    if _total_units() + amount > get_garrison_level() * 30:
        return _result(false, "Гарнизон заполнен. Улучшите его, чтобы увеличить вместимость.")
    var cost: int = get_recruitment_cost(unit_id, amount)
    if float(GameState.player_state.get("money", 0.0)) < cost:
        return _result(false, "Не хватает денег: нужно %d." % cost)
    var before: Dictionary = GameState.combat_state.duplicate(true)
    var old_money: float = float(GameState.player_state.get("money", 0.0))
    GameState.player_state["money"] = old_money - cost
    var duration: int = int(definition.get("seconds_per_unit", 10)) * amount
    GameState.combat_state["recruitment"] = {
        "unit_id": unit_id,
        "amount": amount,
        "started_at": _now(),
        "completes_at": _now() + duration
    }
    if not SaveSystem.save_game():
        GameState.player_state["money"] = old_money
        GameState.combat_state = before
        return _result(false, "Не удалось сохранить найм.")
    return _result(true, "Обучение началось. Отряд будет готов через %d сек." % duration)

func promote_unit(unit_id: String) -> Dictionary:
    if not is_at_home():
        return _result(false, "Улучшать отряды можно только в главном порту.")
    var units: Dictionary = GameState.combat_state.get("units", {})
    if not units.has(unit_id):
        return _result(false, "Сначала наймите этот отряд.")
    var saved: Dictionary = units[unit_id]
    var level: int = int(saved.get("level", 1))
    if level >= get_garrison_level() or level >= 5:
        return _result(false, "Нужен гарнизон более высокого уровня.")
    var required_experience: int = level * 100
    if int(saved.get("experience", 0)) < required_experience:
        return _result(false, "Нужен опыт отряда: %d / %d." % [int(saved.get("experience", 0)), required_experience])
    var cost: int = level * 350
    if float(GameState.player_state.get("money", 0.0)) < cost:
        return _result(false, "Не хватает денег: нужно %d." % cost)
    var old_state: Dictionary = GameState.combat_state.duplicate(true)
    var old_money: float = float(GameState.player_state.money)
    saved["level"] = level + 1
    saved["experience"] = int(saved.get("experience", 0)) - required_experience
    units[unit_id] = saved
    GameState.combat_state["units"] = units
    GameState.player_state["money"] = old_money - cost
    if not SaveSystem.save_game():
        GameState.combat_state = old_state
        GameState.player_state["money"] = old_money
        return _result(false, "Не удалось сохранить улучшение.")
    return _result(true, "%s повышен до %d уровня." % [str(_catalog.units[unit_id].name), level + 1])

func upgrade_garrison() -> Dictionary:
    if not is_at_home():
        return _result(false, "Гарнизон улучшается только в главном порту.")
    var cost: Dictionary = get_garrison_upgrade_cost()
    if cost.is_empty():
        return _result(false, "Гарнизон уже достиг максимального уровня.")
    if not GameState.combat_state.get("construction_job", {}).is_empty():
        return _result(false, "Сначала дождитесь окончания стройки.")
    var port: Dictionary = GameState.port_state.get(get_home_port_id(), {})
    var inventory: Dictionary = port.get("inventory", {})
    for resource_id in cost:
        if resource_id == "money":
            continue
        if int(inventory.get(resource_id, 0)) < int(cost[resource_id]):
            return _result(false, "Не хватает материала: %s — нужно %d." % [resource_id, int(cost[resource_id])])
    if float(GameState.player_state.get("money", 0.0)) < float(cost.get("money", 0)):
        return _result(false, "Не хватает денег: нужно %d." % int(cost.get("money", 0)))
    var old_state: Dictionary = GameState.combat_state.duplicate(true)
    var old_money: float = float(GameState.player_state.money)
    var old_inventory: Dictionary = inventory.duplicate(true)
    GameState.player_state["money"] = old_money - float(cost.get("money", 0))
    for resource_id in cost:
        if resource_id != "money":
            inventory[resource_id] = int(inventory.get(resource_id, 0)) - int(cost[resource_id])
    port["inventory"] = inventory
    GameState.port_state[get_home_port_id()] = port
    var upgrade_seconds: Array = _rules().get("garrison_upgrade_seconds", [0, 60, 150, 300, 600])
    var target_level: int = get_garrison_level() + 1
    var seconds: int = int(upgrade_seconds[target_level - 1]) if target_level - 1 < upgrade_seconds.size() else target_level * 60
    GameState.combat_state["construction_job"] = {
        "kind": "garrison_upgrade",
        "target_level": target_level,
        "started_at": _now(),
        "completes_at": _now() + seconds
    }
    if not SaveSystem.save_game():
        GameState.combat_state = old_state
        GameState.player_state["money"] = old_money
        port["inventory"] = old_inventory
        GameState.port_state[get_home_port_id()] = port
        return _result(false, "Не удалось сохранить улучшение гарнизона.")
    return _result(true, "Улучшение запущено. Новый уровень откроется через %d сек." % seconds)

func build_tower(tower_type: String) -> Dictionary:
    if not is_at_home():
        return _result(false, "Башни строятся только в главном порту.")
    tower_type = _normalize_tower_type(tower_type)
    if not _catalog.get("towers", {}).has(tower_type):
        return _result(false, "Неизвестный тип башни.")
    var towers: Array = GameState.combat_state.get("towers", [])
    var limit: int = _tower_slot_limit()
    if towers.size() >= limit:
        return _result(false, "Свободных мест нет. Улучшите гарнизон.")
    if not GameState.combat_state.get("construction_job", {}).is_empty():
        return _result(false, "Сначала дождитесь окончания стройки.")
    var cost: Dictionary = _rules().get("tower_cost", {})
    var port: Dictionary = GameState.port_state.get(get_home_port_id(), {})
    var inventory: Dictionary = port.get("inventory", {})
    for resource_id in cost:
        if resource_id == "money":
            continue
        if int(inventory.get(resource_id, 0)) < int(cost[resource_id]):
            return _result(false, "Не хватает материала: %s — нужно %d." % [resource_id, int(cost[resource_id])])
    if float(GameState.player_state.get("money", 0.0)) < float(cost.get("money", 0)):
        return _result(false, "Не хватает денег: нужно %d." % int(cost.get("money", 0)))
    var old_state: Dictionary = GameState.combat_state.duplicate(true)
    var old_money: float = float(GameState.player_state.money)
    var old_inventory: Dictionary = inventory.duplicate(true)
    for resource_id in cost:
        if resource_id == "money":
            continue
        inventory[resource_id] = int(inventory.get(resource_id, 0)) - int(cost[resource_id])
    port["inventory"] = inventory
    GameState.port_state[get_home_port_id()] = port
    GameState.player_state["money"] = old_money - float(cost.get("money", 0))
    var seconds: int = int(_rules().get("tower_build_seconds", 45))
    GameState.combat_state["construction_job"] = {
        "kind": "tower_build",
        "tower_type": tower_type,
        "started_at": _now(),
        "completes_at": _now() + seconds
    }
    if not SaveSystem.save_game():
        GameState.combat_state = old_state
        GameState.player_state["money"] = old_money
        port["inventory"] = old_inventory
        GameState.port_state[get_home_port_id()] = port
        return _result(false, "Не удалось сохранить строительство башни.")
    return _result(true, "Строительство башни началось. Готовность через %d сек." % seconds)

func repair_fortification() -> Dictionary:
    if not is_at_home():
        return _result(false, "Ремонт доступен только в главном порту.")
    var integrity: float = float(GameState.combat_state.get("fort_integrity", 100.0))
    if integrity >= 100.0:
        return _result(false, "Укрепления не повреждены.")
    var cost: int = int(ceil((100.0 - integrity) * 12.0))
    if float(GameState.player_state.get("money", 0.0)) < cost:
        return _result(false, "Для ремонта нужно %d денег." % cost)
    GameState.player_state["money"] = float(GameState.player_state.money) - cost
    GameState.combat_state["fort_integrity"] = minf(100.0, integrity + 25.0)
    if not SaveSystem.save_game():
        GameState.player_state["money"] = float(GameState.player_state.money) + cost
        GameState.combat_state["fort_integrity"] = integrity
        return _result(false, "Не удалось сохранить ремонт.")
    return _result(true, "Укрепления отремонтированы до %.0f%%." % float(GameState.combat_state.fort_integrity))

func resolve_hidden_attack(enemy_power: int, enemy_name: String = "Пираты") -> Dictionary:
    if bool(GameState.combat_state.get("active_raid", {}).get("active", false)):
        return _result(false, "Сначала завершите текущую операцию.")
    enemy_power = maxi(1, enemy_power)
    var report: Dictionary = _resolve_battle(enemy_power, "defense", enemy_name)
    GameState.combat_state["next_defense_at"] = _now() + _next_home_raid_delay()
    _store_report(report)
    return {"ok": true, "report": report, "message": "Было нападение на базу. " + str(report.get("summary", ""))}

func start_player_raid(target_name: String, enemy_power: int, duration_seconds: int = -1) -> Dictionary:
    if not is_at_home():
        return _result(false, "Подготовить операцию можно только в главном порту.")
    if bool(GameState.combat_state.get("active_raid", {}).get("active", false)):
        return _result(false, "Операция уже идёт.")
    if _total_units() <= 0:
        return _result(false, "Нет отрядов для операции.")
    if duration_seconds <= 0:
        duration_seconds = int(_rules().get("player_raid_duration_seconds", 45))
    var speed_factor: float = 1.0 + clampf(get_average_speed() / 100.0, 0.0, 0.25)
    duration_seconds = maxi(1, int(ceil(float(duration_seconds) / speed_factor)))
    GameState.combat_state["active_raid"] = {
        "active": true,
        "target": target_name,
        "enemy_power": maxi(1, enemy_power),
        "started_at": _now(),
        "completes_at": _now() + duration_seconds
    }
    if not SaveSystem.save_game():
        GameState.combat_state["active_raid"] = {}
        return _result(false, "Не удалось сохранить операцию.")
    return _result(true, "Бой начат. Отряды выдвинулись к цели.")

func start_port_raid(port_id: String, target_name: String, enemy_power: int, duration_seconds: int = 45) -> Dictionary:
    if bool(GameState.combat_state.get("naval_battle", {}).get("active", false)): return _result(false, "Сначала завершите морской бой.")
    if port_id == "" or str(GameState.ship_state.get("docked_port_id", "")) != port_id:
        return _result(false, "Подойди к порту и пришвартуйся перед боем.")
    if port_id == get_home_port_id():
        return _result(false, "Этот вызов доступен только в чужом порту.")
    var port_state: Dictionary = GameState.port_state.get(port_id, {})
    if bool(port_state.get("captured_by_player", false)):
        return _result(false, "Этот порт уже захвачен.")
    if int(port_state.get("base_immunity_until", 0)) > _now():
        return _result(false, "База игрока защищена иммунитетом после поражения на 3 дня.")
    if bool(port_state.get("tribute_active", false)):
        return _result(false, "Порт платит дань и защищён от повторного нападения до восстания.")
    if int(port_state.get("revolt_immunity_until", 0)) > _now():
        return _result(false, "Остров получил иммунитет после восстания до %s." % Time.get_datetime_string_from_unix_time(int(port_state.get("revolt_immunity_until", 0)), true))
    if int(GameState.combat_state.get("envoys", 1)) <= 0:
        return _result(false, "Нужен свободный посланник для управления данью.")
    var port_systems: Array[Node] = get_tree().get_nodes_in_group("port_system")
    var owner_race := str(port_state.get("owner_race_id", ""))
    if owner_race.is_empty() and not port_systems.is_empty() and port_systems[0].has_method("get_port_faction_id"):
        owner_race = str(port_systems[0].call("get_port_faction_id", port_id))
    var player_race := str(GameState.player_state.get("origin_race_id", ""))
    if not owner_race.is_empty() and not player_race.is_empty() and owner_race == player_race:
        return _result(false, "На порты своей расы нападать нельзя.")
    var transport_system: Node = get_tree().get_first_node_in_group("military_transport_system")
    var transports: Array = transport_system.raid_transports() if transport_system != null else []
    if transports.is_empty():
        return _result(false, "Для рейда нужен транспорт сопровождения с войсками рядом с портом.")
    if bool(GameState.combat_state.get("active_raid", {}).get("active", false)):
        return _result(false, "Операция уже идёт.")
    var naval_power: int = 0
    var transport_ids: Array = []
    var names: Array[String] = []
    for transport in transports:
        var definition: Dictionary = GameData.get_ship(str(transport.ship_type_id))
        var hull_ratio: float = clampf(float(transport.get("hull",definition.get("hull_max",145)))/float(definition.get("hull_max",145)),0.0,1.0)
        if hull_ratio <= 0: continue
        naval_power += int(round(float(definition.get("naval_attack",72))*hull_ratio))
        transport_ids.append(str(transport.instance_id))
        names.append(str(transport.get("name","Транспорт")))
    if transport_ids.is_empty(): return _result(false,"Транспорты требуют ремонта.")
    GameState.combat_state["active_raid"] = {
        "active": true,
        "target": target_name,
        "target_port_id": port_id,
        "enemy_power": maxi(1, enemy_power),
        "naval_power": naval_power,
        "attacking_ship": ", ".join(names),
        "transport_ids": transport_ids,
        "envoy_reserved": true,
        "started_at": _now(),
        "completes_at": _now() + maxi(5, duration_seconds)
    }
    if not SaveSystem.save_game():
        GameState.combat_state["active_raid"] = {}
        return _result(false, "Не удалось сохранить поход.")
    return _result(true, "Десант высаживается с транспортов: %s." % ", ".join(names))

func get_player_raid_status() -> Dictionary:
    var raid: Dictionary = GameState.combat_state.get("active_raid", {})
    if raid.is_empty() or not bool(raid.get("active", false)):
        return {}
    var started: int = int(raid.get("started_at", _now()))
    var completes: int = int(raid.get("completes_at", started))
    return {
        "target": str(raid.get("target", "Цель")),
        "percent": clampf(float(_now() - started) / maxf(1.0, float(completes - started)) * 100.0, 0.0, 100.0),
        "seconds_left": maxi(0, completes - _now())
    }

func get_reports() -> Array:
    return GameState.combat_state.get("reports", []).duplicate(true)

func get_unread_report_count() -> int:
    return int(GameState.combat_state.get("unread_reports", 0))

func mark_reports_seen() -> void:
    if get_unread_report_count() <= 0:
        return
    GameState.combat_state["unread_reports"] = 0
    SaveSystem.save_game()

func _complete_recruitment() -> void:
    var job: Dictionary = GameState.combat_state.get("recruitment", {})
    if job.is_empty() or _now() < int(job.get("completes_at", 0)):
        return
    var unit_id: String = str(job.get("unit_id", ""))
    var units: Dictionary = GameState.combat_state.get("units", {})
    var saved: Dictionary = units.get(unit_id, {"count": 0, "level": 1, "experience": 0})
    saved["count"] = int(saved.get("count", 0)) + int(job.get("amount", 0))
    units[unit_id] = saved
    GameState.combat_state["units"] = units
    GameState.combat_state["recruitment"] = {}
    SaveSystem.save_game()

func _complete_construction() -> void:
    var job: Dictionary = GameState.combat_state.get("construction_job", {})
    if job.is_empty() or _now() < int(job.get("completes_at", 0)):
        return
    if str(job.get("kind", "")) == "garrison_upgrade":
        GameState.combat_state["garrison_level"] = int(job.get("target_level", get_garrison_level()))
    elif str(job.get("kind", "")) == "tower_build":
        var towers: Array = GameState.combat_state.get("towers", [])
        towers.append({"type": "island", "crystal_id": "", "built_at": _now()})
        GameState.combat_state["towers"] = towers
    GameState.combat_state["construction_job"] = {}
    SaveSystem.save_game()

func _complete_player_raid() -> void:
    var raid: Dictionary = GameState.combat_state.get("active_raid", {})
    if raid.is_empty() or not bool(raid.get("active", false)) or _now() < int(raid.get("completes_at", 0)):
        return
    var transport_ids: Array = raid.get("transport_ids", [])
    var transports: Array = []
    var aboard: Dictionary = {}
    var attack_power: int = 0
    for ship in GameState.fleet_state:
        if not transport_ids.has(str(ship.get("instance_id",""))): continue
        transports.append(ship)
        attack_power += get_attack_power(ship.get("embarked_units",{}))
        for id in ship.get("embarked_units",{}):
            var cohort: Dictionary = ship.embarked_units[id]
            if not aboard.has(id):
                aboard[id] = cohort.duplicate(true)
            else:
                aboard[id]["count"] = int(aboard[id].count)+int(cohort.get("count",0))
                aboard[id]["level"] = mini(int(aboard[id].get("level",1)),int(cohort.get("level",1)))
    var report: Dictionary = _resolve_battle(int(raid.get("enemy_power", 1)), "player_raid", str(raid.get("target", "Цель")), aboard if not transport_ids.is_empty() else null, attack_power if not transport_ids.is_empty() else -1)
    var remaining_losses: Dictionary = report.get("unit_losses",{}).duplicate(true)
    for ship in transports:
        for id in ship.get("embarked_units",{}):
            var cohort: Dictionary = ship.embarked_units[id]
            var lost: int = mini(int(cohort.get("count",0)),int(remaining_losses.get(id,0)))
            cohort["count"] = int(cohort.get("count",0))-lost
            remaining_losses[id] = int(remaining_losses.get(id,0))-lost
            if int(cohort.count)>0: cohort["experience"] = int(cohort.get("experience",0))+(10 if bool(report.won) else 5)

    if int(raid.get("naval_power", 0)) > 0:
        var damage: float = 9.0 if bool(report.get("won", false)) else 30.0
        if transport_ids.is_empty():
            # Finish operations from legacy saves without changing their participants.
            GameState.ship_state["hull"] = maxf(1.0, float(GameState.ship_state.get("hull",100.0))-damage)
        for ship in transports:
            ship["hull"] = maxf(1.0,float(ship.get("hull",145.0))-damage)
        report["attacking_ship"] = str(raid.get("attacking_ship", "Боевой катер"))
        report["ship_hull_damage"] = damage
        var target_port_id: String = str(raid.get("target_port_id", ""))
        report["participants"] = aboard.duplicate(true)
        report["target_port_id"] = target_port_id
        report["battle_cards"] = {"attacker": aboard.duplicate(true), "attacker_losses": report.get("unit_losses", {}).duplicate(true), "defender": report.get("enemy_roster", {}).duplicate(true), "defender_losses": report.get("enemy_unit_loss_roster", {}).duplicate(true)}
        if target_port_id != "" and not bool(report.get("won", false)):
            var failed_target: Dictionary = GameState.port_state.get(target_port_id, {})
            if bool(failed_target.get("is_online_player", false)):
                failed_target["base_immunity_until"] = _now() + 3 * 86400
                GameState.port_state[target_port_id] = failed_target
                report["base_immunity_until"] = int(failed_target["base_immunity_until"])
                report["summary"] = str(report.get("summary", "")) + " База защищена иммунитетом на три дня."
        if bool(report.get("won", false)) and target_port_id != "":
            var target_port: Dictionary = GameState.port_state.get(target_port_id, {})
            report["occupation_transport_ids"] = transport_ids.duplicate()
            if bool(target_port.get("is_online_player", false)):
                _capture_online_player_port(target_port_id, target_port, aboard, transport_ids, report)
            else:
                _start_bot_port_tribute(target_port_id, target_port, aboard, transport_ids, report)
        else:
            report["port_captured"] = false
        var port_result := "под вашим флагом" if bool(report.get("online_island_captured", false)) else ("платит дань" if bool(report.get("tribute_started", false)) else ("удержан противником" if not bool(report.get("won", false)) else "освобождён"))
        report["summary"] = "Эскадра: %s. Повреждение каждого транспорта: %.0f. Остров %s. %s" % [str(raid.get("attacking_ship", "Капитан")), damage, port_result, str(report.get("summary", ""))]
    GameState.combat_state["active_raid"] = {}
    _store_report(report)

func _capture_online_player_port(port_id: String, port: Dictionary, aboard: Dictionary, transport_ids: Array, report: Dictionary) -> void:
    port["captured_by_player"] = true
    port["tribute_active"] = false
    port["owner_race_id"] = str(GameState.player_state.get("origin_race_id", "humans"))
    var survivors: Dictionary = {}
    for unit_id in aboard:
        survivors[unit_id] = maxi(0, int(aboard[unit_id].get("count", 0)) - int(report.get("unit_losses", {}).get(unit_id, 0)))
    port["occupation_garrison"] = {}
    port["occupation_initial_roster"] = survivors
    port["occupation_transport_ids"] = transport_ids.duplicate()
    port["occupation_envoy"] = false
    GameState.port_state[port_id] = port
    for port_system in get_tree().get_nodes_in_group("port_system"):
        port_system.call("mark_port_captured", port_id)
    report["port_captured"] = true
    report["online_island_captured"] = true
    report["summary"] = str(report.get("summary", "")) + " Остров игрока перешёл под ваш флаг."

func _start_bot_port_tribute(port_id: String, port: Dictionary, aboard: Dictionary, transport_ids: Array, report: Dictionary) -> void:
    # Bot ports remain in the trade network and pay tribute instead of disappearing.
    port["captured_by_player"] = false
    port["tribute_active"] = true
    port["tribute_rate"] = 0.10
    var daily_profit: int = maxi(100, int(port.get("daily_profit", port.get("ai_daily_profit", 0))))
    if daily_profit <= 100:
        daily_profit = 100 + int(port.get("level", 1)) * 50
    port["ai_daily_profit"] = daily_profit
    port["tribute_daily_amount"] = maxi(1, int(round(float(daily_profit) * 0.10)))
    port["tribute_started_at"] = _now()
    port["tribute_last_tick"] = _now()
    port["tribute_revolt_at"] = _now() + 7 * 86400 + posmod(hash(port_id), 8) * 86400
    var occupation_roster: Dictionary = {}
    for unit_id in aboard.keys():
        var survivors: int = maxi(0, int(aboard[unit_id].get("count", 0)) - int(report.get("unit_losses", {}).get(unit_id, 0)))
        occupation_roster[unit_id] = survivors
    # Keep all survivors aboard until the player chooses an occupation force in
    # the post-battle handover screen. The previous invisible 20% auto-deployment
    # made it unclear which troops had actually left the transports.
    port["occupation_garrison"] = {}
    port["occupation_initial_roster"] = occupation_roster
    port["occupation_envoy"] = true
    port["occupation_transport_ids"] = transport_ids.duplicate()
    GameState.combat_state["envoys"] = maxi(0, int(GameState.combat_state.get("envoys", 5)) - 1)
    GameState.port_state[port_id] = port
    report["port_captured"] = false
    report["tribute_started"] = true
    report["tribute_daily_amount"] = int(port.get("tribute_daily_amount", 0))
    report["tribute_transition"] = "Представитель острова приносит дань. Посланник остаётся на месте; выберите, сколько выживших бойцов высадить для контроля."

func _process_tribute_income() -> void:
    var now := _now()
    var changed := false
    for raw_id in GameState.port_state.keys():
        var port: Dictionary = GameState.port_state[raw_id]
        if not bool(port.get("tribute_active", false)):
            continue
        var last := int(port.get("tribute_last_tick", now))
        var days := maxi(0, (now - last) / 86400)
        if days > 0:
            GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + float(port.get("tribute_daily_amount", 0)) * days
            port["tribute_last_tick"] = last + days * 86400
            changed = true
        if int(port.get("tribute_revolt_at", 0)) > 0 and now >= int(port.get("tribute_revolt_at", 0)):
            var stationed: Dictionary = port.get("occupation_garrison", {})
            var stationed_power := 0
            var stationed_total := 0
            for unit_id in stationed.keys():
                var unit: Dictionary = _catalog.get("units", {}).get(str(unit_id), {})
                stationed_power += int(stationed[unit_id]) * maxi(1, int(unit.get("attack", 1)) + int(unit.get("defense", 1)))
                stationed_total += int(stationed[unit_id])
            var rebel_power := maxi(8, int(port.get("level", 1)) * 20 + _rng.randi_range(0, 35))
            var revolt_won := stationed_power >= rebel_power
            var garrison_losses := mini(stationed_total, maxi(1, int(ceil(float(stationed_total) * (0.18 if revolt_won else 0.42))))) if stationed_total > 0 else 0
            var rebel_count := maxi(1, int(ceil(float(rebel_power) / 8.0)))
            var rebel_losses := mini(rebel_count, maxi(1, int(ceil(float(rebel_count) * (0.44 if revolt_won else 0.10)))))
            var losses_left := garrison_losses
            for unit_id in stationed.keys():
                var loss := mini(int(stationed[unit_id]), losses_left)
                stationed[unit_id] = int(stationed[unit_id]) - loss
                losses_left -= loss
            var occupation_losses := {"all_units": garrison_losses}
            if revolt_won:
                port["occupation_garrison"] = stationed
                port["tribute_revolt_at"] = now + 7 * 86400 + posmod(hash(str(raw_id)), 8) * 86400
                port["rebellion_suppressed_at"] = now
            else:
                var envoy_returned: bool = bool(port.get("occupation_envoy", false))
                port["tribute_active"] = false
                port["rebellion_active"] = true
                port["revolt_declared_at"] = now
                port["revolt_immunity_until"] = now + 3 * 86400
                port["occupation_garrison"] = {}
                port["occupation_envoy"] = false
                port["occupation_transport_ids"] = []
                GameState.combat_state["envoys"] = int(GameState.combat_state.get("envoys", 0)) + (1 if envoy_returned else 0)
            var revolt_report: Dictionary = {
                "id": int(GameState.combat_state.get("report_sequence", 0)) + 1,
                "kind": "tribute_revolt",
                "target": str(port.get("name", raw_id)),
                "target_port_id": str(raw_id),
                "won": revolt_won,
                "revolt": true,
                "battle_cards": {"defender_losses": rebel_losses, "occupation_losses": occupation_losses, "rebels": true},
                "casualties_text": "гарнизон %d, мятежники %d" % [garrison_losses, rebel_losses],
                "summary": "Письмо экстренное: бунт подавлен, дань восстановлена. Потери гарнизона: %d; мятежников: %d." % [garrison_losses, rebel_losses] if revolt_won else "Письмо экстренное: остров освободился и получил иммунитет на 3 дня. Потери гарнизона: %d; мятежников: %d." % [garrison_losses, rebel_losses]
            }
            _store_report(revolt_report)
            changed = true
        GameState.port_state[raw_id] = port
    if changed:
        SaveSystem.save_game()

func set_tribute_occupation_roster(port_id: String, requested: Dictionary) -> Dictionary:
    var port: Dictionary = GameState.port_state.get(port_id, {})
    if port.is_empty() or (not bool(port.get("tribute_active", false)) and not bool(port.get("captured_by_player", false))):
        return {"ok": false, "message": "Остров больше не находится под вашим контролем.", "stationed": {}}
    var stationed: Dictionary = {}
    var original_roster: Dictionary = port.get("occupation_initial_roster", {})
    var ids: Array = port.get("occupation_transport_ids", [])
    var available_by_unit: Dictionary = {}
    for ship in GameState.fleet_state:
        if not ids.has(str(ship.get("instance_id", ""))):
            continue
        var cargo: Dictionary = ship.get("embarked_units", {})
        for raw_id in cargo.keys():
            var unit_id := str(raw_id)
            var cohort: Dictionary = cargo[unit_id]
            available_by_unit[unit_id] = int(available_by_unit.get(unit_id, 0)) + int(cohort.get("count", 0))
    for raw_id in original_roster.keys():
        var unit_id := str(raw_id)
        var take := mini(maxi(0, int(requested.get(unit_id, 0))), mini(int(original_roster[raw_id]), int(available_by_unit.get(unit_id, 0))))
        if take > 0:
            stationed[unit_id] = take
    _remove_embarked_occupation(ids, stationed)
    port["occupation_garrison"] = stationed
    port["occupation_enhanced"] = true
    GameState.port_state[port_id] = port
    SaveSystem.save_game()
    var total := 0
    for count in stationed.values():
        total += int(count)
    return {"ok": true, "stationed": stationed.duplicate(true), "total": total, "message": "На острове оставлено бойцов: %d." % total}

func _remove_embarked_occupation(transport_ids: Array, occupation: Dictionary) -> void:
    var remaining: Dictionary = occupation.duplicate(true)
    for ship in GameState.fleet_state:
        if not transport_ids.has(str(ship.get("instance_id", ""))):
            continue
        var cargo: Dictionary = ship.get("embarked_units", {})
        for unit_id in remaining.keys():
            if int(remaining[unit_id]) <= 0 or not cargo.has(unit_id):
                continue
            var cohort: Dictionary = cargo[unit_id]
            var moved := mini(int(cohort.get("count", 0)), int(remaining[unit_id]))
            cohort["count"] = int(cohort.get("count", 0)) - moved
            cargo[unit_id] = cohort
            remaining[unit_id] = int(remaining[unit_id]) - moved
        ship["embarked_units"] = cargo

func _resolve_battle(enemy_power: int, kind: String, enemy_name: String, roster: Variant = null, embarked_power: int = -1) -> Dictionary:
    var own_power: int = get_defense_power() if kind == "defense" else get_attack_power()
    if embarked_power >= 0: own_power = embarked_power
    var naval_operation: bool = kind == "player_raid" and int(GameState.combat_state.get("active_raid", {}).get("naval_power", 0)) > 0
    if kind == "player_raid":
        own_power += int(GameState.combat_state.get("active_raid", {}).get("naval_power", 0))
    enemy_power = maxi(1, enemy_power)
    var luck_result: Dictionary = _resolve_lucky_strikes(enemy_power, kind, roster)
    var effective_enemy_power: int = int(luck_result.get("effective_enemy_power", enemy_power))
    var won: bool = own_power >= effective_enemy_power
    var unit_losses: Dictionary = _apply_naval_casualties(won, roster) if naval_operation else _apply_casualties(won, own_power, effective_enemy_power, kind == "defense")
    _award_unit_experience(won, roster)
    var enemy_unit_count: int = maxi(1, int(ceil(float(enemy_power) / 8.0)))
    var enemy_losses: int = mini(enemy_unit_count, int(ceil(float(enemy_unit_count) * (0.30 if won else 0.08))))
    var enemy_roster: Dictionary = _make_enemy_roster(enemy_unit_count)
    var enemy_loss_roster: Dictionary = _make_enemy_losses(enemy_roster, enemy_losses)
    var base_damage: float = 0.0
    var lost_goods: int = 0
    if kind == "defense" and not won:
        base_damage = 2.4 if int(GameState.combat_state.get("units", {}).get("stone_warden", {}).get("count", 0)) > 0 else 3.0
        GameState.combat_state["fort_integrity"] = maxf(0.0, float(GameState.combat_state.get("fort_integrity", 100.0)) - base_damage)
        lost_goods = _apply_stock_losses()
    var outcome: String = "Победа" if won else "Поражение"
    var loss_ratio: String = "" if not naval_operation else (" Боевые потери при захвате снижены." if won else " Войска и артиллерия понесли тяжёлые потери при отступлении.")
    var summary: String = "%s. Ваши потери: %d отрядов; потери противника: %d.%s" % [outcome, _sum_losses(unit_losses), enemy_losses, loss_ratio]
    if base_damage > 0.0:
        summary += " Укрепления: -%.0f%%." % base_damage
    if lost_goods > 0:
        summary += " Потеряно складских единиц: %d." % lost_goods
    var lucky_summary: String = str(luck_result.get("summary", ""))
    if lucky_summary != "":
        summary += " " + lucky_summary
    return {
        "id": int(GameState.combat_state.get("report_sequence", 0)) + 1,
        "kind": kind,
        "enemy": enemy_name,
        "outcome": outcome,
        "won": won,
        "enemy_power": enemy_power,
        "effective_enemy_power": effective_enemy_power,
        "own_power": own_power,
        "unit_losses": unit_losses,
        "enemy_unit_losses": enemy_losses,
        "enemy_roster": enemy_roster,
        "enemy_unit_loss_roster": enemy_loss_roster,
        "fort_damage": base_damage,
        "goods_lost": lost_goods,
        "lucky_effects": luck_result.get("effects", []),
        "armor_reduction_percent": luck_result.get("armor_reduction_percent", 0.0),
        "vitality_damage": luck_result.get("vitality_damage", 0),
        "timestamp": _now(),
        "summary": summary
    }

func _make_enemy_roster(total: int) -> Dictionary:
    var roster: Dictionary = {}
    var order: Array = _catalog.get("unit_order", [])
    if order.is_empty():
        return roster
    var weights: Array[float] = [0.30, 0.22, 0.16, 0.12, 0.14, 0.06]
    var assigned := 0
    for index in order.size():
        var unit_id := str(order[index])
        var count := int(floor(float(total) * weights[mini(index, weights.size() - 1)]))
        roster[unit_id] = count
        assigned += count
    for index in total - assigned:
        var unit_id := str(order[index % order.size()])
        roster[unit_id] = int(roster.get(unit_id, 0)) + 1
    return roster

func _make_enemy_losses(roster: Dictionary, total_losses: int) -> Dictionary:
    var losses: Dictionary = {}
    var left := total_losses
    for unit_id in roster.keys():
        if left <= 0:
            break
        var lost := mini(int(roster[unit_id]), maxi(1, int(ceil(float(total_losses) * float(roster[unit_id]) / maxi(1, _sum_losses(roster))))))
        lost = mini(lost, left)
        losses[unit_id] = lost
        left -= lost
    return losses

func _resolve_lucky_strikes(enemy_power: int, kind: String, roster: Variant = null) -> Dictionary:
    var armor_reduction: float = 0.0
    var vitality_damage: float = 0.0
    var vitality_limit: float = float(enemy_power) * 0.20
    var effects: Array[String] = []
    var luck_bonus: float = float(get_tower_bonuses().get("luck", 0.0))
    var cap: float = float(_mage_guild_rules.get("effect_caps", {}).get("final_luck_chance_percentage", 35.0))
    var units: Dictionary = GameState.combat_state.get("units", {}) if roster == null else roster
    var definitions: Dictionary = _catalog.get("units", {})
    for unit_id in units:
        var saved: Dictionary = units[unit_id]
        var count: int = maxi(0, int(saved.get("count", 0)))
        if count <= 0:
            continue
        var definition: Dictionary = definitions.get(str(unit_id), {})
        var chance: float = minf(cap, 2.0 + 0.5 * _unit_stat(definition, saved, "luck") + luck_bonus)
        if _rng.randf() * 100.0 >= chance:
            continue
        var group_attack: float = float(count) * (_unit_stat(definition, saved, "attack") + _unit_stat(definition, saved, "luck") * 0.3)
        match str(unit_id):
            "rune_spearman":
                armor_reduction += 6.0
                effects.append("Рунный пробой −6% брони")
            "coast_guard":
                vitality_damage = minf(vitality_limit, vitality_damage + group_attack * 0.25)
                effects.append("Караул: дополнительный удар")
            "wind_rider":
                vitality_damage = minf(vitality_limit, vitality_damage + group_attack * 0.35)
                effects.append("Фланговый налёт: дополнительный урон")
            "storm_drake":
                armor_reduction += 4.0
                vitality_damage = minf(vitality_limit, vitality_damage + group_attack * 0.15)
                effects.append("Грозовой выдох: броня и живучесть")
    armor_reduction = minf(24.0, armor_reduction)
    var reduced_power: int = maxi(1, int(ceil(float(enemy_power) * (1.0 - armor_reduction / 100.0))))
    var effective_power: int = maxi(1, int(ceil(float(reduced_power) - vitality_damage)))
    var summary: String = "Удачные удары: %s." % ", ".join(effects) if not effects.is_empty() else ""
    return {
        "effective_enemy_power": effective_power,
        "armor_reduction_percent": armor_reduction,
        "vitality_damage": int(round(vitality_damage)),
        "effects": effects,
        "summary": summary
    }

func _apply_casualties(won: bool, own_power: int, enemy_power: int, home_defense: bool = false) -> Dictionary:
    var losses: Dictionary = {}
    var units: Dictionary = GameState.combat_state.get("units", {})
    var total: int = _total_units()
    if total <= 1:
        return losses
    var ratio: float = (0.01 if won else 0.04) if home_defense else (0.025 if won else 0.12)
    if home_defense and int(units.get("stone_warden", {}).get("count", 0)) > 0:
        ratio *= 0.85
    if own_power <= 0:
        ratio = 0.0
    var loss_count: int = mini(total - 1, int(round(float(total) * ratio)))
    if not won and loss_count == 0:
        loss_count = 1
    for unit_id in units.keys():
        if loss_count <= 0:
            break
        var saved: Dictionary = units[unit_id]
        var count: int = int(saved.get("count", 0))
        var lost: int = mini(maxi(0, count - 1), loss_count)
        if lost > 0:
            saved["count"] = count - lost
            units[unit_id] = saved
            losses[str(unit_id)] = lost
            loss_count -= lost
    GameState.combat_state["units"] = units
    return losses

func _apply_naval_casualties(won: bool, roster: Variant = null) -> Dictionary:
    var losses: Dictionary = {}
    var units: Dictionary = GameState.combat_state.get("units", {}) if roster == null else roster
    var ratio: float = 0.08 if won else 0.25
    for id in units:
        var cohort: Dictionary = units[id]
        var count: int = maxi(0,int(cohort.get("count",0)))
        if count <= 0: continue
        var lost: int = mini(count,maxi(1,int(ceil(count*ratio))))
        cohort["count"] = count-lost
        losses[id] = lost
    if roster == null: GameState.combat_state["units"] = units
    return losses

func _award_unit_experience(won: bool, roster: Variant = null) -> void:
    var units: Dictionary = GameState.combat_state.get("units", {}) if roster == null else roster
    var earned: int = 10 if won else 5
    for unit_id in units:
        var saved: Dictionary = units[unit_id]
        if int(saved.get("count", 0)) <= 0:
            continue
        saved["experience"] = int(saved.get("experience", 0)) + earned
        units[unit_id] = saved
    if roster == null: GameState.combat_state["units"] = units

func _apply_stock_losses() -> int:
    var port_id: String = get_home_port_id()
    var port: Dictionary = GameState.port_state.get(port_id, {})
    var inventory: Dictionary = port.get("inventory", {})
    var total: int = 0
    for value in inventory.values():
        total += maxi(0, int(value))
    var target_loss: int = mini(8, int(floor(float(total) * 0.005)))
    var remaining: int = target_loss
    for raw_id in inventory.keys():
        if remaining <= 0:
            break
        var id: String = str(raw_id)
        var amount: int = maxi(0, int(inventory[id]))
        var lost: int = mini(amount, int(floor(float(amount) * 0.005)))
        if lost > 0:
            inventory[id] = amount - lost
            remaining -= lost
    port["inventory"] = inventory
    GameState.port_state[port_id] = port
    return target_loss - remaining

func _award_magic_shards_for_victory(report: Dictionary) -> void:
    var state: Dictionary = GameState.combat_state
    var victories: int = int(state.get("battle_victories", 0)) + 1
    state["battle_victories"] = victories
    var rewards: Dictionary = _mage_guild_rules.get("shard_rewards", {})
    var interval: int = maxi(1, int(rewards.get("first_and_each_nth_victory_interval", 3)))
    if victories != 1 and (victories - 1) % interval != 0:
        GameState.combat_state = state
        return
    var shards: int = maxi(1, int(rewards.get("magic_shards_per_reward", 3)))
    state["magic_shards"] = maxi(0, int(state.get("magic_shards", 0))) + shards
    report["magic_shards_reward"] = shards
    report["summary"] = str(report.get("summary", "")) + " Найдено осколков магии: %d." % shards
    GameState.combat_state = state

func _store_report(report: Dictionary) -> void:
    if bool(report.get("won", false)):
        _award_magic_shards_for_victory(report)
    var state: Dictionary = GameState.combat_state
    var reports: Array = state.get("reports", [])
    reports.push_front(report)
    var limit: int = int(_rules().get("report_limit", 30))
    while reports.size() > limit:
        reports.pop_back()
    state["reports"] = reports
    state["report_sequence"] = int(report.get("id", 0))
    state["unread_reports"] = int(state.get("unread_reports", 0)) + 1
    GameState.combat_state = state
    if not SaveSystem.save_game():
        push_warning("Боевой отчёт не удалось сохранить.")
    EventBus.combat_report_ready.emit(report)

func _total_units() -> int:
    var total: int = 0
    for saved in GameState.combat_state.get("units", {}).values():
        total += maxi(0, int(saved.get("count", 0)))
    return total

func _sum_losses(losses: Dictionary) -> int:
    var total: int = 0
    for value in losses.values():
        total += int(value)
    return total

func _result(ok: bool, message: String) -> Dictionary:
    return {"ok": ok, "message": message}
