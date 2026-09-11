extends CanvasLayer

## Fleet window: build vessels, assign crew, and run known routes.

var _fleet_system: Node
var _button: Button
var _panel: PanelContainer
var _summary: Label
var _list: VBoxContainer
var _is_open: bool = false
var _selected_ship_id: String = ""
var _notice: String = ""
var _refresh_elapsed: float = 0.0

func _ready() -> void:
	layer = 31
	_button = Button.new()
	_button.text = "ФЛОТ [F]"
	_button.custom_minimum_size = Vector2(180, 40)
	_button.add_theme_font_size_override("font_size", 17)
	_button.pressed.connect(_toggle)
	add_child(_button)
	_panel = PanelContainer.new()
	_panel.size = Vector2(780, 760)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.55, 0.7, 0.3, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "УПРАВЛЕНИЕ ФЛОТОМ"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 18)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 550
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_panel.hide()

func initialize(fleet_system: Node) -> void:
	_fleet_system = fleet_system

func _process(delta: float) -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_button.position = Vector2((viewport.x - _button.size.x) * 0.5, 445.0)
	_panel.position = (viewport - _panel.size) * 0.5
	_panel.visible = _is_open
	if _is_open:
		_refresh_elapsed += delta
		if _refresh_elapsed >= 0.5:
			_refresh_elapsed = 0.0
			_refresh()

func _toggle() -> void:
	_is_open = not _is_open
	if _is_open:
		_refresh_elapsed = 0.0
		_refresh()

func _close() -> void:
	_is_open = false

func _refresh() -> void:
	if _fleet_system == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var docked_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var place_text: String = "В море"
	if docked_port_id != "":
		place_text = "в порту " + _fleet_system._port_system.get_port_name(docked_port_id)
	var progress: Dictionary = _fleet_system.get_command_progress()
	_summary.text = "Ваше судно: %s. Дополнительных кораблей: %d.\nДопуск: %s, ранг %d.\n%s" % [place_text, GameState.fleet_state.size(), str(progress.get("stage_name", "Матрос")), int(progress.get("rank", 1)), _notice]
	_add_active_ship_card()
	for raw_ship in _fleet_system.get_auxiliary_ships():
		var ship: Dictionary = raw_ship
		_add_auxiliary_ship_card(ship)
	_add_build_section(home_port_id, docked_port_id)
	if _selected_ship_id != "":
		_add_selected_ship_actions()

func _create_card() -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.15, 1.0)
	style.border_color = Color(0.18, 0.34, 0.46, 1.0)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	_list.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return box

func _add_active_ship_card() -> void:
	var box: VBoxContainer = _create_card()
	var crew: Array = _fleet_system.get_ship_crew("active_ship")
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 19)
	title.text = "★ ТЕКУЩИЙ КОРАБЛЬ — под вашим управлением | экипаж: %d" % crew.size()
	box.add_child(title)
	var crew_label: Label = Label.new()
	crew_label.add_theme_font_size_override("font_size", 17)
	crew_label.text = _get_crew_text(crew)
	box.add_child(crew_label)

func _add_auxiliary_ship_card(ship: Dictionary) -> void:
	var box: VBoxContainer = _create_card()
	var ship_id: String = str(ship.get("instance_id", ""))
	var crew: Array = ship.get("crew", [])
	var current_port_id: String = str(ship.get("current_port_id", ""))
	var location: String = _fleet_system._port_system.get_port_name(current_port_id)
	var autopilot: Dictionary = ship.get("autopilot", {})
	var status: String = str(ship.get("status", "В порту"))
	if not autopilot.is_empty():
		var now: float = Time.get_unix_time_from_system()
		var elapsed: float = now - float(autopilot.get("started_at", now))
		var duration: float = maxf(1.0, float(autopilot.get("duration_seconds", 1.0)))
		var progress: int = int(clampf(elapsed / duration, 0.0, 1.0) * 100.0)
		status = "В пути к " + _fleet_system._port_system.get_port_name(str(autopilot.get("destination_port_id", ""))) + " — " + str(progress) + "%"
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 19)
	title.text = "%s | %s | порт: %s | экипаж: %d" % [str(ship.get("name", "Корабль")), status, location, crew.size()]
	box.add_child(title)
	var crew_label: Label = Label.new()
	crew_label.add_theme_font_size_override("font_size", 17)
	crew_label.text = _get_crew_text(crew)
	box.add_child(crew_label)
	var select_button: Button = Button.new()
	select_button.text = "Выбрать этот корабль"
	select_button.custom_minimum_size.y = 36
	select_button.pressed.connect(_select_ship.bind(ship_id))
	box.add_child(select_button)

