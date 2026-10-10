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

func test_legacy_training_squadron_is_retired_to_one_player_warship() -> void:
	GameState.fleet_state = [
		{"instance_id":"debug_training_warship","ship_type_id":"war_humans_1","name":"Старый учебный страж","hull":0.0},
		{"instance_id":"debug_training_warship_2","ship_type_id":"war_humans_2","name":"Живой учебный страж","hull":360.0},
		{"instance_id":"debug_training_warship_archived_1","ship_type_id":"war_humans_3","name":"Запасной учебный страж","hull":180.0}
	]
	GameState.combat_state.naval_enemies={"debug_training_patrol":{"id":"debug_training_patrol","hull":2000.0}}
	GameState.combat_state.naval_battle={"active":true,"ship_ids":["debug_training_warship_2"],"enemy_ids":["debug_training_patrol"]}
	navy.initialize(main,military)
	assert_eq(GameState.fleet_state.size(),1,"the retired 3v3 fixture leaves one player warship")
	var retained: Dictionary=GameState.fleet_state[0]
	assert_eq(str(retained.instance_id),"fleet_warship_retained")
	assert_eq(str(retained.name),"Боевой страж")
	assert_eq(str(retained.ship_type_id),"war_humans_2","the strongest surviving fixture is retained")
	assert_true(bool(retained.escort_enabled))
	assert_true(GameState.combat_state.naval_enemies.is_empty())
	assert_false(navy.active(),"the obsolete training battle is closed")

func test_retiring_training_fixture_never_removes_player_built_warships() -> void:
	GameState.fleet_state.append({"instance_id":"debug_training_warship","ship_type_id":"war_humans_2","hull":360.0})
	navy.initialize(main,military)
	assert_eq(GameState.fleet_state.size(),1,"temporary fixtures are removed when a normal warship exists")
	assert_eq(str(GameState.fleet_state[0].instance_id),"war1")

func test_three_ship_battle_supports_independent_map_orders() -> void:
	_sea()
	for index in range(2,4):
		GameState.fleet_state.append({"instance_id":"war%d" % index,"ship_type_id":"war_humans_%d" % index,"name":"Страж %d" % index,"current_port_id":"","escort_enabled":true,"escort_state":{"initialized":true,"position":Vector2(-200,(index-2)*180-90),"heading":Vector2.RIGHT}})
	navy.initialize(main,military)
	GameState.combat_state.naval_enemies={}
	for index in 3:
		var enemy_id: String="enemy%d" % (index+1)
		GameState.combat_state.naval_enemies[enemy_id]={"id":enemy_id,"ship_type_id":"war_surr_%d" % (index+1),"name":"Противник %d" % (index+1),"position":Vector2(260,index*160-160),"heading":Vector2.LEFT,"faction_id":"surr","hull":280.0,"hull_max":280.0,"hostile":false,"cooldown":1000.0,"retreat_until":0.0}
	assert_eq(navy.warships().size(),3)
	assert_true(navy.begin_battle().ok)
	var battle: Dictionary=GameState.combat_state.naval_battle
	assert_eq(battle.ship_ids.size(),3)
	assert_eq(battle.enemy_ids.size(),3,"the wings join their training leader beyond the alert circle")
	var map: Control=preload("res://systems/ui/naval_tactical_map.gd").new()
	add_child(map); map.system=navy; map.size=Vector2(320,560); map.fit_battle()
	for index in 3:
		var ship: Dictionary=navy.ship_by_id(str(battle.ship_ids[index]))
		var target: Dictionary=GameState.combat_state.naval_enemies[battle.enemy_ids[index]]
		var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
		click.position=map.point(navy.position(ship)); map._gui_input(click)
		assert_eq(map.selected,str(ship.instance_id))
		click.position=map.point(navy.vector(target.position)); map._gui_input(click)
		assert_eq(str(ship.naval_order.enemy_id),str(target.id),"every selected ship retains its own target")
		assert_true(Rect2(Vector2.ZERO,map.size).has_point(map.point(navy.vector(target.position))),"all initial targets fit the map")
	var moving_ship: Dictionary=navy.ship_by_id(map.selected)
	var start: Vector2=navy.position(moving_ship)
	var move_click:=InputEventMouseButton.new(); move_click.button_index=MOUSE_BUTTON_LEFT; move_click.pressed=true
	move_click.position=map.point(start+Vector2(-700,0)); map._gui_input(move_click)
	assert_eq(str(moving_ship.naval_order.kind),"move","a sea click moves only the selected vessel")
	for index in 2: assert_eq(str(navy.ship_by_id(str(battle.ship_ids[index])).naval_order.enemy_id),str(battle.enemy_ids[index]))
	for step in 100:
		military._time+=.1
		military._step_ship(moving_ship,2,.1)
	assert_gt(navy.position(moving_ship).distance_to(start),5,"the independently ordered ship actually moves")
	var before_orders: Array=navy.warships().map(func(ship): return ship.naval_order.duplicate(true))
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_RIGHT; press.pressed=true
	map._gui_input(press)
	var before_center: Vector2=map.center
	var motion:=InputEventMouseMotion.new(); motion.relative=Vector2(35,-20); map._gui_input(motion)
	assert_eq(map.center,before_center-motion.relative/map.zoom)
	press.pressed=false; map._input(press)
	assert_false(map._dragging,"release outside stops dragging")
	var wheel:=InputEventMouseButton.new(); wheel.pressed=true; wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.position=Vector2(70,80)
	var anchor: Vector2=map.world(wheel.position)
	var before_zoom: float=map.zoom
	map._gui_input(wheel)
	assert_gt(map.zoom,before_zoom)
	assert_lt(map.world(wheel.position).distance_to(anchor),.01,"zoom keeps the world point under the cursor")
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; map._gui_input(wheel)
	assert_lt(absf(map.zoom-before_zoom),.001)
	assert_eq(navy.warships().map(func(ship): return ship.naval_order),before_orders,"navigation never changes ship orders")
	map.free()
	assert_true(SaveSystem.save_game())
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.combat_state.naval_battle.ship_ids.size(),3)
	assert_eq(GameState.combat_state.naval_battle.enemy_ids.size(),3)
	assert_eq(navy.warships().map(func(ship): return ship.naval_order),before_orders,"individual orders survive reloading the battle")
	navy.surrender()

