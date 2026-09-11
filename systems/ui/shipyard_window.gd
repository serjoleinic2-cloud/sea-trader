extends CanvasLayer

## Shipyard window with a named project and warehouse material sliders.

var _system: Node
var _root: Control
var _panel: PanelContainer
var _title: Label
var _details: Label
var _name_input: LineEdit
var _material_list: VBoxContainer
var _build_button: Button
var _notice: String = ""
var _is_open: bool = false

func _ready() -> void:
	add_to_group("shipyard_window")
	layer = 60
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.8, 0.55, 0.22, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	_title = Label.new()
	_title.text = "ВЕРФЬ — СТРОИТЕЛЬСТВО КОРАБЛЯ"
	_title.add_theme_font_size_override("font_size", 24)
	box.add_child(_title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 18)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Имя или номер корабля"
	_name_input.add_theme_font_size_override("font_size", 19)
	_name_input.text_submitted.connect(_save_name)
	box.add_child(_name_input)
	var save_name_button: Button = Button.new()
	save_name_button.text = "Сохранить имя"
	save_name_button.custom_minimum_size.y = 36
	save_name_button.pressed.connect(_save_name.bind(""))
	box.add_child(save_name_button)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 400
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_material_list = VBoxContainer.new()
	_material_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_material_list)
	_build_button = Button.new()
	_build_button.text = "ПОСТРОИТЬ И СПУСТИТЬ НА ВОДУ"
	_build_button.custom_minimum_size.y = 46
	_build_button.pressed.connect(_finish_project)
	box.add_child(_build_button)
	var cancel_button: Button = Button.new()
	cancel_button.text = "Отменить проект и вернуть материалы"
	cancel_button.custom_minimum_size.y = 38
	cancel_button.pressed.connect(_cancel_project)
	box.add_child(cancel_button)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size.y = 38
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_root.hide()

func initialize(system: Node) -> void:
	_system = system

func open_for_ship(ship_type_id: String) -> void:
	var project: Dictionary = _system.get_project()
	if project.is_empty():
		var result: Dictionary = _system.create_project(ship_type_id)
		_notice = str(result.get("message", ""))
	else:
		_notice = "Продолжается ранее открытый проект."
	_is_open = true
	_refresh()

func _process(_delta: float) -> void:
	_root.visible = _is_open
	if not _is_open:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(690.0, viewport.x - 24.0), minf(840.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5

func _refresh() -> void:
	if _system == null:
		return
	for child in _material_list.get_children():
		child.queue_free()
	var project: Dictionary = _system.get_project()
	if project.is_empty():
		_details.text = _notice
		_build_button.disabled = true
		return
	_name_input.text = str(project.get("name", ""))
	var required: Dictionary = project.get("required_materials", {})
	var materials: Dictionary = project.get("materials", {})
	var ready: bool = _system.is_project_ready(project)
	_details.text = "Проект: %s\nПередайте материалы со склада. Каждый ползунок переводит материал в верфь.\n%s" % [
		str(project.get("ship_type_id", "")),
		_notice
	]
	for resource_id in required:
		_add_material_row(str(resource_id), int(materials.get(resource_id, 0)), int(required.get(resource_id, 0)))
	_build_button.disabled = not ready
	if ready:
		_build_button.text = "ПОСТРОИТЬ И СПУСТИТЬ НА ВОДУ"
	else:
		_build_button.text = "НЕ ХВАТАЕТ МАТЕРИАЛОВ"

func _add_material_row(resource_id: String, current: int, required: int) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 19)
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
	slider.value_changed.connect(_set_material.bind(resource_id))
	box.add_child(slider)
	_material_list.add_child(box)

func _set_material(value: float, resource_id: String) -> void:
	var result: Dictionary = _system.set_material_amount(resource_id, int(round(value)))
	if not bool(result.get("ok", false)):
		_notice = str(result.get("message", ""))
	_refresh()

func _save_name(_submitted_text: String = "") -> void:
	var result: Dictionary = _system.set_project_name(_name_input.text)
	_notice = str(result.get("message", ""))
	_refresh()

func _finish_project() -> void:
	var result: Dictionary = _system.finish_project()
	_notice = str(result.get("message", ""))
	_refresh()

func _cancel_project() -> void:
	var result: Dictionary = _system.cancel_project()
	_notice = str(result.get("message", ""))
	_refresh()

func _close() -> void:
	_is_open = false