func _add_build_section(home_port_id: String, docked_port_id: String) -> void:
	var box: VBoxContainer = _create_card()
	var title: Label = Label.new()
	title.text = "ВЕРФЬ — постройка нового корабля"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	if home_port_id == "" or docked_port_id != home_port_id:
		var hint: Label = Label.new()
		hint.text = "Постройка доступна только на вашей базе."
		hint.add_theme_font_size_override("font_size", 17)
		box.add_child(hint)
		return
	for raw_type in _fleet_system.get_ship_types():
		var ship_type: Dictionary = raw_type
		var button: Button = Button.new()
		button.custom_minimum_size.y = 38
		button.text = "Построить: %s (допуск %d, трюм %d, цена %.0f)" % [
			str(ship_type.get("name", "Корабль")),
			int(ship_type.get("command_rank_required", 1)),
			int(ship_type.get("cargo_capacity", 0)),
			float(ship_type.get("price", 0.0))
		]
		button.pressed.connect(_build_ship.bind(str(ship_type.get("id", ""))))
		box.add_child(button)

func _add_selected_ship_actions() -> void:
	var ship: Dictionary = _get_selected_ship()
	if ship.is_empty():
		_selected_ship_id = ""
		return
	var box: VBoxContainer = _create_card()
	var title: Label = Label.new()
	title.text = "ПРИКАЗЫ: " + str(ship.get("name", "Корабль"))
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var crew: Array = ship.get("crew", [])
	var current_port_id: String = str(ship.get("current_port_id", ""))
	var autopilot: Dictionary = ship.get("autopilot", {})
	if autopilot.is_empty():
		var routes: Array = _fleet_system.get_routes_from_port(current_port_id)
		if routes.is_empty():
			var hint: Label = Label.new()
			hint.text = "Нет изученных маршрутов из этого порта."
			hint.add_theme_font_size_override("font_size", 17)
			box.add_child(hint)
		for route_info in routes:
			var info: Dictionary = route_info
			var route: Dictionary = info.get("route", {})
			var route_key: String = str(info.get("route_key", ""))
			var other_port_id: String = str(route.get("port_b_id", ""))
			if other_port_id == current_port_id:
				other_port_id = str(route.get("port_a_id", ""))
			var route_button: Button = Button.new()
			route_button.custom_minimum_size.y = 38
			route_button.text = "Автопилот в " + _fleet_system._port_system.get_port_name(other_port_id)
			route_button.pressed.connect(_start_autopilot.bind(_selected_ship_id, route_key))
			box.add_child(route_button)
	else:
		var stop_button: Button = Button.new()
		stop_button.text = "Остановить автопилот"
		stop_button.custom_minimum_size.y = 38
		stop_button.pressed.connect(_stop_autopilot.bind(_selected_ship_id))
		box.add_child(stop_button)
	var crew_title: Label = Label.new()
	crew_title.text = "Перевести сотрудника на выбранный корабль:"
	crew_title.add_theme_font_size_override("font_size", 18)
	box.add_child(crew_title)
	var assigned_any: bool = false
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		var employee_id: String = str(employee.get("employee_instance_id", ""))
		if crew.has(employee_id):
			continue
		assigned_any = true
		var employee_button: Button = Button.new()
		employee_button.custom_minimum_size.y = 36
		employee_button.text = "%s — %s" % [str(employee.get("name", "")), str(employee.get("role_name", ""))]
		employee_button.pressed.connect(_assign_employee.bind(employee_id, _selected_ship_id))
		box.add_child(employee_button)
	if not assigned_any:
		var empty: Label = Label.new()
		empty.text = "Нет свободных сотрудников. Наймите их в любом порту."
		empty.add_theme_font_size_override("font_size", 17)
		box.add_child(empty)
	for employee_id in crew:
		var employee: Dictionary = _fleet_system.get_employee(str(employee_id))
		var return_button: Button = Button.new()
		return_button.custom_minimum_size.y = 34
		return_button.text = "Вернуть: " + str(employee.get("name", "сотрудник")) + " на текущий корабль"
		return_button.pressed.connect(_assign_employee.bind(str(employee_id), "active_ship"))
		box.add_child(return_button)

func _get_selected_ship() -> Dictionary:
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		if str(ship.get("instance_id", "")) == _selected_ship_id:
			return ship
	return {}

func _get_crew_text(crew: Array) -> String:
	if crew.is_empty():
		return "Экипаж не назначен."
	var names: Array[String] = []
	for employee_id in crew:
		var employee: Dictionary = _fleet_system.get_employee(str(employee_id))
		names.append(str(employee.get("name", "сотрудник")))
	return "Экипаж: " + ", ".join(names)

func _select_ship(ship_id: String) -> void:
	_selected_ship_id = ship_id
	_notice = "Корабль выбран."
	_refresh()

func _build_ship(ship_type_id: String) -> void:
	var result: Dictionary = _fleet_system.build_ship(ship_type_id)
	_notice = str(result.get("message", ""))
	_refresh()

func _assign_employee(employee_id: String, ship_id: String) -> void:
	var result: Dictionary = _fleet_system.assign_employee(employee_id, ship_id)
	_notice = str(result.get("message", ""))
	_refresh()

func _start_autopilot(ship_id: String, route_key: String) -> void:
	var result: Dictionary = _fleet_system.start_autopilot(ship_id, route_key)
	_notice = str(result.get("message", ""))
	_refresh()

func _stop_autopilot(ship_id: String) -> void:
	var result: Dictionary = _fleet_system.stop_autopilot(ship_id)
	_notice = str(result.get("message", ""))
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F or event.physical_keycode == KEY_F:
		_toggle()
		get_viewport().set_input_as_handled()
