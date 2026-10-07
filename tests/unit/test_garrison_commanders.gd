extends "res://tests/test_base.gd"
var combat: Node
var window: Node
func before_each() -> void:
	SaveSystem.delete_save(); GameState.reset_to_defaults()
	GameState.player_state.origin_race_id="nerids"; GameState.player_state.money=50000.0
	GameState.world_state.seed=42; GameState.world_state.home_port_id="home"; GameState.ship_state.docked_port_id="home"
	GameState.port_state={"home":{"inventory":{}}}
	GameState.combat_state.units={"coast_guard":{"count":10,"level":1,"experience":0}}
	combat=preload("res://systems/combat/combat_system.gd").new(); add_child(combat); combat.initialize(); combat.set_process(false)
	window=preload("res://systems/ui/garrison_window.gd").new(); add_child(window); window.initialize(combat)
func after_each() -> void:
	window.free(); combat.free(); SaveSystem.delete_save(); GameState.reset_to_defaults()
func test_two_live_command_slots_changes_visible_army_and_save() -> void:
	window.open()
	var screen: Control = window._art_screen
	assert_eq(screen._slots.size(),2)
	assert_eq(screen._factions.size(),6)
	var base: float = combat.get_unit_command_effect("coast_guard").attack
	var power: int = combat.get_attack_power()
	assert_true(combat.hire_commander(window._commander_profile("nerids",0),0).ok)
	assert_true(combat.hire_commander(window._commander_profile("nerids",1),1).ok)
	assert_eq(combat.get_commander_bonuses().attack,9.0)
	assert_gt(combat.get_attack_power(),power)
	assert_gt(combat.get_unit_command_effect("coast_guard").attack,base)
	assert_eq(GameState.combat_state.units.coast_guard.count,10)
	screen.refresh(combat)
	assert_true(screen._groups[0].attack.text.contains("+9%"))
	assert_true(screen._slots[1].status.text.contains("Назначен"))
	assert_gt(float(screen._groups[0].attack_bar.value),30.0)
	assert_true(SaveSystem.load_game()); assert_false(combat.get_commander(1).is_empty())
	assert_false(combat.hire_commander(window._commander_profile("nerids",0),1).ok)
	assert_true(combat.dismiss_commander(1).ok); assert_eq(combat.get_commander_bonuses().attack,6.0)
func test_programmatic_layout_and_canonical_portraits_emblems() -> void:
	window.open()
	var screen: Control = window._art_screen
	assert_eq(screen.find_children("GarrisonArtScreen", "TextureRect",true,false).size(),0)
	for race in screen._factions:
		assert_eq(screen._factions[race].emblem.texture,GameData.get_faction_emblem(str(race)))
		assert_eq(screen._factions[race].portrait.texture.resource_path,"res://assets/characters/crew/%s_officer.webp" % str(race))
	window._select_faction("surr")
	assert_true(screen._hire.disabled,"other race is a preview, not a race change")

func test_legacy_commander_remains_visible_and_can_be_dismissed() -> void:
	GameState.combat_state.commander={"name":"Сирена Вальтэра","race_id":"nerids","attack_bonus":6.0,"defense_bonus":4.0,"expenses_bonus":2.0}
	combat._normalize_state(); window.open()
	assert_eq(combat.get_commander().id,"nerids_marshal")
	assert_eq(window._art_screen._hire.text,"СНЯТЬ С ДОЛЖНОСТИ")
	assert_false(window._art_screen._hire.disabled)
	window._art_screen._hire.pressed.emit()
	assert_true(combat.get_commander().is_empty())

func test_command_bonus_applies_to_embarked_army_without_adding_home_units() -> void:
	var troops: Dictionary = {"coast_guard":{"count":4,"level":1,"experience":0}}
	var base: int = combat.get_attack_power(troops)
	combat.hire_commander(window._commander_profile("nerids",0),0)
	assert_gt(combat.get_attack_power(troops),base)
	assert_lt(combat.get_attack_power(troops),combat.get_attack_power())
