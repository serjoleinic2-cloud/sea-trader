extends "res://tests/test_base.gd"

var navy: Node
var military: Node
var main: Node
class NavigationWorld extends Node:
	var _navigation_world: Dictionary = {"islands":[],"ports":{"home":{"id":"home","position":Vector2.ZERO}}}
	var _active_route_autopilot: Node

func before_each() -> void:
	SaveSystem.delete_save(); GameState.reset_to_defaults()
	GameState.player_state.origin_race_id="humans"; GameState.player_state.money=200000.0
	GameState.world_state.seed=42; GameState.world_state.home_port_id="home"
	GameState.ship_state.position=Vector2.ZERO; GameState.ship_state.docked_port_id="home"
	GameState.port_state={"home":{"inventory":{"resource_timber":1000,"resource_parts":300}}}
	GameState.fleet_state=[{"instance_id":"war1","ship_type_id":"war_humans_1","name":"Страж","current_port_id":"home","escort_enabled":true,"escort_state":{"initialized":true,"position":Vector2(-200,200),"heading":Vector2.RIGHT}}]
	main=NavigationWorld.new(); add_child(main)
	military=preload("res://systems/fleet/military_transport_system.gd").new(); add_child(military); military.initialize(main); military.set_process(false)
	navy=preload("res://systems/combat/naval_combat_system.gd").new(); add_child(navy); navy.initialize(main,military); navy.set_process(false)
	GameState.combat_state.naval_enemies={"enemy1":{"id":"enemy1","ship_type_id":"war_surr_1","name":"Противник","position":Vector2(350,0),"heading":Vector2.UP,"faction_id":"surr","hull":280.0,"hull_max":280.0,"hostile":false,"cooldown":1000.0,"retreat_until":0.0}}

func after_each() -> void:
	navy.free(); military.free(); main.free(); SaveSystem.delete_save(); GameState.reset_to_defaults()

func _sea() -> void:
	GameState.ship_state.docked_port_id=""

func test_catalog_models_slots_and_races() -> void:
	var catalog: Array = GameData.read("res://data/ships/naval_ship_catalog.json").ships
	assert_eq(catalog.size(),30)
	var races: Dictionary = {}
	for definition in catalog:
		races[definition.faction_id]=int(races.get(definition.faction_id,0))+1
		assert_eq(int(definition.gun_slots),[2,3,4,6,8][int(definition.tier)-1])
		var root:=Node3D.new(); add_child(root)
		var model: Node3D = preload("res://systems/rendering/naval_ship_factory.gd").new().attach(root,str(definition.id),5.1,false)
		assert_true(model!=null,"clean checkout generates each naval project without external assets")
		assert_eq(str(model.get_meta("procedural_ship_id")),str(definition.id))
		assert_gt(model.get_child(0).get_child_count(),5,"warships contain actual meshes")
		root.free()
	for count in races.values(): assert_eq(count,5)

func test_detection_protection_and_hull_radius() -> void:
	assert_eq(navy.nearby_enemies().size(),0,"docked player is protected")
	_sea(); assert_eq(navy.nearby_enemies().size(),1)
	GameState.combat_state.naval_enemies.enemy1.position=Vector2(navy.alert_radius()+1,0)
	assert_eq(navy.nearby_enemies().size(),0)
	GameState.combat_state.naval_enemies.enemy1.position=Vector2(navy.alert_radius(),0)
	assert_eq(navy.nearby_enemies().size(),1)
	GameState.fleet_state[0].escort_enabled=false
	assert_false(navy.ready_for_battle()); assert_false(navy.begin_battle().ok)

func test_battle_detaches_restores_and_saves_vectors() -> void:
	_sea(); assert_true(navy.begin_battle().ok)
	assert_false(GameState.fleet_state[0].escort_enabled)
	assert_true(navy.issue_order("war1",Vector2(1234,567)).ok)
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.fleet_state[0].escort_state.position,Vector2(-200,200))
	assert_eq(GameState.fleet_state[0].naval_order.point,Vector2(1234,567))
	assert_true(navy.active()); assert_true(navy.propose_truce().ok)
	var money: float = GameState.player_state.money
	assert_true(navy.respond_truce(true).ok)
	assert_eq(GameState.player_state.money,money)
	assert_true(GameState.fleet_state[0].escort_enabled)
	assert_false(navy.active()); assert_eq(navy.nearby_enemies().size(),0,"retreated enemy cannot reenter")

