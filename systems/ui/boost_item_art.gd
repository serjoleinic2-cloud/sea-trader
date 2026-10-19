extends RefCounted

const DIRECTORY := "res://assets/ui/boosts/painted_v1/"
static var _textures: Dictionary = {}

static func texture(stat: String) -> Texture2D:
	if _textures.has(stat): return _textures[stat]
	var path: String = DIRECTORY + stat + ".png"
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/training_scrolls/scroll_%s.svg" % str({"speed":"seafaring", "fuel":"efficiency", "repair":"engineering", "crew_xp":"navigation", "sale":"logistics", "damage":"engineering", "reload":"logistics", "accuracy":"navigation"}.get(stat,"seafaring"))
	var result: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[stat] = result
	return result
