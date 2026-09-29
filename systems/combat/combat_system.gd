extends Node

## Offline-first, text-only combat simulation. Battle outcomes live in GameState.
const CATALOG_PATH := "res://data/combat/unit_catalog.json"

var _catalog: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    add_to_group("combat_system")
    _rng.randomize()

func initialize() -> void:
    _catalog = GameData.read(CATALOG_PATH)
    _normalize_state()
    _ensure_starter_garrison_materials()
    var state: Dictionary = GameState.combat_state
    if int(state.get("next_defense_at", 0)) <= 0:
        state["next_defense_at"] = _now() + int(_rules().get("passive_attack_interval_seconds", 21600))

func _process(_delta: float) -> void:
    if _catalog.is_empty():
        return
    _normalize_state()
    _ensure_starter_garrison_materials()
    _complete_recruitment()
    _complete_construction()
    _complete_player_raid()
    var state: Dictionary = GameState.combat_state
    if _now() >= int(state.get("next_defense_at", 0)) and not bool(state.get("active_raid", {}).get("active", false)):
        var level: int = int(state.get("garrison_level", 1))
        var enemy_power: int = _rng.randi_range(14 + level * 5, 25 + level * 10)
        resolve_hidden_attack(enemy_power, "Пиратский отряд")

func _ensure_starter_garrison_materials() -> void:
    var state: Dictionary = GameState.combat_state
    if bool(state.get("starter_tower_kit_granted", false)):
        return
    var home_id: String = get_home_port_id()
    if home_id == "" or not GameState.port_state.has(home_id):
        return
    var towers: Array = state.get("towers", [])
    if not towers.is_empty():
        state["starter_tower_kit_granted"] = true
        GameState.combat_state = state
        SaveSystem.save_game()
        return
    var port: Dictionary = GameState.port_state.get(home_id, {})
    var inventory: Dictionary = port.get("inventory", {})
    var package_key: String = "starter_garrison_and_tower_kit" if get_garrison_level() == 1 else "starter_tower_kit"
    var starter_kit: Dictionary = _rules().get(package_key, {})
    for resource_id in starter_kit:
        inventory[resource_id] = maxi(int(inventory.get(resource_id, 0)), int(starter_kit[resource_id]))
    port["inventory"] = inventory
    GameState.port_state[home_id] = port
    state["starter_tower_kit_granted"] = true
    GameState.combat_state = state
    SaveSystem.save_game()

func _normalize_state() -> void:
    var state: Dictionary = GameState.combat_state
    state.merge(GameState.default_combat_state(), false)
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
    if not state.get("crystals", {}) is Dictionary:
        state["crystals"] = {}
    var crystal_inventory: Dictionary = state.get("crystals", {})
    for crystal_id in _catalog.get("crystals", {}).keys():
        crystal_inventory[crystal_id] = maxi(0, int(crystal_inventory.get(crystal_id, 0)))
    state["crystals"] = crystal_inventory
    var legacy_crystals: Dictionary = {"power": "crystal_power", "guard": "crystal_guard", "wind": "crystal_wind"}
    var towers: Array = state.get("towers", [])
    for index in range(towers.size()):
        var tower: Dictionary = towers[index]
        var old_type: String = str(tower.get("type", "island"))
        if legacy_crystals.has(old_type) and str(tower.get("crystal_id", "")) == "":
            tower["crystal_id"] = str(legacy_crystals[old_type])
            tower["type"] = "island"
            towers[index] = tower
    state["towers"] = towers
    if not state.has("starter_tower_kit_granted"):
        state["starter_tower_kit_granted"] = false
    if int(state.get("battle_victories", -1)) < 0:
        state["battle_victories"] = 0
    if int(state.get("next_crystal_reward", -1)) < 0:
        state["next_crystal_reward"] = 0
    var units: Dictionary = state.units
    if not units.has("coast_guard"):
        units["coast_guard"] = {"count": 8, "level": 1, "experience": 0}
    state["units"] = units
    GameState.combat_state = state

func _rules() -> Dictionary:
    return _catalog.get("rules", {})

func _now() -> int:
    return int(Time.get_unix_time_from_system())

func get_home_port_id() -> String:
    return str(GameState.world_state.get("home_port_id", ""))