func test_bow_enemy_turns_toward_target_even_inside_firing_distance() -> void:
	_sea()
	var ship: Dictionary=navy.ship_by_id("war1")
	ship.escort_state.position=Vector2(200,0)
	var enemy: Dictionary=GameState.combat_state.naval_enemies.enemy1
	enemy.position=Vector2.ZERO
	enemy.heading=Vector2.LEFT
	enemy.cooldown=0.0
	assert_true(navy.begin_battle(["enemy1"]).ok)
	for step in 100: navy._step_battle(.1)
	assert_gt(navy.vector(enemy.heading).dot(Vector2.RIGHT),.5,"bow guns face the target instead of waiting forever")
	assert_gt(int(GameState.combat_state.naval_battle.get("enemy_shots",0)),0,"the enemy actually returns fire")

func test_enemy_in_active_battle_remains_visible_with_a_stale_retreat_timer() -> void:
	_sea()
	GameState.combat_state.naval_enemies.enemy1.retreat_until=1000.0
	GameState.combat_state.naval_battle={"active":true,"enemy_ids":["enemy1"],"ship_ids":["war1"]}
	var snapshots: Array[Dictionary]=navy.get_enemy_snapshots()
	assert_eq(snapshots.size(),1,"a battle participant is not hidden by a saved patrol cooldown")

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
	assert_eq(GameState.combat_state.magic_shards,100,"offline surrender does not erase long-term progression")
	assert_eq(GameState.port_state.home.inventory.resource_timber,1000,"the home warehouse is protected from NPC battles")
	assert_eq(GameState.port_state.home.inventory.resource_parts,300)
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

func test_foreign_patrols_spawn_in_groups_of_one_to_three() -> void:
	main._navigation_world.ports["foreign"]={"id":"foreign","position":Vector2(500,0),"faction_id":"humans"}
	_sea(); navy._ensure_patrols()
	var patrols: Array=[]
	for enemy in GameState.combat_state.naval_enemies.values():
		if str(enemy.get("encounter_group",""))=="patrol_foreign": patrols.append(enemy)
	assert_gte(patrols.size(),1)
	assert_lte(patrols.size(),3)
	for enemy in patrols:
		assert_ne(str(enemy.faction_id),"humans","faction patrols belong to another race")
		assert_eq(str(enemy.kind),"faction_patrol")

