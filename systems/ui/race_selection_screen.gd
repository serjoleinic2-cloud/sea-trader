extends CanvasLayer

## First-run origin selection. The selected faction ID is returned to Main;
## this screen never writes save data directly.

var _factions: Array = []
var _on_confirm: Callable
var _selected_id: String = ""
var _cards: Dictionary = {}
var _grid: GridContainer
var _selected_label: Label
var _confirm_button: Button


func configure(factions: Array, on_confirm: Callable) -> void:
	_factions = factions.duplicate(true)
	_on_confirm = on_confirm


func _ready() -> void:
	layer = 120
	_build()
	get_viewport().size_changed.connect(_update_columns)


func _build() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#061724")
	screen.add_child(backdrop)

	var sea_glow := ColorRect.new()
	sea_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sea_glow.offset_bottom = 230.0
	sea_glow.color = Color(0.03, 0.31, 0.38, 0.32)
	screen.add_child(sea_glow)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 34.0
	frame.offset_top = 28.0
	frame.offset_right = -34.0
	frame.offset_bottom = -28.0
	frame.add_theme_stylebox_override("panel", _frame_style())
	screen.add_child(frame)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	frame.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	content.add_child(_make_header())

	_grid = GridContainer.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	content.add_child(_grid)
	_update_columns()

	for faction_value in _factions:
		if faction_value is Dictionary:
			_add_faction_card(faction_value)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	content.add_child(footer)

	_selected_label = Label.new()
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selected_label.add_theme_color_override("font_color", Color("#d7e9e9"))
	_selected_label.add_theme_font_size_override("font_size", 18)
	_selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_selected_label)

	_confirm_button = Button.new()
	_confirm_button.text = "НАЧАТЬ ПУТЬ"
	_confirm_button.custom_minimum_size = Vector2(280, 68)
	_confirm_button.add_theme_font_size_override("font_size", 22)
	_confirm_button.add_theme_color_override("font_color", Color("#f5edda"))
	_confirm_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_confirm_button.add_theme_stylebox_override("normal", _button_style(Color("#073b49"), Color("#c6a45d"), 2))
	_confirm_button.add_theme_stylebox_override("hover", _button_style(Color("#0c5661"), Color("#52d4d4"), 3))
	_confirm_button.add_theme_stylebox_override("pressed", _button_style(Color("#092d39"), Color("#52d4d4"), 3))
	_confirm_button.pressed.connect(_confirm_selection)
	footer.add_child(_confirm_button)

	var note := Label.new()
	note.text = "Каждая раса торгует и сражается. Выбор задаёт ваше происхождение и герб, но не закрывает пути к другим народам."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#a9bec0"))
	note.add_theme_font_size_override("font_size", 15)
	content.add_child(note)

	if not _factions.is_empty():
		_select_faction(str(_factions[0].get("id", "")))
	else:
		_selected_label.text = "Не удалось загрузить каталог рас."
		_confirm_button.disabled = true


func _make_header() -> Control:
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 20)
	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(76, 76)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = GameData.get_faction_emblem("sea_trader")
	header.add_child(logo)
	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "ВЫБЕРИТЕ СВОЁ ПРОИСХОЖДЕНИЕ"
	title.add_theme_color_override("font_color", Color("#f2e5c7"))
	title.add_theme_font_size_override("font_size", 31)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Пять народов одного морского мира"
	subtitle.add_theme_color_override("font_color", Color("#56d5d4"))
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(subtitle)
	header.add_child(title_box)
	return header


func _add_faction_card(faction: Dictionary) -> void:
	var faction_id := str(faction.get("id", ""))
	if faction_id == "":
		return
	var card := Button.new()
	card.custom_minimum_size = Vector2(210, 340)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.clip_contents = true
	card.add_theme_stylebox_override("normal", _card_style(Color("#112b38"), Color("#465962"), 1))
	card.add_theme_stylebox_override("hover", _card_style(Color("#173b49"), Color("#8bc6c3"), 2))
	card.add_theme_stylebox_override("pressed", _card_style(Color("#17424e"), Color("#52d4d4"), 3))
	card.add_theme_stylebox_override("focus", _card_style(Color("#173b49"), Color("#52d4d4"), 3))
	card.pressed.connect(_select_faction.bind(faction_id))
	_grid.add_child(card)
	_cards[faction_id] = card

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)

	var identity := HBoxContainer.new()
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 10)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(identity)
	var emblem := TextureRect.new()
	emblem.custom_minimum_size = Vector2(46, 46)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.texture = GameData.get_faction_emblem(faction_id)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(emblem)
	var name_label := Label.new()
	name_label.text = str(faction.get("name", faction_id))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color("#f0dfbb"))
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(name_label)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 118)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = GameData.get_faction_portrait(faction_id)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(portrait)

	var trade := Label.new()
	trade.text = "ТОРГОВЛЯ  ·  " + _join_words(faction.get("trade_identity", []), 3)
	trade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade.add_theme_color_override("font_color", Color("#72ddd2"))
	trade.add_theme_font_size_override("font_size", 13)
	trade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(trade)

	var combat := Label.new()
	combat.text = "БОЕВОЙ СТИЛЬ  ·  " + str(faction.get("origin_combat_summary", faction.get("combat_identity", "")))
	combat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat.add_theme_color_override("font_color", Color("#d6c29d"))
	combat.add_theme_font_size_override("font_size", 13)
	combat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(combat)

	var selected := Label.new()
	selected.name = "SelectedMark"
	selected.text = "ВЫБРАНО"
	selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected.add_theme_color_override("font_color", Color("#55e0dc"))
	selected.add_theme_font_size_override("font_size", 15)
	selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(selected)
	selected.hide()


func _select_faction(faction_id: String) -> void:
	if not _cards.has(faction_id):
		return
	_selected_id = faction_id
	for id in _cards:
		var card: Button = _cards[id]
		var selected: bool = str(id) == _selected_id
		card.add_theme_stylebox_override("normal", _card_style(
			Color("#153b48") if selected else Color("#112b38"),
			Color("#55dcd9") if selected else Color("#465962"),
			3 if selected else 1))
		var mark: Label = card.find_child("SelectedMark", true, false)
		if mark != null:
			mark.visible = selected
	var faction: Dictionary = GameData.get_faction(_selected_id)
	_selected_label.text = "Ваш герб: %s" % str(faction.get("name", _selected_id))
	_confirm_button.disabled = false


func _confirm_selection() -> void:
	if _selected_id == "" or not _on_confirm.is_valid():
		return
	_confirm_button.disabled = true
	_on_confirm.call(_selected_id)


func _update_columns() -> void:
	if _grid == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	_grid.columns = 5 if width >= 1160.0 else (3 if width >= 900.0 else 2)


func _join_words(values: Variant, max_items: int) -> String:
	if not values is Array:
		return ""
	var words := PackedStringArray()
	for index in range(mini(values.size(), max_items)):
		words.append(str(values[index]))
	return " · ".join(words)


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.048, 0.068, 0.98)
	style.border_color = Color("#b49558")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 14
	return style


func _card_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 6
	return style


func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style