func is_at_home() -> bool:
    var home_id: String = get_home_port_id()
    return home_id != "" and str(GameState.ship_state.get("docked_port_id", "")) == home_id

func get_catalog() -> Dictionary:
    return _catalog.duplicate(true)

func get_garrison_level() -> int:
    return int(GameState.combat_state.get("garrison_level", 1))

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
    return _catalog.get("crystals", {}).duplicate(true)

func get_crystal_order() -> Array:
    return _catalog.get("crystal_order", []).duplicate()

func get_crystal_inventory() -> Dictionary:
    return GameState.combat_state.get("crystals", {}).duplicate(true)

func get_crystal_name(crystal_id: String) -> String:
    return str(_catalog.get("crystals", {}).get(crystal_id, {}).get("name", crystal_id))

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
    return float(GameState.player_state.get("money", 0.0)) >= int(definition.get("hire_cost", 0)) * amount

func get_towers() -> Array:
    return GameState.combat_state.get("towers", []).duplicate(true)

func get_tower_bonuses() -> Dictionary:
    var result: Dictionary = {"attack": 0.0, "defense": 0.0, "speed": 0.0}
    var defs: Dictionary = _catalog.get("crystals", {})
    for raw_tower in get_towers():
        var tower: Dictionary = raw_tower
        var definition: Dictionary = defs.get(str(tower.get("crystal_id", "")), {})
        result["attack"] += float(definition.get("attack_bonus", 0.0))
        result["defense"] += float(definition.get("defense_bonus", 0.0))
        result["speed"] += float(definition.get("speed_bonus", 0.0))
    for key in result:
        result[key] = minf(float(result[key]), 40.0)
    return result

func get_defense_power() -> int:
    var total: float = 0.0
    var units: Dictionary = GameState.combat_state.get("units", {})
    var defs: Dictionary = _catalog.get("units", {})
    for unit_id in units:
        var saved: Dictionary = units[unit_id]
        var definition: Dictionary = defs.get(str(unit_id), {})
        total += float(saved.get("count", 0)) * (_unit_stat(definition, saved, "defense") + _unit_stat(definition, saved, "luck") * 0.3)
    var bonuses: Dictionary = get_tower_bonuses()
    var integrity: float = float(GameState.combat_state.get("fort_integrity", 100.0)) / 100.0
    return maxi(0, int(round(total * (1.0 + float(bonuses.defense) / 100.0) * integrity)))

func get_attack_power() -> int:
    var total: float = 0.0
    var units: Dictionary = GameState.combat_state.get("units", {})
    var defs: Dictionary = _catalog.get("units", {})
    for unit_id in units:
        var saved: Dictionary = units[unit_id]
        var definition: Dictionary = defs.get(str(unit_id), {})
        total += float(saved.get("count", 0)) * (_unit_stat(definition, saved, "attack") + _unit_stat(definition, saved, "luck") * 0.3)
    var bonuses: Dictionary = get_tower_bonuses()
    return maxi(0, int(round(total * (1.0 + float(bonuses.attack) / 100.0))))

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
    return weighted_speed / float(count) * (1.0 + float(get_tower_bonuses().speed) / 100.0)

func _unit_stat(definition: Dictionary, saved: Dictionary, stat: String) -> float:
    var level: int = int(saved.get("level", 1))
    return float(definition.get(stat, 0.0)) * (1.0 + 0.08 * float(maxi(0, level - 1)))

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
    var slots: Array = _rules().get("tower_slots_by_garrison_level", [])
    var level: int = clampi(get_garrison_level(), 1, int(_rules().get("max_garrison_level", 5)))
    if level < slots.size():
        return mini(3, int(slots[level]))
    return mini(3, level)

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
    var cost: int = int(definition.get("hire_cost", 0)) * amount
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
    var interval: int = int(_rules().get("passive_attack_interval_seconds", 21600))
    GameState.combat_state["next_defense_at"] = _now() + interval
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
    var report: Dictionary = _resolve_battle(int(raid.get("enemy_power", 1)), "player_raid", str(raid.get("target", "Цель")))
    GameState.combat_state["active_raid"] = {}
    _store_report(report)

