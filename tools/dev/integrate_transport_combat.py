from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'systems/combat/combat_system.gd'; s=p.read_text(encoding='utf-8-sig')
def replace(old,new):
    global s
    assert old in s,old[:100]
    s=s.replace(old,new)
for name,args in [('get_attack_power',''),('_resolve_lucky_strikes','enemy_power: int, kind: String'),('_apply_naval_casualties','won: bool'),('_award_unit_experience','won: bool')]:
    start=s.index('func '+name+'('); end=s.find('\nfunc ',start+1)
    block=s[start:end]
    block=block.replace('('+args+')','('+args+(', ' if args else '')+'roster: Variant = null)')
    block=block.replace('var units: Dictionary = GameState.combat_state.get("units", {})','var units: Dictionary = GameState.combat_state.get("units", {}) if roster == null else roster')
    block=block.replace('GameState.combat_state["units"] = units','if roster == null: GameState.combat_state["units"] = units')
    block=block.replace('var total: int = _total_units()','var total: int = 0\n    for cohort in units.values(): total += maxi(0,int(cohort.get("count",0)))')
    s=s[:start]+block+s[end:]
replace('    if str(GameState.ship_state.get("ship_id", "")) != "ship_combat_cutter":\n        return _result(false, "Для рейда нужен боевой катер под командованием капитана.")','    var transport_system: Node = get_tree().get_first_node_in_group("military_transport_system")\n    var transports: Array = transport_system.raid_transports() if transport_system != null else []\n    if transports.is_empty():\n        return _result(false, "Для рейда нужен транспорт сопровождения с войсками рядом с портом.")')
start=s.index('    var ship_type: Dictionary = GameData.get_ship("ship_combat_cutter")',s.index('func start_port_raid'))
end=s.index('    GameState.combat_state["active_raid"]',start)
s=s[:start]+'''    var naval_power: int = 0
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
'''+s[end:]
replace('"attacking_ship": str(GameState.ship_state.get("name", "Боевой катер")),','"attacking_ship": ", ".join(names),\n        "transport_ids": transport_ids,')
replace('return _result(true, "Катер %s под командованием капитана вышел на бой." % str(GameState.ship_state.get("name", "")))','return _result(true, "Десант высаживается с транспортов: %s." % ", ".join(names))')
replace('    var report: Dictionary = _resolve_battle(int(raid.get("enemy_power", 1)), "player_raid", str(raid.get("target", "Цель")))','''    var transport_ids: Array = raid.get("transport_ids", [])
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
''')
replace('        GameState.ship_state["hull"] = maxf(1.0, float(GameState.ship_state.get("hull", 100.0)) - damage)','''        if transport_ids.is_empty():
            # Finish operations from legacy saves without changing their participants.
            GameState.ship_state["hull"] = maxf(1.0, float(GameState.ship_state.get("hull",100.0))-damage)
        for ship in transports:
            ship["hull"] = maxf(1.0,float(ship.get("hull",145.0))-damage)''')
replace('%s вёл катер лично. Корпус потерял %.0f ед. Порт %s. Противник: %s','Эскадра: %s. Повреждение каждого транспорта: %.0f. Порт %s. %s')
replace('func _resolve_battle(enemy_power: int, kind: String, enemy_name: String) -> Dictionary:','func _resolve_battle(enemy_power: int, kind: String, enemy_name: String, roster: Variant = null, embarked_power: int = -1) -> Dictionary:')
replace('    var naval_operation: bool = kind == "player_raid"','    if embarked_power >= 0: own_power = embarked_power\n    var naval_operation: bool = kind == "player_raid"')
replace('_resolve_lucky_strikes(enemy_power, kind)','_resolve_lucky_strikes(enemy_power, kind, roster)')
replace('_apply_naval_casualties(won) if naval_operation','_apply_naval_casualties(won, roster) if naval_operation')
replace('    _award_unit_experience(won)','    _award_unit_experience(won, roster)')
p.write_text(s,encoding='utf-8')
p=R/'systems/fleet/fleet_system.gd'; s=p.read_text(encoding='utf-8-sig')
s=s.replace('var candidate: Dictionary = GameState.fleet_state[index]\n','var candidate: Dictionary = GameState.fleet_state[index]\n\tif str(candidate.get("ship_type_id","")) == "ship_combat_cutter":\n\t\treturn {"ok": false, "message": "Военный транспорт следует за вашим кораблём. Управляйте десантом в окне флота."}\n',1)
for decl in ['var ship: Dictionary = GameState.fleet_state[index]\n\tvar quote:','var ship: Dictionary = GameState.fleet_state[ship_index]\n\tif not ship.get("autopilot", {}).is_empty():']:
    assert decl in s
    head,tail=decl.split('\n',1)
    s=s.replace(decl,head+'\n\tif str(ship.get("ship_type_id","")) == "ship_combat_cutter":\n\t\treturn {"ok": false, "message": "Военный транспорт перевозит десант и не назначается на торговые рейсы."}\n'+tail)
p.write_text(s,encoding='utf-8')
