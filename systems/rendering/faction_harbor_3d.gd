extends Node3D

var _style: RefCounted
var _beacons: Array[OmniLight3D] = []
var _forest: Array[GeometryInstance3D] = []
var _clock: float = 0.0
var _lighthouse: Node3D
var _beam: ShaderMaterial
var _sweep: float = 0.0

func setup(key: String) -> void:
	var spec: Dictionary = GameData.read("res://data/world/faction_harbors.json").get("variants", {}).get(key, {})
	if spec.is_empty(): return
	_style = load("res://systems/rendering/faction_base_style.gd").new()
	var low_poly = load("res://systems/rendering/low_poly_island.gd")
	low_poly.build(self, spec.get("coastline", []), str(spec.faction), bool(spec.mini))
	low_poly.build_piers(self, spec.get("piers", []), str(spec.faction))
	low_poly.build_settlement(self, spec.get("coastline", []), str(spec.faction), bool(spec.mini))
	_add_reef(float(spec.reference_radius), 0.55 if bool(spec.mini) else 0.34)
	var at: Array = spec.get("lighthouse", [])
	if at.size() == 3: _add_lighthouse(Vector3(float(at[0]),float(at[1]),float(at[2])))
	var gulls = load("res://systems/rendering/seabird_flock.gd").new()
	gulls.name = "BayGulls"
	gulls.scale = Vector3.ONE * 5.0
	gulls.position = Vector3(0,15,0)
	add_child(gulls)
	if str(spec.faction) == "aery" and not bool(spec.mini):
		var sky = load("res://systems/rendering/sky_harbor.gd").new()
		sky.name = "DistantSkyHarbor"
		sky.position = Vector3(-350,250,-240)
		sky.scale = Vector3.ONE * 1.7
		add_child(sky)
	for raw in spec.get("flags", []):
		var flag: Node3D = _style.make_flag(str(spec.faction), 9.0)
		flag.position = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		add_child(flag)
		var lamp: Node3D = _style._make_lantern(_beacons.size() < 2)
		lamp.position = flag.position + Vector3(1, 2, 0)
		lamp.scale = Vector3.ONE * 2.0
		add_child(lamp)
	# Warm harbor entrance lights; the geometry remains at realistic pier height.
	for polygon in spec.get("piers", []):
		var p: Array = polygon[1]
		var light := OmniLight3D.new()
		light.position = Vector3(float(p[0]), 5, float(p[1]))
		light.light_color = Color("ffd18a")
		light.omni_range = 20.0
		light.shadow_enabled = false
		add_child(light)
		_beacons.append(light)

func _collect_forest(node: Node) -> void:
	if node is GeometryInstance3D and str(node.name).begins_with("ForestBatch"):
		_forest.append(node)
	for child in node.get_children(): _collect_forest(child)

func _add_reef(radius: float, opening: float) -> void:
	# These shallow shelves mark the same impassable ring as navigation, with the
	# sole safe entrance along local +Z. No invisible collision wall in deep water.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(96):
		var a: float = opening + (TAU-opening*2.0)*float(index)/96.0
		var b: float = opening + (TAU-opening*2.0)*float(index+1)/96.0
		var p: Array[Vector3] = []
		for entry in [[a,1.055],[a,1.15],[b,1.15],[b,1.055]]:
			var angle: float = float(entry[0])
			var distance: float = radius*float(entry[1])
			var y: float = -1.5 + sin(angle*19.0)*.35
			p.append(Vector3(sin(angle)*distance,y,cos(angle)*distance))
		for corner in [0,2,1,0,3,2]: surface.add_vertex(p[corner])
	surface.generate_normals()
	var shelf := MeshInstance3D.new()
	shelf.name = "VisibleReefShelf"
	shelf.mesh = surface.commit()
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color("9b9c6c")
	sand.roughness = .95
	sand.cull_mode = BaseMaterial3D.CULL_DISABLED
	shelf.material_override = sand
	add_child(shelf)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color("666b55")
	rock.roughness = .9
	for index in range(12):
		var angle: float = opening+.09+(TAU-opening*2.0-.18)*float(index)/11.0
		var mesh := SphereMesh.new()
		mesh.radius = 1.2+float(index%3)*.45
		mesh.height = mesh.radius*1.3
		mesh.radial_segments = 5
		mesh.rings = 2
		var stone := MeshInstance3D.new()
		stone.mesh = mesh
		stone.material_override = rock
		stone.position = Vector3(sin(angle)*radius*1.10,-.55,cos(angle)*radius*1.10)
		stone.scale = Vector3(1.4,1.0,.85)
		add_child(stone)

func set_night_strength(strength: float) -> void:
	if _style != null: _style.set_night_strength(strength)
	for beacon in _beacons:
		beacon.visible = strength > 0.02
		beacon.light_energy = strength * 1.4
	if _lighthouse != null:
		_lighthouse.visible = strength > 0.02
		_lighthouse.get_node("SweepLight").light_energy = strength * 3.5
		_beam.set_shader_parameter("night_strength", strength)

func _add_lighthouse(at: Vector3) -> void:
	_lighthouse = Node3D.new()
	_lighthouse.position = at
	add_child(_lighthouse)
	var light := SpotLight3D.new()
	light.name = "SweepLight"
	light.light_color = Color("ffcf87")
	light.spot_range = 350
	light.spot_angle = 7
	light.shadow_enabled = false
	_lighthouse.add_child(light)
	_beam = ShaderMaterial.new()
	_beam.shader = load("res://assets/world/props/lighthouse/light_beam.gdshader")
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 20
	cone.height = 300
	cone.radial_segments = 16
	beam.mesh = cone
	beam.rotation.x = PI*.5
	beam.position.z = -150
	beam.material_override = _beam
	_lighthouse.add_child(beam)

func _process(delta: float) -> void:
	_sweep += delta * .22
	if _lighthouse != null: _lighthouse.rotation.y = _sweep
	_clock += delta
	if _clock < 0.5: return
	_clock = 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return
	var close: bool = camera.global_position.distance_to(global_position) < 280.0
	for batch in _forest: batch.visible = close