func _resolve_battle(enemy_power: int, kind: String, enemy_name: String) -> Dictionary:
    var own_power: int = get_defense_power() if kind == "defense" else get_attack_power()
    var won: bool = own_power >= enemy_power
    var unit_losses: Dictionary = _apply_casualties(won, own_power, enemy_power)
    _award_unit_experience(won)
    var enemy_unit_count: int = maxi(1, int(ceil(float(enemy_power) / 8.0)))
    var enemy_losses: int = mini(enemy_unit_count, int(ceil(float(enemy_unit_count) * (0.30 if won else 0.08))))
    var base_damage: float = 0.0
    var lost_goods: int = 0
    if kind == "defense" and not won:
        base_damage = 8.0
        GameState.combat_state["fort_integrity"] = maxf(0.0, float(GameState.combat_state.get("fort_integrity", 100.0)) - base_damage)
        lost_goods = _apply_stock_losses()
    var outcome: String = "Победа" if won else "Поражение"
    var summary: String = "%s. Ваши потери: %d отрядов; потери противника: %d." % [outcome, _sum_losses(unit_losses), enemy_losses]
    if base_damage > 0.0:
        summary += " Укрепления: -%.0f%%." % base_damage
    if lost_goods > 0:
        summary += " Потеряно складских единиц: %d." % lost_goods
    return {
        "id": int(GameState.combat_state.get("report_sequence", 0)) + 1,
        "kind": kind,
        "enemy": enemy_name,
        "outcome": outcome,
        "won": won,
        "enemy_power": enemy_power,
        "own_power": own_power,
        "unit_losses": unit_losses,
        "enemy_unit_losses": enemy_losses,
        "fort_damage": base_damage,
        "goods_lost": lost_goods,
        "timestamp": _now(),
        "summary": summary
    }

func _apply_casualties(won: bool, own_power: int, enemy_power: int) -> Dictionary:
    var losses: Dictionary = {}
    var units: Dictionary = GameState.combat_state.get("units", {})
    var total: int = _total_units()
    if total <= 1:
        return losses
    var ratio: float = 0.025 if won else 0.12
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

func _award_unit_experience(won: bool) -> void:
    var units: Dictionary = GameState.combat_state.get("units", {})
    var earned: int = 10 if won else 5
    for unit_id in units:
        var saved: Dictionary = units[unit_id]
        if int(saved.get("count", 0)) <= 0:
            continue
        saved["experience"] = int(saved.get("experience", 0)) + earned
        units[unit_id] = saved
    GameState.combat_state["units"] = units

func _apply_stock_losses() -> int:
    var port_id: String = get_home_port_id()
    var port: Dictionary = GameState.port_state.get(port_id, {})
    var inventory: Dictionary = port.get("inventory", {})
    var total: int = 0
    for value in inventory.values():
        total += maxi(0, int(value))
    var target_loss: int = mini(10, int(floor(float(total) * 0.02)))
    var remaining: int = target_loss
    for raw_id in inventory.keys():
        if remaining <= 0:
            break
        var id: String = str(raw_id)
        var amount: int = maxi(0, int(inventory[id]))
        var lost: int = mini(amount, int(floor(float(amount) * 0.02)))
        if lost > 0:
            inventory[id] = amount - lost
            remaining -= lost
    port["inventory"] = inventory
    GameState.port_state[port_id] = port
    return target_loss - remaining

func _award_crystal_for_victory(report: Dictionary) -> void:
    var state: Dictionary = GameState.combat_state
    var victories: int = int(state.get("battle_victories", 0)) + 1
    state["battle_victories"] = victories
    var interval: int = maxi(1, int(_rules().get("victories_between_crystal_rewards", 3)))
    if victories != 1 and (victories - 1) % interval != 0:
        GameState.combat_state = state
        return
    var order: Array = get_crystal_order()
    if order.is_empty():
        GameState.combat_state = state
        return
    var reward_index: int = int(state.get("next_crystal_reward", 0)) % order.size()
    var crystal_id: String = str(order[reward_index])
    var inventory: Dictionary = state.get("crystals", {})
    inventory[crystal_id] = int(inventory.get(crystal_id, 0)) + 1
    state["crystals"] = inventory
    state["next_crystal_reward"] = reward_index + 1
    report["crystal_reward"] = crystal_id
    report["summary"] = str(report.get("summary", "")) + " Найден: %s." % get_crystal_name(crystal_id)
    GameState.combat_state = state

func _store_report(report: Dictionary) -> void:
    if bool(report.get("won", false)):
        _award_crystal_for_victory(report)
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