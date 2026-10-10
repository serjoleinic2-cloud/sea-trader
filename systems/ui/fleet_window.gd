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
var _origin_emblem: TextureRect
var _crew_atlas: Texture2D
var _armament_window: Control
const CREW_ATLAS := "res://assets/characters/crew/crew_portrait_atlas.png"
const CharacterArtCatalog = preload("res://systems/characters/character_art_catalog.gd")

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
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	box.add_child(title_row)
	_origin_emblem = TextureRect.new()
	_origin_emblem.custom_minimum_size = Vector2(46, 46)
	_origin_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_origin_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_origin_emblem.texture = _get_origin_emblem()
	title_row.add_child(_origin_emblem)
	var title: Label = Label.new()
	title.text = "УПРАВЛЕНИЕ ФЛОТОМ"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title_row.add_child(title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 18)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 550
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	preload("res://systems/ui/brass_close_button.gd").apply(close_button)
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_armament_window=preload("res://systems/ui/naval_armament_window.gd").new()
	_armament_window.closed.connect(_return_from_armament)
	add_child(_armament_window)
	_panel.hide()

func initialize(fleet_system: Node) -> void:
	_fleet_system = fleet_system
	_crew_atlas = load(CREW_ATLAS) as Texture2D if ResourceLoader.exists(CREW_ATLAS) else null
	if _origin_emblem != null:
		_origin_emblem.texture = _get_origin_emblem()


func _get_origin_emblem() -> Texture2D:
	return GameData.get_faction_emblem(str(GameState.player_state.get("origin_race_id", "")))

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

func _open_armament(ship_id: String) -> void:
	var navy: Node=get_tree().get_first_node_in_group("naval_combat_system")
	if navy==null: _notice="Система вооружения недоступна."; return
	_is_open=false
	_armament_window.initialize(navy)
	_armament_window.open_ship(ship_id)

func _return_from_armament() -> void:
	_is_open=true
	_refresh()

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
	_compact_buttons(_panel)

func _compact_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			var button := child as Button
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if bool(button.get_meta("wide_action", false)) else Control.SIZE_SHRINK_BEGIN
		_compact_buttons(child)

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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	panel.add_child(row)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var art := VBoxContainer.new()
	art.custom_minimum_size.x = 210
	row.add_child(art)
	box.set_meta("portrait_column",art)
	return box

func _add_active_ship_card() -> void:
	var box: VBoxContainer = _create_card()
	_add_ship_portrait(box, str(GameState.ship_state.get("ship_id", "ship_sloop")))
	var crew: Array = _fleet_system.get_ship_crew("active_ship")
	var definition: Dictionary = _fleet_system.get_ship_type(str(GameState.ship_state.get("ship_id", "ship_sloop")))
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 19)
	title.text = "★ %s — под вашим управлением | ячейки экипажа: %d / %d · нанять минимум %d" % [str(definition.get("name", "Текущий корабль")), crew.size(), int(definition.get("max_crew", 1)), maxi(0, int(definition.get("min_crew", 1)) - 1)]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var crew_label: Label = Label.new()
	crew_label.add_theme_font_size_override("font_size", 17)
	crew_label.text = _get_crew_text(crew)
	box.add_child(crew_label)
	var details: Button = Button.new()
	details.text = "Экипаж: навыки и замена сотрудников"
	details.custom_minimum_size.y = 44
	details.pressed.connect(_open_active_crew)
	box.add_child(details)

func _open_active_crew() -> void:
	_open_personnel("active_ship", "trade")

func _open_personnel(ship_id: String, personnel_mode: String) -> void:
	var windows: Array[Node] = get_tree().get_nodes_in_group("hiring_window")
	if not windows.is_empty() and windows[0].has_method("open_for_ship"):
		windows[0].call("open_for_ship", ship_id, personnel_mode)

