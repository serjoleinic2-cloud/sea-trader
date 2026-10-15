extends Node3D

## Decorative only. Two shared, bounded MultiMeshes; no per-particle nodes,
## pathfinding, collisions, lights or gameplay changes.
const Ocean = preload("res://systems/rendering/ocean_surface.gd")
var _rules: Dictionary
var _profile: Dictionary
var _quality := ""
var _foam: Array[Dictionary] = []
var _spray: Array[Dictionary] = []
var _emitters: Dictionary = {}
var _foam_mesh: MultiMeshInstance3D
var _spray_mesh: MultiMeshInstance3D
var _material: ShaderMaterial
var _camera: Camera3D
var _clock := 0.0
var _emitted_this_frame := 0

func _ready() -> void:
	_rules=GameData.read("res://data/world/ship_wake_rules.json")
	_material=ShaderMaterial.new()
	_material.shader=preload("res://assets/vfx/sailing/wake_foam.gdshader")
	_material.set_shader_parameter("atlas",preload("res://assets/vfx/sailing/foam_wake.svg"))
	Ocean.configure_material(_material)
	var plane:=PlaneMesh.new()
	plane.size=Vector2.ONE
	plane.subdivide_width=2;plane.subdivide_depth=2
	_foam_mesh=_make_pool("FoamTrail",plane,_material,int(_rules.profiles.high.foam_capacity))
	var spray_material:=ShaderMaterial.new()
	spray_material.shader=preload("res://assets/vfx/sailing/bow_spray.gdshader")
	spray_material.set_shader_parameter("atlas",preload("res://assets/vfx/naval/splash.svg"))
	var quad:=QuadMesh.new();quad.size=Vector2.ONE
	_spray_mesh=_make_pool("BowSpray",quad,spray_material,int(_rules.profiles.high.spray_capacity))
	apply_settings()

func _make_pool(title: String, mesh: Mesh, material: Material, capacity: int) -> MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new()
	node.name=title
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.multimesh=MultiMesh.new()
	node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data=true
	node.multimesh.mesh=mesh
	node.multimesh.instance_count=capacity
	node.multimesh.visible_instance_count=0
	node.material_override=material
	add_child(node)
	return node

func apply_settings() -> void:
	var quality: String=str(GameState.settings_state.get("ship_wake_quality",_rules.get("default_quality","low")))
	if not _rules.profiles.has(quality): quality="low"
	if quality!=_quality:
		_quality=quality;_profile=_rules.profiles[quality];clear_trail()
	_material.set_shader_parameter("water_waves",str(GameState.settings_state.get("water_quality","medium")) not in ["low","simple"])

func clear_trail() -> void:
	_foam.clear();_spray.clear();_emitters.clear()
	_foam_mesh.multimesh.visible_instance_count=0
	_spray_mesh.multimesh.visible_instance_count=0

func begin_frame(delta: float, time: float, camera: Camera3D) -> void:
	_clock=time;_camera=camera;_emitted_this_frame=0
	if _quality=="off":return
	_material.set_shader_parameter("ocean_time",time)
	for pool in [_foam,_spray]:
		for index in range(pool.size()-1,-1,-1):
			pool[index].age=float(pool[index].age)+delta
			if float(pool[index].age)>=float(pool[index].life):pool.remove_at(index)
	for id in _emitters.keys():
		if time-float(_emitters[id].seen)>1.0:_emitters.erase(id)

