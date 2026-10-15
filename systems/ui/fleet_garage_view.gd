extends VBoxContainer

## One stable fleet workspace: owned vessels and construction share selection,
## filters, model preview and a visible project status.
var owner_window: Node
var mode := "owned"
var category := "all"
var selected_type := ""
var _tabs: HBoxContainer
var _filters: HBoxContainer
var _carousel: HFlowContainer
var _preview: Control
var _heading: Label
var _specs: Label
var _context: Label
var _actions: VBoxContainer
var _name_input: LineEdit
var _build: Button
var _cancel: Button
var _availability: Label
var _project: Label
var _construction_footer: VBoxContainer
var _owned_footer: VBoxContainer
var _draft_names: Dictionary = {}
var _tick := 0.0
var _signature := ""

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new()
	add_child(header)
	var pennant = preload("res://systems/ui/faction_pennant.gd").new()
	header.add_child(pennant)
	pennant.set_faction(str(GameState.player_state.get("origin_race_id", "humans")))
	pennant.custom_minimum_size = Vector2(30, 40)
	var title: Label = _label("ФЛОТ И ВЕРФЬ", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.name = "CloseButton"
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(owner_window._close)
	header.add_child(close)
	_tabs = HBoxContainer.new()
	header.add_child(_tabs)
	header.move_child(_tabs, 2)
	for choice in [["owned", "МОЙ ФЛОТ"], ["build", "ПОСТРОИТЬ КОРАБЛЬ"]]:
		var button: Button = _button(str(choice[1]), _set_mode.bind(str(choice[0])))
		_tabs.add_child(button)
	_filters = HBoxContainer.new()
	add_child(_filters)
	for choice in [["all", "Все суда"], ["trade", "Торговые"], ["transport", "Транспорты армии"], ["combat", "Боевые с орудиями"]]:
		_filters.add_child(_button(str(choice[1]), _set_category.bind(str(choice[0]))))
	_context = _label("", 12)
	add_child(_context)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	add_child(body)
	var information := VBoxContainer.new()
	information.custom_minimum_size.x = 310
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.size_flags_stretch_ratio = 0.55
	body.add_child(information)
	_heading = _label("", 18)
	information.add_child(_heading)
	_specs = _label("", 13)
	information.add_child(_specs)
	var scroll := ScrollContainer.new()
	scroll.name = "SelectedShipActions"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	information.add_child(scroll)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_actions)
	owner_window._list = _actions
	var art_column := VBoxContainer.new()
	art_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_column.size_flags_stretch_ratio = 1.0
	body.add_child(art_column)
	_preview = preload("res://systems/ui/ship_preview.gd").new()
	art_column.add_child(_preview)
	var hint: Label = _label("Мышь — вращение · колесо — масштаб · двойной щелчок — исходный вид", 11)
	art_column.add_child(hint)
	_construction_footer = VBoxContainer.new()
	_construction_footer.add_theme_constant_override("separation", 4)
	add_child(_construction_footer)
	_owned_footer = VBoxContainer.new()
	add_child(_owned_footer)
	_carousel = HFlowContainer.new()
	_carousel.name = "FleetCarousel"
	_carousel.alignment = FlowContainer.ALIGNMENT_CENTER
	_carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carousel.add_theme_constant_override("h_separation", 8)
	_carousel.add_theme_constant_override("v_separation", 6)
	add_child(_carousel)

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("compact_description", true)
	label.set_meta("ui_base_font_size", font_size)
	return label

func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 12)
	button.set_meta("compact_description", true)
	button.set_meta("ui_base_font_size", 12)
	button.set_meta("ui_base_min_height", 32)
	button.pressed.connect(callback)
	return button

func _set_mode(value: String) -> void:
	mode = value
	owner_window._notice = ""
	owner_window._refresh()

func open_construction() -> void:
	owner_window._is_open = true
	mode = "build"
	owner_window._refresh()

func _set_category(value: String) -> void:
	category = value
	owner_window._refresh()

func _matches(definition: Dictionary) -> bool:
	var kind := "combat" if bool(definition.get("warship", false)) else ("transport" if bool(definition.get("military_transport", false)) else "trade")
	return category == "all" or kind == category