func test_truce_needs_consent_and_surrender_is_once() -> void:
	GameState.combat_state.magic_shards=100
	GameState.economy_state.merchant={"sell_orders":[{"resource_id":"resource_timber","quantity_available":900,"status":"active"}]}
	_sea(); assert_true(navy.begin_battle().ok)
	assert_true(navy.propose_truce().ok); assert_true(navy.active())
	assert_true(navy.respond_truce(false).ok); assert_true(navy.active())
	assert_true(navy.surrender().ok)
	assert_eq(GameState.player_state.money,180000.0)
	assert_eq(GameState.combat_state.magic_shards,90)
	assert_eq(GameState.port_state.home.inventory.resource_timber,990,"only free warehouse resources are deducted")
	assert_eq(GameState.port_state.home.inventory.resource_parts,270)
	assert_false(navy.surrender().ok); assert_eq(GameState.player_state.money,180000.0)

func test_hostile_can_attack_only_ready_escort() -> void:
	_sea(); GameState.combat_state.naval_enemies.enemy1.hostile=true
	for index in 12: navy._detect_hostile()
	assert_true(navy.active())
	navy.propose_truce(); navy.respond_truce(true)
	GameState.combat_state.naval_enemies.enemy1.retreat_until=0
	GameState.fleet_state[0].escort_enabled=false
	for index in 20: navy._detect_hostile()
	assert_false(navy.active())

func test_ship_gun_commander_progression_and_arsenal() -> void:
	assert_true(navy.hire_commander("war1").ok)
	assert_false(navy.hire_commander("war1").ok)
	assert_true(navy.install_gun("war1",0,"cannon").ok)
	GameState.fleet_state[0].guns[0].experience=150
	assert_false(navy.upgrade_gun("war1",0).ok,"commander limits progression")
	assert_true(navy.train_skill("war1","gunnery").ok)
	assert_true(navy.upgrade_gun("war1",0).ok)
	assert_eq(GameState.fleet_state[0].guns[0].level,2)
	assert_true(navy.remove_gun("war1",0).ok)
	assert_eq(GameState.combat_state.naval_arsenal[0].experience,100)
	assert_true(navy.install_gun("war1",1,"",0).ok)
	assert_eq(GameState.fleet_state[0].guns[1].level,2)
	GameState.fleet_state[0].experience=100
	assert_true(navy.upgrade_ship("war1").ok)
	assert_eq(GameState.fleet_state[0].level,2)

func test_actual_damage_victory_and_xp() -> void:
	assert_true(navy.hire_commander("war1").ok)
	assert_true(navy.install_gun("war1",0,"cannon").ok)
	GameState.fleet_state[0].escort_state.position=Vector2(0,0)
	GameState.combat_state.naval_enemies.enemy1.position=Vector2(250,0)
	GameState.combat_state.naval_enemies.enemy1.hull=25
	_sea(); assert_true(navy.begin_battle().ok)
	for index in 200:
		if navy.active(): navy._step_battle(.2)
	assert_false(navy.active()); assert_eq(GameState.combat_state.naval_report.outcome,"Победа")
	assert_gt(int(GameState.fleet_state[0].experience),80)
	assert_gt(int(GameState.fleet_state[0].guns[0].experience),0)

func test_rally_reaches_parked_ship_and_restores_its_state() -> void:
	var parked: Dictionary = GameState.fleet_state[0].duplicate(true)
	parked.instance_id="parked"; parked.escort_enabled=false; parked.escort_state.position=Vector2(1500,1500)
	GameState.fleet_state.append(parked)
	_sea(); assert_true(navy.begin_battle().ok); assert_true(navy.rally().ok)
	assert_true(GameState.combat_state.naval_battle.ship_ids.has("parked"))
	assert_eq(GameState.fleet_state[1].escort_state.position,Vector2(1500,1500),"rally does not teleport")
	military._step_ship(GameState.fleet_state[1],1,.1)
	assert_ne(GameState.fleet_state[1].escort_state.position,Vector2(1500,1500))
	navy.propose_truce(); navy.respond_truce(true)
	assert_false(GameState.fleet_state[1].escort_enabled)

func test_changed_order_clears_path_and_damage_blocks_movement() -> void:
	_sea(); navy.begin_battle()
	military._paths["war1"]={"target":Vector2(-1000,-1000),"path":PackedVector2Array([Vector2(-1000,-1000)]),"time":0}
	navy.issue_order("war1",Vector2(1000,1000))
	assert_false(military._paths.has("war1"))
	GameState.fleet_state[0].hull=0
	var old: Vector2 = GameState.fleet_state[0].escort_state.position
	military._step_ship(GameState.fleet_state[0],0,.1)
	assert_eq(GameState.fleet_state[0].escort_state.position,old)
	assert_false(navy.issue_order("war1",Vector2.ZERO).ok)

func test_surrender_never_credits_negative_treasury() -> void:
	GameState.player_state.money=-100.0
	_sea(); navy.begin_battle(); navy.surrender()
	assert_eq(GameState.player_state.money,-100.0)
	assert_eq(GameState.combat_state.naval_report.losses.money,0.0)
