extends RefCounted

## Shared mini-art for catalog goods and the two currencies. Originals stay local.
const DIRECTORY := "res://assets/ui/resources/painted_v1/"
static var _textures: Dictionary = {}

static func texture(resource_id: String) -> Texture2D:
	if _textures.has(resource_id):
		return _textures[resource_id]
	var path: String = DIRECTORY + resource_id + ".png"
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/styles/approved_hud/" + resource_id + ".png"
	var result: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[resource_id] = result
	return result
