extends RefCounted

## Repository contains code/manifests, while optional artist models stay in work/.
## A clean checkout always has the procedural geometry as a working fallback.
func attach(parent: Node3D, identity: String, target_size: float, prefer_local: bool = true) -> Node3D:
	var definition: Dictionary = GameData.get_ship(identity)
	if not bool(definition.get("warship",false)): return null
	var visual: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships",{}).get(identity,{})
	var wrapper:=Node3D.new()
	wrapper.name="Asset_"+identity
	wrapper.set_meta("world_asset_id",identity)
	wrapper.set_meta("reference_length",float(visual.get("length",5.1)))
	wrapper.scale=Vector3.ONE*target_size/maxf(.01,float(visual.get("length",5.1)))
	parent.add_child(wrapper)
	var model: Node3D
	var path: String = str(visual.get("local_scene",""))
	if prefer_local and path!="" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene!=null: model=scene.instantiate() as Node3D
	if model==null:
		model=preload("res://systems/rendering/naval_ship_visual.gd").new()
		model.faction_id=str(definition.faction_id)
		model.tier=int(definition.tier)
		wrapper.set_meta("procedural_ship_id",identity)
	wrapper.add_child(model)
	return wrapper
