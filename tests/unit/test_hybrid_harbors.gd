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
			assert_true(spec.has("coastline") and spec.coastline.size() >= 3,key+" low-poly shoreline")
			assert_false(spec.has("scene"),key+" must not depend on heavyweight island GLB")
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

func test_buoyancy_finds_the_horizontally_displaced_gerstner_surface() -> void:
	var ocean = load("res://systems/rendering/ocean_surface.gd")
	var worst_error: float = 0.0
	for step in range(60):
		var position := Vector2(step * 1.23, step * -0.83)
		var time: float = step * 0.31
		var displacement: Vector3 = ocean.displacement_at(position, time)
		var rendered_position: Vector2 = position + Vector2(displacement.x, displacement.z)
		worst_error = maxf(worst_error, absf(ocean.height_at(rendered_position, time) - displacement.y))
	assert_true(worst_error < 0.00002, "Buoyancy must sample displaced GPU vertices, not the undeformed plane")

func test_low_poly_bay_terrain_and_forest_remain_on_land() -> void:
	var builder = preload("res://systems/rendering/low_poly_island.gd")
	var spec: Dictionary = GameData.read("res://data/world/faction_harbors.json").variants.humans
	var outline := PackedVector2Array()
	for point in spec.coastline: outline.append(Vector2(point[0], point[1]))
	var root := Node3D.new()
	builder.build(root,spec.coastline,"humans")
	var terrain: MeshInstance3D = root.get_node("LowPolyIslandTerrain")
	var vertices: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var highest: float = 0.0
	for point in vertices:
		highest = maxf(highest, point.y)
	assert_true(highest > 20.0,"the bay has a connected mountain mass")
	assert_true(vertices.size() < 15000,"terrain stays a lightweight batched mesh")
	assert_true(root.has_node("LowPolyIslandForest"))
	var forest_vertices: PackedVector3Array = root.get_node("LowPolyIslandForest").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var trees_on_land: bool = true
	for point in forest_vertices:
		if not Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),outline): trees_on_land = false
	assert_true(trees_on_land,"forest roots and canopies stay outside the navigable bay")
	assert_eq(root.get_child_count(),3,"terrain, submerged cliff base and forest are batched")
	assert_false(root.has_node("LowPolyHarborSettlement"))
	root.free()

func test_rocky_strait_stacks_are_tall_and_do_not_expand_waterline_collision() -> void:
	var root := Node3D.new()
	preload("res://systems/rendering/rocky_straits.gd").build_stack(root,10.0,123)
	var stack: MeshInstance3D = root.get_node("RockyStraitsStack")
	var vertices: PackedVector3Array = stack.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var highest: float = 0.0
	var waterline_radius: float = 0.0
	for point in vertices:
		highest = maxf(highest,point.y)
		if absf(point.y) < 0.001: waterline_radius = maxf(waterline_radius,Vector2(point.x,point.z).length())
	assert_true(highest >= 30.0)
	assert_almost_eq(waterline_radius,10.0,0.001,"visible stacks use the existing shoreline radius")
	assert_true(vertices.size() < 1000)
	assert_eq(root.get_child_count(),1,"one mesh per stack, no settlement or physics bodies")
	root.free()
