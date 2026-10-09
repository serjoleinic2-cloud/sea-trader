extends CanvasLayer

## Material and timed construction window for base buildings.

var _system: Node
var _root: Control
var _panel: PanelContainer
var _details: Label
var _building_icon: TextureRect
var _material_list: VBoxContainer
var _progress_label: Label
var _progress_bar: ProgressBar
var _start_button: Button
var _cancel_button: Button
var _notice: String = ""
var _is_open: bool = false
var _building_id: String = ""
var _last_refresh_second: int = -1

func _ready() -> void:
	add_to_group("building_project_window")
	layer = 61
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.45, 0.75, 0.38, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation",24)
	margin.add_child(layout)
	var controls := ScrollContainer.new()
	controls.name = "LeftControls"
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.size_flags_stretch_ratio = 1.15
	controls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(controls)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	controls.add_child(box)
	var title: Label = Label.new()
	title.text = "СТРОИТЕЛЬСТВО ЗДАНИЯ"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	_building_icon = TextureRect.new()
	_building_icon.custom_minimum_size = Vector2(360, 320)
	_building_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_building_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_building_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_building_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(_building_icon)
	_details = Label.new()
	_details.set_meta("compact_description", true)
	_details.add_theme_font_size_override("font_size", 14)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size.y = 22
	box.add_child(_progress_bar)
	_material_list = VBoxContainer.new()
	_material_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_material_list.add_theme_constant_override("separation",8)
	box.add_child(_material_list)
	_start_button = Button.new()
	_start_button.add_theme_font_size_override("font_size", 14)
	_start_button.custom_minimum_size.y = 42
	_start_button.pressed.connect(_start)
	box.add_child(_start_button)
	_cancel_button = Button.new()
	_cancel_button.text = "Отменить проект"
	_cancel_button.add_theme_font_size_override("font_size", 14)
	_cancel_button.custom_minimum_size.y = 46
	_cancel_button.pressed.connect(_cancel)
	box.add_child(_cancel_button)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	preload("res://systems/ui/brass_close_button.gd").apply(close_button)
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close_button.custom_minimum_size.y = 46
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_root.hide()

func initialize(system: Node) -> void:
	_system = system

func open_for_building(building_id: String) -> void:
	_building_id = building_id
	var project: Dictionary = _system.get_project(building_id)
	if project.is_empty():
		var result: Dictionary = _system.create_project(building_id)
		_notice = str(result.get("message", ""))
	else:
		_notice = "Открыт ранее подготовленный проект."
	_is_open = true
	_refresh()

func _process(_delta: float) -> void:
	_root.visible = _is_open
	if not _is_open:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(920.0, viewport.x - 32.0), minf(1080.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	var current_second: int = int(Time.get_unix_time_from_system())
	if current_second != _last_refresh_second and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_last_refresh_second = current_second
		_refresh()

func _refresh() -> void:
	if _system == null:
		return
	for child in _material_list.get_children():
		child.queue_free()
	var project: Dictionary = _system.get_project(_building_id)
	if project.is_empty():
		_progress_label.hide()
		_progress_bar.hide()
		_details.text = _notice
		_start_button.text = "ПРОЕКТ НЕДОСТУПЕН"
		_start_button.disabled = true
		_cancel_button.disabled = true
		return
	var building_id: String = str(project.get("building_id", ""))
	var icon_path: String = "res://assets/ui/ports/%s/%s.png" % [str(GameState.player_state.get("origin_race_id", "humans")), building_id]
	if not ResourceLoader.exists(icon_path): icon_path = _system.get_building_icon_path(building_id)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_building_icon.texture = load(icon_path) as Texture2D
		var native_size: Vector2 = _building_icon.texture.get_size()
		_building_icon.custom_minimum_size = native_size
	else:
		_building_icon.texture = null
	var level: int = int(project.get("target_level", 1))
	var required: Dictionary = project.get("required_materials", {})
	var material_status: Dictionary = _system.get_material_status(project)
	var started: bool = _system.is_project_started(project)
	_progress_label.visible = started
	_progress_bar.visible = started
	if started:
		var duration: float = maxf(1.0, float(project.get("duration_sec", 1)))
		var remaining: int = _system.get_project_time_left(project)
		var percent: int = clampi(int(round((1.0 - float(remaining) / duration) * 100.0)), 0, 100)
		_progress_bar.value = percent
		_progress_label.text = "Прогресс строительства: %d%% · осталось %s" % [percent, _format_remaining(remaining)]
	_details.text = "%s — уровень %d / 30\n%s\nДопуск: %d | открытых портов: %d\nЭффект: %s\nСтатус: %s\n%s" % [
		_system.get_building_name(building_id),
		level,
		_system.get_building_description(building_id),
		int(project.get("required_rank", 1)),
		int(project.get("required_ports", 1)),
		_system.get_effect_text(building_id, level),
		_system.get_project_status(project),
		_notice
	]
	for resource_id in required:
		_add_material_row(str(resource_id), material_status.rows[resource_id], started)
	var start_status: Dictionary = _system.get_start_status(building_id)
	_start_button.disabled = not bool(start_status.ok)
	_start_button.tooltip_text = str(start_status.message)
	if started:
		_start_button.text = "СТРОИТЕЛЬСТВО ИДЁТ"
	elif bool(start_status.ok):
		_start_button.text = "ПОСТРОИТЬ" if level == 1 else "УЛУЧШИТЬ"
	else:
		_start_button.text = "НЕ ХВАТАЕТ МАТЕРИАЛОВ" if not bool(material_status.ready) else "СТРОИТЕЛЬСТВО НЕДОСТУПНО"
		_details.text += "\n" + str(start_status.message)
	_cancel_button.disabled = started

func _add_material_row(resource_id: String, status: Dictionary, started: bool) -> void:
	var label: Label = Label.new()
	label.set_meta("compact_description", true)
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if started:
		label.text = "%s: использовано %d" % [_system.get_goods_name(resource_id), int(status.required)]
	else:
		label.text = "%s: нужно %d · доступно %d" % [_system.get_goods_name(resource_id), int(status.required), int(status.available)]
		if int(status.reserved) > 0:
			label.text += " · уже внесено %d" % int(status.reserved)
		if int(status.missing) > 0:
			label.text += " · не хватает %d" % int(status.missing)
		label.modulate = Color("efb186") if int(status.missing) > 0 else Color("a9d9ad")
	_material_list.add_child(label)

func _format_remaining(seconds: int) -> String:
	var minutes: int = seconds / 60
	var remainder: int = seconds % 60
	if minutes > 0:
		return "%d мин %02d сек" % [minutes, remainder]
	return "%d сек" % remainder

func _start() -> void:
	var result: Dictionary = _system.start_project(_building_id)
	_notice = str(result.get("message", ""))
	_refresh()

func _cancel() -> void:
	var result: Dictionary = _system.cancel_project(_building_id)
	_notice = str(result.get("message", ""))
	_refresh()

func _close() -> void:
	_is_open = false
