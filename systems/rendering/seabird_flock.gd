extends Node3D

## Decorative gulls. No physics, saves, or gameplay state changes.
var periodic: bool = false
var _clock: float = 0.0
var _birds: MultiMeshInstance3D
var _perched: MultiMeshInstance3D

func _ready() -> void:
	_birds = _make_flock(8 if periodic else 14, true)
	if not periodic:
		_perched = _make_flock(8, false)
		for index in range(8):
			var side: float = -1.0 if index % 2 == 0 else 1.0
			_perched.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.7), Vector3(side * 31.0, 1.8, -24.0 - float(index / 2) * 6.0)))

func _make_flock(count: int, flying: bool) -> MultiMeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [Vector3(-0.1, 0, -0.3), Vector3(0.1, 0, -0.3), Vector3(0, 0.14, 0.35),
		Vector3(-0.08, 0, -0.12), Vector3(-0.60, 0.03, 0.08), Vector3(-0.12, 0, 0.18),
		Vector3(0.08, 0, -0.12), Vector3(0.12, 0, 0.18), Vector3(0.60, 0.03, 0.08)]
	for point in vertices:
		tool.set_uv(Vector2(absf(point.x) / 0.6, point.z + 0.3))
		tool.add_vertex(point)
	tool.generate_normals()
	var flock := MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = tool.commit()
	instances.instance_count = count
	flock.multimesh = instances
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/world/props/seabirds/seabird_wings.gdshader")
	flock.material_override = material
	add_child(flock)
	for index in range(count):
		instances.set_instance_custom_data(index, Color(float(index) / count, 1.0 if flying else 0.0, 0, 1))
	return flock

func _process(delta: float) -> void:
	_clock += delta
	if _birds == null:
		return
	_birds.visible = not periodic or fposmod(_clock, 55.0) < 18.0
	for index in range(_birds.multimesh.instance_count):
		var phase := _clock * 0.17 + float(index) * 1.73
		var radius: float = 10.0 + index % 4 * 3.0
		var at := Vector3(cos(phase) * radius, 6.0 + index % 5 * 1.1 + sin(phase * 2.0), sin(phase) * radius - (8.0 if periodic else 36.0))
		var forward := Vector3(-sin(phase), 0, cos(phase))
		var basis := Basis.looking_at(forward, Vector3.UP)
		_birds.multimesh.set_instance_transform(index, Transform3D(basis, at))