func test_nearby_member_brings_its_patrol_group_into_battle() -> void:
	_sea()
	GameState.combat_state.naval_enemies={
		"wing_1":{"id":"wing_1","ship_type_id":"war_surr_1","name":"Ведущий","position":Vector2(300,0),"heading":Vector2.LEFT,"faction_id":"surr","kind":"faction_patrol","encounter_group":"wing","hull":280.0,"hull_max":280.0,"retreat_until":0.0},
		"wing_2":{"id":"wing_2","ship_type_id":"war_surr_1","name":"Ведомый","position":Vector2(navy.alert_radius()*1.5,0),"heading":Vector2.LEFT,"faction_id":"surr","kind":"faction_patrol","encounter_group":"wing","hull":280.0,"hull_max":280.0,"retreat_until":0.0}}
	assert_true(navy.begin_battle(["wing_1"]).ok)
	assert_eq(GameState.combat_state.naval_battle.enemy_ids.size(),2)

func test_pirates_spawn_as_rare_black_faction_groups() -> void:
	_sea(); navy._clock=1000.0; GameState.combat_state.next_pirate_at=0.0
	navy._ensure_pirates()
	var pirates: Array=[]
	for enemy in GameState.combat_state.naval_enemies.values():
		if str(enemy.get("kind",""))=="pirate": pirates.append(enemy)
	assert_gte(pirates.size(),1)
	assert_lte(pirates.size(),2)
	for pirate in pirates:
		assert_eq(str(pirate.faction_id),"pirates")
		assert_true(bool(pirate.hostile))
	var snapshots: Array[Dictionary]=navy.get_enemy_snapshots()
	var pirate_snapshot: Dictionary={}
	for snapshot in snapshots:
		if str(snapshot.get("enemy_kind",""))=="pirate": pirate_snapshot=snapshot
	assert_eq(pirate_snapshot.get("color",Color.WHITE),Color("17191f"))

func test_unescorted_pirates_rob_free_cargo_but_not_sealed_contracts() -> void:
	_sea(); GameState.fleet_state[0].escort_enabled=false
	GameState.ship_state.cargo=[{"resource_id":"resource_timber","quantity":10},{"resource_id":"resource_parts","quantity":6,"contract_id":"sealed"}]
	GameState.combat_state.naval_enemies={"pirate":{"id":"pirate","ship_type_id":"war_humans_1","name":"Чёрный корсар","position":Vector2(100,0),"heading":Vector2.LEFT,"faction_id":"pirates","kind":"pirate","hull":280.0,"hull_max":280.0,"hostile":true,"warning":0.0,"retreat_until":0.0}}
	for index in int(navy._rules.hostile_warning_seconds): navy._detect_hostile()
	assert_eq(GameState.player_state.money,190000.0)
	assert_eq(GameState.ship_state.cargo.size(),2)
	assert_eq(int(GameState.ship_state.cargo[0].quantity),9)
	assert_eq(int(GameState.ship_state.cargo[1].quantity),6,"sealed contract cargo is protected")
	assert_true(str(GameState.combat_state.naval_report.outcome).contains("ограбили"))

func test_defeat_by_pirates_loots_cargo_after_the_ship_sinks() -> void:
	_sea(); GameState.ship_state.cargo=[{"resource_id":"resource_timber","quantity":10}]
	GameState.combat_state.naval_enemies.enemy1.kind="pirate"
	GameState.combat_state.naval_enemies.enemy1.faction_id="pirates"
	assert_true(navy.begin_battle(["enemy1"]).ok)
	GameState.fleet_state[0].hull=0.0
	for second in 9:
		if navy.active(): navy._step_battle(1.0)
	assert_false(navy.active())
	assert_true(str(GameState.combat_state.naval_report.outcome).contains("пиратов"))
	assert_eq(int(GameState.ship_state.cargo[0].quantity),9)

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

