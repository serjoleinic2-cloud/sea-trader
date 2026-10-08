extends RefCounted
## Lightweight island presentation built from the same shoreline data used by navigation.

static func build(parent: Node3D, raw_outline: Array, race_id: String = "humans", mini: bool = false) -> void:
	var outline := PackedVector2Array()
	for point in raw_outline:
		if point is Array and point.size() >= 2:
			outline.append(Vector2(float(point[0]), float(point[1])))
	if outline.size() < 3:
		return
	outline = _simplify(outline, 40 if mini else 56)
	var triangles := Geometry2D.triangulate_polygon(outline)
	if triangles.is_empty():
		return
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var size := maxf(bounds.size.x, bounds.size.y)
	var center := bounds.get_center()
	var race_color := _race_color(race_id)
	_add_top(parent, outline, triangles, race_color)
	_add_cliff_band(parent, outline, center, race_color.darkened(0.42), size)
	_add_ridge(parent, center, bounds.size, race_color, mini)
	_add_forest(parent, center, bounds.size, race_color, mini)


static func build_piers(parent: Node3D, raw_piers: Array, race_id: String = "humans") -> void:
	var wood := _race_color(race_id).darkened(0.22).lerp(Color("9a7044"), 0.5)
	for raw_polygon in raw_piers:
		if not raw_polygon is Array or raw_polygon.size() < 3:
			continue
		var polygon := PackedVector2Array()
		for point in raw_polygon:
			if point is Array and point.size() >= 2:
				polygon.append(Vector2(float(point[0]), float(point[1])))
		if polygon.size() < 3:
			continue
		var mesh := _extruded_polygon(polygon, 0.8, wood, wood.darkened(0.3))
		if mesh == null:
			continue
		var dock := MeshInstance3D.new()
		dock.name = "LowPolyPier"
		dock.mesh = mesh
		parent.add_child(dock)


static func build_settlement(parent: Node3D, raw_outline: Array, race_id: String = "humans", mini: bool = false) -> void:
	var outline := PackedVector2Array()
	for point in raw_outline:
		if point is Array and point.size() >= 2:
			outline.append(Vector2(float(point[0]), float(point[1])))
	if outline.size() < 3:
		return
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var scale_factor := maxf(1.0, minf(bounds.size.x, bounds.size.y))
	var wall := _race_color(race_id).darkened(0.22)
	var roof := _race_color(race_id).darkened(0.48).lerp(Color("bc8b53"), 0.35)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var house_count := 5 if mini else 10
	for index in house_count:
		var row := index / 5
		var col := index % 5
		var x := center.x + (float(col) - 2.0) * scale_factor * 0.105
		var z := center.y - scale_factor * (0.10 + float(row) * 0.12)
		var width := scale_factor * (0.025 if mini else 0.028)
		var depth := width * 0.78
		var height := scale_factor * (0.035 + float(index % 3) * 0.005)
		_append_house(tool, Vector3(x, 0.1, z), Vector3(width, height, depth), wall.lightened(0.04 * float(index % 3)), roof)
	# A few taller silhouettes give the port a visible center without loading a city GLB.
	var tower_count := 1 if mini else 3
	for index in tower_count:
		var x := center.x + (float(index) - float(tower_count - 1) * 0.5) * scale_factor * 0.22
		var z := center.y - scale_factor * 0.29
		var width := scale_factor * 0.032
		_append_house(tool, Vector3(x, 0.15, z), Vector3(width, scale_factor * 0.10, width), wall.lightened(0.12), roof.lightened(0.16))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_surface(parent, tool.commit(), material, "LowPolyHarborSettlement")


static func _append_house(tool: SurfaceTool, base: Vector3, half: Vector3, wall: Color, roof: Color) -> void:
	var x := half.x
	var y := half.y
	var z := half.z
	var a := base + Vector3(-x, 0.0, -z)
	var b := base + Vector3(x, 0.0, -z)
	var c := base + Vector3(x, 0.0, z)
	var d := base + Vector3(-x, 0.0, z)
	var e := base + Vector3(-x, y, -z)
	var f := base + Vector3(x, y, -z)
	var g := base + Vector3(x, y, z)
	var h := base + Vector3(-x, y, z)
	var faces := [[a, d, c, b], [a, b, f, e], [b, c, g, f], [c, d, h, g], [d, a, e, h], [e, f, g, h]]
	for face_index in faces.size():
		var face: Array = faces[face_index]
		var color := wall.darkened(0.12 if face_index % 2 == 0 else 0.0)
		for corner in [0, 1, 2, 0, 2, 3]:
			tool.set_color(color)
			tool.add_vertex(face[corner])
	var ridge_front := base + Vector3(0.0, y * 1.55, -z)
	var ridge_back := base + Vector3(0.0, y * 1.55, z)
	for triangle in [[e, ridge_front, ridge_back], [e, ridge_back, h], [ridge_front, f, g], [ridge_front, g, ridge_back], [e, f, ridge_front], [h, ridge_back, g]]:
		for point in triangle:
			tool.set_color(roof)
			tool.add_vertex(point)


static func _simplify(points: PackedVector2Array, maximum: int) -> PackedVector2Array:
	if points.size() <= maximum:
		return points
	var result := PackedVector2Array()
	for index in range(maximum):
		result.append(points[int(float(index) * float(points.size()) / float(maximum))])
	return result


