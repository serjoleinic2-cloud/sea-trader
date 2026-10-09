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
var _frames: Dictionary = {}
var _damage_effects: Dictionary = {}
var _rules: Dictionary = {}
var _audio = preload("res://systems/rendering/naval_battle_audio.gd").new()
var _rng := RandomNumberGenerator.new()

func initialize(approach_view: Node) -> void:
	_approach = approach_view
	_world = approach_view.get("_scene_root") as Node3D
	_rules = GameData.read("res://data/combat/naval_rules.json")
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
	var finish := Vector3(target.x * MAP_TO_METERS, 0.48 if hit else 0.08, target.y * MAP_TO_METERS)
	var palette := _palette(weapon_kind)
	_spawn_flash(start, palette.flash)
	_audio.play(_world,"cannon_fire",start)
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
	var duration: float = preload("res://systems/combat/naval_artillery.gd").flight_seconds(origin,target,weapon_kind)
	_shots.append({"projectile": projectile, "tracer": tracer, "start": start, "finish": finish, "previous": start, "progress": 0.0, "duration": duration, "hit": hit, "kind": weapon_kind})

func _model_muzzle_position(attacker_id: String, fallback: Vector3) -> Vector3:
	if attacker_id == "" or not is_instance_valid(_world): return fallback
	var model: Node3D = _world.get_node_or_null("Traffic_combat_" + attacker_id) as Node3D
	if model == null: return fallback
	for marker_name in ["BowMuzzlePoint", "MuzzlePoint", "GunMuzzle", "MuzzleFlash"]:
		var marker: Node3D = model.find_child(marker_name, true, false) as Node3D
		if marker != null: return marker.global_position
	return fallback

func _process(delta: float) -> void:
	if _approach != null and is_instance_valid(_approach):
		if _combat_system == null: _combat_system = get_tree().get_first_node_in_group("naval_combat_system")
		if _military_system == null: _military_system = get_tree().get_first_node_in_group("military_transport_system")
		_approach.call("_sync_traffic", self, "combat")
		_sync_damage_effects()
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
			else: _spawn_splash(shot.finish)
			_remove_shot(index)
	for index in range(_debris.size() - 1, -1, -1):
		var piece: Dictionary = _debris[index]
		piece.ttl = float(piece.ttl) - delta
		var node: Node3D = piece.node
		if not is_instance_valid(node) or float(piece.ttl) <= 0.0:
			if is_instance_valid(node): node.queue_free()
			_debris.remove_at(index)
			continue
		if bool(piece.get("gravity",false)): piece.velocity.y -= 2.4 * delta
		node.position += Vector3(piece.velocity) * delta
		if node is AnimatedSprite3D:
			node.modulate.a = minf(1.0, float(piece.ttl) * 3.0)

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

func _animation(kind: String, duration: float, loop: bool = false) -> SpriteFrames:
	var key: String = kind+str(duration)+str(loop)
	if _frames.has(key): return _frames[key]
	var texture: Texture2D = load("res://assets/vfx/naval/"+kind+".svg") as Texture2D
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default",loop)
	frames.set_animation_speed("default",8.0/duration)
	for index in 8:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(index*256,0,256,256)
		frames.add_frame("default",frame)
	_frames[key] = frames
	return frames