func _add_auxiliary_ship_card(ship: Dictionary) -> void:
	var box: VBoxContainer = _create_card()
	_add_ship_portrait(box, str(ship.get("ship_type_id", "ship_sloop")))
	var ship_id: String = str(ship.get("instance_id", ""))
	if bool(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("warship", false)):
		_add_naval_ship_card(ship)
		return
	if str(ship.get("ship_type_id","")) == "ship_combat_cutter" and ship.get("autopilot",{}).is_empty():
		_add_transport_controls(box,ship)
		return
	var crew: Array = ship.get("crew", [])
	var definition: Dictionary = _fleet_system.get_ship_type(str(ship.get("ship_type_id", "")))
	var voyage: Dictionary = _fleet_system.get_auxiliary_voyage_status(ship_id)
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 19)
	title.text = str(ship.get("name", "Корабль")).to_upper()
	box.add_child(title)
	var take_status: Dictionary = _fleet_system.get_take_control_status(ship_id)
	var take_button: Button = Button.new()
	take_button.text = "Сесть за штурвал"
	take_button.custom_minimum_size.y = 42
	take_button.disabled = not bool(take_status.get("ok", false))
	take_button.tooltip_text = str(take_status.get("message", ""))
	take_button.pressed.connect(_take_control.bind(ship_id))
	box.add_child(take_button)
	if not bool(take_status.get("ok", false)):
		var take_hint: Label = Label.new()
		take_hint.text = str(take_status.get("message", ""))
		take_hint.add_theme_font_size_override("font_size", 16)
		take_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(take_hint)
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
	cargo_label.text = "Груз: %d / %d | Ячейки экипажа: %d / %d · минимум для рейса %d" % [
		int(voyage.get("cargo_units", 0)), int(ship.get("cargo_capacity", 0)), crew.size(),
		int(definition.get("max_crew", 1)), int(definition.get("min_crew", 1))
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

func _add_ship_portrait(box: VBoxContainer, ship_type_id: String) -> void:
	var definition: Dictionary = GameData.get_ship(ship_type_id)
	var path := str(definition.get("ui_icon", ""))
	if not ResourceLoader.exists(path):
		return
	var icon := TextureRect.new()
	icon.texture = load(path) as Texture2D
	icon.custom_minimum_size = Vector2(160, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art: Node = box.get_meta("portrait_column",box)
	art.add_child(icon)
	var inspect := Button.new()
	inspect.text = "Осмотреть в 3D"
	inspect.pressed.connect(func(): preload("res://systems/ui/ship_inspection_window.gd").show_ship(self, ship_type_id))
	box.add_child(inspect)

func _add_transport_controls(box: VBoxContainer, ship: Dictionary) -> void:
	var system: Node = get_tree().get_first_node_in_group("military_transport_system")
	if system == null: return
	var id: String = str(ship.instance_id)
	var count: Dictionary = system.capacity(ship)
	var label := Label.new()
	label.text = "%s — %s\nДесант: %d / %d · Орудия: %d / %d · Корпус: %d\nПеревод отрядов между гарнизоном и транспортом — на своей базе." % [str(ship.get("name","Транспорт")),str(ship.get("status","Готов")),int(count.soldiers),int(count.soldier_capacity),int(count.artillery),int(count.artillery_capacity),int(ship.get("hull",145))]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("compact_description",true)
	label.add_theme_font_size_override("font_size",14)
	box.add_child(label)
	var personnel_button := Button.new()
	personnel_button.text = "ЭКИПАЖ И КОМАНДИР ТРАНСПОРТА"
	personnel_button.custom_minimum_size.y = 40
	personnel_button.tooltip_text = "Персонал этого военного транспортного корабля. Солдаты и орудия размещаются ниже."
	personnel_button.pressed.connect(_open_personnel.bind(id, "military"))
	box.add_child(personnel_button)
	var available: bool = system._at_home(ship) and not system._locked(id)
	var escort_status: Dictionary = system.get_escort_change_status(id)
	var escort := Button.new()
	escort.text = "Оставить транспорт в порту" if bool(ship.get("escort_enabled",false)) else "Включить в сопровождение"
	escort.disabled = not bool(escort_status.ok)
	escort.tooltip_text = str(escort_status.message)
	escort.pressed.connect(func():
		var result: Dictionary = system.set_escort(id,not bool(ship.get("escort_enabled",false)))
		_notice = str(result.message)
		_refresh())
	box.add_child(escort)
	if not bool(escort_status.ok):
		var escort_hint := Label.new()
		escort_hint.text = str(escort_status.message)
		escort_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		escort_hint.set_meta("compact_description", true)
		box.add_child(escort_hint)
	var units: Dictionary = GameData.read("res://data/combat/unit_catalog.json").get("units",{})
	for unit_id in units:
		var aboard: int = int(ship.get("embarked_units",{}).get(unit_id,{}).get("count",0))
		var garrison: int = int(GameState.combat_state.get("units",{}).get(unit_id,{}).get("count",0))
		if aboard+garrison == 0: continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var title := Label.new()
		title.text = "%s · на борту %d · в гарнизоне %d" % [str(units[unit_id].get("name",unit_id)),aboard,garrison]
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.set_meta("compact_description",true)
		title.add_theme_font_size_override("font_size",14)
		row.add_child(title)
		for step in [-1,1,10]:
			var button := Button.new()
			button.text = "−1" if step < 0 else "+%d" % step
			button.tooltip_text = "В гарнизон" if step < 0 else "Погрузить из гарнизона"
			button.disabled = not available or (aboard < 1 if step < 0 else garrison < step)
			button.pressed.connect(_transfer_troops.bind(id,str(unit_id),absi(step),step>0))
			row.add_child(button)

func _transfer_troops(id: String, unit_id: String, amount: int, embark: bool) -> void:
	var system: Node = get_tree().get_first_node_in_group("military_transport_system")
	var result: Dictionary = system.transfer_units(id,unit_id,amount,embark)
	_notice = str(result.message)
	_refresh()

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
	title.text = "ВЕРФЬ"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var hint: Label = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if home_port_id != "" and docked_port_id == home_port_id:
		hint.text = "Карточки кораблей и постройка находятся во вкладке «Верфь» в окне базы."
	else:
		hint.text = "Чтобы строить корабли, пришвартуйтесь на своей базе и откройте вкладку «Верфь»."
	box.add_child(hint)

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
			route_button.set_meta("wide_action", true)
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
	var personnel_button := Button.new()
	personnel_button.text = "ЭКИПАЖ И КОМАНДИР · УПРАВЛЕНИЕ ПЕРСОНАЛОМ"
	personnel_button.custom_minimum_size.y = 42
	personnel_button.tooltip_text = "Открыть единый раздел персонала для этого торгового корабля."
	personnel_button.pressed.connect(_open_personnel.bind(_selected_ship_id, "trade"))
	box.add_child(personnel_button)

func _add_auxiliary_crew_slots(box: VBoxContainer, ship: Dictionary) -> void:
	var crew_title: Label = Label.new()
	crew_title.text = "ЯЧЕЙКИ ЭКИПАЖА · найм на бирже, перемещение между кораблями в одном порту"
	crew_title.add_theme_font_size_override("font_size", 16)
	crew_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(crew_title)
	var crew: Array = ship.get("crew", [])
	var definition: Dictionary = _fleet_system.get_ship_type(str(ship.get("ship_type_id", "")))
	for slot_index in range(int(definition.get("max_crew", 1))):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var employee: Dictionary = _fleet_system.get_employee(str(crew[slot_index])) if slot_index < crew.size() else {}
		if employee.is_empty():
			var vacant := Label.new()
			vacant.text = "ЯЧЕЙКА %d · СВОБОДНА" % (slot_index + 1)
			vacant.custom_minimum_size.x = 170
			vacant.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(vacant)
			var eligible: Array = _fleet_system.get_assignable_employees(_selected_ship_id)
			if eligible.is_empty():
				var hire_hint := Label.new()
				hire_hint.text = "Наймите сотрудника на бирже или пришвартуйте корабли в одном порту для перевода."
				hire_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				hire_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(hire_hint)
			else:
				var selector := OptionButton.new()
				selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				for candidate in eligible:
					selector.add_item("%s · %s" % [str(candidate.get("name", "")), str(candidate.get("role_name", "член экипажа"))])
					selector.set_item_metadata(selector.item_count - 1, str(candidate.get("employee_instance_id", "")))
				row.add_child(selector)
				var board_button := Button.new()
				board_button.text = "Посадить"
				board_button.pressed.connect(func():
					if selector.item_count > 0:
						_assign_employee(str(selector.get_item_metadata(selector.selected)), _selected_ship_id)
				)
				row.add_child(board_button)
			continue
		var portrait := TextureRect.new()
		portrait.texture = _get_employee_portrait(employee)
		portrait.custom_minimum_size = Vector2(54, 64)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		row.add_child(portrait)
		var info := Label.new()
		info.text = "ЯЧЕЙКА %d · %s\n%s · %s" % [slot_index + 1, str(employee.get("name", "")), str(employee.get("race_name", "")), str(employee.get("role_name", ""))]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var return_status: Dictionary = _fleet_system.get_employee_assignment_status(str(employee.get("employee_instance_id", "")), "active_ship")
		var return_button := Button.new()
		return_button.text = "Перевести"
		return_button.disabled = not bool(return_status.get("ok", false))
		return_button.tooltip_text = str(return_status.get("message", ""))
		return_button.pressed.connect(_assign_employee.bind(str(employee.get("employee_instance_id", "")), "active_ship"))
		row.add_child(return_button)

func _get_employee_portrait(employee: Dictionary) -> Texture2D:
	if _crew_atlas == null:
		return null
	var race_id: String = str(employee.get("race_id", "humans"))
	var role_id: String = str(employee.get("role_id", ""))
	if role_id.is_empty():
		role_id = str(employee.get("role_name", "")).to_lower()
	return CharacterArtCatalog.ship_officer_portrait(race_id, role_id, int(employee.get("portrait_id", 0)), _crew_atlas)

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

func _take_control(ship_id: String) -> void:
	var result: Dictionary = _fleet_system.take_control(ship_id)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_selected_ship_id = ""
	_refresh()


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

func _naval_action(callback: Callable) -> void:
	var result: Dictionary = callback.call()
	_notice = str(result.get("message", ""))
	_refresh()

func _naval_button(box: Control, text_value: String, enabled: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	button.disabled = not enabled
	button.pressed.connect(_naval_action.bind(callback))
	box.add_child(button)
	return button

func _add_naval_ship_card(ship: Dictionary) -> void:
	var navy: Node = get_tree().get_first_node_in_group("naval_combat_system")
	var military: Node = get_tree().get_first_node_in_group("military_transport_system")
	if navy == null or military == null: return
	navy.normalize_ship(ship)
	var id: String = str(ship.instance_id)
	var box: VBoxContainer = _create_card()
	_add_ship_portrait(box, str(ship.ship_type_id))
	var definition: Dictionary = GameData.get_ship(str(ship.ship_type_id))
	var title := Label.new()
	title.text = "%s · уровень %d / 30" % [str(ship.name), int(ship.level)]
	title.add_theme_font_size_override("font_size", 19)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var stats := Label.new()
	stats.text = "Корпус %.0f / %.0f · опыт %d / %d\nОрудийные слоты %d · %s" % [float(ship.hull), navy.hull_max(ship), int(ship.experience), int(ship.level) * int(navy._rules.ship_level_xp), int(definition.gun_slots), str(ship.get("status", "У причала"))]
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats)
	var escort_status: Dictionary = military.get_escort_change_status(id)
	var escort: Button = _naval_button(box, "Оставить в порту" if bool(ship.escort_enabled) else "В сопровождение · готовность к бою", bool(escort_status.ok), func(): return military.set_escort(id, not bool(ship.escort_enabled)))
	escort.tooltip_text = str(escort_status.message)
	var status: Dictionary = navy.management_status(id)
	var available: bool = bool(status.ok)
	var row := HBoxContainer.new()
	box.add_child(row)
	_naval_button(row, "Улучшить корпус", available, func(): return navy.upgrade_ship(id))
	_naval_button(row, "Ремонт", available, func(): return navy.repair_ship(id))
	var commander: Dictionary = ship.commander
	var personnel_button := Button.new()
	personnel_button.text = "КОМАНДИР И ЭКИПАЖ · %s" % (str(commander.get("name", "назначить командира")) if not commander.is_empty() else "НАНЯТЬ И НАЗНАЧИТЬ")
	personnel_button.custom_minimum_size.y = 42
	personnel_button.disabled = not available
	personnel_button.tooltip_text = "Командир и экипаж этого боевого корабля; командир влияет только на это судно."
	personnel_button.pressed.connect(_open_personnel.bind(id, "military"))
	box.add_child(personnel_button)
	var installed: int=0
	for gun in ship.guns:
		if not gun.is_empty(): installed+=1
	var arsenal_count: int=GameState.combat_state.get("naval_arsenal",[]).size()
	var armament_summary:=Label.new()
	armament_summary.text="Вооружение: %d / %d · допуск класса %d · склад %d / %d" % [installed,ship.guns.size(),navy.ship_gun_class_cap(ship),arsenal_count,navy.arsenal_capacity()]
	armament_summary.add_theme_font_size_override("font_size",14)
	box.add_child(armament_summary)
	var armament_button:=Button.new()
	armament_button.text="Открыть вооружение и склад"
	armament_button.custom_minimum_size.y=40
	armament_button.disabled=not available
	armament_button.tooltip_text=str(status.message)
	armament_button.pressed.connect(_open_armament.bind(id))
	box.add_child(armament_button)
	if not available:
		var hint := Label.new()
		hint.text = str(status.message)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)
