extends Node3D

## Temporary hulls, sails and rigging shared by sea vessels and catalog previews.
@export var faction_id: String = "humans"
@export_range(1, 5) var tier: int = 1
@export var warship: bool = true
@export var ship_id: String = ""

func _ready() -> void:
	var palette: Array = GameData.get_faction(faction_id).get("palette", ["#243744", "#34dacc", "#d3ad67"])
	var hull := _material(Color(str(palette[0])),false)
	var metal := _material(Color(str(palette[2])),false)
	var rune := _material(Color(str(palette[1])),true)
	var sail := _material(Color(str(palette[1])).lightened(.55),false)
	sail.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rope := _material(Color("897a59"),false)
	var length: float = 4.0+tier*1.1
	var width: float = 1.2+tier*.19
	_hull(length,width,hull,metal)
	_box(Vector3(width*.62,.52,.7+tier*.1),Vector3(0,.72,length*.28),hull)
	_box(Vector3(width*.67,.09,.85+tier*.1),Vector3(0,1.02,length*.28),metal)
	for side in [-1,1]:
		for window in 3:
			_box(Vector3(.02,.16,.13),Vector3(side*width*.315,.79,length*.28-.24+window*.24),rune)
		for rail in 7:
			_rod(Vector3(side*width*.43,.43,-length*.3+rail*length*.1),Vector3(side*width*.43,.66,-length*.3+rail*length*.1),.014,metal)
		_rod(Vector3(side*width*.43,.66,-length*.3),Vector3(side*width*.43,.66,length*.3),.018,metal)
		if faction_id == "aery": _box(Vector3(.3,.06,length*.4),Vector3(side*width*.57,.4,0),metal)
		if faction_id == "nerids":
			_box(Vector3(.15,.2,length*.48),Vector3(side*width*.55,.08,0),hull)
			_rod(Vector3(side*width*.4,.34,-length*.15),Vector3(side*width*.55,.18,-length*.15),.05,metal)
		_rod(Vector3(side*width*.39,.4,-length*.28),Vector3(side*width*.39,.4,length*.28),.026,rune)
	var mast_count: int = 1 if tier == 1 else (2 if tier<4 else 3)
	for index in mast_count:
		var z: float = -length*.15+(index-(mast_count-1)*.5)*length*.23
		var height: float = 1.5+tier*.19-index*.08
		var top := Vector3(0,height+.45,z)
		_rod(Vector3(0,.45,z),top,.035+tier*.004,metal)
		var span: float = width*(.62 if faction_id=="aery" else .53)
		_rod(Vector3(-span,height+.36,z),Vector3(span,height+.36,z),.022,metal)
		_sail(span,height,z,sail)
		for side in [-1,1]:
			_rod(top,Vector3(side*width*.4,.45,z+.32),.008,rope)
			_rod(Vector3(side*span,height+.36,z),Vector3(0,.48,z+.35),.007,rope)
	_rod(Vector3(0,.5,-length*.33),Vector3(0,.6,-length*.6),.026,metal)
	_rod(Vector3(0,.6,-length*.6),Vector3(0,1.5,-length*.15),.008,rope)
	if warship:
		var slots: int = [2,3,4,6,8][tier-1]
		var bow_slots: int=int(GameData.get_ship(ship_id).get("bow_gun_slots",0))
		for index in slots:
			var muzzle: Vector3
			if index<bow_slots:
				var bow_side: float=-1.0 if index%2==0 else 1.0
				var x: float=bow_side*.14 if bow_slots>1 else 0.0
				_box(Vector3(.22,.14,.28),Vector3(x,.53,-length*.42),metal)
				muzzle=Vector3(x,.7,-length*.59)
				_rod(Vector3(x,.7,-length*.4),muzzle,.055,hull)
			else:
				var broadside_index: int=index-bow_slots
				var z: float=-length*.27+floori(float(broadside_index)/2.0)*length*.16
				var side: float=-1.0 if broadside_index%2==0 else 1.0
				_box(Vector3(.3,.14,.34),Vector3(side*width*.25,.53,z),metal)
				muzzle=Vector3(side*(width*.48+.24),.7,z)
				_rod(Vector3(side*width*.25,.7,z),muzzle,.055,hull)
			if index==0:
				var marker := Marker3D.new()
				marker.name="BowMuzzlePoint" if index<bow_slots else "MuzzlePoint"; marker.position=muzzle; add_child(marker)
	else:
		if ship_id.contains("tanker"):
			for index in 3: _rod(Vector3(0,.73,-length*.25+index*.75),Vector3(0,.73,-length*.25+index*.75+.55),width*.32,metal)
		else:
			for index in maxi(1,tier*2):
				_box(Vector3(.4,.27,.4),Vector3(-.25 if index%2==0 else .25,.6,-length*.2+(index/2)*.5),hull if index%3==0 else metal)
		if tier>=4:
			_rod(Vector3(width*.32,.5,-length*.2),Vector3(width*.32,1.3,-length*.2),.04,metal)
			_rod(Vector3(width*.32,1.3,-length*.2),Vector3(0,1.3,-length*.4),.025,metal)
	if faction_id=="crystari":
		var crystal := CylinderMesh.new()
		crystal.top_radius=0; crystal.bottom_radius=.18; crystal.height=.5; crystal.radial_segments=5
		_mesh(crystal,Vector3(0,1.35,length*.28),rune)

