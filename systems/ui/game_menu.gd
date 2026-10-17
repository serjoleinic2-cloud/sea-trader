extends CanvasLayer

## One pause menu; gameplay windows contain only their own actions.
const Settings = preload("res://systems/ui/game_settings.gd")
const Layout = preload("res://systems/ui/workspace_layout.gd")
var _is_open := false
var _was_paused := false
var _root: Control
var _panel: PanelContainer
var _content: VBoxContainer
var _status: Label
var _apply_button: Button
var _draft: Dictionary = {}
var _tabs: Dictionary = {}
var _section := "graphics"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	add_to_group("game_menu")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.015, 0.025, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "GameMenuPanel"
	_panel.theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = _label("ИГРОВОЕ МЕНЮ", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.name = "CloseButton"
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(close_menu)
	header.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 180
	body.add_child(navigation)
	for choice in [["graphics", "Графика"], ["sound", "Звук"], ["controls", "Управление"], ["save", "Сохранение и загрузка"]]:
		var button: Button = _button(str(choice[1]), _show_section.bind(str(choice[0])))
		button.toggle_mode = true
		navigation.add_child(button)
		_tabs[str(choice[0])] = button
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	_status = _label("", 13)
	_status.name = "GameMenuStatus"
	column.add_child(_status)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	footer.add_child(_button("Продолжить игру", close_menu))
	_apply_button = _button("Применить настройки", _apply_settings)
	_apply_button.name = "ApplySettings"
	footer.add_child(_apply_button)
	_root.hide()
	Settings.apply(get_tree(), GameState.settings_state)

func _label(value: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("compact_description", true)
	label.set_meta("ui_base_font_size", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.set_meta("compact_description", true)
	button.set_meta("ui_base_font_size", 12)
	button.set_meta("ui_base_min_height", 34)
	button.pressed.connect(callback)
	return button

func open_menu() -> void:
	if _is_open:
		return
	_was_paused = get_tree().paused
	_draft = Settings.normalized(GameState.settings_state)
	_is_open = true
	_root.show()
	_status.text = "Игра приостановлена."
	_show_section(_section)
	get_tree().paused = true

func close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	_root.hide()
	get_tree().paused = _was_paused

func _process(_delta: float) -> void:
	if _is_open:
		Layout.fill_screen(_panel, get_viewport().get_visible_rect().size, Layout.safe_top(get_tree()))

func _show_section(section: String) -> void:
	_section = section
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for id in _tabs:
		_tabs[id].set_pressed_no_signal(str(id) == section)
	_apply_button.visible = section != "save"
	match section:
		"graphics":
			_content.add_child(_label("ГРАФИКА", 18))
			_content.add_child(_label("Нажмите «Применить настройки». Масштаб 3D не меняет резкость текста и меню.", 13))
			_water_quality_slider()
			_choice("След и брызги кораблей", "ship_wake_quality", ["Выключено", "Лёгкий", "Подробный"], ["off", "low", "high"])
			_choice("Дальность прорисовки", "view_distance", ["Ближняя", "Средняя", "Дальняя"], ["near", "medium", "far"])
			_toggle("Полноэкранный режим", "fullscreen")
			_toggle("VSync", "vsync")
			_content.add_child(_label("Синхронизирует кадры с монитором и убирает разрывы изображения. Иногда снижает FPS и добавляет небольшую задержку управления.", 12))
			_choice("Ограничение FPS", "fps_limit", ["30", "60", "120", "Без ограничения"], [30, 60, 120, 0])
			_choice("Разрешение 3D", "render_scale", ["100%", "85%", "70%"], [1.0, 0.85, 0.7])
			_toggle("Сглаживание краёв", "antialiasing")
			_toggle("Облака в небе", "clouds_enabled")

		"sound":
			_content.add_child(_label("ЗВУК", 18))
			_slider("Громкость игры", "master_volume", 0.0, 1.0, 0.05, true)
			_slider("Орудия и звуковые эффекты", "sfx_volume", 0.0, 1.0, 0.05, true)
		"controls":
			_content.add_child(_label("УПРАВЛЕНИЕ", 18))
			_choice("Размер текста", "ui_scale", ["100%", "125%", "150%"], [1.0, 1.25, 1.5])
			var keys := GridContainer.new()
			keys.columns = 2
			keys.add_theme_constant_override("h_separation", 24)
			_content.add_child(keys)
			for row in [["W / S", "Ход вперёд / назад"], ["A / D", "Поворот"], ["Пробел — удерживать", "Остановить корабль"], ["E", "Швартовка / выйти в море"], ["F", "Флот и верфь"], ["Z", "Начать / открыть морской бой"], ["R", "Исследовать обломки"], ["ПКМ / колесо", "Камера; на тактической карте — перемещение / масштаб"], ["Esc", "Закрыть окно; из плавания — игровое меню"]]:
				keys.add_child(_label(str(row[0]), 13))
				keys.add_child(_label(str(row[1]), 13))
			_content.add_child(_label("Управление наклоном устройства:", 14))
			_slider("Чувствительность наклона", "control_sensitivity", 0.5, 2.0, 0.1)
			_toggle("Инверсия поворота при наклоне", "control_inversion")
		"save":
			_content.add_child(_label("СОХРАНЕНИЕ И ЗАГРУЗКА", 18))
			_content.add_child(_label("Сохранить текущее плавание, флот, ресурсы и развитие базы. В игре также работает автосохранение.", 14))
			var save_button: Button = _button("Сохранить игру", _save_game)
			save_button.name = "SaveGame"
			_content.add_child(save_button)
			var load_button: Button = _button("Загрузить последнее сохранение", _request_load)
			load_button.name = "LoadGame"
			load_button.disabled = not SaveSystem.has_save()
			_content.add_child(load_button)

func _row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label: Label = _label(title, 13)
	label.custom_minimum_size.x = 260
	row.add_child(label)
	_content.add_child(row)
	return row

func _toggle(title: String, key: String) -> HBoxContainer:
	var row: HBoxContainer = _row(title)
	var toggle := Button.new()
	toggle.name = "Setting_" + key
	toggle.toggle_mode = true
	toggle.button_pressed = bool(_draft.get(key, false))
	toggle.text = "Вкл" if toggle.button_pressed else "Выкл"
	toggle.custom_minimum_size.x = 78
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.set_meta("compact_description", true)
	toggle.set_meta("ui_base_font_size", 12)
	toggle.toggled.connect(func(value: bool):
		_draft[key] = value
		toggle.text = "Вкл" if value else "Выкл")
	row.add_child(toggle)
	return row

func _choice(title: String, key: String, captions: Array, values: Array) -> void:
	var row: HBoxContainer = _row(title)
	var choice := OptionButton.new()
	choice.name = "Setting_" + key
	choice.set_meta("compact_description", true)
	choice.set_meta("ui_base_font_size", 12)
	choice.add_theme_font_size_override("font_size", 15)
	for index in captions.size():
		choice.add_item(str(captions[index]))
		if _draft.get(key) == values[index]:
			choice.select(index)
	choice.item_selected.connect(func(index: int): _draft[key] = values[index])
	row.add_child(choice)

func _water_quality_slider() -> void:
	var row: HBoxContainer = _row("Качество воды")
	var column := VBoxContainer.new()
	row.add_child(column)
	var slider := HSlider.new()
	slider.name = "Setting_water_quality"
	slider.custom_minimum_size = Vector2(320, 30)
	slider.max_value = 2
	slider.step = 1
	slider.tick_count = 3
	slider.ticks_on_borders = true
	var values: Array[String] = ["low", "medium", "high"]
	slider.value = values.find(str(_draft.water_quality))
	column.add_child(slider)
	var stops := HBoxContainer.new()
	column.add_child(stops)
	for text in ["Минимум", "Средняя", "Максимум"]:
		var stop: Label = _label(text, 11)
		stop.autowrap_mode = TextServer.AUTOWRAP_OFF
		stop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stops.add_child(stop)
	var descriptions: Array[String] = ["Лёгкая поверхность, без преломления и пены.", "Волны, мелководье и береговая пена.", "Волны, пена и преломление на мелководье."]
	var caption: Label = _label(descriptions[int(slider.value)], 12)
	column.add_child(caption)
	slider.value_changed.connect(func(value: float):
		_draft.water_quality = values[int(value)]
		caption.text = descriptions[int(value)])

func _slider(title: String, key: String, minimum: float, maximum: float, step_value: float, percent: bool = false) -> void:
	var row: HBoxContainer = _row(title)
	var slider := HSlider.new()
	slider.name = "Setting_" + key
	slider.custom_minimum_size = Vector2(200, 30)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.value = float(_draft.get(key, 1.0))
	row.add_child(slider)
	var value_label: Label = _label("%d%%" % roundi(slider.value * 100.0) if percent else "%.1f" % slider.value, 13)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float):
		_draft[key] = value
		value_label.text = "%d%%" % roundi(value * 100.0) if percent else "%.1f" % value)

func _apply_settings() -> void:
	Settings.apply(get_tree(), _draft)
	_status.text = "Настройки применены и сохранены." if SaveSystem.save_game() else "Настройки применены; записать сохранение не удалось."

func _save_game() -> void:
	Settings.apply(get_tree(), _draft)
	_status.text = "Игра сохранена." if SaveSystem.save_game() else "Не удалось сохранить игру. Прогресс остаётся в текущей игре."

func _request_load() -> void:
	_show_section("save")
	_content.add_child(_label("Загрузить последнее сохранение? Несохранённые изменения текущей игры будут заменены.", 14))
	var row := HBoxContainer.new()
	_content.add_child(row)
	var confirm: Button = _button("Да, загрузить", _load_game)
	confirm.name = "ConfirmLoad"
	row.add_child(confirm)
	row.add_child(_button("Отмена", _show_section.bind("save")))

func _load_game() -> void:
	if not SaveSystem.load_game():
		_status.text = "Загрузить сохранение не удалось. Текущая игра не закрыта."
		return
	get_tree().paused = false
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		get_tree().paused = true
		_status.text = "Не удалось перезапустить игровой мир: %s." % error_string(error)

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()