func _select(value: String) -> void:
	if mode == "build":
		selected_type = value
	else:
		owner_window._selected_ship_id = value
	owner_window._notice = ""
	owner_window._refresh()

func refresh() -> void:
	var fleet: Node = owner_window._fleet_system
	if fleet == null:
		return
	for node in _carousel.get_children():
		_carousel.remove_child(node)
		node.queue_free()
	for node in _actions.get_children():
		_actions.remove_child(node)
		node.queue_free()
	for node in _construction_footer.get_children():
		_construction_footer.remove_child(node)
		node.queue_free()
	for node in _owned_footer.get_children():
		_owned_footer.remove_child(node)
		node.queue_free()
	_construction_footer.visible = mode == "build"
	_owned_footer.visible = mode == "owned"
	for index in _tabs.get_child_count():
		_tabs.get_child(index).toggle_mode = true
		_tabs.get_child(index).button_pressed = (mode == "owned") == (index == 0)
	for index in _filters.get_child_count():
		_filters.get_child(index).toggle_mode = true
		_filters.get_child(index).button_pressed = category == ["all", "trade", "transport", "combat"][index]
	var entries: Array = []
	if mode == "build":
		for definition in fleet.get_ship_types():
			if _matches(definition):
				entries.append({"id": str(definition.id), "type": str(definition.id), "name": str(definition.name)})
	else:
		var active_type: String = str(GameState.ship_state.get("ship_id", "ship_sloop"))
		if _matches(GameData.get_ship(active_type)):
			entries.append({"id": "active_ship", "type": active_type, "name": "★ " + str(GameData.get_ship(active_type).get("name", "Флагман"))})
		for ship in fleet.get_auxiliary_ships():
			var type_id: String = str(ship.get("ship_type_id", ""))
			if _matches(GameData.get_ship(type_id)):
				entries.append({"id": str(ship.instance_id), "type": type_id, "name": str(ship.get("name", "Корабль"))})
	var selection: String = selected_type if mode == "build" else owner_window._selected_ship_id
	if entries.filter(func(entry: Dictionary) -> bool: return str(entry.id) == selection).is_empty():
		selection = str(entries[0].id) if not entries.is_empty() else ""
		if mode == "build":
			selected_type = selection
		else:
			owner_window._selected_ship_id = selection
	var definition: Dictionary = {}
	for entry in entries:
		var selected: bool = str(entry.id) == selection
		var data: Dictionary = GameData.get_ship(str(entry.type))
		var subtitle: String = "%d орудия · ранг %d" % [int(data.get("gun_slots", 0)), int(data.get("command_rank_required", 1))] if bool(data.get("warship", false)) else ("Перевозит десант" if bool(data.get("military_transport", false)) else "Трюм %d" % int(data.get("cargo_capacity", 0)))
		var title: String = str(entry.name).split(" · ")[0]
		var button: Button = _button(title + "\n" + subtitle, _select.bind(str(entry.id)))
		button.tooltip_text = str(entry.name) + "\n" + subtitle
		button.name = "Ship_" + str(entry.id)
		button.custom_minimum_size = Vector2(220, 56)
		button.toggle_mode = true
		button.button_pressed = selected
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var icon_path: String = str(data.get("ui_icon", ""))
		if ResourceLoader.exists(icon_path):
			button.icon = load(icon_path)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 32)
		_carousel.add_child(button)
		if selected:
			definition = data
	var home: String = str(GameState.world_state.get("home_port_id", ""))
	var yard: Dictionary = GameState.port_state.get(home, {}).get("buildings", {}).get("shipyard", {})
	_context.text = "Верфь ур. %d · ранг капитана %d · %s" % [int(yard.get("level", 0)), int(fleet.get_command_progress().get("rank", 1)), "Транспорты возят армию. Боевые корабли ведут артиллерийский бой."]
	if definition.is_empty():
		_heading.text = "Нет судов в этой категории"
		_specs.text = "Откройте «Построить корабль», чтобы посмотреть проекты своей расы."
		_preview.hide()
		return
	_preview.show()
	_preview.show_ship(str(definition.id))
	_heading.text = str(definition.name)
	_specs.text = "%s\nКорпус %d · скорость %d · экипаж %d–%d" % [str(definition.get("role", "")), int(definition.get("hull_max", 100)), int(definition.get("base_speed", 0)), int(definition.get("min_crew", 1)), int(definition.get("max_crew", 1))]
	if mode == "build":
		_construction(definition, home, yard)
	elif selection == "active_ship":
		owner_window._add_active_ship_card()
	else:
		var ship: Dictionary = owner_window._get_selected_ship()
		owner_window._add_auxiliary_ship_card(ship)
		if not bool(definition.get("warship", false)) and not bool(definition.get("military_transport", false)):
			owner_window._add_selected_ship_actions()
	if owner_window._notice != "":
		_owned_footer.add_child(_label(str(owner_window._notice), 12))
	if mode == "owned":
		var row := HFlowContainer.new()
		_owned_footer.add_child(row)
		_move_primary_actions(_actions, row)
		var reasons: Array[String] = []
		for button in row.get_children():
			if button.disabled and button.tooltip_text != "" and not reasons.has(button.tooltip_text):
				reasons.append(button.tooltip_text)
		if not reasons.is_empty():
			_owned_footer.add_child(_label(" · ".join(reasons), 12))
	_compact(_actions)
	_signature = _state_signature()