func test_weapon_classes_follow_ship_project_and_level_progression() -> void:
	var ship: Dictionary=GameState.fleet_state[0]
	assert_eq(navy.ship_gun_class_cap(ship),1)
	ship.level=10
	assert_eq(navy.ship_gun_class_cap(ship),2)
	ship.level=20
	assert_eq(navy.ship_gun_class_cap(ship),3)
	assert_true(navy.gun_install_status(ship,0,"long_cannon").ok,"an upgraded cutter can carry class-two bow artillery")
	assert_false(navy.gun_install_status(ship,0,"heavy_cannon").ok,"a broadside-only battery cannot be mounted on the bow")
	var battleship: Dictionary={"ship_type_id":"war_humans_5","level":25,"guns":[]}
	navy.normalize_ship(battleship)
	assert_eq(navy.ship_gun_class_cap(battleship),5)
	assert_eq(navy.gun_slot_layout(battleship),["port","port","port","starboard","starboard","starboard","bow","stern"])
	assert_true(navy.gun_install_status(battleship,6,"leviathan_rune").ok)
	assert_false(navy.gun_install_status(battleship,7,"leviathan_rune").ok,"the Leviathan rune has no stern firing mount")

func test_weapon_store_capacity_expansion_and_half_price_sale() -> void:
	assert_eq(navy.arsenal_capacity(),10)
	var initial_money: float=GameState.player_state.money
	assert_true(navy.buy_gun("war1","cannon").ok)
	assert_eq(GameState.combat_state.naval_arsenal.size(),1)
	assert_eq(GameState.player_state.money,initial_money-180)
	for index in 9: GameState.combat_state.naval_arsenal.append({"kind":"cannon","level":1,"experience":0})
	assert_false(navy.buy_gun("war1","rune").ok,"the initial ten-place store is a real limit")
	var expansion_cost: int=navy.arsenal_expansion_cost()
	assert_true(navy.expand_arsenal("war1").ok)
	assert_eq(navy.arsenal_capacity(),15)
	assert_eq(GameState.player_state.money,initial_money-180-expansion_cost)
	assert_true(navy.buy_gun("war1","rune").ok)
	var before_sale: float=GameState.player_state.money
	assert_true(navy.sell_arsenal_gun("war1",0).ok)
	assert_eq(GameState.player_state.money,before_sale+90,"a used gun sells for half of its base price")

func test_full_weapon_store_blocks_removal_without_losing_the_installed_gun() -> void:
	assert_true(navy.install_gun("war1",0,"cannon").ok)
	GameState.combat_state.naval_arsenal=[]
	for index in navy.arsenal_capacity(): GameState.combat_state.naval_arsenal.append({"kind":"cannon","level":1,"experience":0})
	assert_false(navy.remove_gun("war1",0).ok)
	assert_false(GameState.fleet_state[0].guns[0].is_empty())

func test_armament_window_shows_ship_hardpoints_preview_shop_and_store() -> void:
	var window: Control=preload("res://systems/ui/naval_armament_window.gd").new()
	add_child(window)
	window.initialize(navy)
	window.open_ship("war1")
	assert_true(window.visible)
	assert_true(window.find_children("*","SubViewportContainer",true,false).any(func(node): return node.has_meta("armament_ship_preview")))
	var slot_buttons: Array=window.find_children("*","Button",true,false).filter(func(node): return node.has_meta("armament_slot"))
	assert_eq(slot_buttons.size(),2)
	assert_eq(window._shop_list.get_child_count(),17,"capacity note plus sixteen weapon choices")
	assert_true(str(window._title.text).contains("Страж"))
	window.free()

