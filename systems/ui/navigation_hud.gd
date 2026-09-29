extends CanvasLayer

## Карта известных портов и постоянный компас до выбранной цели или домашней базы.
var _port_system: Node
var _toggle_button: Button
var _panel: PanelContainer
var _destination_list: VBoxContainer
var _course_label: Label
var _chart: Control
var _is_open: bool = false
var _last_destination_id: String = ""
var _last_chart_second: int = -1

func _ready() -> void:
	layer = 25
	_toggle_button = Button.new()
	_toggle_button.text = "КАРТА [N]"
	_toggle_button.custom_minimum_size = Vector2(210, 44)
	_toggle_button.add_theme_font_size_override("font_size", 19)
	_toggle_button.pressed.connect(_toggle_panel)
	add_child(_toggle_button)

	_course_label = Label.new()
	_course_label.add_theme_font_size_override("font_size", 20)
	_course_label.add_theme_color_override("font_color", Color("#fff0a5"))
	_course_label.custom_minimum_size = Vector2(440, 80)
	_course_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_course_label)

	_panel = PanelContainer.new()
	_panel.size = Vector2(680, 760)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0d1c26")
	style.border_color = Color("#c1a448")
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var title := Label.new()
	title.text = "КАРТА МИРА"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)
	var hint := Label.new()
	hint.text = "Колесо мыши — масштаб вокруг корабля · перетаскивание — обзор карты · подписи показывают ваши суда и известные порты"
	hint.add_theme_font_size_override("font_size", 18)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var chart_script: GDScript = load("res://systems/ui/navigation_chart.gd") as GDScript
	_chart = chart_script.new() as Control
	_chart.custom_minimum_size = Vector2(600, 420)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_chart)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 280
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	body.add_child(sidebar)
	var home_button := Button.new()
	home_button.text = "ПРОЛОЖИТЬ КУРС ДОМОЙ"
	home_button.custom_minimum_size.y = 54
	home_button.add_theme_font_size_override("font_size", 20)
	home_button.pressed.connect(_set_home_destination)
	sidebar.add_child(home_button)
	var center_button := Button.new()
	center_button.text = "ЦЕНТР НА МОЁМ СУДНЕ"
	center_button.custom_minimum_size.y = 48
	center_button.add_theme_font_size_override("font_size", 18)
	center_button.pressed.connect(_center_chart_on_ship)
	sidebar.add_child(center_button)

	var destination_title := Label.new()
	destination_title.text = "ИЗВЕСТНЫЕ ПОРТЫ"
	destination_title.add_theme_font_size_override("font_size", 20)
	sidebar.add_child(destination_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	_destination_list = VBoxContainer.new()
	_destination_list.add_theme_constant_override("separation", 6)
	_destination_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_destination_list)
	var close_button := Button.new()
	close_button.text = "ЗАКРЫТЬ КАРТУ  [N]"
	close_button.custom_minimum_size.y = 52
	close_button.add_theme_font_size_override("font_size", 19)
	close_button.pressed.connect(_toggle_panel)
	sidebar.add_child(close_button)
	_panel.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system
	if _chart != null and _chart.has_method("initialize"):
		_chart.call("initialize", _port_system)

func _process(_delta: float) -> void:
	var viewport: Rect2 = get_viewport().get_visible_rect()
	_toggle_button.position = Vector2(12.0, 205.0)
	_course_label.position = Vector2(12.0, 255.0)
	_panel.position = viewport.position
	_panel.size = viewport.size
	_panel.visible = _is_open
	_chart.visible = _is_open

	var destination_id: String = str(GameState.world_state.get("destination_port_id", ""))
	if destination_id != _last_destination_id:
		_last_destination_id = destination_id
		_rebuild_destinations()
	var second: int = int(Time.get_unix_time_from_system())
	if _is_open and second != _last_chart_second:
		_last_chart_second = second
		_chart.queue_redraw()
	_update_course(destination_id)

func _toggle_panel() -> void:
	_is_open = not _is_open
	if _is_open:
		_rebuild_destinations()
		if _chart != null and _chart.has_method("center_on_ship"):
			_chart.call("center_on_ship")
		_chart.queue_redraw()

func _center_chart_on_ship() -> void:
	if _chart != null and _chart.has_method("center_on_ship"):
		_chart.call("center_on_ship")

func _rebuild_destinations() -> void:
	if _destination_list == null or _port_system == null:
		return
	for child in _destination_list.get_children():
		child.queue_free()
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	for raw_port_id in GameState.player_state.get("discovered_port_ids", []):
		var port_id: String = str(raw_port_id)
		if port_id != "" and port_id != home_port_id:
			_add_destination_button(port_id)

func _add_destination_button(port_id: String) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 44
	button.text = _port_system.get_port_name(port_id)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_select_destination.bind(port_id))
	_destination_list.add_child(button)

func _set_home_destination() -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or _port_system == null:
		_course_label.text = "ДОМАШНИЙ ПОРТ НЕ НАЗНАЧЕН"
		return
	if _port_system.select_destination(home_port_id):
		_is_open = false
		_last_destination_id = home_port_id
		_update_course(home_port_id)

func _select_destination(port_id: String) -> void:
	if _port_system != null and _port_system.select_destination(port_id):
		_is_open = false
		_last_destination_id = port_id
		_update_course(port_id)

func _update_course(destination_id: String) -> void:
	var heading: float = float(GameState.ship_state.get("heading", -PI / 2.0))
	var compass_degrees: int = posmod(roundi(rad_to_deg(heading) + 90.0), 360)
	var cardinal_points: Array[String] = ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"]
	var cardinal_index: int = posmod(roundi(float(compass_degrees) / 45.0), 8)
	var compass_text: String = "КОМПАС %s  %03d°" % [cardinal_points[cardinal_index], compass_degrees]
	if _port_system == null:
		_course_label.text = compass_text + "\nНет данных о портах."
		return

	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var active_destination: String = destination_id
	var is_home_target: bool = false
	if active_destination == "":
		active_destination = home_port_id
		is_home_target = active_destination != ""
	elif active_destination == home_port_id:
		is_home_target = true
	if active_destination == "":
		_course_label.text = compass_text + "\nДомашняя база не назначена."
		return

	var target: Vector2 = _port_system.get_port_position(active_destination)
	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var direction: Vector2 = target - ship_position
	var distance: int = int(direction.length())
	var relative_bearing: float = wrapf(direction.angle() - heading, -PI, PI)
	var relative_arrows: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
	var arrow_index: int = posmod(roundi(relative_bearing / (PI / 4.0)), 8)
	var target_name: String = _port_system.get_port_name(active_destination)
	var target_text: String = "ДОМОЙ" if is_home_target else "ЦЕЛЬ: " + target_name
	_course_label.text = compass_text + "\n%s %s  ·  %s  ·  %d м" % [target_text, relative_arrows[arrow_index], target_name, distance]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_N or event.physical_keycode == KEY_N:
		_toggle_panel()
		get_viewport().set_input_as_handled()