func track(id: String, at: Vector2, heading: float, hull_length: float, delta: float, enabled: bool = true) -> void:
	if _quality=="off" or _camera==null:return
	var point:=Vector3(at.x,Ocean.SEA_LEVEL,at.y)
	if not enabled or _camera.global_position.distance_to(point)>float(_profile.distance_m) or not _camera.is_position_in_frustum(point):
		_emitters.erase(id);return
	var previous:Dictionary=_emitters.get(id,{})
	if previous.is_empty():
		if _emitters.size()>=int(_profile.emitters):return
		_emitters[id]={"position":at,"distance":0.0,"seen":_clock};return
	var travel:Vector2=at-Vector2(previous.position)
	var elapsed:float=maxf(delta,_clock-float(previous.seen))
	previous.position=at;previous.seen=_clock
	var length:float=maxf(2.0,hull_length)
	if elapsed>0.4 or travel.length()>maxf(12.0,length*3.0):previous.distance=0.0;return
	var speed:float=travel.length()/maxf(0.001,elapsed)
	if speed<float(_rules.minimum_speed_mps):previous.distance=0.0;return
	previous.distance=float(previous.distance)+travel.length()
	var spacing:float=maxf(0.45,length*float(_profile.spacing_hulls))
	if float(previous.distance)<spacing or _emitted_this_frame>=6:return
	previous.distance=fmod(float(previous.distance),spacing)
	_emitted_this_frame+=1
	var forward:Vector2=Vector2.from_angle(heading)
	var reverse:bool=forward.dot(travel)<0
	if reverse:forward=-forward
	var right:=Vector2(-forward.y,forward.x)
	var strength:float=clampf(speed/float(_rules.full_strength_speed_mps),0.12,1.0)*(0.65 if reverse else 1.0)
	for side in [-1.0,1.0]:
		var stern:Vector2=at-forward*length*0.42+right*side*length*0.10
		_append(_foam,{"at":Vector3(stern.x,0,stern.y),"velocity":Vector3(right.x,0,right.y)*side*minf(speed*0.25,length*0.30),"forward":forward,"width":length*0.24,"length":maxf(spacing*1.9,length*0.36),"strength":strength,"age":0.0,"life":float(_profile.foam_lifetime)},int(_profile.foam_capacity))
		if strength>0.22:
			var bow:Vector2=at+forward*length*0.40+right*side*length*0.075
			var height:float=Ocean.height_at(bow,_clock) if str(GameState.settings_state.get("water_quality","medium")) not in ["low","simple"] else 0.0
			_append(_spray,{"at":Vector3(bow.x,Ocean.SEA_LEVEL+height+length*0.045,bow.y),"velocity":Vector3(right.x*side,1.1,right.y*side)*length*0.12,"width":length*0.20*strength,"length":length*0.20*strength,"strength":strength,"age":0.0,"life":0.75},int(_profile.spray_capacity))

func _append(pool: Array[Dictionary], piece: Dictionary, capacity: int) -> void:
	if capacity<=0:return
	if pool.size()>=capacity:pool.pop_front()
	pool.append(piece)

func finish_frame() -> void:
	if _quality=="off":return
	_draw(_foam,_foam_mesh,false)
	_draw(_spray,_spray_mesh,true)

func _draw(pool: Array[Dictionary], node: MultiMeshInstance3D, spray: bool) -> void:
	var bounds:=AABB()
	var count:=0
	for piece in pool:
		var age:float=float(piece.age)
		var phase:float=age/float(piece.life)
		var at:Vector3=Vector3(piece.at)+Vector3(piece.velocity)*age
		var alpha:float=(1.0-smoothstep(0.08,1.0,phase))*smoothstep(0.0,0.08,phase)*float(piece.strength)
		if _camera!=null:
			var distance:float=_camera.global_position.distance_to(at)
			alpha*=1.0-smoothstep(float(_profile.distance_m)*0.7,float(_profile.distance_m),distance)
			if distance>float(_profile.distance_m) or not _camera.is_position_in_frustum(at):continue
		if alpha<0.02:continue
		var basis:=Basis.IDENTITY
		var expansion:float=1.0+phase*0.9
		if spray:
			at.y-=age*age*0.65
			basis=basis.scaled(Vector3(float(piece.width)*expansion,float(piece.length)*expansion,1))
		else:
			var forward:Vector2=piece.forward
			basis=Basis(Vector3(-forward.y,0,forward.x),Vector3.UP,Vector3(-forward.x,0,-forward.y)).scaled_local(Vector3(float(piece.width)*expansion,1,float(piece.length)*expansion))
		node.multimesh.set_instance_transform(count,Transform3D(basis,at))
		node.multimesh.set_instance_custom_data(count,Color(phase,alpha*float(_rules.spray_opacity if spray else _rules.foam_opacity),0,0))
		bounds=AABB(at,Vector3.ZERO) if count==0 else bounds.expand(at)
		count+=1
	node.multimesh.visible_instance_count=count
	node.multimesh.custom_aabb=bounds.grow(8.0)