func test_armament_filters_and_button_purchase_install_upgrade_flow() -> void:
	var window: Control=preload("res://systems/ui/naval_armament_window.gd").new()
	add_child(window)
	window.initialize(navy)
	window.open_ship("war1")
	window._compatible_filter.button_pressed=true
	var choices: Array=window._shop_list.find_children("*","Button",true,false).filter(func(button): return button.has_meta("armament_buy"))
	assert_eq(choices.size(),2,"a new bow cutter offers only its two compatible starter guns")
	var buy: Button=choices.filter(func(button): return str(button.get_meta("armament_buy"))=="cannon")[0]
	assert_true(buy.get_theme_stylebox("normal") is StyleBoxTexture,"purchases use the approved brass art")
	var money: float=GameState.player_state.money
	buy.pressed.emit()
	assert_eq(GameState.player_state.money,money-180)
	assert_eq(GameState.combat_state.naval_arsenal.size(),1)
	var install: Button=window._storage_list.find_children("*","Button",true,false).filter(func(button): return button.has_meta("armament_install"))[0]
	assert_false(install.disabled)
	install.pressed.emit()
	assert_eq(str(GameState.fleet_state[0].guns[0].kind),"cannon")
	assert_true(GameState.combat_state.naval_arsenal.is_empty())
	assert_true(window._selected_actions.get_child(0).disabled,"a gun cannot be upgraded without a skilled commander")
	assert_true(window._selected_progress.visible)
	assert_true(navy.hire_commander("war1").ok)
	assert_true(navy.train_skill("war1","gunnery").ok)
	GameState.fleet_state[0].guns[0].experience=50
	window._refresh()
	assert_false(window._selected_actions.get_child(0).disabled)
	window._selected_actions.get_child(0).pressed.emit()
	assert_eq(int(GameState.fleet_state[0].guns[0].level),2)
	assert_true(str(window._selected_details.text).contains("ур. 2"))
	window._selected_actions.get_child(1).pressed.emit()
	assert_eq(int(GameState.combat_state.naval_arsenal[0].level),2,"removal preserves the purchased upgrade")
	assert_false(window._selected_progress.visible)
	window._class_filter.select(5)
	window._class_filter.item_selected.emit(5)
	assert_eq(window._shop_list.find_children("*","Button",true,false).size(),0,"class-five filtering never presents incompatible guns as installable")
	window._close()
	assert_eq(window._preview_viewport.render_target_update_mode,SubViewport.UPDATE_DISABLED,"closing the window stops rendering the preview")
	window.free()

func test_upgraded_weapon_display_stats_match_the_fired_projectile() -> void:
	assert_true(navy.install_gun("war1",0,"cannon").ok)
	var ship: Dictionary=GameState.fleet_state[0]
	ship.guns[0].level=2
	ship.commander={"level":4,"skills":{"gunnery":2,"accuracy":1,"reload":3}}
	ship.escort_state={"position":Vector2.ZERO,"heading":Vector2.RIGHT,"initialized":true}
	var stats: Dictionary=navy.gun_combat_stats(ship,ship.guns[0])
	assert_gt(float(stats.damage),18.0)
	assert_lt(float(stats.reload),12.0)
	_sea()
	assert_true(navy.begin_battle(["enemy1"]).ok)
	assert_true(navy.issue_order("war1",Vector2(350,0),"enemy1").ok)
	var battle: Dictionary=GameState.combat_state.naval_battle
	var enemies: Array[Dictionary]=[GameState.combat_state.naval_enemies.enemy1]
	navy._fire_ship(ship,enemies,.1,battle)
	assert_eq(battle.projectiles.size(),1)
	var armor: float=float(GameData.get_ship("war_surr_1").get("armor",0))
	assert_eq(float(battle.projectiles[0].damage),maxf(1,float(stats.damage)-armor),"the equipment screen and impact use the same commander and gun bonuses")
	assert_eq(float(ship.naval_reload),float(stats.reload))

func test_actual_damage_victory_and_xp() -> void:
	assert_true(navy.hire_commander("war1").ok)
	assert_true(navy.install_gun("war1",0,"cannon").ok)
	GameState.fleet_state[0].escort_state.position=Vector2(0,0)
	GameState.combat_state.naval_enemies.enemy1.position=Vector2(250,0)
	GameState.combat_state.naval_enemies.enemy1.hull=25
	_sea(); assert_true(navy.begin_battle().ok)
	assert_eq(int(GameState.combat_state.naval_battle.shots),0,"the fleet waits for the player's attack order")
	assert_true(navy.issue_order("war1",Vector2(250,0),"enemy1").ok)
	for index in 200:
		if navy.active(): navy._step_battle(.2)
	assert_false(navy.active()); assert_eq(GameState.combat_state.naval_report.outcome,"Победа")
	assert_gt(int(GameState.fleet_state[0].experience),80)
	assert_gt(int(GameState.fleet_state[0].guns[0].experience),0)

