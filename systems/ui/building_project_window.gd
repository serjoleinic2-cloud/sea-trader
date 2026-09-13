extends CanvasLayer

## Material and timed construction window for base buildings.

var _system: Node
var _root: Control
var _panel: PanelContainer
var _details: Label
var _material_list: VBoxContainer
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
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "ПРОЕКТ БАЗЫ"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 22)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 510
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_material_list = VBoxContainer.new()
	_material_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_material_list)
	_start_button = Button.new()
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.custom_minimum_size.y = 54
	_start_button.pressed.connect(_start)
	box.add_child(_start_button)
	_cancel_button = Button.new()
	_cancel_button.text = "Отменить проект и вернуть материалы"
	_cancel_button.add_theme_font_size_override("font_size", 20)
	_cancel_button.custom_minimum_size.y = 46
	_cancel_button.pressed.connect(_cancel)
	box.add_child(_cancel_button)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.add_theme_font_size_override("font_size", 20)
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
	if current_second != _last_refresh_second:
		_last_refresh_second = current_second
		_refresh()

func _refresh() -> void:
	if _system == null:
		return
	for child in _material_list.get_children():
		child.queue_free()
	var project: Dictionary = _system.get_project(_building_id)
	if project.is_empty():
		_details.text = _notice
		_start_button.text = "ПРОЕКТ НЕДОСТУПЕН"
		_start_button.disabled = true
		_cancel_button.disabled = true
		return
	var building_id: String = str(project.get("building_id", ""))
	var level: int = int(project.get("target_level", 1))
	var required: Dictionary = project.get("required_materials", {})
	var reserved: Dictionary = project.get("materials", {})
	var started: bool = _system.is_project_started(project)
	_details.text = "%s — уровень %d / 30\nДопуск: %d | открытых портов: %d\nЭффект: %s\nСтатус: %s\n%s" % [
		_system.get_building_name(building_id),
		level,
		int(project.get("required_rank", 1)),
		int(project.get("required_ports", 1)),
		_system.get_effect_text(building_id, level),
		_system.get_project_status(project),
		_notice
	]
	for resource_id in required:
		_add_material_row(building_id, str(resource_id), int(reserved.get(resource_id, 0)), int(required.get(resource_id, 0)), started)
	_start_button.disabled = started or not _system.is_project_ready(project)
	_start_button.text = "СТРОИТЕЛЬСТВО ИДЁТ" if started else ("ЗАПУСТИТЬ СТРОИТЕЛЬСТВО" if not _start_button.disabled else "НЕ ХВАТАЕТ МАТЕРИАЛОВ")
	_cancel_button.disabled = started

func _add_material_row(building_id: String, resource_id: String, current: int, required: int, started: bool) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 23)
	label.text = "%s: %d / %d — %d%%" % [
		_system.get_goods_name(resource_id),
		current,
		required,
		int(float(current) / maxf(1.0, float(required)) * 100.0)
	]
	box.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = float(required)
	slider.step = 1.0
	slider.value = float(current)
	slider.editable = not started
	slider.drag_ended.connect(_commit_slider.bind(slider, building_id, resource_id))
	box.add_child(slider)
	_material_list.add_child(box)

func _commit_slider(value_changed: bool, slider: HSlider, building_id: String, resource_id: String) -> void:
	if not value_changed:
		return
	var result: Dictionary = _system.set_material_amount(building_id, resource_id, int(round(slider.value)))
	if not bool(result.get("ok", false)):
		_notice = str(result.get("message", ""))
	_refresh()

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
