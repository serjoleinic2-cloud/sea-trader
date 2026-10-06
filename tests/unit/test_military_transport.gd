extends "res://tests/test_base.gd"

var system: Node
var main: Node
class NavigationWorld extends Node:
	var _navigation_world: Dictionary = {"islands":[],"ports":{}}
class NoRoutePlanner extends RefCounted:
	func plan(_start: Vector2, _destination: Vector2, _islands: Array, _can_move: Callable, _clearance: float = 48.0) -> PackedVector2Array:
		return PackedVector2Array()

func before_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	GameState.world_state.seed = 42
	GameState.world_state.home_port_id = "home"
	GameState.ship_state.docked_port_id = "home"
	GameState.ship_state.position = Vector2.ZERO
	GameState.ship_state.heading = 0.0
	GameState.combat_state.units = {"coast_guard":{"count":80,"level":2,"experience":40},"crystal_mortar":{"count":8,"level":1,"experience":0}}
	GameState.fleet_state = [{"instance_id":"transport1","ship_type_id":"ship_combat_cutter","current_port_id":"home","embarked_units":{},"escort_enabled":true,"escort_state":{},"autopilot":{},"cargo":[]}]
	main = NavigationWorld.new()
	add_child(main)
	system = preload("res://systems/fleet/military_transport_system.gd").new()
	add_child(system)
	system.initialize(main)
	system.set_process(false)

func after_each() -> void:
	system.free()
	main.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_loading_capacity_roundtrip_and_save() -> void:
	assert_true(system.transfer_units("transport1","coast_guard",60).ok)
	assert_false(system.transfer_units("transport1","coast_guard",1).ok)
	assert_true(system.transfer_units("transport1","crystal_mortar",6).ok)
	assert_false(system.transfer_units("transport1","crystal_mortar",1).ok)
	assert_eq(GameState.combat_state.units.coast_guard.count,20)
	assert_true(system.transfer_units("transport1","coast_guard",10,false).ok)
	assert_eq(GameState.combat_state.units.coast_guard.count,30)
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.fleet_state[0].embarked_units.coast_guard.count,50)
	assert_eq(GameState.fleet_state[0].embarked_units.coast_guard.level,2)
	GameState.ship_state.docked_port_id = "foreign"
	assert_false(system.transfer_units("transport1","coast_guard",1).ok)
	assert_false(system.transfer_units("transport1","coast_guard",1,false).ok)

func test_escorts_form_behind_left_and_keep_separation() -> void:
	GameState.ship_state.docked_port_id = ""
	var second: Dictionary = GameState.fleet_state[0].duplicate(true)
	second.instance_id = "transport2"
	GameState.fleet_state.append(second)
	for step in 140:
		system._time += .1
		for index in 2: system._step_ship(GameState.fleet_state[index],index,.1)
	var a: Vector2 = GameState.fleet_state[0].escort_state.position
	var b: Vector2 = GameState.fleet_state[1].escort_state.position
	var leader := Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var forward := Vector2.from_angle(float(GameState.ship_state.get("heading", -PI * .5)))
	var relative := a - leader
	assert_lt(relative.dot(forward), -90.0,"keeps aft separation from leader")
	assert_gt(absf(relative.dot(Vector2(-forward.y, forward.x))), 60.0,"keeps lateral formation offset")
	assert_gte(a.distance_to(b),system._length(GameState.fleet_state[0])*2.0,"escort ships maintain a two-hull center gap")
	assert_gt(a.length(),170.0,"does not obstruct player hull")

func test_escort_tracks_player_after_leaving_port() -> void:
	GameState.ship_state.docked_port_id = ""
	var ship: Dictionary = GameState.fleet_state[0]
	for step in 80:
		system._time += .1
		system._step_ship(ship, 0, .1)
	var before: Vector2 = ship.escort_state.position
	GameState.ship_state.position = Vector2(500, 0)
	for step in 120:
		system._time += .1
		system._step_ship(ship, 0, .1)
	var after: Vector2 = ship.escort_state.position
	assert_gt(after.distance_to(before), 100.0, "an enabled war transport sails after the leader moves")
	assert_lt(after.distance_to(GameState.ship_state.position), 900.0, "escort catches back up instead of remaining at the base")

