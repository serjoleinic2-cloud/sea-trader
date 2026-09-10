extends CanvasLayer

## Central port window with a separate home-port development panel.

var _port_system: Node
var _root: Control
var _sheet: PanelContainer
var _title: Label
var _details: Label
var _building_list: VBoxContainer
var _plan_button: Button
var _save_button: Button
var _leave_button: Button
var _building_catalog: Array = []
var _selected_building_id: String = ""
var _last_home_port_id: String = ""
var _notice: String = ""

func _ready() -> void:
	layer = 35
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.38)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	_sheet = PanelContainer.new()
	_sheet.size = Vector2(540, 760)
	_root.add_child(_sheet)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_sheet.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 19)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_details)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 260
	column.add_child(scroll)
	_building_list = VBoxContainer.new()
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_building_list)
	_plan_button = Button.new()
	_plan_button.text = "Запланировать строительство"
	_plan_button.custom_minimum_size.y = 42
	_plan_button.pressed.connect(_plan_selected_building)
	column.add_child(_plan_button)
	_save_button = Button.new()
	_save_button.text = "Сохранить игру"
	_save_button.custom_minimum_size.y = 42
	_save_button.pressed.connect(_save_progress)
	column.add_child(_save_button)
	_leave_button = Button.new()
	_leave_button.text = "Выйти в море [E]"
	_leave_button.custom_minimum_size.y = 42
	_leave_button.pressed.connect(_leave_port)
	column.add_child(_leave_button)
	_root.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/ports/building_catalog.json")
	_building_catalog = catalog.get("buildings", [])

func _process(_delta: float) -> void:
	if _root == null or _port_system == null:
		return
	var docked_port: String = str(GameState.ship_state.get("docked_port_id", ""))
	_root.visible = docked_port != ""
	if docked_port == "":
		_last_home_port_id = ""
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_sheet.size = Vector2(minf(540.0, viewport_size.x - 24.0), minf(760.0, viewport_size.y - 24.0))
	_sheet.position = (viewport_size - _sheet.size) * 0.5
	var is_home: bool = docked_port == str(GameState.world_state.get("home_port_id", ""))
	if is_home and docked_port != _last_home_port_id:
		_last_home_port_id = docked_port
		_rebuild_building_list(docked_port)
	elif not is_home:
		_last_home_port_id = ""
	_building_list.visible = is_home
	_plan_button.visible = is_home
	_refresh_text(docked_port, is_home)

func _refresh_text(port_id: String, is_home: bool) -> void:
	var ship: Dictionary = GameState.ship_state
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var port_name: String = _port_system.get_port_name(port_id)
	if not is_home:
		_title.text = "ПОРТ: " + port_name
		_details.text = (
			"Корабль пришвартован\n"
			+ "Уровень порта: %d\n\n"
			+ "Деньги: %.0f\n"
			+ "Топливо: %.1f / %.0f\n"
			+ "Корпус: %.0f / 100\n\n"
			+ "Это обычный порт. Здесь будут торговля, заправка и ремонт."
		) % [
			int(port.get("level", 1)),
			float(GameState.player_state.get("money", 0.0)),
			float(ship.get("fuel", 0.0)), float(ship.get("fuel_max", 0.0)),
			float(ship.get("hull", 0.0))
		]
		return
	_title.text = "ГЛАВНЫЙ ПОРТ: " + port_name
	var selected_name: String = "не выбрано"
	var selected_state: String = ""
	if _selected_building_id != "":
		selected_name = _get_building_name(_selected_building_id)
		selected_state = _get_building_state(port, _selected_building_id)
	_details.text = (
		"Ваша развиваемая база\n"
		+ "Уровень порта: %d\n"
		+ "Деньги: %.0f\n\n"
		+ "Выбрано: %s\n"
		+ "Статус: %s\n"
		+ "%s"
	) % [
		int(port.get("level", 1)),
		float(GameState.player_state.get("money", 0.0)),
		selected_name,
		selected_state if selected_state != "" else "-",
		_notice
	]

func _rebuild_building_list(port_id: String) -> void:
	for child in _building_list.get_children():
		child.queue_free()
	for raw_building in _building_catalog:
		var building: Dictionary = raw_building
		var building_id: String = str(building.get("building_id", ""))
		var button: Button = Button.new()
		button.custom_minimum_size.y = 38
		button.text = _get_building_name(building_id) + " — " + _get_building_state(GameState.port_state.get(port_id, {}), building_id)
		button.pressed.connect(_select_building.bind(building_id))
		_building_list.add_child(button)
	if _selected_building_id == "" and not _building_catalog.is_empty():
		_selected_building_id = str(_building_catalog[0].get("building_id", ""))

func _select_building(building_id: String) -> void:
	_selected_building_id = building_id
	_notice = ""

func _plan_selected_building() -> void:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id == "" or _selected_building_id == "":
		return
	var port: Dictionary = GameState.port_state.get(port_id, {})
	if not port.has("buildings") or not (port["buildings"] is Dictionary):
		port["buildings"] = {}
	var buildings: Dictionary = port["buildings"]
	if buildings.has(_selected_building_id):
		_notice = "Этот проект уже запланирован."
		return
	buildings[_selected_building_id] = {"level": 0, "status": "planned"}
	GameState.port_state[port_id] = port
	_notice = "Проект сохранён. Стоимость и время строительства добавим в экономику."
	SaveSystem.save_game()
	_rebuild_building_list(port_id)

func _get_building_name(building_id: String) -> String:
	for raw_building in _building_catalog:
		var building: Dictionary = raw_building
		if str(building.get("building_id", "")) == building_id:
			return str(building.get("display_name", building_id))
	return building_id

func _get_building_state(port: Dictionary, building_id: String) -> String:
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary) or not raw_buildings.has(building_id):
		return "план"
	var building: Dictionary = raw_buildings[building_id]
	var level: int = int(building.get("level", 0))
	var status: String = str(building.get("status", "построено"))
	return status + ", ур. %d" % level

func _save_progress() -> void:
	SaveSystem.save_game()
	_notice = "Игра сохранена."

func _leave_port() -> void:
	_port_system.undock()

func _unhandled_key_input(event: InputEvent) -> void:
	if _port_system == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E or event.physical_keycode == KEY_E:
		_leave_port()
		get_viewport().set_input_as_handled()
