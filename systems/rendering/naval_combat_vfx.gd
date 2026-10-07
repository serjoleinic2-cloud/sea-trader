extends Node

## Lightweight battle VFX in the shared 3D sailing world. All geometry is procedural.
const MAP_TO_METERS: float = 0.04
const MAX_ACTIVE_SHOTS: int = 28

var _world: Node3D
var _approach: Node
var _combat_system: Node
var _military_system: Node
var _shots: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func initialize(approach_view: Node) -> void:
	_approach = approach_view
	_world = approach_view.get("_scene_root") as Node3D
	_rng.randomize()
	if not EventBus.naval_shot_visual.is_connected(_on_shot):
		EventBus.naval_shot_visual.connect(_on_shot)

func _on_shot(origin: Vector2, target: Vector2, hit: bool, weapon_kind: String, heading: Vector2, attacker_id: String) -> void:
	if not is_instance_valid(_world): return
	var side: Vector2 = heading.normalized().orthogonal()
	if side.length_squared() < 0.01: side = (target - origin).normalized().orthogonal()
	var muzzle_map: Vector2 = origin + side * 13.0
	var start := Vector3(muzzle_map.x * MAP_TO_METERS, 0.58, muzzle_map.y * MAP_TO_METERS)
	start = _model_muzzle_position(attacker_id, start)
	var finish := Vector3(target.x * MAP_TO_METERS, 0.48, target.y * MAP_TO_METERS)
	var palette := _palette(weapon_kind)
	_spawn_flash(start, palette.flash)
	if _shots.size() >= MAX_ACTIVE_SHOTS:
		_remove_shot(0)
	var projectile := MeshInstance3D.new()
	projectile.name = "NavalProjectile"
	var sphere := SphereMesh.new()
	sphere.radius = 0.10 if weapon_kind == "cannon" else 0.14
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	projectile.mesh = sphere
	projectile.material_override = _glow_material(palette.projectile, palette.energy)
	_world.add_child(projectile)
	var tracer := MeshInstance3D.new()
	tracer.name = "NavalShotTrail"
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(0.055, 0.055, 0.1)
	tracer.mesh = trail_mesh
	tracer.material_override = _glow_material(palette.trail, palette.energy * 0.75)
	_world.add_child(tracer)
	var distance: float = start.distance_to(finish)
	var speed: float = 34.0 if weapon_kind == "mortar" else (58.0 if weapon_kind == "cannon" else 82.0)
	_shots.append({"projectile": projectile, "tracer": tracer, "start": start, "finish": finish, "previous": start, "progress": 0.0, "duration": clampf(distance / speed, 0.16, 0.95), "hit": hit, "kind": weapon_kind})

func _model_muzzle_position(attacker_id: String, fallback: Vector3) -> Vector3:
	if attacker_id == "" or not is_instance_valid(_world): return fallback
	var model: Node3D = _world.get_node_or_null("Traffic_combat_" + attacker_id) as Node3D
	if model == null: return fallback
	for marker_name in ["MuzzlePoint", "GunMuzzle", "MuzzleFlash"]:
		var marker: Node3D = model.find_child(marker_name, true, false) as Node3D
		if marker != null: return marker.global_position
	return fallback

func _process(delta: float) -> void:
	if _approach != null and is_instance_valid(_approach):
		if _combat_system == null: _combat_system = get_tree().get_first_node_in_group("naval_combat_system")
		if _military_system == null: _military_system = get_tree().get_first_node_in_group("military_transport_system")
		_approach.call("_sync_traffic", self, "combat")
	for index in range(_shots.size() - 1, -1, -1):
		var shot: Dictionary = _shots[index]
		shot.progress = float(shot.progress) + delta / float(shot.duration)
		var t: float = minf(float(shot.progress), 1.0)
		var current: Vector3 = shot.start.lerp(shot.finish, t)
		if str(shot.kind) == "mortar": current.y += sin(t * PI) * 1.1
		var projectile: MeshInstance3D = shot.projectile
		var tracer: MeshInstance3D = shot.tracer
		if is_instance_valid(projectile): projectile.position = current
		if is_instance_valid(tracer):
			var previous: Vector3 = shot.previous
			var segment: Vector3 = current - previous
			tracer.position = (current + previous) * 0.5
			tracer.look_at(current if segment.length_squared() > 0.00001 else current + Vector3.FORWARD, Vector3.UP)
			var mesh: BoxMesh = tracer.mesh as BoxMesh
			mesh.size = Vector3(0.045, 0.045, maxf(0.06, segment.length()))
		shot.previous = current
		if t >= 1.0:
			if bool(shot.hit): _spawn_impact(shot.finish, str(shot.kind))
			_remove_shot(index)
	for index in range(_debris.size() - 1, -1, -1):
		var piece: Dictionary = _debris[index]
		piece.ttl = float(piece.ttl) - delta
		var node: MeshInstance3D = piece.node
		if not is_instance_valid(node) or float(piece.ttl) <= 0.0:
			if is_instance_valid(node): node.queue_free()
			_debris.remove_at(index)
			continue
		piece.velocity.y -= 2.4 * delta
		node.position += Vector3(piece.velocity) * delta
		node.rotate_x(float(piece.spin.x) * delta)
		node.rotate_z(float(piece.spin.y) * delta)

