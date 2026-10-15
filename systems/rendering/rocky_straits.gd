extends RefCounted

## Sea stacks use the existing circular waterline collider. Their upper silhouettes
## vary by seed; no saved anchors, coast routes or ship positions are moved.
static func build_stack(parent: Node3D, radius: float, seed_value: int) -> void:
	var spec: Dictionary = GameData.read("res://data/world/environment_catalog.json").get("rocky_straits", {})
	var sides: int = int(spec.get("sides", 14))
	var height: float = radius * float(spec.get("height_radius_ratio", 3.2))
	var phase: float = float(posmod(seed_value, 628)) * 0.01
	var levels: Array[float] = [-0.13, 0.0, 0.22, 0.46, 0.68, 0.86, 1.0]
	var rings: Array = []
	for tier in levels.size():
		var fraction: float = levels[tier]
		var ring: Array[Vector3] = []
		for side in sides:
			var angle: float = TAU * float(side) / float(sides)
			var taper: float = [1.0, 1.0, 0.97, 0.93, 0.88, 0.65, 0.36][tier]
			var irregular: float = 1.0 if tier <= 1 else 0.82 + 0.15 * sin(angle * 3.0 + phase + tier * 0.3)
			var shift := Vector2(sin(phase), cos(phase)) * radius * maxf(0.0, fraction) * 0.25
			ring.append(Vector3(cos(angle) * radius * taper * irregular + shift.x, fraction * height * (1.0 if tier <= 1 else 0.92 + 0.08 * sin(angle * 2.0 + phase)), sin(angle) * radius * taper * irregular + shift.y))
		rings.append(ring)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in levels.size() - 1:
		for side in sides:
			var next: int = (side + 1) % sides
			var a: Vector3 = rings[tier][side]
			var b: Vector3 = rings[tier][next]
			var c: Vector3 = rings[tier + 1][side]
			var d: Vector3 = rings[tier + 1][next]
			var color := Color("596b6b").lightened(float(posmod(side * 7 + tier * 3 + seed_value, 5)) * 0.03)
			if tier >= 4 and side % 3 == 0: color = Color("4a6b3f")
			for point in [a,c,b,b,c,d]:
				tool.set_color(color)
				tool.add_vertex(point)
	var top: Vector3 = rings[-1][0]
	for side in range(1, sides - 1):
		for point in [top, rings[-1][side + 1], rings[-1][side]]:
			tool.set_color(Color("677a56"))
			tool.add_vertex(point)
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.98
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var model := MeshInstance3D.new()
	model.name = "RockyStraitsStack"
	model.mesh = tool.commit()
	model.material_override = material
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
