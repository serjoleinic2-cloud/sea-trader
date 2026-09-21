extends CanvasLayer

## Central port window with a separate home-port development panel.

var _transfers: Node
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
var _buy_button: Button
var _supply_order_button: Button
var _sell_to_merchants_button: Button
var _asking_price_label: Label
var _asking_price_slider: HSlider
var _production_mode_button: Button
var _production_cap_label: Label
var _production_cap_slider: HSlider
var _production_cap_button: Button
var _market_switches: HBoxContainer
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
var _base_demands: Array = []
var _selected_building_id: String = ""
var _last_home_port_id: String = ""
var _notice: String = ""
var _current_section: String = "construction"
var _modernization_branch: String = "buildings"
var _market_view: String = "personal"
var _selected_market_resource_id: String = ""
var _selected_quantity: int = 1
var _selected_asking_price: float = 0.0

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
	_plan_button.text = "Открыть проект строительства"
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
	EventBus.building_activated.connect(_on_building_activated)
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
	_buy_button = Button.new()
	_buy_button.text = "Купить"
	_buy_button.custom_minimum_size.y = 42
	_buy_button.pressed.connect(_buy_one_unit)
	column.add_child(_buy_button)
	_supply_order_button = Button.new()
	_supply_order_button.text = "Заказать поставку"
	_supply_order_button.custom_minimum_size.y = 42
	_supply_order_button.pressed.connect(_open_supply_order_window)
	column.add_child(_supply_order_button)
	_asking_price_label = Label.new()
	_asking_price_label.add_theme_font_size_override("font_size", 19)
	column.add_child(_asking_price_label)
	_asking_price_slider = HSlider.new()
	_asking_price_slider.min_value = 1.0
	_asking_price_slider.max_value = 1.0
	_asking_price_slider.step = 1.0
	_asking_price_slider.value_changed.connect(_on_asking_price_changed)
	column.add_child(_asking_price_slider)
	_sell_to_merchants_button = Button.new()
	_sell_to_merchants_button.custom_minimum_size.y = 42
	_sell_to_merchants_button.pressed.connect(_create_sell_order)
	column.add_child(_sell_to_merchants_button)
	_production_mode_button = Button.new()
	_production_mode_button.custom_minimum_size.y = 42
	_production_mode_button.pressed.connect(_toggle_production)
	column.add_child(_production_mode_button)
	_production_cap_label = Label.new()
	_production_cap_label.add_theme_font_size_override("font_size", 19)
	column.add_child(_production_cap_label)
	_production_cap_slider = HSlider.new()
	_production_cap_slider.min_value = 1.0
	_production_cap_slider.max_value = 1.0
	_production_cap_slider.step = 1.0
	_production_cap_slider.value_changed.connect(_on_production_cap_changed)
	column.add_child(_production_cap_slider)
	_production_cap_button = Button.new()
	_production_cap_button.custom_minimum_size.y = 42
	_production_cap_button.pressed.connect(_apply_production_cap)
	column.add_child(_production_cap_button)
	_market_switches = HBoxContainer.new()
	_market_switches.add_theme_constant_override("separation", 8)
	column.add_child(_market_switches)
	var personal_market_button: Button = Button.new()
	personal_market_button.text = "Я продаю"
	personal_market_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	personal_market_button.custom_minimum_size.y = 40
	personal_market_button.pressed.connect(_set_market_view.bind("personal"))
	_market_switches.add_child(personal_market_button)
	var port_market_button: Button = Button.new()
	port_market_button.text = "Я покупаю"
	port_market_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_market_button.custom_minimum_size.y = 40
	port_market_button.pressed.connect(_set_market_view.bind("port"))
	_market_switches.add_child(port_market_button)
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

