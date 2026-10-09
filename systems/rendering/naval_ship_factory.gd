extends RefCounted

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
	wrapper.set_meta("reference_length",reference)
	wrapper.scale=Vector3.ONE*target_size/maxf(.01,reference)
	parent.add_child(wrapper)
	var model: Node3D
	var path: String = str(visual.get("local_scene",""))
	if prefer_local and path!="" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene!=null: model=scene.instantiate() as Node3D
	if model==null:
		model=preload("res://systems/rendering/naval_ship_visual.gd").new()
		model.faction_id=str(definition.get("faction_id",faction_id if faction_id!="" else GameState.player_state.get("origin_race_id","humans")))
		model.warship=bool(definition.get("warship",false))
		model.ship_id=identity
		model.tier=model_tier
		wrapper.set_meta("procedural_ship_id",identity)
	wrapper.add_child(model)
	return wrapper