func _sync_damage_effects() -> void:
	if not is_instance_valid(_world): return
	var keep: Dictionary = {}
	for vessel in get_vessel_snapshots():
		var maximum: float=maxf(1.0,float(vessel.get("hull_max",vessel.get("hull",1))))
		var damage: float=1.0-clampf(float(vessel.get("hull",maximum))/maximum,0.0,1.0)
		var level: int=2 if damage>=float(_rules.get("critical_damage_fraction",.7)) else (1 if damage>=float(_rules.get("fire_damage_fraction",.5)) else 0)
		if level==0: continue
		var id: String=str(vessel.get("id",""))
		var model: Node3D=_world.get_node_or_null("Traffic_combat_"+id) as Node3D
		if model==null: continue
		keep[id]=true
		var root: Node3D=_damage_effects.get(id) as Node3D
		if root==null or not is_instance_valid(root) or int(root.get_meta("damage_level",0))!=level:
			if is_instance_valid(root): root.queue_free()
			root=_make_damage_effect(id,float(vessel.get("length",100))*MAP_TO_METERS,level)
			_world.add_child(root)
			_damage_effects[id]=root
		root.global_transform=Transform3D(model.global_basis.orthonormalized(),model.global_position)
		root.visible=float(vessel.get("sink_progress",0))<1.0
	for raw_id in _damage_effects.keys():
		var id: String=str(raw_id)
		if keep.has(id): continue
		var root: Node3D=_damage_effects[id] as Node3D
		if is_instance_valid(root): root.queue_free()
		_damage_effects.erase(id)

func _make_damage_effect(id: String, length: float, level: int) -> Node3D:
	var root:=Node3D.new()
	root.name="DamageFX_"+id
	root.set_meta("damage_level",level)
	_add_loop_sprite(root,"fire",Vector3(-length*.09,.82,-length*.12),1.65 if level==1 else 2.15,Color.WHITE,id+"fire_a",.72)
	_add_loop_sprite(root,"fire",Vector3(length*.08,.70,length*.13),1.35 if level==1 else 1.85,Color("fff2cf"),id+"fire_b",.61)
	if level>=2:
		_add_loop_sprite(root,"fire",Vector3(0,.9,-length*.01),2.5,Color("fff0cc"),id+"fire_c",.84)
		_add_loop_sprite(root,"smoke",Vector3(-length*.02,2.05,-length*.02),4.1,Color(1,1,1,.92),id+"smoke",1.15)
	return root

func _add_loop_sprite(parent: Node3D, kind: String, position: Vector3, size: float, color: Color, phase_key: String, duration: float) -> void:
	var sprite:=AnimatedSprite3D.new()
	sprite.name=kind.capitalize()
	sprite.sprite_frames=_animation(kind,duration,true)
	sprite.pixel_size=size/256.0
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded=false
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.modulate=color
	sprite.position=position
	parent.add_child(sprite)
	sprite.play()
	sprite.frame=posmod(hash(phase_key),8)

func _spawn_sprite(kind: String, at: Vector3, color: Color, size: float, duration: float, velocity: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(_world): return
	if _debris.size()>=80:
		var oldest: Dictionary = _debris.pop_front()
		if is_instance_valid(oldest.node): oldest.node.queue_free()
	var sprite := AnimatedSprite3D.new()
	sprite.name = "Naval_"+kind
	sprite.sprite_frames = _animation(kind,duration)
	sprite.pixel_size = size/256.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.modulate = color
	sprite.position = at
	_world.add_child(sprite)
	sprite.play()
	_debris.append({"node":sprite,"velocity":velocity,"gravity":kind=="splinter","ttl":duration})

func _spawn_flash(at: Vector3, color: Color) -> void:
	_spawn_sprite("flash",at,color,1.2,0.20)

func _spawn_splash(at: Vector3) -> void:
	_audio.play(_world,"water_splash",at)
	# Eight camera-facing frames: lift, foam crown, droplets and collapse.
	_spawn_sprite("splash",at+Vector3(0,0.85,0),Color.WHITE,2.8,1.3)

func _spawn_impact(at: Vector3, weapon_kind: String) -> void:
	_audio.play(_world,"hull_impact",at)
	_spawn_sprite("impact",at,_palette(weapon_kind).flash,1.6,0.55)
	for index in 6:
		_spawn_sprite("splinter",at+Vector3(0,0.25,0),Color.WHITE,0.35,1.2,Vector3(_rng.randf_range(-1.6,1.6),_rng.randf_range(1.5,2.8),_rng.randf_range(-1.6,1.6)))

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
