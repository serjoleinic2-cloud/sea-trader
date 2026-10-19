extends Node

## Lightweight 3D silhouettes for the deterministic debris used by the
## research HUD. They are visual markers only; collection remains in the HUD.

const MAP_TO_METERS: float = 0.04
const VISIBLE_RADIUS: float = 760.0

var _main: Node
var _scene_root: Node3D
var _markers: Array[Dictionary] = []
var _debris: Array = []

func initialize(main: Node) -> void:
	_main = main
	var approach: Node = main.get_node_or_null("Approach3DView")
	if approach != null:
		_scene_root = approach.get("_scene_root") as Node3D
	_rebuild()

func _process(_delta: float) -> void:
	if _scene_root == null or not is_instance_valid(_scene_root):
		var approach: Node = _main.get_node_or_null("Approach3DView") if _main != null else null
		if approach != null:
			_scene_root = approach.get("_scene_root") as Node3D
		if _scene_root == null:
			return
	var ship_position := Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var collected: Array = GameState.world_state.get("collected_debris_ids", [])
	for entry in _markers:
		var marker: Node3D = entry.get("node") as Node3D
		if marker == null or not is_instance_valid(marker):
			continue
		var debris: Dictionary = entry.get("debris", {})
		var debris_id := str(debris.get("id", ""))
		var distance: float = ship_position.distance_to(Vector2(debris.get("position", Vector2.ZERO)))
		marker.visible = not collected.has(debris_id) and distance <= VISIBLE_RADIUS
		if marker.visible:
			marker.rotation.y += _delta * 0.18

func _rebuild() -> void:
	_debris.clear()
	for entry in _markers:
		var marker: Node3D = entry.get("node") as Node3D
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()
	if _main == null or _scene_root == null:
		return
	var world: Dictionary = _main.get("_world_data")
	_debris = preload("res://systems/world/drift_debris_catalog.gd").generate(world, int(GameState.world_state.get("seed", 0)), str(GameState.world_state.get("home_port_id", "")))
	for debris in _debris:
		_add_marker(debris)

func _add_marker(debris: Dictionary) -> void:
	var marker := Node3D.new()
	marker.name = str(debris.get("id", "Debris"))
	marker.position = Vector3(float(Vector2(debris.get("position", Vector2.ZERO)).x) * MAP_TO_METERS, 0.24, float(Vector2(debris.get("position", Vector2.ZERO)).y) * MAP_TO_METERS)
	marker.rotation.y = randf() * TAU
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _make_mesh(str(debris.get("kind", "Обломки")))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#b78a4f") if str(debris.get("kind", "")) == "Ящик" else Color("#754d35") if str(debris.get("kind", "")) == "Бочка" else Color("#71838a")
	material.roughness = 0.82
	mesh_instance.material_override = material
	marker.add_child(mesh_instance)
	_scene_root.add_child(marker)
	_markers.append({"node": marker, "debris": debris})

func _make_mesh(kind: String) -> Mesh:
	if kind == "Бочка":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.34
		cylinder.bottom_radius = 0.34
		cylinder.height = 0.54
		cylinder.radial_segments = 12
		return cylinder
	var box := BoxMesh.new()
	box.size = Vector3(0.68, 0.42, 0.58) if kind == "Ящик" else Vector3(1.0, 0.25, 0.34)
	return box

