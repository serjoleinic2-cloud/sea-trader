extends CanvasLayer

## Central port window with a separate home-port development panel.

var _port_system: Node
var _root: Control
var _sheet: PanelContainer
var _title: Label
var _details: Label
var _building_list: VBoxContainer
var _plan_button: Button
var _load_button: Button
var _unload_button: Button
var _sell_button: Button
var _quantity_label: Label
var _quantity_slider: HSlider
var _modernization_switches: HBoxContainer
var _save_button: Button
var _bottom_menu: PanelContainer
var _leave_button: Button
var _building_catalog: Array = []
var _production_recipes: Array = []
var _goods: Dictionary = {}
var _goods_prices: Dictionary = {}
var _market_rules: Dictionary = {}
var _selected_building_id: String = ""
var _last_home_port_id: String = ""
var _notice: String = ""
var _current_section: String = "construction"
var _modernization_branch: String = "buildings"
var _selected_quantity: int = 1

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
	var sheet_style: StyleBoxFlat = StyleBoxFlat.new()
	sheet_style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	sheet_style.border_color = Color(0.22, 0.45, 0.62, 1.0)
	sheet_style.set_border_width_all(2)
	_sheet.add_theme_stylebox_override("panel", sheet_style)
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
	scroll.custom_minimum_size.y = 225
	column.add_child(scroll)
	_building_list = VBoxContainer.new()
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_building_list)
	_plan_button = Button.new()
	_plan_button.text = "Построить (без цены)"
	_plan_button.custom_minimum_size.y = 42
	_plan_button.pressed.connect(_plan_selected_building)
	column.add_child(_plan_button)
	_load_button = Button.new()
	_load_button.text = "Загрузить 1 единицу"
	_load_button.custom_minimum_size.y = 42
	_quantity_label = Label.new()
	_quantity_label.add_theme_font_size_override("font_size", 19)
	column.add_child(_quantity_label)
	_quantity_slider = HSlider.new()
	_quantity_slider.min_value = 1.0
	_quantity_slider.max_value = 1.0
	_quantity_slider.step = 1.0
	_quantity_slider.custom_minimum_size.y = 30
	_quantity_slider.value_changed.connect(_on_quantity_changed)
	column.add_child(_quantity_slider)
	_load_button.pressed.connect(_load_one_unit)
	column.add_child(_load_button)
	_unload_button = Button.new()
	_unload_button.text = "Выгрузить 1 единицу"
	_unload_button.custom_minimum_size.y = 42
	_unload_button.pressed.connect(_unload_one_unit)
	column.add_child(_unload_button)
	_sell_button = Button.new()
	_sell_button.text = "Продать 1 единицу"
	_sell_button.custom_minimum_size.y = 42
	_sell_button.pressed.connect(_sell_one_unit)
	column.add_child(_sell_button)
	_modernization_switches = HBoxContainer.new()
	_modernization_switches.add_theme_constant_override("separation", 8)
	column.add_child(_modernization_switches)
	var upgrade_buildings_button: Button = Button.new()
	upgrade_buildings_button.text = "Здания"
	upgrade_buildings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_buildings_button.custom_minimum_size.y = 42
	upgrade_buildings_button.pressed.connect(_set_modernization_branch.bind("buildings"))
	_modernization_switches.add_child(upgrade_buildings_button)
	var upgrade_units_button: Button = Button.new()
	upgrade_units_button.text = "Юниты"
	upgrade_units_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_units_button.custom_minimum_size.y = 42
	upgrade_units_button.pressed.connect(_set_modernization_branch.bind("units"))
	_modernization_switches.add_child(upgrade_units_button)
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
	_create_bottom_menu()
	_root.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/ports/building_catalog.json")
	_building_catalog = catalog.get("buildings", [])
	var production: Dictionary = SaveSystem._read_json("res://data/ports/production_recipes.json")
	_production_recipes = production.get("recipes", [])
	var goods_catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	var raw_resources: Variant = goods_catalog.get("resources", [])
	if raw_resources is Array:
		for raw_resource in raw_resources:
			var resource: Dictionary = raw_resource
			var resource_id: String = str(resource.get("id", ""))
			_goods[resource_id] = str(resource.get("display_name", resource_id))
			_goods_prices[resource_id] = float(resource.get("base_price", 0.0))
	_market_rules = SaveSystem._read_json("res://data/economy/market_rules.json")

