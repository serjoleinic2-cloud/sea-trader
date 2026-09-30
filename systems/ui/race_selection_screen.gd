extends CanvasLayer

## First-run captain gallery and origin dossier. The callback is invoked only
## after the player confirms the irreversible first-game choice.

const LOCK_WARNING := "ВНИМАНИЕ: после начала игры сменить выбранную расу в этом сохранении нельзя."

var _factions: Array = []
var _on_confirm: Callable
var _candidate_id: String = ""
var _cards: Dictionary = {}
var _grid: GridContainer
var _gallery_view: VBoxContainer
var _detail_view: VBoxContainer
var _detail_crest: TextureRect
var _detail_portrait: TextureRect
var _detail_title: Label
var _detail_description: Label
var _detail_focus: Label
var _detail_strength: Label
var _detail_weakness: Label
var _choose_button: Button


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
	sea_glow.offset_bottom = 260.0
	sea_glow.color = Color(0.03, 0.31, 0.38, 0.32)
	screen.add_child(sea_glow)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 30.0
	frame.offset_top = 24.0
	frame.offset_right = -30.0
	frame.offset_bottom = -24.0
	frame.add_theme_stylebox_override("panel", _frame_style())
	screen.add_child(frame)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	frame.add_child(margin)

	var views := Control.new()
	views.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(views)

	_gallery_view = VBoxContainer.new()
	_gallery_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery_view.add_theme_constant_override("separation", 12)
	views.add_child(_gallery_view)
	_build_gallery()

	_detail_view = VBoxContainer.new()
	_detail_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_view.add_theme_constant_override("separation", 12)
	views.add_child(_detail_view)
	_build_details()
	_detail_view.hide()
	_update_columns()


func _build_gallery() -> void:
	_gallery_view.add_child(_make_header())

	var warning := Label.new()
	warning.text = LOCK_WARNING
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color("#e5be78"))
	warning.add_theme_font_size_override("font_size", 17)
	_gallery_view.add_child(warning)

	_grid = GridContainer.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_gallery_view.add_child(_grid)

	for faction_value in _factions:
		if faction_value is Dictionary:
			_add_faction_card(faction_value)

	var note := Label.new()
	note.text = "Наведите курсор, чтобы выделить капитана. Нажмите на карточку, чтобы открыть досье и сравнить сильные и слабые стороны."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#b6c9c9"))
	note.add_theme_font_size_override("font_size", 16)
	_gallery_view.add_child(note)


func _make_header() -> Control:
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 18)
	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(64, 64)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = GameData.get_faction_emblem("sea_trader")
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(logo)
	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "ВЫБЕРИТЕ КАПИТАНА И ПРОИСХОЖДЕНИЕ"
	title.add_theme_color_override("font_color", Color("#f2e5c7"))
	title.add_theme_font_size_override("font_size", 29)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Шесть народов одного морского мира"
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
	card.custom_minimum_size = Vector2(145, 430)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.clip_contents = false
	card.pivot_offset = card.custom_minimum_size * 0.5
	card.add_theme_stylebox_override("normal", _card_style(Color("#112b38"), Color("#465962"), 1))
	card.add_theme_stylebox_override("hover", _card_style(Color("#173b49"), Color("#8bc6c3"), 2))
	card.add_theme_stylebox_override("pressed", _card_style(Color("#17424e"), Color("#52d4d4"), 3))
	card.add_theme_stylebox_override("focus", _card_style(Color("#173b49"), Color("#52d4d4"), 3))
	card.mouse_entered.connect(_animate_card_hover.bind(card, true))
	card.mouse_exited.connect(_animate_card_hover.bind(card, false))
	card.pressed.connect(_open_dossier.bind(faction_id))
	_grid.add_child(card)
	_cards[faction_id] = card
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)

	var crest := TextureRect.new()
	crest.custom_minimum_size = Vector2(52, 52)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.texture = GameData.get_faction_emblem(faction_id)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(crest)

	var portrait := TextureRect.new()
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = GameData.get_faction_portrait(faction_id)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(portrait)

	var name_label := Label.new()
	name_label.text = str(faction.get("name", faction_id))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color("#f0dfbb"))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(name_label)

	var focus_label := Label.new()
	focus_label.text = str(faction.get("origin_focus", ""))
	focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_label.add_theme_color_override("font_color", Color("#72ddd2"))
	focus_label.add_theme_font_size_override("font_size", 13)
	focus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(focus_label)


