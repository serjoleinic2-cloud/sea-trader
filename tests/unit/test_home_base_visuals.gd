extends "res://tests/test_base.gd"

func test_every_catalogued_building_has_all_visual_levels() -> void:
	var visuals: Dictionary = GameData.read("res://data/world/home_base_visuals.json")
	var catalog: Dictionary = GameData.read("res://data/ports/building_catalog.json")
	for definition in catalog.buildings:
		var id: String = str(definition.building_id)
		var levels: Array = visuals.buildings.get(id, [])
		assert_eq(levels.size(), int(definition.max_level), id)
		for index in range(levels.size()):
			assert_eq(int(levels[index].level), index + 1, id)
			assert_true(ResourceLoader.exists(str(levels[index].scene)), str(levels[index].scene))
	assert_true(ResourceLoader.exists(str(visuals.terrain)))
	assert_true(ResourceLoader.exists(str(visuals.tower)))

func test_maximum_showcase_switches_levels_without_changing_game_state() -> void:
	var before: Dictionary = GameState.port_state.duplicate(true)
	var combat_before: Dictionary = GameState.combat_state.duplicate(true)
	var base = load("res://systems/rendering/home_base_3d.gd").new()
	add_child(base)
	base.setup("", 30)
	assert_eq(base.get_node("BuildingDistrict").get_child_count(), 10)
	assert_eq(base.get_node("BuildingDistrict/warehouse").get_meta("building_level"), 30)
	base.set_showcase_level(1)
	assert_eq(base.get_node("BuildingDistrict/warehouse").get_meta("building_level"), 1)
	for faction in GameData.get_factions():
		base.set_showcase_faction(str(faction.id))
		var warehouse: Node3D = base.get_node("BuildingDistrict/warehouse")
		assert_eq(warehouse.get_meta("architecture_faction"), str(faction.id))
		assert_true(warehouse.has_node("FactionArchitecture"))
		assert_eq(warehouse.get_node("HeraldicFlagpole").get_meta("emblem_faction"), str(faction.id))
	base.set_night_strength(1.0)
	assert_eq(base._lighthouses.size(), 2)
	assert_true(base.get_node("HarborLighthouse_0").visible)
	assert_gt(base.get_node("HarborLighthouse_0/SweepLight").light_energy, 1.0)
	var old_heading: float = base.get_node("HarborLighthouse_0").rotation.y
	base._process(1.0)
	assert_true(base.get_node("HarborLighthouse_0").rotation.y != old_heading)
	assert_true(base.has_node("BayGulls"))
	var sky_port: Node3D = base.get_node("SkyHarbor")
	assert_gt(Vector2(sky_port.position.x, sky_port.position.z).length(), 600.0, "Flyer port is a distant separate harbor")
	for mesh_node in sky_port.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = mesh_node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var material: Material = instance.get_surface_override_material(surface)
			if material == null:
				material = instance.mesh.surface_get_material(surface)
			assert_false(material != null and (material.resource_name.to_lower().contains("waterfall") or material.resource_name.to_lower().contains("flowing water")), "Sky harbor has no waterfall surfaces")
	assert_eq(base.get_node("SkyHarbor/SkyPortDistrict").get_child_count(), 13)
	var lights: Array[Node] = base.find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 12)
	for light in lights:
		assert_true(light.visible)
		assert_gt(light.light_energy, 0.5)
	base.set_night_strength(0.0)
	assert_false(base.get_node("HarborLighthouse_0").visible)
	for light in lights:
		assert_false(light.visible)
	assert_eq(GameState.port_state, before)
	assert_eq(GameState.combat_state, combat_before)
	base.free()

func test_game_buttons_use_the_supplied_art_crop() -> void:
	var game_theme = load("res://systems/ui/game_ui_theme.gd").new()
	var button_style: StyleBoxTexture = game_theme.get_theme().get_stylebox("normal", "Button") as StyleBoxTexture
	assert_true(button_style != null and button_style.texture.resource_path.ends_with("approved_hud/button_frame.png"))

func test_runtime_uses_saved_levels_and_only_built_towers() -> void:
	var before: Dictionary = GameState.port_state.duplicate(true)
	var combat_before: Dictionary = GameState.combat_state.duplicate(true)
	GameState.port_state["visual_test"] = {"buildings": {"dock": {"level": 7}}}
	GameState.combat_state["towers"] = []
	var base = load("res://systems/rendering/home_base_3d.gd").new()
	add_child(base)
	base.setup("visual_test")
	assert_eq(base.get_node("BuildingDistrict").get_child_count(), 1)
	assert_eq(base.get_node("BuildingDistrict/dock").get_meta("building_level"), 7)
	GameState.port_state.visual_test.buildings["warehouse"] = {"level": 12}
	GameState.combat_state["towers"] = [{"type": "island", "crystal_id": "crystal_power"}]
	base._refresh_buildings()
	assert_eq(base.get_node("BuildingDistrict").get_child_count(), 3)
	assert_true(base.get_node("BuildingDistrict/IslandTower_0").has_node("InstalledCrystal"))
	base.free()
	GameState.port_state = before
	GameState.combat_state = combat_before
