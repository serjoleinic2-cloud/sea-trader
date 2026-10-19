extends CanvasLayer

signal purchase_requested(id: String)
signal outfit_requested(ids: Array)
var _panel: PanelContainer
var _preview: Control
var _service: Node
var _product: Dictionary
var _choice: OptionButton
var _original: CheckButton
var _night: CheckButton
var _ids: Array = []

func _ready() -> void:
	layer = 160
	var shade := ColorRect.new()
	shade.color = Color(0, 0.02, 0.04, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	add_child(_panel)
	get_viewport().size_changed.connect(_layout)
	_layout()

func configure(product: Dictionary, service: Node) -> void:
	_product = product
	_service = service
	_ids = product.get("styles", []).duplicate()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_label(header, "ПРИМЕРОЧНАЯ · " + str(product.get("name", "Оформление")), 18)
	var close := Button.new()
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(queue_free)
	header.add_child(close)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	_choice = OptionButton.new()
	_choice.custom_minimum_size.x = 250
	_choice.add_item("Весь комплект")
	for id in _ids: _choice.add_item(str(service.rules.styles.get(str(id), {}).get("name", id)))
	_choice.item_selected.connect(func(_index: int) -> void: _refresh())
	controls.add_child(_choice)
	_original = CheckButton.new(); _original.text = "Без оформления"
	_original.toggled.connect(func(_enabled: bool) -> void: _refresh())
	controls.add_child(_original)
	_night = CheckButton.new(); _night.text = "Ночь"
	_night.toggled.connect(func(enabled: bool) -> void: _preview.set_night(enabled))
	controls.add_child(_night)
	_preview = preload("res://systems/ui/ship_preview.gd").new()
	_preview.name = "FittingModelPreview"
	_preview.stretch_shrink = 1
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	column.add_child(_preview)
	_label(column, "Вращение: перетащите мышью · Масштаб: колесо · Двойной щелчок: исходный ракурс. Примерка не меняет корабль, ресурсы или характеристики.", 12)
	_label(column, str(product.get("description", "")), 12)
	if str(product.get("preview", "")) == "harbor": _label(column, "Схематический визуал базы для проверки модулей. Финальную 3D-модель создаёт владелец проекта.", 12)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	if str(product.get("id", "")) != "":
		_button(actions, "К покупке", func() -> void: purchase_requested.emit(str(product.id)); queue_free())
	var all_owned: bool = not _ids.is_empty()
	for id in _ids: all_owned = all_owned and service.personal().owned_styles.has(str(id))
	if all_owned: _button(actions, "Установить оформление", func() -> void: outfit_requested.emit(_ids); queue_free())
	_button(actions, "Вернуться", queue_free)
	_refresh()

func _refresh() -> void:
	var selection: Array = _ids.duplicate()
	if _choice.selected > 0: selection = [_ids[_choice.selected - 1]]
	if _original.button_pressed: selection = []
	var harbor_style: String = ""
	for id in selection:
		if str(_service.rules.styles.get(str(id), {}).get("slot", "")) == "harbor": harbor_style = str(id)
	var harbor: bool = str(_product.get("preview", "")) == "harbor"
	if _choice.selected > 0: harbor = str(_service.rules.styles.get(str(_ids[_choice.selected - 1]), {}).get("slot", "")) == "harbor"
	var race: String = str(GameState.player_state.get("origin_race_id", "humans"))
	if harbor:
		var entry: Dictionary = _service.clans.clan()
		_preview.show_harbor(_product.get("preview_base", entry.get("base", {})), race, str(entry.get("logo_png", "")), harbor_style)
		_preview.tooltip_text = "Пока схематический визуал. Финальные 3D-модели баз создаёт владелец проекта и хранит локально."
	else:
		if _preview._ship_id == "harbor": _preview._ship_id = ""
		_preview.show_ship(str(GameState.ship_state.get("ship_id", "ship_sloop")))
		if is_instance_valid(_preview._model): preload("res://systems/rendering/company_appearance.gd").apply(_preview._model, selection)
	_preview.set_night(_night.button_pressed)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("fixed_font_size", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new(); button.text = text
	button.set_meta("fixed_font_size", 13)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(action)
	parent.add_child(button)

func _layout() -> void:
	preload("res://systems/ui/workspace_layout.gd").fill_screen(_panel, get_viewport().get_visible_rect().size, preload("res://systems/ui/workspace_layout.gd").safe_top(get_tree()))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()
