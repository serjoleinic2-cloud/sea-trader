extends "res://tests/test_base.gd"

func test_all_six_harbors_and_outposts_have_matching_assets_and_open_anchors() -> void:
	var saved: Dictionary = GameState.player_state.duplicate(true)
	var catalog: Dictionary = GameData.read("res://data/world/faction_harbors.json")
	assert_eq(catalog.variants.size(),12)
	assert_eq(catalog.route_islands.size(),2)
	for faction in GameData.get_factions():
		GameState.player_state.origin_race_id = str(faction.id)
		for mini in [false,true]:
			var key: String = str(faction.id) + ("_outpost" if mini else "")
			var spec: Dictionary = catalog.variants[key]
			assert_true(ResourceLoader.exists(str(spec.scene)),key)
			var anchor := Vector2(90,350)
			var port: Dictionary = {"id":"harbor_test", "island_id":"island_test", "position":anchor,"harbor_angle":1.27,"owner_race_id":str(faction.id)}
			var raw: Dictionary = {"seed":32,"ports":{"harbor_test":port},"islands":[{"id":"island_test","position":Vector2.ZERO,"radius":300.0 if mini else 1200.0}]}
			var world: Dictionary = load("res://systems/world/faction_harbor_layout.gd").new().decorate(raw,"" if mini else "harbor_test")
			assert_eq(world.ports.harbor_test.position,anchor,"Saved anchors cannot move")
			assert_eq(world.islands[0].harbor_variant,key)
			var guard = load("res://systems/ship/ship_physics.gd").new()
			guard.set_collision_data_provider(func():return world)
			var outward := Vector2.from_angle(float(world.islands[0].bay_angle))
			assert_false(guard.is_navigation_move_blocked(anchor+outward*float(world.islands[0].radius)*1.5,anchor),key+" entrance")
			assert_true(guard.is_navigation_move_blocked(Vector2(world.islands[0].position)-outward*float(world.islands[0].radius)*1.5,anchor),key+" rear ridge")
			guard.free()
		for id in ["dock","warehouse","workshop","market","shipyard","timber_yard","fishing_wharf","mage_guild","annex","tower","scaffold"]:
			assert_true(ResourceLoader.exists("res://assets/ui/ports/%s/%s.png"%[faction.id,id]))
	GameState.player_state=saved

func test_shared_buoyancy_tracks_water_without_washing_over_smallest_deck() -> void:
	var ocean = load("res://systems/rendering/ocean_surface.gd")
	var ship := Node3D.new()
	var worst: float = 0.0
	for tick in range(240):
		var time: float = float(tick)*.31
		var position := Vector2(8.7+tick*.32,-14.2+tick*.15)
		var heading: float = tick*.087
		ocean.float_ship(ship,position,heading,3.48,time)
		ship.rotation.y=-heading-PI*.5
		for local in [Vector3(-.48,.257,-1.4),Vector3(.48,.257,-1.4),Vector3(-.48,.257,1.4),Vector3(.48,.257,1.4)]:
			var point: Vector3 = ship.transform*local
			var at := position+Vector2(point.x,point.z)
			var height: float = ocean.SEA_LEVEL+ocean.height_at(at,time)
			worst=maxf(worst,height-point.y)
	assert_almost_eq(worst,0.0,.0001,"Water must remain below every sampled corner of the sloop deck")
	ship.free()