func test_escort_choice_in_shared_foreign_port_is_saved_and_parked_ship_stays_put() -> void:
	GameState.ship_state.docked_port_id = "foreign"
	var ship: Dictionary = GameState.fleet_state[0]
	ship.current_port_id = "foreign"
	ship.escort_state = {"initialized":true,"position":Vector2(-400,-200),"heading":Vector2.RIGHT}
	assert_true(system.set_escort("transport1",false).ok)
	var parked: Vector2 = ship.escort_state.position
	GameState.ship_state.docked_port_id = ""
	GameState.ship_state.position = Vector2(500,0)
	for frame in 20: system._process(1.0/60.0)
	assert_eq(ship.escort_state.position, parked, "leaving a ship in port does not make it follow")
	assert_false(system.set_escort("transport1",true).ok, "composition cannot change at sea")
	GameState.ship_state.docked_port_id = "foreign"
	GameState.ship_state.position = Vector2.ZERO
	assert_true(system.set_escort("transport1",true).ok)
	assert_true(SaveSystem.load_game())
	assert_true(GameState.fleet_state[0].escort_enabled)
	assert_eq(GameState.fleet_state[0].current_port_id, "foreign")

func test_escort_moves_each_small_frame_without_tenth_second_jumps() -> void:
	GameState.ship_state.docked_port_id = ""
	var ship: Dictionary = GameState.fleet_state[0]
	ship.escort_state = {"initialized":true,"position":Vector2(-900,-200),"heading":Vector2.RIGHT,"blocked_seconds":0.0}
	var previous: Vector2 = ship.escort_state.position
	for frame in 6:
		system._process(1.0/60.0)
		var current: Vector2 = ship.escort_state.position
		assert_gt(current.distance_to(previous), 0.0, "movement is visible even before 0.1 seconds elapse")
		assert_lt(current.distance_to(previous), 10.0, "one frame never accumulates a tenth-second position jump")
		previous = current

func test_cannot_take_escort_from_another_port_or_before_it_arrives() -> void:
	var ship: Dictionary = GameState.fleet_state[0]
	ship.escort_enabled = false
	ship.current_port_id = "foreign"
	assert_false(system.set_escort("transport1",true).ok)
	ship.current_port_id = "home"
	ship.escort_state = {"initialized":true,"position":Vector2(5000,0),"heading":Vector2.RIGHT}
	assert_false(system.set_escort("transport1",true).ok)

func test_stuck_escorts_recover_on_the_saved_world_route() -> void:
	var generator = preload("res://systems/world/world_generator.gd").new()
	var world: Dictionary = generator.generate(5247185189, 2)
	# Recreate the player's streamed, already-explored sea. The base map alone
	# missed the islands which had trapped both transports in the actual save.
	var explored_chunks := ["-1:-1","-1:-2","-1:0","-1:1","-2:-1","-2:-2","-2:0","-2:1","0:-1","0:-2","0:-3","0:0","0:1","1:-1","1:-2","1:-3","1:0","1:1","2:-1","2:-2","2:-3","2:-4","2:0","3:-1","3:-2","3:-3","3:-4","4:-1","4:-2","4:-3","4:-4","5:-2","5:-3","5:-4","6:-2","6:-3","6:-4","7:-2","7:-3","7:-4","7:-5","8:-2","8:-3","8:-4","8:-5","9:-2","9:-3","9:-4","9:-5"]
	for key in explored_chunks:
		var coordinate: PackedStringArray = str(key).split(":")
		var chunk: Dictionary = generator.generate_chunk(5247185189, Vector2i(int(coordinate[0]),int(coordinate[1])), 2)
		world.islands.append_array(chunk.get("islands",[]))
		world.hazard_zones.append_array(chunk.get("hazard_zones",[]))
		world.ports.merge(chunk.get("ports",{}),true)
	var home_id := "port_island_great_c0_-1"
	var nav_world: Dictionary = preload("res://systems/world/home_harbor_layout.gd").new().decorate(world, home_id)
	main._navigation_world = nav_world
	var traders = preload("res://systems/world/trader_traffic_renderer.gd").new()
	var fleet_traffic = preload("res://systems/world/fleet_traffic_renderer.gd").new()
	add_child(traders)
	add_child(fleet_traffic)
	traders.initialize(nav_world)
	fleet_traffic.initialize(nav_world)
	traders.external_traffic = Callable(fleet_traffic, "get_vessel_snapshots")
	GameState.world_state.home_port_id = home_id
	GameState.ship_state.position = Vector2(14787.4902, -8613.0469)
	GameState.ship_state.heading = -0.1977108
	GameState.ship_state.velocity = Vector2(56.2234, -11.2631)
	GameState.ship_state.docked_port_id = ""
	GameState.fleet_state = [
		{"instance_id":"fleet_ship_001","ship_type_id":"ship_combat_cutter","escort_enabled":true,"autopilot":{},"cargo":[],"current_port_id":"","escort_state":{"initialized":true,"position":Vector2(8174.14,-6685.061),"heading":Vector2(0.909299,0.416143),"blocked_seconds":266.5}},
		{"instance_id":"fleet_ship_002","ship_type_id":"ship_combat_cutter","escort_enabled":true,"autopilot":{},"cargo":[],"current_port_id":"","escort_state":{"initialized":true,"position":Vector2(7913.383,-6625.427),"heading":Vector2(-0.793708,0.608299),"blocked_seconds":356.0}}
	]
	system._paths.clear()
	system._trail = PackedVector2Array()
	system._time = 0.0
	var first_before: Vector2 = GameState.fleet_state[0].escort_state.position
	var initial_gap: float = first_before.distance_to(GameState.ship_state.position)
	for step in 80:
		system._process(0.25)
		traders._process(0.25)
	var first_after: Vector2 = GameState.fleet_state[0].escort_state.position
	assert_gt(first_after.distance_to(first_before), 100.0, "a transport blocked for minutes resumes moving on the real generated map")
	assert_lt(first_after.distance_to(GameState.ship_state.position), initial_gap - 800.0, "a recovered transport makes substantial progress toward the player")
	assert_eq(float(GameState.fleet_state[0].escort_state.get("blocked_seconds",0.0)), 0.0, "successful recovery clears the stuck timer")