func _move_primary_actions(node: Node, row: HFlowContainer) -> void:
	for child in node.get_children():
		if child is Button and child.has_meta("fleet_primary_action"):
			node.remove_child(child)
			child.text = str(child.get_meta("fleet_primary_action"))
			child.set_meta("compact_description", true)
			child.set_meta("ui_base_font_size", 12)
			child.set_meta("ui_base_min_height", 32)
			child.custom_minimum_size = Vector2(0, 32)
			row.add_child(child)
		else:
			_move_primary_actions(child, row)

func _compact(node: Node) -> void:
	for child in node.get_children():
		if child is Label or child is Button:
			child.set_meta("compact_description", true)
			child.set_meta("ui_base_font_size", 12)
			child.add_theme_font_size_override("font_size", 12)
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if child is Button:
				child.custom_minimum_size.y = 32
				child.set_meta("ui_base_min_height", 32)
		_compact(child)

func _construction(definition: Dictionary, home: String, yard: Dictionary) -> void:
	var shipyard: Node = get_tree().get_first_node_in_group("shipyard_system")
	if shipyard == null:
		return
	var project: Dictionary = shipyard.get_project()
	_project = _label("", 12)
	_construction_footer.add_child(_project)
	_project.visible = not project.is_empty()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_construction_footer.add_child(buttons)
	if not project.is_empty():
		_project.text = "Верфь занята: «%s». Отмена возвращает материалы на склад." % str(project.get("name", "Корабль"))
	_name_input = LineEdit.new()
	_name_input.name = "NewShipName"
	_name_input.placeholder_text = "Имя корабля"
	_name_input.text = str(_draft_names.get(selected_type, str(project.get("name", definition.name)) if str(project.get("ship_type_id", "")) == selected_type else str(definition.name)))
	_name_input.max_length = 28
	_name_input.custom_minimum_size.y = 32
	_name_input.custom_minimum_size.x = 220
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.set_meta("compact_description", true)
	_name_input.set_meta("ui_base_font_size", 12)
	_name_input.text_changed.connect(func(value: String): _draft_names[selected_type] = value)
	buttons.add_child(_name_input)
	var funding_project: Dictionary = project if str(project.get("ship_type_id", "")) == selected_type else {"required_materials": definition.get("build_materials", {}), "materials": {}}
	var materials = preload("res://systems/buildings/construction_materials.gd").new()
	var quote: Dictionary = materials.quote(funding_project, GameState.port_state.get(home, {}).get("inventory", {}), GameState.economy_state)
	_actions.add_child(_label("Материалы: свободно / требуется", 12))
	var resources := GridContainer.new()
	resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources.columns = 2
	resources.add_theme_constant_override("h_separation", 10)
	resources.add_theme_constant_override("v_separation", 3)
	_actions.add_child(resources)
	for resource in quote.rows:
		var row: Dictionary = quote.rows[resource]
		var label: Label = _label("%s: %d / %d" % [shipyard.get_goods_name(str(resource)), int(row.available), int(row.required)], 12)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.modulate = Color("efb186") if int(row.missing) > 0 else Color("a9d9ad")
		resources.add_child(label)
	var access: Dictionary = owner_window._fleet_system.get_ship_access(selected_type)
	var reason := "Материалы спишутся со склада; корабль появится на своей базе."
	var ready: bool = true
	if not bool(shipyard._is_at_home()):
		ready = false
		reason = "Для постройки нужна действующая верфь и швартовка на своей базе."
	elif not bool(access.ok):
		ready = false
		reason = str(access.message)
	elif not project.is_empty() and str(project.get("ship_type_id", "")) != selected_type:
		ready = false
		reason = "Верфь занята проектом «%s». Завершите его или отмените кнопкой выше." % str(project.get("name", "Корабль"))
	elif not bool(quote.ready):
		ready = false
		reason = "Не хватает материалов: недостающее количество отмечено в списке."
	_build = _button("ПОСТРОИТЬ «%s»" % str(definition.name), _build_ship)
	_build.name = "BuildSelectedShip"
	_build.disabled = not ready
	buttons.add_child(_build)
	if not project.is_empty():
		_cancel = _button("Отменить текущий проект", _cancel_project)
		_cancel.tooltip_text = "Все внесённые материалы будут возвращены на склад."
		buttons.add_child(_cancel)
	_availability = _label(reason, 12)
	_availability.name = "ShipBuildAvailability"
	_construction_footer.add_child(_availability)
	_actions.add_child(_button("Улучшить верфь · ур. %d" % int(yard.get("level", 0)), _upgrade_yard))

