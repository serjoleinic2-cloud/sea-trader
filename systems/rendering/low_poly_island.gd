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
	_add_terrain(parent, outline, triangles, bounds, mini)
	_add_cliff_band(parent, outline, center, Color("8c9180"), size)
	_add_terrain_forest(parent, outline, bounds, mini)


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
	material.vertex_color_is_srgb = true
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


static func _coast_distance(point: Vector2, outline: PackedVector2Array) -> float:
	var nearest: float = INF
	for index in outline.size():
		nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, outline[index], outline[(index + 1) % outline.size()])))
	return nearest


static func terrain_height(point: Vector2, outline: PackedVector2Array, bounds: Rect2) -> float:
	if not Geometry2D.is_point_in_polygon(point, outline):
		return 0.0
	var size: float = maxf(bounds.size.x, bounds.size.y)
	var inland: float = _coast_distance(point, outline) / size
	var p: Vector2 = (point - bounds.get_center()) / size
	# Connected, asymmetric ridges and broad ledges, not overlapping cones.
	var ridge: float = exp(-pow((p.x + 0.12 + sin(p.y * 7.0) * 0.13) * 5.5, 2.0))
	var relief: float = (0.045 + 0.24 * ridge) * smoothstep(0.008, 0.065, inland)
	relief *= 0.84 + 0.16 * sin(p.y * 12.0 + p.x * 5.0)
	var ledge: float = floor(relief / 0.026) * 0.026
	return size * lerpf(relief, ledge, 0.48)


static func _add_terrain(parent: Node3D, outline: PackedVector2Array, triangles: PackedInt32Array, bounds: Rect2, mini: bool) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights: Dictionary = {}
	for index in range(0, triangles.size(), 3):
		_terrain_triangle(tool, outline[triangles[index]], outline[triangles[index + 1]], outline[triangles[index + 2]], 2 if mini else 3, outline, bounds, heights)
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_surface(parent, tool.commit(), material, "LowPolyIslandTerrain")


static func _terrain_triangle(tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, depth: int, outline: PackedVector2Array, bounds: Rect2, heights: Dictionary) -> void:
	if depth > 0:
		var ab: Vector2 = (a + b) * 0.5
		var bc: Vector2 = (b + c) * 0.5
		var ca: Vector2 = (c + a) * 0.5
		for tri in [[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]:
			_terrain_triangle(tool, tri[0], tri[1], tri[2], depth - 1, outline, bounds, heights)
		return
	var points: Array[Vector3] = []
	for p in [a,b,c]:
		if not heights.has(p): heights[p] = terrain_height(p, outline, bounds)
		points.append(Vector3(p.x, float(heights[p]), p.y))
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var center: Vector2 = (a + b + c) / 3.0
	var size: float = maxf(bounds.size.x, bounds.size.y)
	var coast: float = _coast_distance(center, outline) / size
	var grass := Color("416a36")
	var stone := Color("707e70")
	var color: Color = stone if absf(normal.y) < 0.63 else grass
	if coast < 0.009: color = Color("baad7f")
	var shade: float = float(posmod(hash(center.snapped(Vector2.ONE)), 5)) * 0.022
	color = color.lightened(shade)
	for point in points:
		tool.set_color(color)
		tool.add_vertex(point)


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
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_surface(parent, tool.commit(), material, "LowPolyIslandCliffs")


static func _add_terrain_forest(parent: Node3D, outline: PackedVector2Array, bounds: Rect2, mini: bool) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 14 if mini else 38
	var size: float = maxf(bounds.size.x, bounds.size.y)
	var placed: int = 0
	for index in count * 8:
		if placed >= count: break
		var p := bounds.position + Vector2(fposmod(float(index) * 0.754877666, 1.0), fposmod(float(index) * 0.569840296, 1.0)) * bounds.size
		if not Geometry2D.is_point_in_polygon(p, outline) or _coast_distance(p, outline) < size * 0.026:
			continue
		var height: float = size * (0.024 + float(index % 4) * 0.003)
		var base := Vector3(p.x, terrain_height(p, outline, bounds), p.y)
		var lean := Vector3(height * 0.06 * sin(float(index)), 0, height * 0.04 * cos(float(index)))
		_append_cone(tool, base, height * 0.048, height * 0.76, 5, Color("796246"))
		# Four slim overlapping tiers, with varied greens and no exposed roots.
		var green: Color = [Color("527648"), Color("63854d"), Color("7a9956")][index % 3]
		for tier in 4:
			var fraction: float = float(tier) / 4.0
			_append_cone(tool, base + lean * fraction + Vector3(0, height * (0.20 + fraction * 0.60), 0), height * (0.22 - fraction * 0.14), height * (0.42 - fraction * 0.15), 6, green.lightened(float(tier) * 0.025))
		placed += 1
	if placed == 0: return
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.93
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