func initialize(port_system: Node, transfers: Node) -> void:
	_transfers = transfers
	_port_system = port_system
	var catalog: Dictionary = GameData.read("res://data/ports/building_catalog.json")
	_building_catalog = catalog.get("buildings", [])
	var production: Dictionary = GameData.read("res://data/ports/production_recipes.json")
	_production_recipes = production.get("recipes", [])
	var goods_catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
	var raw_resources: Variant = goods_catalog.get("resources", [])
	if raw_resources is Array:
		for raw_resource in raw_resources:
			var resource: Dictionary = raw_resource
			var resource_id: String = str(resource.get("id", ""))
			_goods[resource_id] = str(resource.get("display_name", resource_id))
			_goods_prices[resource_id] = float(resource.get("base_price", 0.0))
	var base_demand_catalog: Dictionary = GameData.read("res://data/economy/base_demand_catalog.json")
	_base_demands = base_demand_catalog.get("base_demands", [])

func _process(_delta: float) -> void:
	if _root == null or _port_system == null:
		return
	var docked_port: String = str(GameState.ship_state.get("docked_port_id", ""))
	_root.visible = docked_port != ""
	if docked_port == "":
		_last_home_port_id = ""
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_sheet.size = Vector2(minf(540.0, viewport_size.x - 24.0), minf(840.0, viewport_size.y - 124.0))
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
	_building_list.visible = (is_home and (_current_section == "construction" or _current_section == "resources" or _current_section == "market")) or (not is_home and _current_section == "market") or _current_section == "management"
	_plan_button.visible = is_home and _current_section == "construction"
	_modernization_switches.visible = is_home and _current_section == "modernization"
	_update_quantity_selector(docked_port, is_home)
	_update_load_button(docked_port, is_home)
	_update_unload_button(is_home)
	_update_sell_button(is_home)
	_update_buy_button(docked_port, is_home)
	_market_switches.visible = not is_home and _current_section == "market"
	_supply_order_button.visible = is_home and _current_section == "market"
	_update_home_market_controls(docked_port, is_home)
	_update_production_controls(docked_port, is_home)
	_refresh_text(docked_port, is_home)

func _refresh_text(port_id: String, is_home: bool) -> void:
	var ship: Dictionary = GameState.ship_state
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var port_name: String = _port_system.get_port_name(port_id)
	if _current_section == "management":
		_title.text = "УПРАВЛЕНИЕ: " + port_name
		_details.text = "Выберите действие. Улучшения зданий находятся в разделе «Строительство»."
		return
	if not is_home:
		if _current_section == "market":
			_refresh_market_page(port_name, ship, port)
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
			+ "Торговля — в разделе «Рынок». Заправка и ремонт — в «Управление»."
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
		_refresh_market_page(port_name, ship, port)
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
	_details.text = "Выбрано: %s\nСтатус: %s\n%s" % [selected_name, selected_state, _notice]

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
	var inventory: Dictionary = _get_inventory(GameState.port_state.get(port_id, {}))
	var ids: Array = inventory.keys()
	for item in GameState.ship_state.get("cargo", []):
		var id: String = str(item.get("resource_id", ""))
		if not ids.has(id):
			ids.append(id)
	for recipe in _production_recipes:
		var id: String = str(recipe.get("resource_id", ""))
		if not ids.has(id):
			ids.append(id)
	for resource_id in ids:
		var button: Button = Button.new()
		button.custom_minimum_size.y = 44
		button.text = "%s — склад: %d | трюм: %d%s" % [_get_resource_name(str(resource_id)), int(inventory.get(resource_id, 0)), _get_cargo_quantity(str(resource_id)), _production_text(GameState.port_state.get(port_id, {}), str(resource_id))]
		button.pressed.connect(_select_transfer_resource.bind(str(resource_id)))
		_building_list.add_child(button)
	if _get_selected_resource_id() == "" and not ids.is_empty():
		_selected_market_resource_id = str(ids[0])

