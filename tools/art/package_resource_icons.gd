extends SceneTree

## Package approved, already generated artwork; never alters local originals.
const SOURCE := "res://work/art/resource_icons/painted_v1/"
const DESTINATION := "res://assets/ui/resources/painted_v1/"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DESTINATION + "prompts.json"))
	DirAccess.make_dir_recursive_absolute(DESTINATION)
	var failed := 0
	var bytes := 0
	for entry in manifest.get("assets", []):
		var id: String = str(entry.id)
		var image := Image.load_from_file(SOURCE + id + ".png")
		if image == null or image.is_empty():
			push_error("Missing local resource artwork: " + id)
			failed += 1
			continue
		if image.detect_alpha() == Image.ALPHA_NONE or image.get_pixel(0, 0).a > 0.01:
			push_error("Resource art needs real transparency: " + id)
			failed += 1
			continue
		image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		var path: String = DESTINATION + id + ".png"
		if image.save_png(path) != OK:
			push_error("Could not package resource artwork: " + id)
			failed += 1
			continue
		bytes += FileAccess.get_file_as_bytes(path).size()
	print("RESOURCE ART packaged=%d failed=%d bytes=%d" % [manifest.get("assets", []).size() - failed, failed, bytes])
	quit(0 if failed == 0 else 1)