func test_destroyed_ship_sinks_before_battle_result() -> void:
	_sea()
	assert_true(navy.begin_battle().ok)
	var enemy: Dictionary=GameState.combat_state.naval_enemies.enemy1
	enemy.hull=1.0
	var battle: Dictionary=GameState.combat_state.naval_battle
	battle.projectiles=[{"remaining":0.0,"hit":true,"damage":10.0,"target_kind":"enemy","target_id":"enemy1"}]
	navy._step_battle(.1)
	assert_true(navy.active(),"victory waits while the destroyed hull remains visible")
	assert_true(bool(enemy.sinking))
	assert_gt(float(enemy.sink_elapsed),0.0)
	var snapshot: Dictionary=navy.get_enemy_snapshots()[0]
	assert_eq(float(snapshot.hull),0.0)
	assert_gt(float(snapshot.sink_progress),0.0)
	for step in 7: navy._step_battle(1.0)
	assert_true(navy.active(),"slow sinking remains visible for most of its duration")
	navy._step_battle(1.0)
	assert_false(navy.active())
	assert_eq(str(GameState.combat_state.naval_report.outcome),"Победа")

func test_damage_thresholds_are_data_driven() -> void:
	assert_eq(float(navy._rules.fire_damage_fraction),.5)
	assert_eq(float(navy._rules.critical_damage_fraction),.7)
	assert_eq(float(navy._rules.sinking_duration_seconds),8.0)

func test_repair_clears_old_sinking_state() -> void:
	var ship: Dictionary=navy.ship_by_id("war1")
	ship.hull=0.0; ship.sinking=true; ship.sink_elapsed=8.0
	assert_true(navy.repair_ship("war1").ok)
	assert_gt(float(ship.hull),0.0)
	assert_false(ship.has("sinking"))
	assert_false(ship.has("sink_elapsed"))

func test_z_starts_battle_without_a_confirmation_dialog() -> void:
	_sea()
	var hud = load("res://systems/ui/naval_battle_hud.gd").new()
	add_child(hud)
	hud.initialize(navy)
	var key := InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_Z
	hud._unhandled_key_input(key)
	assert_true(navy.active())
	assert_false(bool(GameState.combat_state.naval_battle.get("enemy_initiated",false)))
	hud.free()

func test_hostile_patrol_starts_battle_and_marks_its_initiative() -> void:
	_sea()
	GameState.combat_state.naval_enemies.enemy1.hostile=true
	var warning_seconds: int = int(navy._rules.hostile_warning_seconds)
	for _index in warning_seconds:
		navy._detect_hostile()
	assert_true(navy.active())
	assert_true(bool(GameState.combat_state.naval_battle.get("enemy_initiated",false)))
	var hud = load("res://systems/ui/naval_battle_hud.gd").new()
	add_child(hud)
	hud.initialize(navy)
	hud._process(0.1)
	assert_true(hud._attack_notice.visible)
	assert_eq(hud._attack_notice.text,"ВЫ АТАКОВАНЫ")
	hud.free()

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

func test_cannon_damage_waits_for_arrival_and_reload() -> void:
	assert_true(navy.install_gun("war1",0,"cannon").ok)
	GameState.fleet_state[0].escort_state.position=Vector2.ZERO
	GameState.fleet_state[0].escort_state.heading=Vector2.RIGHT
	GameState.combat_state.naval_enemies.enemy1.position=Vector2(250,0)
	_sea(); assert_true(navy.begin_battle().ok)
	assert_true(navy.issue_order("war1",Vector2(250,0),"enemy1").ok)
	var hull: float = GameState.combat_state.naval_enemies.enemy1.hull
	navy._step_battle(.05)
	assert_eq(GameState.combat_state.naval_enemies.enemy1.hull,hull,"firing cannot deal instant damage")
	assert_eq(GameState.combat_state.naval_battle.projectiles.size(),1)
	assert_gte(float(GameState.fleet_state[0].guns[0].cooldown),7.0,"artillery needs a visible reload")
	var projectile: Dictionary = GameState.combat_state.naval_battle.projectiles[0]
	projectile.hit=true # Exercise impact resolution independently of deterministic accuracy.
	navy._step_battle(1.0)
	assert_lt(GameState.combat_state.naval_enemies.enemy1.hull,hull)
	assert_eq(int(GameState.combat_state.naval_battle.shots),1,"gun cannot fire again during reload")