func _process(_delta: float) -> void:
	if _root == null or _port_system == null:
		return
	var docked_port: String = str(GameState.ship_state.get("docked_port_id", ""))
	_root.visible = docked_port != ""
	if docked_port == "":
		_last_home_port_id = ""
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_sheet.size = Vector2(minf(540.0, viewport_size.x - 24.0), minf(760.0, viewport_size.y - 124.0))
	_sheet.position = (viewport_size - _sheet.size) * 0.5 - Vector2(0.0, 38.0)
	_bottom_menu.size = Vector2(minf(920.0, viewport_size.x - 24.0), 82.0)
	_bottom_menu.position = Vector2((viewport_size.x - _bottom_menu.size.x) * 0.5, viewport_size.y - _bottom_menu.size.y - 14.0)
	var is_home: bool = docked_port == str(GameState.world_state.get("home_port_id", ""))
	if is_home and docked_port != _last_home_port_id:
		_last_home_port_id = docked_port
		_rebuild_building_list(docked_port)
	elif not is_home:
		_last_home_port_id = ""
	_bottom_menu.visible = true
	_building_list.visible = (is_home and (_current_section == "construction" or _current_section == "resources")) or _current_section == "market"
	_plan_button.visible = is_home and _current_section == "construction"
	_modernization_switches.visible = is_home and _current_section == "modernization"
	_update_quantity_selector(docked_port, is_home)
	_update_load_button(docked_port, is_home)
	_update_unload_button(is_home)
	_update_sell_button(is_home)
	_refresh_text(docked_port, is_home)

func _refresh_text(port_id: String, is_home: bool) -> void:
	var ship: Dictionary = GameState.ship_state
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var port_name: String = _port_system.get_port_name(port_id)
	if not is_home:
		if _current_section == "market":
			_refresh_market_page(port_name, ship)
			return
		if _current_section == "resources":
			_refresh_away_resources_page(ship, port_name)
			return
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
	if _current_section == "resources":
		_refresh_resources_page(port, ship, port_name)
		return
	if _current_section == "market":
		_refresh_market_page(port_name, ship)
		return
	if _current_section == "modernization":
		_refresh_modernization_page(port, ship, port_name)
		return
	_title.text = "СТРОИТЕЛЬСТВО: " + port_name
	var selected_name: String = "не выбрано"
	var selected_state: String = ""
	if _selected_building_id != "":
		selected_name = _get_building_name(_selected_building_id)
		selected_state = _get_building_state(port, _selected_building_id)
	var inventory_text: String = _get_inventory_text(port)
	var cargo_units: int = _get_cargo_units()
	var cargo_capacity: int = int(ship.get("cargo_capacity", 0))
	_details.text = (
		"Ваша развиваемая база\n"
		+ "Уровень порта: %d\n"
		+ "Деньги: %.0f\n"
		+ "Склад: %s\n"
		+ "Трюм: %d / %d\n\n"
		+ "Выбрано: %s\n"
		+ "Статус: %s\n"
		+ "%s"
	) % [
		int(port.get("level", 1)),
		float(GameState.player_state.get("money", 0.0)),
		inventory_text,
		cargo_units, cargo_capacity,
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

func _rebuild_resource_list(port_id: String) -> void:
	for child in _building_list.get_children():
		child.queue_free()
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var inventory: Dictionary = _get_inventory(port)
	for raw_recipe in _production_recipes:
		var recipe: Dictionary = raw_recipe
		var building_id: String = str(recipe.get("building_id", ""))
		var resource_id: String = str(recipe.get("resource_id", ""))
		var button: Button = Button.new()
		button.custom_minimum_size.y = 42
		button.text = "%s: %d — %s" % [
			_get_resource_name(resource_id),
			int(inventory.get(resource_id, 0)),
			_get_building_state(port, building_id)
		]
		button.pressed.connect(_select_building.bind(building_id))
		_building_list.add_child(button)

func _rebuild_market_list(_port_id: String) -> void:
	for child in _building_list.get_children():
		child.queue_free()
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array) or raw_cargo.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "В трюме нет товара для продажи."
		empty_label.add_theme_font_size_override("font_size", 19)
		_building_list.add_child(empty_label)
		return
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		var resource_id: String = str(item.get("resource_id", ""))
		var building_id: String = _get_building_id_for_resource(resource_id)
		if building_id == "":
			continue
		var button: Button = Button.new()
		button.custom_minimum_size.y = 42
		button.text = "%s: %d — цена %.0f" % [
			_get_resource_name(resource_id),
			int(item.get("quantity", 0)),
			_get_sale_price(resource_id)
		]
		button.pressed.connect(_select_building.bind(building_id))
		_building_list.add_child(button)