func _rebuild_market_list(port_id: String) -> void:
	for child in _building_list.get_children():
		child.queue_free()
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		var port: Dictionary = GameState.port_state.get(port_id, {})
		var inventory: Dictionary = _get_inventory(port)
		var merchant: Node = _get_merchant_system()
		for resource_id in inventory:
			var reserved: int = int(merchant.get_reserved_quantity(str(resource_id))) if merchant != null else 0
			var button: Button = Button.new()
			button.custom_minimum_size.y = 44
			button.text = "Выставить: %s — свободно %d | резерв %d" % [_get_resource_name(str(resource_id)), maxi(0, int(inventory[resource_id]) - reserved), reserved]
			button.pressed.connect(_select_market_resource.bind(str(resource_id)))
			_building_list.add_child(button)
		if merchant != null:
			var orders: Array = merchant.get_sell_orders()
			if not orders.is_empty():
				var heading: Label = Label.new()
				heading.text = "АКТИВНЫЕ ЗАЯВКИ"
				heading.add_theme_font_size_override("font_size", 19)
				_building_list.add_child(heading)
				for raw_order in orders:
					var order: Dictionary = raw_order
					var cancel: Button = Button.new()
					cancel.custom_minimum_size.y = 46
					cancel.text = "Снять: %s %d ед. × %.0f — %s" % [
						_get_resource_name(str(order.get("resource_id", ""))), int(order.get("quantity_available", 0)), float(order.get("asking_price", 0.0)), str(order.get("last_feedback", ""))
					]
					cancel.pressed.connect(_cancel_sell_order.bind(str(order.get("id", ""))))
					_building_list.add_child(cancel)
		if _selected_market_resource_id == "" and not inventory.is_empty():
			_selected_market_resource_id = str(inventory.keys()[0])
		return
	if _market_view == "port":
		var stock: Dictionary = _get_port_market_stock(port_id)
		for resource_id in stock:
			var button: Button = Button.new()
			button.custom_minimum_size.y = 42
			button.text = "Купить: %s (%d) — цена %.0f" % [
				_get_resource_name(str(resource_id)),
				int(stock[resource_id]),
				_get_purchase_price(str(resource_id))
			]
			button.pressed.connect(_select_market_resource.bind(str(resource_id)))
			_building_list.add_child(button)
		return
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
		var button: Button = Button.new()
		button.custom_minimum_size.y = 42
		button.text = "Продать: %s (%d) — цена %.0f" % [
			_get_resource_name(resource_id),
			int(item.get("quantity", 0)),
			_get_sale_price(resource_id)
		]
		button.pressed.connect(_select_market_resource.bind(resource_id))
		_building_list.add_child(button)

func _select_building(building_id: String) -> void:
	_selected_market_resource_id = ""
	_selected_building_id = building_id
	_notice = ""
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id != "" and _get_selected_resource_id() != "" and (_current_section == "construction" or _current_section == "resources"):
		EventBus.production_output_requested.emit(port_id, building_id)
	if _current_section == "resources":
		_rebuild_resource_list(port_id)

func _select_transfer_resource(resource_id: String) -> void:
	_selected_building_id = ""
	_selected_market_resource_id = resource_id
	_notice = ""
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id != "":
		_rebuild_resource_list(port_id)

func _is_production_active_for_resource(port: Dictionary, resource_id: String) -> bool:
	var building_id: String = _get_building_id_for_resource(resource_id)
	if building_id == "":
		return false
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary):
		return false
	var buildings: Dictionary = raw_buildings
	if not buildings.has(building_id):
		return false
	var building: Dictionary = buildings[building_id]
	return int(building.get("level", 0)) >= 1 and str(building.get("status", "")) == "active"

func _on_building_activated(port_id: String, _building_id: String) -> void:
	if port_id == str(GameState.ship_state.get("docked_port_id", "")):
		_rebuild_building_list(port_id)

func _plan_selected_building() -> void:
	if _selected_building_id == "":
		return
	var windows: Array[Node] = get_tree().get_nodes_in_group("building_project_window")
	if not windows.is_empty():
		windows[0].open_for_building(_selected_building_id)

