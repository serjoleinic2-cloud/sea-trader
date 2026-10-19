extends RefCounted

## Visual-only overrides. Preserve source materials for reversible fitting.
static func equipped() -> Dictionary:
	return GameState.company_state.get("activity_collection", {}).get("profiles", {}).get(str(GameState.player_state.get("social_id", "")), {}).get("equipped", {})

static func apply(root: Node3D, ids: Array) -> void:
	var catalog: Dictionary = GameData.read("res://data/social/expeditions_and_collection.json").get("styles", {})
	var styles: Dictionary = {}
	for id in ids:
		if catalog.has(str(id)): styles[str(catalog[str(id)].slot)] = catalog[str(id)]
	_visit(root, styles)
	root.set_meta("company_appearance", ids.duplicate())

static func _visit(node: Node, styles: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		if not node.has_meta("appearance_originals"):
			var originals: Array = []
			for index in node.mesh.get_surface_count(): originals.append(node.get_surface_override_material(index))
			node.set_meta("appearance_originals", originals)
		var originals: Array = node.get_meta("appearance_originals")
		for index in node.mesh.get_surface_count():
			node.set_surface_override_material(index, originals[index])
			var original: Material = originals[index] if originals[index] != null else node.mesh.surface_get_material(index)
			if not original is StandardMaterial3D: continue
			var tag: String = (str(node.name) + " " + str(original.resource_name)).to_lower()
			var slot: String = ""
			if styles.has("harbor") and tag.contains("harbor"): slot = "harbor"
			elif tag.contains("sail") or tag.contains("canvas") or tag.contains("парус"): slot = "sail"
			elif tag.contains("hull") or tag.contains("корпус"): slot = "hull"
			elif original.emission_enabled and (tag.contains("engine") or tag.contains("rune") or tag.contains("thruster")): slot = "engine"
			if slot == "" or not styles.has(slot): continue
			var material: StandardMaterial3D = original.duplicate()
			material.albedo_color = Color(str(styles[slot].tint))
			if slot == "engine" or (slot == "harbor" and tag.contains("lamp")):
				material.emission_enabled = true
				material.emission = Color(str(styles[slot].accent))
				material.emission_energy_multiplier = 0.8
			node.set_surface_override_material(index, material)
	for child in node.get_children(): _visit(child, styles)