func _select_building(building_id: String) -> void:
	_selected_building_id = building_id
	_notice = ""
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id != "" and _get_selected_resource_id() != "" and (_current_section == "construction" or _current_section == "resources"):
		_ensure_selected_production_is_active(port_id)
		EventBus.production_output_requested.emit(port_id, building_id)
	if _current_section == "resources":
		_rebuild_resource_list(port_id)

func _ensure_selected_production_is_active(port_id: String) -> void:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var raw_buildings: Variant = port.get("buildings", {})
	var buildings: Dictionary = raw_buildings if raw_buildings is Dictionary else {}
	var is_active: bool = false
	if buildings.has(_selected_building_id):
		var existing_building: Dictionary = buildings[_selected_building_id]
		is_active = int(existing_building.get("level", 0)) >= 1 and str(existing_building.get("status", "")) == "active"
	if is_active:
		return
	buildings[_selected_building_id] = {"level": 1, "status": "active"}
	port["buildings"] = buildings
	GameState.port_state[port_id] = port
	_notice = "Производство запущено."
	SaveSystem.save_game()
	_rebuild_building_list(port_id)

func _plan_selected_building() -> void:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id == "" or _selected_building_id == "":
		return
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary):
		port["buildings"] = {}
	var buildings: Dictionary = port.get("buildings", {})
	if buildings.has(_selected_building_id):
		var existing_building: Dictionary = buildings[_selected_building_id]
		if int(existing_building.get("level", 0)) >= 1 and str(existing_building.get("status", "")) == "active":
			_notice = "Это здание уже работает."
			return
		# Saves from the earlier planning prototype are upgraded to an active building.
		buildings[_selected_building_id] = {"level": 1, "status": "active"}
		_notice = "Старый проект построен и запущен. Производство начнётся через 10 секунд."
	else:
		buildings[_selected_building_id] = {"level": 1, "status": "active"}
		_notice = "Здание построено. Производство начнётся через 10 секунд."
	port["buildings"] = buildings
	GameState.port_state[port_id] = port
	EventBus.building_activated.emit(port_id, _selected_building_id)
	SaveSystem.save_game()
	_rebuild_building_list(port_id)

