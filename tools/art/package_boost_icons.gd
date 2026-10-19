extends SceneTree

## Resize generated transparent originals kept locally in work/.
const SOURCE := "res://work/art/boosts/painted_v1/"
const DESTINATION := "res://assets/ui/boosts/painted_v1/"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DESTINATION + "prompts.json"))
	var failed: int = 0
	var bytes: int = 0
	for entry in manifest.assets:
		var id: String = str(entry.id)
		var image := Image.load_from_file(SOURCE + id + ".png")
		if image == null or image.is_empty() or image.detect_alpha() == Image.ALPHA_NONE or image.get_pixel(0, 0).a > 0.01:
			push_error("Missing or opaque boost art: " + id)
			failed += 1
			continue
		image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		var path: String = DESTINATION + id + ".png"
		if image.save_png(path) != OK:
			failed += 1
			continue
		bytes += FileAccess.get_file_as_bytes(path).size()
	print("BOOST ART packaged=%d failed=%d bytes=%d" % [manifest.assets.size() - failed, failed, bytes])
	quit(0 if failed == 0 else 1)