func get_vessel_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if str(GameState.ship_state.get("docked_port_id", "")) != "": return result
	if _military_system != null and is_instance_valid(_military_system):
		result.append_array(_military_system.get_vessel_snapshots())
	if _combat_system != null and is_instance_valid(_combat_system) and _combat_system.active():
		result.append_array(_combat_system.get_enemy_snapshots())
	return result

func _remove_shot(index: int) -> void:
	var shot: Dictionary = _shots[index]
	for key in ["projectile", "tracer"]:
		var node: Node3D = shot.get(key) as Node3D
		if is_instance_valid(node): node.queue_free()
	_shots.remove_at(index)

func _spawn_flash(at: Vector3, color: Color) -> void:
	var flash := MeshInstance3D.new()
	flash.name = "CannonMuzzleFlash"
	var mesh := SphereMesh.new()
	mesh.radius = 0.30
	mesh.height = 0.18
	mesh.radial_segments = 7
	mesh.rings = 3
	flash.mesh = mesh
	flash.position = at
	flash.scale = Vector3(1.0, 0.55, 1.5)
	flash.material_override = _glow_material(color, 3.2)
	_world.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.8
	light.omni_range = 3.5
	light.shadow_enabled = false
	flash.add_child(light)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.075
	flash.add_child(timer)
	timer.timeout.connect(flash.queue_free)
	timer.start()

func _spawn_impact(at: Vector3, weapon_kind: String) -> void:
	if not is_instance_valid(_world): return
	var wood := Color("a97543")
	var spark: Color = _palette(weapon_kind).flash
	for index in 6:
		if _debris.size() >= 80:
			var oldest: Dictionary = _debris.pop_front()
			if is_instance_valid(oldest.node): oldest.node.queue_free()
		var piece := MeshInstance3D.new()
		piece.name = "HullSplinter"
		var plank := BoxMesh.new()
		plank.size = Vector3(_rng.randf_range(0.045, 0.10), _rng.randf_range(0.025, 0.06), _rng.randf_range(0.12, 0.24))
		piece.mesh = plank
		piece.material_override = _glow_material(spark if index < 2 else wood, 1.2 if index < 2 else 0.0)
		piece.position = at + Vector3(_rng.randf_range(-0.16, 0.16), _rng.randf_range(0.20, 0.55), _rng.randf_range(-0.16, 0.16))
		_world.add_child(piece)
		_debris.append({"node": piece, "velocity": Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0.8, 2.1), _rng.randf_range(-1.2, 1.2)), "spin": Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9)), "ttl": _rng.randf_range(0.7, 1.35)})

func _palette(kind: String) -> Dictionary:
	match kind:
		"rune": return {"flash": Color("55eaff"), "projectile": Color("beffff"), "trail": Color("18cbe8"), "energy": 4.0}
		"mortar": return {"flash": Color("ff9e3a"), "projectile": Color("ffd78d"), "trail": Color("ff6a28"), "energy": 3.3}
		_: return {"flash": Color("ffbd62"), "projectile": Color("555b62"), "trail": Color("ff974e"), "energy": 2.0}

func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = energy > 0.0
	if energy > 0.0:
		material.emission = color
		material.emission_energy_multiplier = energy
	return material