func test_broadside_guns_fire_as_a_synchronized_salvo() -> void:
	GameState.combat_state.naval_enemies.enemy1.position=Vector2(300,0)
	assert_true(navy.install_gun("war1",0,"cannon").ok)
	assert_true(navy.install_gun("war1",1,"rune").ok)
	GameState.fleet_state[0].escort_state.heading=Vector2.RIGHT
	_sea()
	assert_true(navy.begin_battle().ok)
	assert_true(navy.issue_order("war1",Vector2(300,0),"enemy1").ok)
	navy._step_battle(.05)
	assert_eq(int(GameState.combat_state.naval_battle.shots),2,"the ship fires both ready broadside guns together")
	assert_almost_eq(float(GameState.fleet_state[0].naval_reload),15.0,.001,"the whole battery waits for its slowest gun to reload")
	for step in 10: navy._step_battle(1.0)
	assert_eq(int(GameState.combat_state.naval_battle.shots),2,"guns do not alternate like a machine gun")
	for step in 5: navy._step_battle(1.0)
	assert_eq(int(GameState.combat_state.naval_battle.shots),4,"the full battery fires its next salvo after reloading")

func test_broadside_ship_turns_beam_on_and_fires_from_standoff() -> void:
	_sea()
	GameState.combat_state.naval_enemies.enemy1.position=Vector2(0,100)
	var broadside_ship: Dictionary={"instance_id":"broadside","ship_type_id":"war_humans_2","name":"Корвет","current_port_id":"","escort_enabled":true,"escort_state":{"initialized":true,"position":Vector2(-200,100),"heading":Vector2.RIGHT}}
	GameState.fleet_state.append(broadside_ship)
	navy.normalize_ship(broadside_ship)
	broadside_ship.guns[0]={"kind":"cannon","level":1,"experience":0,"cooldown":0.0}
	assert_eq(str(GameData.get_ship("war_humans_2").gun_mounting),"broadside")
	assert_true(navy.begin_battle().ok)
	assert_true(navy.issue_order("broadside",Vector2(0,100),"enemy1").ok)
	for step in 40:
		navy._step_battle(.1)
		military._step_ship(broadside_ship,1,.1)
	var heading: Vector2=broadside_ship.escort_state.heading.normalized()
	assert_lt(absf(heading.dot(Vector2.RIGHT)),.58,"the corvette turns its broadside toward the target")
	assert_almost_eq(broadside_ship.escort_state.position.distance_to(Vector2(0,100)),200.0,1.0,"the broadside holds its standoff range")
	assert_gt(int(GameState.combat_state.naval_battle.shots),0,"broadside guns fire after the hull aligns")

func test_misses_land_outside_hull_and_do_no_damage() -> void:
	_sea(); assert_true(navy.begin_battle().ok)
	var battle: Dictionary = GameState.combat_state.naval_battle
	var enemy: Dictionary = GameState.combat_state.naval_enemies.enemy1
	var impact: Vector2 = navy._queue_projectile(battle,Vector2.ZERO,Vector2(350,0),false,"cannon","enemy","enemy1",100,1,130)
	assert_gt(impact.distance_to(Vector2(350,0)),65.0)
	navy._resolve_projectiles(battle,4.0)
	assert_eq(enemy.hull,280.0)

func test_pending_projectiles_survive_saving() -> void:
	_sea(); assert_true(navy.begin_battle().ok)
	navy._queue_projectile(GameState.combat_state.naval_battle,Vector2.ZERO,Vector2(350,0),true,"cannon","enemy","enemy1",100,1,130)
	assert_true(SaveSystem.save_game()); assert_true(SaveSystem.load_game())
	assert_eq(GameState.combat_state.naval_battle.projectiles.size(),1)
	navy._resolve_projectiles(GameState.combat_state.naval_battle,4.0)
	assert_eq(GameState.combat_state.naval_enemies.enemy1.hull,180.0)
