extends Node3D

## Editable low-poly hulls; no generated image substitutes for game geometry.
@export var faction_id: String = "humans"
@export_range(1, 5) var tier: int = 1

func _ready() -> void:
	var faction: Dictionary = GameData.get_faction(faction_id)
	var palette: Array = faction.get("palette", ["#243744", "#34dacc", "#d3ad67"])
	var hull := _material(Color(str(palette[0])), false)
	var metal := _material(Color(str(palette[2])), false)
	var rune := _material(Color(str(palette[1])), true)
	var length: float = 4.0 + tier * 1.1
	var width: float = 1.2 + tier * .15
	var prism := PrismMesh.new()
	prism.size = Vector3(width, .65, length)
	var ship := MeshInstance3D.new()
	ship.mesh = prism
	ship.material_override = hull
	ship.rotation.z = PI
	ship.position.y = .2
	add_child(ship)
	_box(Vector3(width*.85, .15, length*.8), Vector3(0,.52,0), metal)
	_box(Vector3(width*.55, .6+tier*.05, .6+tier*.12), Vector3(0,.8,length*.15), hull)
	_box(Vector3(width*.5,.12,.45), Vector3(0,1.15+tier*.05,length*.15), rune)
	var slots: int = [2,3,4,6,8][tier-1]
	for index in slots:
		var z: float = -length*.35 + float(index)*length*.62/maxf(1,slots-1)
		var side: float = -1 if index%2==0 else 1
		_box(Vector3(.3,.2,.32),Vector3(side*width*.26,.72,z),metal)
		_box(Vector3(.08,.08,.6),Vector3(side*width*.26,.84,z-.2),hull)
	for side in [-1,1]:
		_box(Vector3(.06,.08,length*.7), Vector3(side*width*.42,.59,0),rune)
		if faction_id == "aery": _box(Vector3(.5,.05,length*.45),Vector3(side*width*.6,.52,.3),metal)
		if faction_id == "nerids": _box(Vector3(.25,.25,length*.55),Vector3(side*width*.58,.25,0),hull)
	if faction_id == "crystari":
		var crystal := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0; mesh.bottom_radius = .25; mesh.height = .8; mesh.radial_segments = 5
		crystal.mesh = mesh; crystal.material_override = rune; crystal.position = Vector3(0,1.55,length*.15)
		add_child(crystal)

func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .6
	result.emission_enabled = glow
	result.emission = color if glow else Color.BLACK
	result.emission_energy_multiplier = 1.2
	return result

func _box(dimensions: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.mesh = mesh; node.material_override = material; node.position = at
	add_child(node)