func _update_load_button(port_id: String, is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_load_button.visible = is_home and _current_section == "resources" and resource_id != ""
	if not _load_button.visible:
		return
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var inventory: Dictionary = _get_inventory(port)
	var stock: int = int(inventory.get(resource_id, 0))
	var cargo_capacity: int = int(GameState.ship_state.get("cargo_capacity", 0))
	var production_is_active: bool = _is_selected_production_active(port)
	var available_space: int = cargo_capacity - _get_cargo_units()
	var available_stock: int = stock
	if available_stock <= 0 and production_is_active:
		available_stock = 1
	_load_button.disabled = not production_is_active or _selected_quantity > available_stock or _selected_quantity > available_space
	if stock > 0:
		_load_button.text = "Загрузить %d ед.: %s (%d)" % [_selected_quantity, _get_resource_name(resource_id), stock]
	else:
		_load_button.text = "Подготовить и загрузить %d ед.: %s" % [_selected_quantity, _get_resource_name(resource_id)]

func _update_quantity_selector(port_id: String, is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	var use_selector: bool = resource_id != "" and (_current_section == "resources" or _current_section == "market")
	_quantity_label.visible = use_selector
	_quantity_slider.visible = use_selector
	if not use_selector:
		return
	var maximum: int = _get_cargo_quantity(resource_id)
	if _current_section == "resources" and is_home:
		var port: Dictionary = GameState.port_state.get(port_id, {})
		var stock: int = int(_get_inventory(port).get(resource_id, 0))
		var cargo_capacity: int = int(GameState.ship_state.get("cargo_capacity", 0))
		var free_space: int = cargo_capacity - _get_cargo_units()
		maximum = maxi(maximum, mini(stock, free_space))
		if maximum <= 0 and _is_selected_production_active(port) and free_space > 0:
			maximum = 1
	maximum = maxi(1, maximum)
	if _selected_quantity > maximum:
		_selected_quantity = maximum
	_quantity_slider.max_value = float(maximum)
	_quantity_slider.value = float(_selected_quantity)
	_quantity_label.text = "Количество: %d" % _selected_quantity

func _on_quantity_changed(value: float) -> void:
	_selected_quantity = maxi(1, int(round(value)))

func _update_sell_button(is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_sell_button.visible = _current_section == "market" and resource_id != ""
	if not _sell_button.visible:
		return
	var quantity: int = _get_cargo_quantity(resource_id)
	_sell_button.disabled = _selected_quantity > quantity
	_sell_button.text = "Продать %d ед.: %s (+%.0f)" % [_selected_quantity, _get_resource_name(resource_id), _get_sale_price(resource_id) * _selected_quantity]

func _update_unload_button(is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_unload_button.visible = is_home and _current_section == "resources" and resource_id != ""
	if not _unload_button.visible:
		return
	var quantity: int = _get_cargo_quantity(resource_id)
	_unload_button.disabled = _selected_quantity > quantity
	_unload_button.text = "Выгрузить %d ед.: %s (%d)" % [_selected_quantity, _get_resource_name(resource_id), quantity]

func _load_one_unit() -> void:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var resource_id: String = _get_selected_resource_id()
	if port_id == "" or port_id != home_port_id or resource_id == "":
		return
	var cargo_capacity: int = int(GameState.ship_state.get("cargo_capacity", 0))
	if _get_cargo_units() >= cargo_capacity:
		_notice = "Трюм заполнен."
		return
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var inventory: Dictionary = _get_inventory(port)
	var stock: int = int(inventory.get(resource_id, 0))
	if stock < _selected_quantity:
		if stock > 0 or not _is_selected_production_active(port) or _selected_quantity > 1:
			_notice = "На складе недостаточно товара."
			return
		# Fallback for the schematic prototype: the first completed batch is prepared on demand.
		stock = 1
		inventory[resource_id] = stock
	inventory[resource_id] = stock - _selected_quantity
	port["inventory"] = inventory
	GameState.port_state[port_id] = port
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	var cargo: Array = raw_cargo if raw_cargo is Array else []
	var was_loaded: bool = false
	for index in range(cargo.size()):
		var cargo_item: Dictionary = cargo[index]
		if str(cargo_item.get("resource_id", "")) == resource_id:
			cargo_item["quantity"] = int(cargo_item.get("quantity", 0)) + _selected_quantity
			cargo[index] = cargo_item
			was_loaded = true
			break
	if not was_loaded:
		cargo.append({"resource_id": resource_id, "quantity": _selected_quantity})
	GameState.ship_state["cargo"] = cargo
	var stats: Dictionary = GameState.player_state.get("stats", {})
	stats["cargo_units_moved"] = int(stats.get("cargo_units_moved", 0)) + _selected_quantity
	GameState.player_state["stats"] = stats
	EventBus.cargo_loaded.emit(resource_id, _selected_quantity)
	_notice = "В трюм загружено: %s × %d." % [_get_resource_name(resource_id), _selected_quantity]
	SaveSystem.save_game()

func _is_selected_production_active(port: Dictionary) -> bool:
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary):
		return false
	var buildings: Dictionary = raw_buildings
	if not buildings.has(_selected_building_id):
		return false
	var building: Dictionary = buildings[_selected_building_id]
	return int(building.get("level", 0)) >= 1 and str(building.get("status", "")) == "active"

func _create_bottom_menu() -> void:
	_bottom_menu = PanelContainer.new()
	var menu_style: StyleBoxFlat = StyleBoxFlat.new()
	menu_style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	menu_style.border_color = Color(0.22, 0.45, 0.62, 1.0)
	menu_style.set_border_width_all(2)
	_bottom_menu.add_theme_stylebox_override("panel", menu_style)
	_bottom_menu.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bottom_menu.size = Vector2(920, 82)
	_root.add_child(_bottom_menu)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_bottom_menu.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	_add_navigation_button(row, "Строительство", "construction")
	_add_navigation_button(row, "Ресурсы", "resources")
	_add_navigation_button(row, "Рынок", "market")
	_add_navigation_button(row, "Модернизация", "modernization")

func _add_navigation_button(row: HBoxContainer, label_text: String, section_id: String) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(_open_section.bind(section_id))
	row.add_child(button)

func _open_section(section_id: String) -> void:
	_current_section = section_id
	_notice = ""
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id == "":
		return
	if section_id == "construction":
		_rebuild_building_list(port_id)
	elif section_id == "resources":
		_rebuild_resource_list(port_id)
	elif section_id == "market":
		_rebuild_market_list(port_id)

func _set_modernization_branch(branch_id: String) -> void:
	_modernization_branch = branch_id

func _refresh_resources_page(port: Dictionary, ship: Dictionary, port_name: String) -> void:
	_title.text = "РЕСУРСЫ БАЗЫ: " + port_name
	_details.text = (
		"Склад: %s\n"
		+ "Трюм: %d / %d\n\n"
		+ "Выберите ресурс в списке ниже.\n"
		+ "Его можно загрузить в трюм или выгрузить обратно на склад."
	) % [
		_get_inventory_text(port),
		_get_cargo_units(),
		int(ship.get("cargo_capacity", 0))
	]

func _refresh_away_resources_page(ship: Dictionary, port_name: String) -> void:
	_title.text = "РЕСУРСЫ КОРАБЛЯ: " + port_name
	_details.text = (
		"Трюм: %d / %d\n"
		+ "Груз: %s\n\n"
		+ "В этом порту можно продать товар на вкладке «Рынок».\n"
		+ "Загрузка и выгрузка на склад доступны в главном порту."
	) % [
		_get_cargo_units(),
		int(ship.get("cargo_capacity", 0)),
		_get_ship_cargo_text()
	]

func _refresh_market_page(port_name: String, ship: Dictionary) -> void:
	var resource_id: String = _get_selected_resource_id()
	var selected_text: String = "Выберите товар из трюма в списке ниже."
	if resource_id != "":
		selected_text = "%s: в трюме %d, цена продажи %.0f." % [
			_get_resource_name(resource_id),
			_get_cargo_quantity(resource_id),
			_get_sale_price(resource_id)
		]
	_title.text = "РЫНОК: " + port_name
	_details.text = (
		"Деньги: %.0f\n"
		+ "Трюм: %d / %d\n\n"
		+ "%s\n"
		+ "Продажа пока идёт по базовой цене. Региональный спрос и контракты добавим следующим этапом."
	) % [
		float(GameState.player_state.get("money", 0.0)),
		_get_cargo_units(),
		int(ship.get("cargo_capacity", 0)),
		selected_text
	]

func _refresh_modernization_page(port: Dictionary, ship: Dictionary, port_name: String) -> void:
	var branch_title: String = "ЗДАНИЯ"
	var branch_text: String = (
		"Развитие причалов, склада, верфи и производственных объектов.\n"
		+ "Каждый уровень будет давать скорость производства, вместимость или новые возможности."
	)
	if _modernization_branch == "units":
		branch_title = "ЮНИТЫ"
		branch_text = (
			"Развитие капитана и экипажа: моряк, боцман, офицеры.\n"
			+ "Навыки дадут бонусы к скорости, погрузке, расходу топлива и манёврам."
		)
	_title.text = "МОДЕРНИЗАЦИЯ: " + branch_title
	_details.text = (
		"База: %s\n"
		+ "Корабль: трюм %d / %d\n\n"
		+ "%s"
	) % [
		port_name,
		_get_cargo_units(),
		int(ship.get("cargo_capacity", 0)),
		branch_text
	]

func _sell_one_unit() -> void:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var resource_id: String = _get_selected_resource_id()
	if port_id == "" or port_id != home_port_id or resource_id == "":
		return
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return
	var cargo: Array = raw_cargo
	var found_index: int = -1
	for index in range(cargo.size()):
		var item: Dictionary = cargo[index]
		if str(item.get("resource_id", "")) == resource_id and int(item.get("quantity", 0)) > 0:
			found_index = index
			break
	if found_index < 0:
		_notice = "В трюме нет этого товара."
		return
	var item: Dictionary = cargo[found_index]
	var remaining_quantity: int = int(item.get("quantity", 0)) - _selected_quantity
	if remaining_quantity <= 0:
		cargo.remove_at(found_index)
	else:
		item["quantity"] = remaining_quantity
		cargo[found_index] = item
	GameState.ship_state["cargo"] = cargo
	var sale_price: float = _get_sale_price(resource_id) * _selected_quantity
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + sale_price
	var stats: Dictionary = GameState.player_state.get("stats", {})
	stats["total_sales"] = int(stats.get("total_sales", 0)) + _selected_quantity
	stats["total_earned"] = float(stats.get("total_earned", 0.0)) + sale_price
	GameState.player_state["stats"] = stats
	EventBus.cargo_delivered.emit(resource_id, _selected_quantity)
	_notice = "Продано: %s × %d. Получено %.0f." % [_get_resource_name(resource_id), _selected_quantity, sale_price]
	SaveSystem.save_game()
	_rebuild_market_list(port_id)

func _unload_one_unit() -> void:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var resource_id: String = _get_selected_resource_id()
	if port_id == "" or port_id != home_port_id or resource_id == "":
		return
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return
	var cargo: Array = raw_cargo
	var found_index: int = -1
	for index in range(cargo.size()):
		var cargo_item: Dictionary = cargo[index]
		if str(cargo_item.get("resource_id", "")) == resource_id and int(cargo_item.get("quantity", 0)) > 0:
			found_index = index
			break
	if found_index < 0:
		_notice = "В трюме нет этого товара."
		return
	var item: Dictionary = cargo[found_index]
	var remaining_quantity: int = int(item.get("quantity", 0)) - _selected_quantity
	if remaining_quantity <= 0:
		cargo.remove_at(found_index)
	else:
		item["quantity"] = remaining_quantity
		cargo[found_index] = item
	GameState.ship_state["cargo"] = cargo
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var inventory: Dictionary = _get_inventory(port)
	inventory[resource_id] = int(inventory.get(resource_id, 0)) + _selected_quantity
	port["inventory"] = inventory
	GameState.port_state[port_id] = port
	var stats: Dictionary = GameState.player_state.get("stats", {})
	stats["cargo_units_moved"] = int(stats.get("cargo_units_moved", 0)) + _selected_quantity
	GameState.player_state["stats"] = stats
	EventBus.cargo_delivered.emit(resource_id, _selected_quantity)
	_notice = "На склад выгружено: %s × %d." % [_get_resource_name(resource_id), _selected_quantity]
	SaveSystem.save_game()
	_rebuild_resource_list(port_id)

func _get_ship_cargo_text() -> String:
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array) or raw_cargo.is_empty():
		return "пусто"
	var entries: Array[String] = []
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		entries.append("%s: %d" % [
			_get_resource_name(str(item.get("resource_id", ""))),
			int(item.get("quantity", 0))
		])
	return ", ".join(entries)

func _get_sale_price(resource_id: String) -> float:
	var multiplier: float = float(_market_rules.get("home_port_sell_multiplier", 1.0))
	var docked_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if docked_port_id != "" and docked_port_id != home_port_id:
		multiplier = float(_market_rules.get("remote_port_sell_multiplier", 1.0))
	return round(float(_goods_prices.get(resource_id, 0.0)) * multiplier)

func _get_building_id_for_resource(resource_id: String) -> String:
	for raw_recipe in _production_recipes:
		var recipe: Dictionary = raw_recipe
		if str(recipe.get("resource_id", "")) == resource_id:
			return str(recipe.get("building_id", ""))
	return ""

func _get_cargo_quantity(resource_id: String) -> int:
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return 0
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		if str(item.get("resource_id", "")) == resource_id:
			return int(item.get("quantity", 0))
	return 0

func _get_selected_resource_id() -> String:
	for raw_recipe in _production_recipes:
		var recipe: Dictionary = raw_recipe
		if str(recipe.get("building_id", "")) == _selected_building_id:
			return str(recipe.get("resource_id", ""))
	return ""

func _get_resource_name(resource_id: String) -> String:
	return str(_goods.get(resource_id, resource_id))

func _get_inventory(port: Dictionary) -> Dictionary:
	var raw_inventory: Variant = port.get("inventory", {})
	if raw_inventory is Dictionary:
		return raw_inventory
	return {}

func _get_inventory_text(port: Dictionary) -> String:
	var inventory: Dictionary = _get_inventory(port)
	if inventory.is_empty():
		return "пусто"
	var entries: Array[String] = []
	for resource_id in inventory:
		entries.append("%s: %d" % [_get_resource_name(str(resource_id)), int(inventory[resource_id])])
	return ", ".join(entries)

func _get_cargo_units() -> int:
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return 0
	var total: int = 0
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		total += int(item.get("quantity", 0))
	return total

func _get_building_name(building_id: String) -> String:
	for raw_building in _building_catalog:
		var building: Dictionary = raw_building
		if str(building.get("building_id", "")) == building_id:
			return str(building.get("display_name", building_id))
	return building_id

func _get_building_state(port: Dictionary, building_id: String) -> String:
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary):
		return "план"
	var buildings: Dictionary = raw_buildings
	if not buildings.has(building_id):
		return "план"
	var building: Dictionary = buildings[building_id]
	var level: int = int(building.get("level", 0))
	var status_id: String = str(building.get("status", "planned"))
	var status: String = "план"
	if status_id == "active":
		status = "построено"
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