func _build_ship() -> void:
	var shipyard: Node = get_tree().get_first_node_in_group("shipyard_system")
	var chosen_name: String = _name_input.text.strip_edges()
	if chosen_name == "":
		_availability.text = "Введите имя корабля."
		_name_input.grab_focus()
		return
	var result: Dictionary = shipyard.create_project(selected_type)
	if bool(result.ok):
		result = shipyard.set_project_name(chosen_name)
	if bool(result.ok):
		result = shipyard.finish_project()
	owner_window._notice = str(result.get("message", ""))
	if bool(result.ok):
		mode = "owned"
		category = "all"
		owner_window._selected_ship_id = str(result.get("instance_id", "active_ship"))
	owner_window._refresh()

func _cancel_project() -> void:
	var shipyard: Node = get_tree().get_first_node_in_group("shipyard_system")
	var result: Dictionary = shipyard.cancel_project()
	owner_window._notice = str(result.message)
	owner_window._refresh()

func _upgrade_yard() -> void:
	var windows: Array[Node] = get_tree().get_nodes_in_group("building_project_window")
	if not windows.is_empty():
		windows[0].open_for_building("shipyard")

func _state_signature() -> String:
	# Escort and battle ships update their position/heading every frame. Including
	# the full fleet dictionaries here rebuilt the whole UI twice per second while
	# a moving warship was selected, which appeared as a flashing window. Keep the
	# data that affects visible cards, but omit continuous movement and reload state.
	var visible_fleet: Array[Dictionary] = []
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		var visible_ship: Dictionary = {}
		for key in ["instance_id", "ship_type_id", "name", "status", "hull", "level", "experience", "guns", "commander", "escort_enabled", "embarked_units", "crew", "autopilot", "pending_trade", "cargo", "current_port_id"]:
			if ship.has(key):
				visible_ship[key] = ship[key]
		visible_fleet.append(visible_ship)
	return str(hash([visible_fleet, GameState.port_state.get(str(GameState.world_state.get("home_port_id", "")), {}), GameState.ship_state.get("docked_port_id", ""), GameState.company_state.get("shipyard_project", {}), GameState.progression_state.get("career", {})]))

func _process(delta: float) -> void:
	if not owner_window._is_open:
		return
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0
	if _signature != _state_signature() and not (_name_input != null and is_instance_valid(_name_input) and _name_input.has_focus()):
		owner_window._refresh()
