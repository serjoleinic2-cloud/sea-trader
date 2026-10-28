extends RefCounted

static var _bright_texture_cache: Dictionary = {}

## Repository contains code/manifests, while optional artist models stay in work/.
## A clean checkout always has the procedural geometry as a working fallback.
func attach(parent: Node3D, identity: String, target_size: float, prefer_local: bool = true, faction_id: String = "") -> Node3D:
	var definition: Dictionary = GameData.get_ship(identity)
	if definition.is_empty(): return null
	var visual: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships",{}).get(identity,{})
	var wrapper:=Node3D.new()
	wrapper.name="Asset_"+identity
	wrapper.set_meta("world_asset_id",identity)
	var model_tier: int = clampi(int(definition.get("tier",1)),1,5)
	var reference: float = 4.0+model_tier*1.1
	if prefer_local and not str(visual.get("local_scene", "")).is_empty() and ResourceLoader.exists(str(visual.local_scene)):
		reference = float(visual.get("length",5.1))
	if prefer_local and FileAccess.file_exists(str(visual.get("local_glb", ""))):
		reference = float(visual.get("local_glb_length", visual.get("display_length", visual.get("length", reference))))
	wrapper.set_meta("reference_length",reference)
	var local_glb_used := false
	wrapper.scale=Vector3.ONE*target_size/maxf(.01,reference)
	parent.add_child(wrapper)
	var model: Node3D
	var path: String = str(visual.get("local_scene",""))
	var glb_path: String = str(visual.get("local_glb", ""))
	if prefer_local and glb_path != "" and FileAccess.file_exists(glb_path):
		model = preload("res://systems/rendering/local_ship_gltf_loader.gd").instantiate(glb_path)
		local_glb_used = model != null
	if prefer_local and path!="" and ResourceLoader.exists(path):
		if model == null:
			var scene: PackedScene = load(path) as PackedScene
			if scene!=null: model=scene.instantiate() as Node3D
	if model==null:
		model=preload("res://systems/rendering/naval_ship_visual.gd").new()
		model.faction_id=faction_id if faction_id=="pirates" else str(definition.get("faction_id",faction_id if faction_id!="" else GameState.player_state.get("origin_race_id","humans")))
		model.warship=bool(definition.get("warship",false))
		model.ship_id=identity
		model.tier=model_tier
		wrapper.set_meta("procedural_ship_id",identity)
	wrapper.add_child(model)
	if local_glb_used:
		wrapper.set_meta("local_glb_ship", true)
		_brighten_local_model(model)
	return wrapper

## Local artist GLBs are authored with dark, physically based enamel textures.
## The harbor preview's small model scale and conservative ambient lighting hid
## their color, so lift their material response slightly for in-game readability.
func _brighten_local_model(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var source: Material = mesh_instance.get_surface_override_material(surface)
				if source == null:
					source = mesh_instance.mesh.surface_get_material(surface)
				if source is StandardMaterial3D:
					var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
					# GLB albedo maps, rather than their white material tint, carry most
					# of the hull/deck color. Lift the maps in memory so PBR shading in
					# the sea scene does not crush the trade ships to near-black.
					if material.albedo_texture != null:
						material.albedo_texture = _brighten_texture(material.albedo_texture)
					material.albedo_color = Color(
						minf(1.0, material.albedo_color.r * 1.15),
						minf(1.0, material.albedo_color.g * 1.15),
						minf(1.0, material.albedo_color.b * 1.15),
						material.albedo_color.a)
					material.roughness = maxf(material.roughness, 0.62)
					material.emission_enabled = true
					material.emission = Color("263c3d")
					material.emission_energy_multiplier = 0.16
					mesh_instance.set_surface_override_material(surface, material)
	for child in root.get_children():
		_brighten_local_model(child)

func _brighten_texture(source: Texture2D) -> Texture2D:
	var cache_key: int = source.get_instance_id()
	if _bright_texture_cache.has(cache_key):
		return _bright_texture_cache[cache_key] as Texture2D
	var image: Image = source.get_image()
	if image == null or image.is_empty():
		return source
	image = image.duplicate()
	if image.get_format() != Image.FORMAT_RGBA8 and image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGBA8)
	var luminance_sum: float = 0.0
	var sample_count: int = 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var pixel: Color = image.get_pixel(x, y)
			luminance_sum += pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			sample_count += 1
	var average_luminance: float = luminance_sum / maxf(1.0, float(sample_count))
	# Lighten only dark maps. Sailcloth is already bright and must retain its weave.
	var brightness: float = clampf(0.34 / maxf(average_luminance, 0.1), 1.0, 3.2)
	if brightness <= 1.05:
		_bright_texture_cache[cache_key] = source
		return source
	image.adjust_bcs(brightness, 1.08, 1.04)
	var bright_texture: ImageTexture = ImageTexture.create_from_image(image)
	_bright_texture_cache[cache_key] = bright_texture
	return bright_texture