static func _add_top(parent: Node3D, outline: PackedVector2Array, triangles: PackedInt32Array, base_color: Color) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facet_colors := [base_color, base_color.lightened(0.08), base_color.darkened(0.07)]
	for index in range(0, triangles.size(), 3):
		var color: Color = facet_colors[posmod(index / 3, facet_colors.size())]
		for corner in 3:
			var point := outline[triangles[index + corner]]
			tool.set_color(color)
			tool.add_vertex(Vector3(point.x, 0.0, point.y))
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_surface(parent, tool.commit(), material, "LowPolyIslandTop")


static func _add_cliff_band(parent: Node3D, outline: PackedVector2Array, center: Vector2, color: Color, size: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := maxf(1.0, size * 0.045)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var lower_a := center + (a - center) * 1.035
		var lower_b := center + (b - center) * 1.035
		for point in [Vector3(a.x, -0.04, a.y), Vector3(b.x, -0.04, b.y), Vector3(lower_a.x, -depth, lower_a.y), Vector3(b.x, -0.04, b.y), Vector3(lower_b.x, -depth, lower_b.y), Vector3(lower_a.x, -depth, lower_a.y)]:
			tool.set_color(color if index % 3 else color.lightened(0.1))
			tool.add_vertex(point)
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_surface(parent, tool.commit(), material, "LowPolyIslandCliffs")


static func _add_ridge(parent: Node3D, center: Vector2, extent: Vector2, color: Color, mini: bool) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 5 if mini else 9
	var ridge_height := maxf(2.0, maxf(extent.x, extent.y) * (0.045 if mini else 0.075))
	var ridge_width := maxf(1.0, minf(extent.x, extent.y) * 0.12)
	for peak in count:
		var t := float(peak) / float(maxi(1, count - 1))
		var x := lerpf(-extent.x * 0.31, extent.x * 0.29, t)
		var z := sin(t * PI * 2.0) * extent.y * 0.13
		var height := ridge_height * (0.58 + 0.42 * sin(t * PI))
		var sides := 5
		var apex := Vector3(center.x + x, height, center.y + z)
		for side in sides:
			var a := TAU * float(side) / float(sides)
			var b := TAU * float(side + 1) / float(sides)
			var p1 := Vector3(center.x + x + cos(a) * ridge_width, 0.05, center.y + z + sin(a) * ridge_width)
			var p2 := Vector3(center.x + x + cos(b) * ridge_width, 0.05, center.y + z + sin(b) * ridge_width)
			var facet := color.darkened(0.26 if side % 2 == 0 else 0.12)
			for point in [p1, p2, apex]:
				tool.set_color(facet)
				tool.add_vertex(point)
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_surface(parent, tool.commit(), material, "LowPolyIslandRidge")


static func _add_forest(parent: Node3D, center: Vector2, extent: Vector2, color: Color, mini: bool) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 8 if mini else 18
	var trunk := Color("76583b")
	for index in count:
		var angle := float(index) * 2.399963
		var distance := 0.17 + 0.24 * float(posmod(index * 7, 11)) / 10.0
		var x := center.x + cos(angle) * extent.x * distance
		var z := center.y + sin(angle) * extent.y * distance
		var h := maxf(1.1, maxf(extent.x, extent.y) * (0.012 + 0.005 * float(index % 3)))
		_append_cone(tool, Vector3(x, 0.05, z), h * 0.22, h * 0.55, 5, trunk)
		_append_cone(tool, Vector3(x, h * 0.26, z), h * 0.5, h * 0.62, 5, color.lightened(0.04 * float(index % 3)))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_surface(parent, tool.commit(), material, "LowPolyIslandForest")


static func _append_cone(tool: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, color: Color) -> void:
	var apex := base + Vector3(0.0, height, 0.0)
	for side in sides:
		var a := TAU * float(side) / float(sides)
		var b := TAU * float(side + 1) / float(sides)
		var p1 := base + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		var p2 := base + Vector3(cos(b) * radius, 0.0, sin(b) * radius)
		for point in [p1, p2, apex]:
			tool.set_color(color.darkened(0.05 if side % 2 == 0 else 0.18))
			tool.add_vertex(point)


static func _extruded_polygon(polygon: PackedVector2Array, height: float, top: Color, side: Color) -> ArrayMesh:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty():
		return null
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		var point := polygon[index]
		tool.set_color(top)
		tool.add_vertex(Vector3(point.x, height, point.y))
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		for point in [Vector3(a.x, height, a.y), Vector3(b.x, height, b.y), Vector3(a.x, 0.0, a.y), Vector3(b.x, height, b.y), Vector3(b.x, 0.0, b.y), Vector3(a.x, 0.0, a.y)]:
			tool.set_color(side)
			tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit() as ArrayMesh


static func _add_surface(parent: Node3D, mesh: ArrayMesh, material: StandardMaterial3D, node_name: String) -> void:
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _race_color(race_id: String) -> Color:
	match race_id:
		"nerids": return Color("4f927d")
		"surr": return Color("896756")
		"meridians": return Color("8d8662")
		"aery": return Color("71947c")
		"crystari": return Color("718c8a")
		_: return Color("68805b")
