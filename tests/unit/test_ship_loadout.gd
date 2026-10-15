extends "res://tests/test_base.gd"

const Loadout = preload("res://systems/fleet/ship_loadout.gd")
var hiring: Node
var rewards: Node
var service: RefCounted

func before_each() -> void:
	SaveSystem.delete_save();GameState.reset_to_defaults()
	GameState.world_state.seed=42
	GameState.player_state.origin_race_id="humans"
	GameState.player_state.money=200000.0
	GameState.ship_state.docked_port_id="home"
	GameState.fleet_state=[{"instance_id":"test_war","ship_type_id":"war_humans_1","name":"Страж","current_port_id":"home","crew":[],"hull":280.0,"guns":[{},{}],"commander":{}}]
	hiring=preload("res://systems/employees/hiring_system.gd").new();add_child(hiring);hiring.initialize()
	rewards=preload("res://systems/rewards/reward_system.gd").new();add_child(rewards);rewards.set_process(false)
	service=Loadout.new(get_tree())

func after_each() -> void:
	hiring.free();rewards.free();service=null;SaveSystem.delete_save();GameState.reset_to_defaults()

func test_role_filter_only_offers_player_race_and_candidate_identity() -> void:
	for race in ["humans","nerids","surr","meridians","aery","crystari"]:
		GameState.player_state.origin_race_id=race
		for role in ["captain","navigator","mechanic"]:
			var candidates:Array=service.candidates(role)
			assert_gte(candidates.size(),2)
			for candidate in candidates:
				assert_eq(str(candidate.race_id),race)
				assert_eq(str(candidate.role_id),role)

func test_replacing_crew_retains_paid_employee_and_assigns_reserve_without_charge() -> void:
	var candidates:Array=service.candidates("captain")
	assert_true(service.hire_into_slot("test_war","crew_0",str(candidates[0].candidate_id)).ok)
	var first:String=str(GameState.employee_state[0].employee_instance_id)
	assert_eq(str(GameState.fleet_state[0].commander.name),str(GameState.employee_state[0].name))
	assert_true(service.hire_into_slot("test_war","crew_0",str(candidates[1].candidate_id)).ok)
	assert_eq(str(GameState.employee_state[0].assigned_to),"reserve")
	assert_eq(GameState.fleet_state[0].crew.size(),1)
	var money:float=GameState.player_state.money
	assert_true(service.assign_reserve("test_war","crew_0",first).ok)
	assert_eq(GameState.player_state.money,money)
	assert_eq(str(GameState.fleet_state[0].crew[0]),first)
	assert_true(SaveSystem.save_game())
	GameState.reset_to_defaults();assert_true(SaveSystem.load_game())
	assert_eq(str(Loadout.crew_slots("test_war")[0].person.employee_instance_id),first)

func test_wrong_role_or_race_cannot_fill_a_slot() -> void:
	var candidates:Array=service.candidates("navigator")
	var money:float=GameState.player_state.money
	assert_false(service.hire_into_slot("test_war","crew_0",str(candidates[0].candidate_id)).ok)
	assert_eq(GameState.player_state.money,money)
	assert_true(GameState.fleet_state[0].crew.is_empty())

func test_boosts_have_four_slots_independent_timers_and_real_expiry() -> void:
	assert_true(rewards.equip_ship_boost("test_war",0,"fair_wind",true).ok)
	assert_true(rewards.equip_ship_boost("test_war",1,"economy_rune",true).ok)
	assert_true(rewards.equip_ship_boost("test_war",2,"powder_rune",true).ok)
	assert_true(rewards.equip_ship_boost("test_war",3,"reload_rune",true).ok)
	var ship:Dictionary=GameState.fleet_state[0]
	assert_eq(Loadout.boost_slots(ship).size(),4)
	assert_eq(Loadout.boost_bonus(ship,"speed"),5.0)
	var money:float=GameState.player_state.money
	assert_false(rewards.equip_ship_boost("test_war",0,"aim_rune",true).ok)
	assert_eq(GameState.player_state.money,money)
	rewards._process(700)
	assert_eq(Loadout.boost_bonus(ship,"damage"),0.0)
	assert_eq(Loadout.boost_bonus(ship,"speed"),5.0)
	assert_true(SaveSystem.save_game());GameState.reset_to_defaults();assert_true(SaveSystem.load_game())
	assert_eq(float(GameState.fleet_state[0].boost_slots[0].seconds_remaining),1100.0)

func test_fractional_crew_training_and_flaws_change_the_real_ship_speed() -> void:
	GameState.ship_state.crew=["navigator"]
	GameState.employee_state=[{"employee_instance_id":"navigator","stats":{"speed":-3.0},"skill_stats":{"speed":0.1}}]
	var ship:Node=preload("res://scenes/game/ship/ship.tscn").instantiate();add_child(ship)
	var base_speed:float=float(GameData.get_ship(str(GameState.ship_state.ship_id)).get("base_speed",110))
	assert_almost_eq(ship._physics.get_max_speed(),base_speed*0.971,0.001)
	assert_true(rewards.equip_ship_boost("active_ship",0,"fair_wind",true).ok)
	assert_almost_eq(ship._physics.get_max_speed(),base_speed*1.021,0.001)
	ship.free()

func test_expiring_scroll_cannot_discount_an_entire_long_automatic_voyage() -> void:
	var model=preload("res://systems/economy/economy_model.gd").new()
	var ship:Dictionary=GameState.fleet_state[0]
	var definition:Dictionary=GameData.get_ship(str(ship.ship_type_id))
	var plain:Dictionary=model.voyage_quote(ship,definition,[],100000,0)
	ship.boost_slots=[{"id":"economy_rune","seconds_remaining":1.0}]
	var short:Dictionary=model.voyage_quote(ship,definition,[],100000,0)
	ship.boost_slots[0].seconds_remaining=10000.0
	var full:Dictionary=model.voyage_quote(ship,definition,[],100000,0)
	assert_lt(float(full.fuel),float(short.fuel))
	assert_true(float(short.fuel)>float(plain.fuel)*0.99)
	ship.boost_slots[0].seconds_remaining=0.0
	assert_almost_eq(float(model.voyage_quote(ship,definition,[],100000,0).fuel),float(plain.fuel),0.001)
