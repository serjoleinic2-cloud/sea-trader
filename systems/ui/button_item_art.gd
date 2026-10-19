extends RefCounted

static var _textures: Dictionary = {}

static func apply(button: Button) -> void:
	if str(button.get_meta("action_art_checked_text", "\u0001")) == button.text: return
	button.set_meta("action_art_checked_text", button.text)
	if button.icon != null or button.text.strip_edges() == "" or button is OptionButton or button is CheckBox or button is CheckButton: return
	for marker in ["selection_card", "resource_id", "preserve_art_style", "boost_tile_action", "brass_close"]:
		if button.has_meta(marker): return
	var text: String = button.text.strip_edges().to_lower()
	var path: String = ""
	for entry in [
		[["купить", "продать", "торговать"], "resources/painted_v1/money.png"],
		[["нанять", "назначить", "персонал", "экипаж"], "styles/approved_hud/captain.png"],
		[["построить", "улучшить", "ремонт", "починить"], "resources/painted_v1/resource_parts.png"],
		[["курс", "карта", "домой"], "styles/approved_hud/map.png"],
		[["задания", "забрать груз", "разгрузить", "подать заявку"], "styles/approved_hud/tasks.png"],
		[["создать клан", "мой клан"], "social/clan.svg"],
		[["кланы"], "social/clans.svg"],
		[["магазин"], "social/shop.svg"],
		[["друзья"], "social/chat.svg"]
	]:
		for prefix in entry[0]:
			if text.begins_with(str(prefix)): path = "res://assets/ui/" + str(entry[1]); break
		if path != "": break
	if path == "": return
	if not _textures.has(path): _textures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	button.icon = _textures[path]
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 18)
	button.add_theme_constant_override("h_separation", 6)
