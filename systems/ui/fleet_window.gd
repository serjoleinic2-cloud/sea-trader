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

func _process(_delta: float) -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_button.position = Vector2((viewport.x - _button.size.x) * 0.5, 445.0)
	_panel.position = (viewport - _panel.size) * 0.5
	_panel.visible = _is_open

func _toggle() -> void:
	_is_open = not _is_open
	if _is_open:
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
	var details: Button = Button.new()
	details.text = "Экипаж: контракты и характеристики"
	details.custom_minimum_size.y = 44
	details.pressed.connect(_open_active_crew)
	box.add_child(details)

func _open_active_crew() -> void:
	var window: Node = get_parent().get_node_or_null("CrewWindow")
	if window != null:
		window.set("_is_open", true)

func _add_auxiliary_ship_card(ship: Dictionary) -> void:
	var box: VBoxContainer = _create_card()
	var ship_id: String = str(ship.get("instance_id", ""))
	var crew: Array = ship.get("crew", [])
	var voyage: Dictionary = _fleet_system.get_auxiliary_voyage_status(ship_id)
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 19)
	title.text = str(ship.get("name", "Корабль")).to_upper()
	box.add_child(title)
	var route_label: Label = Label.new()
	route_label.add_theme_font_size_override("font_size", 17)
	if bool(voyage.get("in_transit", false)):
		var origin: String = _fleet_system._port_system.get_port_name(str(voyage.get("origin_port_id", "")))
		var destination: String = _fleet_system._port_system.get_port_name(str(voyage.get("destination_port_id", "")))
		route_label.text = "В ПУТИ: %s → %s | %d%% | прибытие через %s" % [
			origin, destination, int(float(voyage.get("progress", 0.0)) * 100.0),
			_format_duration(float(voyage.get("remaining_seconds", 0.0)))
		]
	else:
		route_label.text = "%s | у причала: %s" % [
			str(voyage.get("status", "У причала")),
			_fleet_system._port_system.get_port_name(str(voyage.get("current_port_id", "")))
		]
	box.add_child(route_label)
	var cargo_label: Label = Label.new()
	cargo_label.add_theme_font_size_override("font_size", 17)
	cargo_label.text = "Груз: %d / %d | Экипаж: %d" % [
		int(voyage.get("cargo_units", 0)), int(ship.get("cargo_capacity", 0)), crew.size()
	]
	box.add_child(cargo_label)
	var crew_label: Label = Label.new()
	crew_label.add_theme_font_size_override("font_size", 17)
	crew_label.text = _get_crew_text(crew)
	box.add_child(crew_label)
	var select_button: Button = Button.new()
	select_button.text = "Выбрать этот корабль"
	select_button.custom_minimum_size.y = 36
	select_button.pressed.connect(_select_ship.bind(ship_id))
	box.add_child(select_button)

func _format_duration(seconds: float) -> String:
	var total: int = maxi(0, int(ceil(seconds)))
	var hours: int = total / 3600
	var minutes: int = (total % 3600) / 60
	var remainder: int = total % 60
	if hours > 0:
		return "%d ч %02d мин" % [hours, minutes]
	if minutes > 0:
		return "%d мин %02d сек" % [minutes, remainder]
	return "%d сек" % remainder

func _add_build_section(home_port_id: String, docked_port_id: String) -> void:
	var box: VBoxContainer = _create_card()
	var title: Label = Label.new()
	title.text = "ВЕРФЬ — ПРОЕКТ СТРОИТЕЛЬСТВА"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	if home_port_id == "" or docked_port_id != home_port_id:
		var hint: Label = Label.new()
		hint.text = "Верфь доступна только на вашей базе."
		hint.add_theme_font_size_override("font_size", 17)
		box.add_child(hint)
		return
	var hint: Label = Label.new()
	hint.text = "Выберите корпус: затем передайте древесину, гвозди, ткань и другие материалы со склада."
	hint.add_theme_font_size_override("font_size", 17)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	for raw_type in _fleet_system.get_ship_types():
		var ship_type: Dictionary = raw_type
		var access: Dictionary = _fleet_system.get_ship_access(str(ship_type.get("id", "")))
		var button: Button = Button.new()
		button.custom_minimum_size.y = 38
		button.text = "Открыть проект: %s (допуск %d)%s" % [
			str(ship_type.get("name", "Корабль")),
			int(ship_type.get("command_rank_required", 1)),
			"" if bool(access.get("ok", false)) else " — закрыто"
		]
		button.disabled = not bool(access.get("ok", false))
		button.tooltip_text = str(access.get("message", ""))
		button.pressed.connect(_open_shipyard.bind(str(ship_type.get("id", ""))))
		box.add_child(button)
	var premium_title: Label = Label.new()
	premium_title.text = "ПРЕМИАЛЬНЫЙ ФЛОТ — ОСОБЫЕ РОЛИ"
	premium_title.add_theme_font_size_override("font_size", 20)
	box.add_child(premium_title)
	var premium_hint: Label = Label.new()
	premium_hint.text = "Особые корабли появятся в магазине. Они меняют стиль игры, но не заменяют развитие капитана."
	premium_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premium_hint.add_theme_font_size_override("font_size", 17)
	box.add_child(premium_hint)
	for raw_premium in _fleet_system.get_premium_ship_types():
		var premium: Dictionary = raw_premium
		var premium_button: Button = Button.new()
		premium_button.custom_minimum_size.y = 48
		premium_button.text = "%s  | %s\n%s" % [str(premium.get("name", "Корабль")),
			str(premium.get("role", "Особая роль")), str(premium.get("perk_text", ""))]
		if str(premium.get("acquisition", "shop_rotation")) == "event_reward":
			premium_button.text += "  | НАГРАДА СОБЫТИЯ"
			premium_button.tooltip_text = "Доступен за редкое игровое событие."
		else:
			premium_button.text += "  | СКОРО В МАГАЗИНЕ"
			premium_button.tooltip_text = "Покупка будет подключена после появления серверного магазина."
		premium_button.disabled = true
		box.add_child(premium_button)

func _open_shipyard(ship_type_id: String) -> void:
	var windows: Array[Node] = get_tree().get_nodes_in_group("shipyard_window")
	if not windows.is_empty():
		windows[0].open_for_ship(ship_type_id)

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
		if not ship.get("pending_trade", {}).is_empty():
			var retry: Button = Button.new()
			retry.text = "Повторить продажу оставшегося груза"
			retry.custom_minimum_size.y = 44
			retry.pressed.connect(_retry_trade.bind(_selected_ship_id))
			box.add_child(retry)
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
			route_button.text = "Переход без груза в %s — %.0f" % [_fleet_system._port_system.get_port_name(other_port_id), float(_fleet_system.quote_leg(_selected_ship_id, route_key, 0).get("cash", 0.0))]
			route_button.pressed.connect(_start_autopilot.bind(_selected_ship_id, route_key))
			box.add_child(route_button)
	else:
		var stop_button: Button = Button.new()
		stop_button.text = "Корабль завершает рейс"
		stop_button.disabled = true
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

func _retry_trade(ship_id: String) -> void:
	var result: Dictionary = _fleet_system.retry_trade(ship_id)
	_notice = str(result.get("message", ""))
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F or event.physical_keycode == KEY_F:
		_toggle()
		get_viewport().set_input_as_handled()
