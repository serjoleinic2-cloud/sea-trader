extends RefCounted

## Loads artist GLBs stored under the Git-ignored work/ directory.
## A cached PackedScene keeps repeated fleet previews from parsing the same file.
static var _scene_cache: Dictionary = {}

static func instantiate(path: String) -> Node3D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var modified: int = FileAccess.get_modified_time(path)
	var cached: Dictionary = _scene_cache.get(path, {})
	if cached.is_empty() or int(cached.get("modified", -1)) != modified:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var packed: PackedScene
		if document.append_from_file(path, state) == OK:
			var generated: Node = document.generate_scene(state)
			if generated != null:
				packed = PackedScene.new()
				if packed.pack(generated) != OK:
					packed = null
				generated.free()
		if packed == null:
			push_warning("Local ship GLB could not be loaded; using procedural ship: %s" % path)
		cached = {"modified": modified, "scene": packed}
		_scene_cache[path] = cached
	var packed_scene: PackedScene = cached.get("scene") as PackedScene
	return packed_scene.instantiate() as Node3D if packed_scene != null else null