func _hull(length: float, width: float, hull: Material, deck: Material) -> void:
	var rings: Array[PackedVector3Array] = []
	for station in [[-.5,.04],[-.38,.72],[-.12,1.0],[.2,.97],[.4,.72],[.5,.48]]:
		var z: float = float(station[0])*length
		var w: float = width*.5*float(station[1])
		rings.append(PackedVector3Array([Vector3(-w,.4,z),Vector3(-w*.77,-.12,z),Vector3(0,-.3,z),Vector3(w*.77,-.12,z),Vector3(w,.4,z)]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(rings.size()-1):
		for side in 4:
			_triangle(surface,rings[index][side],rings[index+1][side],rings[index+1][side+1])
			_triangle(surface,rings[index][side],rings[index+1][side+1],rings[index][side+1])
	for index in [0,rings.size()-1]:
		for side in range(1,4):
			if index==0: _triangle(surface,rings[index][0],rings[index][side+1],rings[index][side])
			else: _triangle(surface,rings[index][0],rings[index][side],rings[index][side+1])
	surface.generate_normals()
	_mesh(surface.commit(),Vector3.ZERO,hull)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(rings.size()-1):
		_triangle(top,rings[index][0],rings[index][4],rings[index+1][4])
		_triangle(top,rings[index][0],rings[index+1][4],rings[index+1][0])
	top.generate_normals()
	_mesh(top.commit(),Vector3.ZERO,deck)

func _sail(span: float, height: float, z: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 4:
		for column in 6:
			var corners: Array[Vector3] = []
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var u: float = (column+offset.x)/6.0
				var v: float = (row+offset.y)/4.0
				corners.append(Vector3((u*2-1)*span*(1-v*.22),height+.35-v*height*.66,z+.24*sin(u*PI)*sin(v*PI)))
			_triangle(surface,corners[0],corners[1],corners[2])
			_triangle(surface,corners[0],corners[2],corners[3])
	surface.generate_normals()
	_mesh(surface.commit(),Vector3.ZERO,material)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a); surface.add_vertex(b); surface.add_vertex(c)

func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color; result.roughness=.65; result.emission_enabled=glow
	result.emission=color if glow else Color.BLACK; result.emission_energy_multiplier=.55
	return result

func _mesh(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh; node.material_override=material; node.position=at; add_child(node)
	return node

func _box(dimensions: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size=dimensions; _mesh(mesh,at,material)

func _rod(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=a.distance_to(b); mesh.radial_segments=6
	var node := _mesh(mesh,(a+b)*.5,material)
	node.quaternion=Quaternion(Vector3.UP,a.direction_to(b))
