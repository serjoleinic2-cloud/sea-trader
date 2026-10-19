extends Node3D

## Lightweight modular clan-base placeholder; future approved models stay local.
func setup(radius: float, outward: Vector2, faction_id: String, wings: int, logo_png: String) -> void:
	rotation.y = -outward.angle() - PI * 0.5
	var palette: Array = GameData.get_faction(faction_id).get("palette", ["#153149", "#38a6b5", "#c49a58"])
	var dark := Color(str(palette[0]))
	var accent := Color(str(palette[1]))
	var brass := Color(str(palette[2]))
	var disk := CylinderMesh.new()
	disk.top_radius = radius * 0.96; disk.bottom_radius = radius; disk.height = 1.6; disk.radial_segments = 16
	_mesh(disk, Vector3(0, -0.3, 0), dark)
	_box(Vector3(radius * 0.7, 1, radius * 0.85), Vector3(0, 0.8, 0), brass.darkened(0.4))
	_box(Vector3(radius * 0.25, 3, radius * 0.3), Vector3(0, 2.7, radius * 0.1), dark)
	_box(Vector3(radius * 0.3, 0.35, radius * 0.35), Vector3(0, 4.4, radius * 0.1), brass)
	_box(Vector3(radius * 0.3, 0.4, radius * 0.4), Vector3(0, 0.65, -radius * 0.9), brass.darkened(0.3))
	for index in clampi(wings, 0, 4):
		var side: float = -1 if index % 2 == 0 else 1
		var z: float = radius * (0.4 if index < 2 else -0.35)
		_box(Vector3(radius * 0.38, 0.4, radius * 0.22), Vector3(side * radius * 0.55, 0.8, z), brass.darkened(0.35))
		_box(Vector3(radius * 0.16, 2.1, radius * 0.16), Vector3(side * radius * 0.63, 2.05, z), dark)
		_box(Vector3(radius * 0.18, 0.25, radius * 0.18), Vector3(side * radius * 0.63, 3.25, z), accent)
	var mast := CylinderMesh.new(); mast.top_radius = 0.1; mast.bottom_radius = 0.12; mast.height = 8
	_mesh(mast, Vector3(0, 5.5, radius * 0.1), brass)
	var flag := MeshInstance3D.new(); var plane := QuadMesh.new(); plane.size = Vector2(3.2, 3.2); flag.mesh = plane
	flag.position = Vector3(1.65, 7.5, radius * 0.1)
	var material := StandardMaterial3D.new(); material.cull_mode = BaseMaterial3D.CULL_DISABLED; material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var image := Image.new()
	material.albedo_texture = ImageTexture.create_from_image(image) if logo_png != "" and image.load_png_from_buffer(Marshalls.base64_to_raw(logo_png)) == OK else GameData.get_faction_emblem(faction_id)
	flag.material_override = material; add_child(flag)

func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new(); mesh.size = size; _mesh(mesh, at, color)

func _mesh(mesh: Mesh, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new(); node.mesh = mesh; node.position = at
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.8
	node.material_override = material; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(node)