func test_escort_can_turn_around_a_blocked_route_when_planner_returns_no_path() -> void:
	main._navigation_world.islands = [{"id":"rock","position":Vector2.ZERO,"radius":100.0}]
	GameState.ship_state.position = Vector2(600,0)
	GameState.ship_state.heading = 0.0
	GameState.ship_state.docked_port_id = ""
	var ship: Dictionary = GameState.fleet_state[0]
	ship.escort_enabled = true
	ship.escort_state = {"initialized":true,"position":Vector2(-200,0),"heading":Vector2.RIGHT,"blocked_seconds":8.0}
	system._planner = NoRoutePlanner.new()
	system._time = 10.0
	var previous_heading: Vector2 = ship.escort_state.heading
	var previous_position: Vector2 = ship.escort_state.position
	var crossed_rock: bool = false
	for step in 24:
		system._step_ship(ship,0,0.1)
		var current_heading: Vector2 = ship.escort_state.heading
		var current_position: Vector2 = ship.escort_state.position
		assert_lte(absf(previous_heading.angle_to(current_heading)),0.221,"escort turn rate stays bounded instead of snapping between avoidance headings")
		crossed_rock = crossed_rock or system._blocked(previous_position,current_position,system._length(ship))
		previous_heading = current_heading
		previous_position = current_position
	assert_true(Vector2(ship.escort_state.position).distance_to(Vector2(-200,0)) > 1.0, "empty route triggers a wider collision-checked steering search")
	assert_false(crossed_rock, "recovery steers around the rock instead of crossing it")

func test_obstacle_detour_moves_without_tunnelling() -> void:
	main._navigation_world.islands = [{"id":"rock","position":Vector2(-430,-165),"radius":100.0}]
	GameState.ship_state.docked_port_id = ""
	var ship: Dictionary = GameState.fleet_state[0]
	ship.escort_state = {"position":Vector2(-750,-165),"heading":Vector2.RIGHT,"initialized":true,"blocked_seconds":0.0}
	var previous: Vector2 = ship.escort_state.position
	var crossed_land: bool = false
	for step in 500:
		system._time += .1
		system._step_ship(ship,0,.1)
		var current: Vector2 = ship.escort_state.position
		crossed_land = crossed_land or system._blocked(previous,current,system._length(ship))
		previous = current
	assert_false(crossed_land,"no shore crossing along the entire route")
	assert_gt(previous.x,-340.0,"finds a route around the rock")

func test_saved_dictionary_vectors_do_not_break_escort_updates() -> void:
	GameState.ship_state.docked_port_id = ""
	var ship: Dictionary = GameState.fleet_state[0]
	ship.escort_state = {"position":{"x":-180.0,"y":-90.0},"heading":{"x":0.0,"y":-1.0},"initialized":true,"blocked_seconds":0.0}
	system._step_ship(ship, 0, 0.1)
	assert_true(ship.escort_state.get("position") is Vector2, "saved JSON coordinate dictionaries are converted before vector math")

func test_only_loaded_nearby_escorts_can_raid_and_active_cannot_unload() -> void:
	assert_true(system.transfer_units("transport1","coast_guard",20).ok)
	system._step_ship(GameState.fleet_state[0],0,.1)
	assert_eq(system.raid_transports().size(),1)
	GameState.fleet_state[0].escort_state.position = Vector2(5000,0)
	assert_eq(system.raid_transports().size(),0)
	GameState.combat_state.active_raid = {"active":true,"transport_ids":["transport1"]}
	assert_false(system.transfer_units("transport1","coast_guard",1,false).ok)
	assert_false(system.set_escort("transport1",false).ok)