func _update_load_button(port_id: String, is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_load_button.visible = is_home and _current_section == "resources" and resource_id != ""
	if not _load_button.visible:
		return
	var inventory: Dictionary = _get_inventory(GameState.port_state.get(port_id, {}))
	var free_space: int = int(GameState.ship_state.get("cargo_capacity", 0)) - _get_cargo_units()
	var available: int = int(inventory.get(resource_id, 0))
	var merchant: Node = _get_merchant_system()
	if merchant != null:
		available -= int(merchant.get_reserved_quantity(resource_id))
	_load_button.disabled = _selected_quantity > available or _selected_quantity > free_space
	_load_button.text = "Загрузить: %s × %d" % [_get_resource_name(resource_id), _selected_quantity]

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
		var merchant: Node = _get_merchant_system()
		if merchant != null:
			stock -= int(merchant.get_reserved_quantity(resource_id))
		var cargo_capacity: int = int(GameState.ship_state.get("cargo_capacity", 0))
		var free_space: int = cargo_capacity - _get_cargo_units()
		maximum = maxi(maximum, mini(stock, free_space))
		if maximum <= 0 and _is_selected_production_active(port) and free_space > 0:
			maximum = 1
	elif _current_section == "market" and is_home:
		var merchant: Node = _get_merchant_system()
		var available_for_sale: int = int(_get_inventory(GameState.port_state.get(port_id, {})).get(resource_id, 0))
		if merchant != null:
			available_for_sale -= int(merchant.get_reserved_quantity(resource_id))
		maximum = maxi(1, available_for_sale)
	elif _current_section == "market" and _market_view == "port":
		var market_stock: Dictionary = _get_port_market_stock(port_id)
		var available: int = int(market_stock.get(resource_id, 0))
		var market_free_space: int = int(GameState.ship_state.get("cargo_capacity", 0)) - _get_cargo_units()
		var affordable: int = int(float(GameState.player_state.get("money", 0.0)) / maxf(1.0, _get_purchase_price(resource_id)))
		maximum = mini(available, mini(market_free_space, affordable))
	maximum = maxi(1, maximum)
	if _selected_quantity > maximum:
		_selected_quantity = maximum
	_quantity_slider.max_value = float(maximum)
	_quantity_slider.value = float(_selected_quantity)
	_quantity_label.text = "Количество: %d" % _selected_quantity

func _on_quantity_changed(value: float) -> void:
	_selected_quantity = maxi(1, int(round(value)))

func _on_asking_price_changed(value: float) -> void:
	_selected_asking_price = float(round(value))

func _on_production_cap_changed(_value: float) -> void:
	# The label is refreshed on the next UI frame; applying is explicit.
	pass

func _get_merchant_system() -> Node:
	var systems: Array[Node] = get_tree().get_nodes_in_group("merchant_visit_system")
	return systems[0] if not systems.is_empty() else null

func _get_production_system() -> Node:
	var systems: Array[Node] = get_tree().get_nodes_in_group("port_production_system")
	return systems[0] if not systems.is_empty() else null

func _update_home_market_controls(port_id: String, is_home: bool) -> void:
	var show: bool = is_home and _current_section == "market" and _get_selected_resource_id() != ""
	_asking_price_label.visible = show
	_asking_price_slider.visible = show
	_sell_to_merchants_button.visible = show
	if not show:
		return
	var resource_id: String = _get_selected_resource_id()
	var base_price: float = maxf(1.0, float(_goods_prices.get(resource_id, 1.0)))
	var minimum: float = maxf(1.0, round(base_price * 0.50))
	var maximum: float = maxf(minimum + 1.0, round(base_price * 1.70))
	_asking_price_slider.min_value = minimum
	_asking_price_slider.max_value = maximum
	if _selected_asking_price < minimum or _selected_asking_price > maximum:
		_selected_asking_price = round(base_price)
		_asking_price_slider.value = _selected_asking_price
	_asking_price_label.text = "Цена заявки: %.0f за единицу (база: %.0f)" % [_selected_asking_price, base_price]
	var merchant: Node = _get_merchant_system()
	var available: int = int(_get_inventory(GameState.port_state.get(port_id, {})).get(resource_id, 0))
	if merchant != null:
		available -= int(merchant.get_reserved_quantity(resource_id))
	_sell_to_merchants_button.disabled = merchant == null or _selected_quantity < 1 or _selected_quantity > available
	_sell_to_merchants_button.text = "Выставить %d ед. торговцам" % _selected_quantity

func _create_sell_order() -> void:
	var merchant: Node = _get_merchant_system()
	if merchant == null:
		_notice = "Система торговцев ещё загружается."
		return
	var result: Dictionary = merchant.create_sell_order(_get_selected_resource_id(), _selected_quantity, _selected_asking_price)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_rebuild_market_list(str(GameState.ship_state.get("docked_port_id", "")))

func _cancel_sell_order(order_id: String) -> void:
	var merchant: Node = _get_merchant_system()
	if merchant == null:
		return
	var result: Dictionary = merchant.cancel_sell_order(order_id)
	_notice = str(result.get("message", ""))
	_rebuild_market_list(str(GameState.ship_state.get("docked_port_id", "")))

func _update_production_controls(_port_id: String, is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	var building_id: String = _get_building_id_for_resource(resource_id)
	var show: bool = is_home and _current_section == "resources" and building_id != ""
	var production: Node = _get_production_system()
	var control: Dictionary = production.get_production_control(building_id) if production != null and show else {}
	show = show and bool(control.get("active", false))
	_production_mode_button.visible = show
	_production_cap_label.visible = show
	_production_cap_slider.visible = show
	_production_cap_button.visible = show
	if not show:
		return
	var mode: String = str(control.get("mode", "auto"))
	var current_stock: int = int(_get_inventory(GameState.port_state.get(str(GameState.world_state.get("home_port_id", "")), {})).get(resource_id, 0))
	var cap: int = int(control.get("cap", 0))
	var minimum: int = maxi(1, current_stock)
	var maximum: int = maxi(minimum + 20, current_stock + 200)
	_production_cap_slider.min_value = minimum
	_production_cap_slider.max_value = maximum
	if _production_cap_slider.value < minimum or _production_cap_slider.value > maximum:
		_production_cap_slider.value = float(cap if cap > 0 else maximum)
	var mode_text: String = "остановлено" if mode == "paused" else ("до лимита" if mode == "capped" else "автоматически")
	_production_mode_button.text = "Запустить производство" if mode == "paused" else "Остановить производство"
	_production_cap_label.text = "Лимит: %d (запас %d; %s)\n%s" % [int(_production_cap_slider.value), current_stock, mode_text, str(control.get("message", ""))]
	_production_cap_button.text = "Производить до %d ед." % int(_production_cap_slider.value)

func _toggle_production() -> void:
	var production: Node = _get_production_system()
	var building_id: String = _get_building_id_for_resource(_get_selected_resource_id())
	if production == null or building_id == "":
		return
	var control: Dictionary = production.get_production_control(building_id)
	var result: Dictionary = production.set_production_mode(building_id, "auto" if str(control.get("mode", "auto")) == "paused" else "paused")
	_notice = str(result.get("message", ""))

func _apply_production_cap() -> void:
	var production: Node = _get_production_system()
	var building_id: String = _get_building_id_for_resource(_get_selected_resource_id())
	if production == null or building_id == "":
		return
	var result: Dictionary = production.set_production_mode(building_id, "capped", int(_production_cap_slider.value))
	_notice = str(result.get("message", ""))

func _production_text(port: Dictionary, resource_id: String) -> String:
	var building_id: String = _get_building_id_for_resource(resource_id)
	if not _is_production_active_for_resource(port, resource_id) or building_id == "":
		return ""
	var building: Dictionary = port.get("buildings", {}).get(building_id, {})
	var mode: String = str(building.get("production_mode", "auto"))
	if mode == "paused":
		return " | производство: пауза"
	if mode == "capped":
		return " | до %d" % int(building.get("production_cap", 0))
	return " | производство: авто"

func _update_buy_button(port_id: String, is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_buy_button.visible = not is_home and _current_section == "market" and _market_view == "port" and resource_id != ""
	if not _buy_button.visible:
		return
	var stock: Dictionary = _get_port_market_stock(port_id)
	var available: int = int(stock.get(resource_id, 0))
	var quote: Dictionary = _transfers._market.quote_purchase(port_id, resource_id, _selected_quantity)
	var unit_price: float = float(quote.get("unit_price", 0.0))
	var free_space: int = int(GameState.ship_state.get("cargo_capacity", 0)) - _get_cargo_units()
	_buy_button.disabled = not bool(quote.get("ok", false)) or _selected_quantity > available or _selected_quantity > free_space or float(GameState.player_state.get("money", 0.0)) < unit_price * _selected_quantity
	_buy_button.text = "Купить %d ед.: %s (-%.0f)" % [_selected_quantity, _get_resource_name(resource_id), unit_price * _selected_quantity]

func _update_sell_button(is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_sell_button.visible = not is_home and _current_section == "market" and _market_view != "port" and resource_id != ""
	if not _sell_button.visible:
		return
	var quantity: int = _get_cargo_quantity(resource_id)
	var quote: Dictionary = _transfers._market.quote_sale(str(GameState.ship_state.get("docked_port_id", "")), resource_id, _selected_quantity)
	_sell_button.disabled = not bool(quote.get("ok", false)) or _selected_quantity > quantity
	_sell_button.text = "Продать %d ед.: %s (+%.0f)" % [_selected_quantity, _get_resource_name(resource_id), float(quote.get("revenue", 0.0))]

func _update_unload_button(is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_unload_button.visible = is_home and _current_section == "resources" and resource_id != ""
	if not _unload_button.visible:
		return
	var quantity: int = _get_cargo_quantity(resource_id)
	_unload_button.disabled = _selected_quantity > quantity
	_unload_button.text = "Выгрузить %d ед.: %s (%d)" % [_selected_quantity, _get_resource_name(resource_id), quantity]

func _load_one_unit() -> void:
	_apply_transfer("load")

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
	_add_navigation_button(row, "Управление", "management")

func _add_navigation_button(row: HBoxContainer, label_text: String, section_id: String) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(_open_section.bind(section_id))
	row.add_child(button)

func _open_section(section_id: String) -> void:
	_notice = ""
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if section_id == "hiring":
		var windows: Array[Node] = get_tree().get_nodes_in_group("hiring_window")
		if not windows.is_empty():
			windows[0].open()
		return
	if section_id == "service":
		var service_windows: Array[Node] = get_tree().get_nodes_in_group("port_service_window")
		if not service_windows.is_empty():
			service_windows[0].open()
		return
	if section_id == "contracts":
		var contract_windows: Array[Node] = get_tree().get_nodes_in_group("work_hire_window")
		if not contract_windows.is_empty():
			contract_windows[0].open()
		return
	if section_id == "transport_contracts":
		var transport_windows: Array[Node] = get_tree().get_nodes_in_group("transport_contract_window")
		if not transport_windows.is_empty():
			transport_windows[0].open()
		return
	if section_id == "logistics":
		var logistics_windows: Array[Node] = get_tree().get_nodes_in_group("logistics_window")
		if not logistics_windows.is_empty():
			logistics_windows[0].open()
		return
	_current_section = section_id
	if port_id == "":
		return
	if section_id == "management":
		for child in _building_list.get_children():
			child.queue_free()
		for action in [["Заказы на перевозку", "transport_contracts"], ["Найм персонала", "hiring"], ["Ремонт и заправка", "service"], ["Работа в найм", "contracts"], ["Рейсы и торговые линии", "logistics"]]:
			var button: Button = Button.new()
			button.text = action[0]
			button.custom_minimum_size.y = 48
			button.pressed.connect(_open_section.bind(str(action[1])))
			_building_list.add_child(button)
	elif section_id == "construction":
		_selected_market_resource_id = ""
		_rebuild_building_list(port_id)
	elif section_id == "resources":
		_selected_market_resource_id = ""
		_rebuild_resource_list(port_id)
	elif section_id == "market":
		_market_view = "personal"
		_selected_market_resource_id = ""
		_rebuild_market_list(port_id)

func _open_supply_order_window() -> void:
	var windows: Array[Node] = get_tree().get_nodes_in_group("supply_order_window")
	if not windows.is_empty():
		windows[0].open()

func _set_market_view(view_id: String) -> void:
	_market_view = view_id
	_selected_market_resource_id = ""
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id != "":
		_rebuild_market_list(port_id)

func _select_market_resource(resource_id: String) -> void:
	_selected_market_resource_id = resource_id
	_notice = ""

func _set_modernization_branch(branch_id: String) -> void:
	_modernization_branch = branch_id

func _refresh_resources_page(_port: Dictionary, ship: Dictionary, port_name: String) -> void:
	_title.text = "СКЛАД И ТРЮМ: " + port_name
	_details.text = "Трюм: %d / %d. Выберите товар и количество.\n%s" % [_get_cargo_units(), int(ship.get("cargo_capacity", 0)), _notice]

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

func _refresh_market_page(port_name: String, ship: Dictionary, port: Dictionary) -> void:
	var docked_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if docked_port_id == home_port_id:
		_title.text = "РЫНОК БАЗЫ: " + port_name
		_details.text = (
			"Склад базы: %s\n\n"
			+ "%s\n\n"
			+ "База не платит сама себе за груз. Выставляйте свободный товар: торговые корабли выкупают подходящие заявки. Высокую цену могут не принять. Биржа показывает спрос и цены уже посещённых портов."
		) % [
			_get_inventory_text(port),
			_get_base_demand_text(port)
		]
		return
	var resource_id: String = _get_selected_resource_id()
	var selected_text: String = "Выберите товар из трюма в списке ниже."
	if resource_id != "":
		selected_text = "%s: в трюме %d, цена продажи %.0f.\n%s" % [
			_get_resource_name(resource_id),
			_get_cargo_quantity(resource_id),
			_get_sale_price(resource_id),
			_get_port_demand_text(docked_port_id, resource_id)
		]
	_title.text = "РЫНОК: " + port_name
	_details.text = (
		"Деньги: %.0f\n"
		+ "Трюм: %d / %d\n\n"
		+ "%s\n"
		+ "Средняя цена партии снижается по мере насыщения рынка. Непроданный товар остаётся в трюме."
	) % [
		float(GameState.player_state.get("money", 0.0)),
		_get_cargo_units(),
		int(ship.get("cargo_capacity", 0)),
		selected_text
	]

func _get_port_demand_text(port_id: String, resource_id: String) -> String:
	var market_systems: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
	if market_systems.is_empty():
		return "Спрос порта ещё рассчитывается."
	var info: Dictionary = market_systems[0].get_market_info(port_id, resource_id)
	if not bool(info.get("accepted", false)):
		return "Порт не принимает этот товар."
	return "Потребность: %d ед. Следующее потребление через %d сек." % [
		int(info.get("demand", 0)),
		int(info.get("restores_in", 0))
	]

func _get_base_demand_text(port: Dictionary) -> String:
	var raw_dynamic_demands: Variant = GameState.economy_state.get("base_deficits", [])
	var demands: Array = raw_dynamic_demands if raw_dynamic_demands is Array and not raw_dynamic_demands.is_empty() else _base_demands
	if demands.is_empty():
		return "Дефицит базы: не назначен."
	var inventory: Dictionary = _get_inventory(port)
	var lines: Array[String] = ["ДЕФИЦИТ БАЗЫ — минимум 30% товаров в дефиците"]
	for raw_demand in demands:
		var demand: Dictionary = raw_demand
		var resource_id: String = str(demand.get("resource_id", ""))
		var target_quantity: int = int(demand.get("target_quantity", 0))
		var current_quantity: int = int(inventory.get(resource_id, 0))
		lines.append("%s: %d / %d — %s" % [
			_get_resource_name(resource_id),
			current_quantity,
			target_quantity,
			str(demand.get("purpose", "поставка"))
		])
	return "\n".join(lines)

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

func _buy_one_unit() -> void:
	_apply_transfer("buy")

func _sell_one_unit() -> void:
	_apply_transfer("sell")

func _unload_one_unit() -> void:
	_apply_transfer("unload")

func _apply_transfer(action: String) -> void:
	var result: Dictionary = _transfers.execute(action, _get_selected_resource_id(), _selected_quantity)
	_notice = str(result.get("message", ""))
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if bool(result.get("ok", false)):
		if _current_section == "market":
			_rebuild_market_list(port_id)
		else:
			_rebuild_resource_list(port_id)

func _get_port_market_stock(port_id: String) -> Dictionary:
	return GameState.port_state.get(port_id, {}).get("market_stock", {})

func _get_purchase_price(resource_id: String) -> float:
	return _transfers.buy_price(str(GameState.ship_state.get("docked_port_id", "")), resource_id)

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
	return _transfers.sell_price(str(GameState.ship_state.get("docked_port_id", "")), resource_id)

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
	if _selected_market_resource_id != "":
		return _selected_market_resource_id
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