func _build_details() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_detail_crest = TextureRect.new()
	_detail_crest.custom_minimum_size = Vector2(72, 72)
	_detail_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_detail_crest)
	_detail_title = Label.new()
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_title.add_theme_color_override("font_color", Color("#f2e5c7"))
	_detail_title.add_theme_font_size_override("font_size", 29)
	header.add_child(_detail_title)
	_detail_view.add_child(header)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 24)
	_detail_view.add_child(main)
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(300, 0)
	portrait_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_panel.add_theme_stylebox_override("panel", _card_style(Color("#0d222d"), Color("#526b6d"), 1))
	main.add_child(portrait_panel)
	var portrait_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		portrait_margin.add_theme_constant_override("margin_" + side, 8)
	portrait_panel.add_child(portrait_margin)
	_detail_portrait = TextureRect.new()
	_detail_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_margin.add_child(_detail_portrait)

	var dossier := VBoxContainer.new()
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier.add_theme_constant_override("separation", 14)
	main.add_child(dossier)
	_detail_description = _detail_block(dossier, "НАРОД И КАПИТАН", "", Color("#d8e5df"), 18)
	_detail_focus = _detail_block(dossier, "СТИЛЬ ИГРЫ", "", Color("#76ded5"), 17)
	_detail_strength = _detail_block(dossier, "ПРЕИМУЩЕСТВО", "", Color("#9cdb9a"), 17)
	_detail_weakness = _detail_block(dossier, "СЛАБАЯ СТОРОНА", "", Color("#e2ae83"), 17)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier.add_child(spacer)

	var warning := Label.new()
	warning.text = LOCK_WARNING
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color("#f0bd68"))
	warning.add_theme_font_size_override("font_size", 18)
	_detail_view.add_child(warning)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	_detail_view.add_child(actions)
	var back_button := Button.new()
	back_button.text = "НАЗАД"
	back_button.custom_minimum_size = Vector2(210, 58)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.add_theme_stylebox_override("normal", _button_style(Color("#182d38"), Color("#8d9da0"), 1))
	back_button.add_theme_stylebox_override("hover", _button_style(Color("#263f4b"), Color("#d6e1df"), 2))
	back_button.pressed.connect(_back_to_gallery)
	actions.add_child(back_button)
	_choose_button = Button.new()
	_choose_button.text = "ВЫБРАТЬ ЭТУ РАСУ"
	_choose_button.custom_minimum_size = Vector2(320, 58)
	_choose_button.add_theme_font_size_override("font_size", 20)
	_choose_button.add_theme_color_override("font_color", Color("#f5edda"))
	_choose_button.add_theme_stylebox_override("normal", _button_style(Color("#073b49"), Color("#c6a45d"), 2))
	_choose_button.add_theme_stylebox_override("hover", _button_style(Color("#0c5661"), Color("#52d4d4"), 3))
	_choose_button.pressed.connect(_confirm_choice)
	actions.add_child(_choose_button)


func _detail_block(parent: VBoxContainer, heading: String, value: String, color: Color, font_size: int) -> Label:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	parent.add_child(block)
	var label := Label.new()
	label.text = heading
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 15)
	block.add_child(label)
	var text := Label.new()
	text.text = value
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", Color("#e1e8e2"))
	text.add_theme_font_size_override("font_size", font_size)
	block.add_child(text)
	return text


func _open_dossier(faction_id: String) -> void:
	var faction: Dictionary = GameData.get_faction(faction_id)
	if faction.is_empty():
		return
	_candidate_id = faction_id
	_detail_title.text = str(faction.get("name", faction_id))
	_detail_crest.texture = GameData.get_faction_emblem(faction_id)
	_detail_portrait.texture = GameData.get_faction_portrait(faction_id)
	_detail_description.text = str(faction.get("origin_description", ""))
	_detail_focus.text = str(faction.get("origin_focus", ""))
	_detail_strength.text = str(faction.get("origin_strength", ""))
	_detail_weakness.text = str(faction.get("origin_weakness", ""))
	_gallery_view.hide()
	_detail_view.show()


func _back_to_gallery() -> void:
	_candidate_id = ""
	_detail_view.hide()
	_gallery_view.show()


func _confirm_choice() -> void:
	if _candidate_id == "" or not _on_confirm.is_valid():
		return
	_choose_button.disabled = true
	_on_confirm.call(_candidate_id)


func _animate_card_hover(card: Button, hovered: bool) -> void:
	card.z_index = 4 if hovered else 0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * (1.055 if hovered else 1.0), 0.14)


func _update_columns() -> void:
	if _grid == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	_grid.columns = 6 if width >= 980.0 else (3 if width >= 700.0 else 2)


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
