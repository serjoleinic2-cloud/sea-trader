extends CanvasLayer

## Shipyard window with a named project and automatic warehouse funding.

var _system: Node
var _root: Control
var _panel: PanelContainer
var _title: Label
var _ship_icon: TextureRect
var _details: Label
var _name_input: LineEdit
var _name_notice: Label
var _material_list: VBoxContainer
var _build_button: Button
var _notice: String = ""
var _is_open: bool = false
var _last_refresh_second: int = -1

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
	_title = Label.new()
	_title.text = "ВЕРФЬ — СТРОИТЕЛЬСТВО КОРАБЛЯ"
	_title.add_theme_font_size_override("font_size", 16)
	box.add_child(_title)
	_ship_icon = TextureRect.new()
	_ship_icon.custom_minimum_size = Vector2(0, 120)
	_ship_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ship_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ship_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_ship_icon)
	var inspect := Button.new()
	inspect.text = "Осмотреть корабль в 3D"
	inspect.pressed.connect(func(): preload("res://systems/ui/ship_inspection_window.gd").show_ship(self,str(_system.get_project().get("ship_type_id","ship_sloop"))))
	box.add_child(inspect)
	_details = Label.new()
	_details.set_meta("compact_description", true)
	_details.add_theme_font_size_override("font_size", 14)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Имя или номер корабля"
	_name_input.add_theme_font_size_override("font_size", 15)
	_name_input.text_submitted.connect(_save_name)
	box.add_child(_name_input)
	_name_notice = Label.new()
	_name_notice.add_theme_font_size_override("font_size", 12)
	_name_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_notice.modulate = Color(0.82, 0.88, 0.78)
	box.add_child(_name_notice)
	var save_name_button: Button = Button.new()
	save_name_button.text = "Сохранить имя"
	save_name_button.add_theme_font_size_override("font_size", 16)
	save_name_button.custom_minimum_size.y = 46
	save_name_button.pressed.connect(_save_name.bind(""))
	box.add_child(save_name_button)
	_material_list = VBoxContainer.new()
	_material_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_material_list.add_theme_constant_override("separation",8)
	box.add_child(_material_list)
	_build_button = Button.new()
	_build_button.text = "ПОСТРОИТЬ И СПУСТИТЬ НА ВОДУ"
	_build_button.add_theme_font_size_override("font_size", 16)
	_build_button.custom_minimum_size.y = 54
	_build_button.pressed.connect(_finish_project)
	box.add_child(_build_button)
	var cancel_button: Button = Button.new()
	cancel_button.text = "Отменить проект"
	cancel_button.add_theme_font_size_override("font_size", 16)
	cancel_button.custom_minimum_size.y = 46
	cancel_button.pressed.connect(_cancel_project)
	box.add_child(cancel_button)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	preload("res://systems/ui/brass_close_button.gd").apply(close_button)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.custom_minimum_size.y = 46
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
	_panel.size = Vector2(minf(920.0, viewport.x - 32.0), minf(1080.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	var second: int = int(Time.get_unix_time_from_system())
	if second != _last_refresh_second:
		_last_refresh_second = second
		_refresh()

func _refresh() -> void:
	if _system == null:
		return
	for child in _material_list.get_children():
		child.queue_free()
	var project: Dictionary = _system.get_project()
	if project.is_empty():
		_ship_icon.texture = null
		_details.text = _notice
		_build_button.disabled = true
		return
	# Refreshes can happen while the player is typing (for example after a UI
	# update). Never replace an in-progress name with the saved project value.
	if not _name_input.has_focus():
		_name_input.text = str(project.get("name", ""))
	_name_notice.text = _notice
	var required: Dictionary = project.get("required_materials", {})
	var material_status: Dictionary = _system.get_material_status(project)
	var build_status: Dictionary = _system.get_build_status()
	var ready: bool = bool(build_status.ok)
	var ship_type_id: String = str(project.get("ship_type_id", ""))
	var fleet_systems: Array[Node] = get_tree().get_nodes_in_group("fleet_system")
	var ship_type: Dictionary = fleet_systems[0].get_ship_type(ship_type_id) if not fleet_systems.is_empty() else {}
	var icon_path: String = str(ship_type.get("ui_icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_ship_icon.texture = load(icon_path) as Texture2D
	else:
		_ship_icon.texture = null
	_details.text = "%s\n%s\nГруз: %d · скорость: %d\nЭкипаж: %d–%d · допуск: ранг %d\nМатериалы спишутся со склада при постройке." % [
		str(ship_type.get("role", ship_type.get("name", "Корабль"))),
		str(ship_type.get("era", "")),
		int(ship_type.get("cargo_capacity", 0)),
		int(ship_type.get("base_speed", 0)),
		int(ship_type.get("min_crew", 0)),
		int(ship_type.get("max_crew", 0)),
		int(ship_type.get("command_rank_required", 1))
	]
	for resource_id in required:
		_add_material_row(str(resource_id), material_status.rows[resource_id])
	_build_button.disabled = not ready
	_build_button.tooltip_text = str(build_status.message)
	if ready:
		_build_button.text = "ПОСТРОИТЬ"
	else:
		_build_button.text = "НЕ ХВАТАЕТ МАТЕРИАЛОВ" if not bool(material_status.ready) else "ПОСТРОЙКА НЕДОСТУПНА"
		_details.text += "\n" + str(build_status.message)

func _add_material_row(resource_id: String, status: Dictionary) -> void:
	var label: Label = Label.new()
	label.set_meta("compact_description", true)
	label.add_theme_font_size_override("font_size", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s: нужно %d · доступно %d" % [_system.get_goods_name(resource_id), int(status.required), int(status.available)]
	if int(status.reserved) > 0:
		label.text += " · уже внесено %d" % int(status.reserved)
	if int(status.missing) > 0:
		label.text += " · не хватает %d" % int(status.missing)
	label.modulate = Color("efb186") if int(status.missing) > 0 else Color("a9d9ad")
	_material_list.add_child(label)

func _save_name(_submitted_text: String = "") -> void:
	var chosen_name: String = _name_input.text.strip_edges().left(28)
	var result: Dictionary = _system.set_project_name(chosen_name)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_notice = "Имя корабля «%s» сохранено." % chosen_name
	_refresh()
	_name_input.release_focus()

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
