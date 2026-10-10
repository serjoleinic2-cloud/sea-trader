extends CanvasLayer

## Central port window with a separate home-port development panel.

var _transfers: Node
var _port_system: Node
var _root: Control
var _sheet: PanelContainer
var _title: Label
var _details: Label
var _building_list: VBoxContainer
var _content_scroll: ScrollContainer
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
var _cargo_tabs: HBoxContainer
var _cargo_action: String = "load"
var _quantity_label: Label
var _quantity_slider: HSlider
var _modernization_switches: HBoxContainer
var _save_button: Button
var _bottom_menu: PanelContainer
var _leave_button: Button
var _encounter_tab_button: Button
var _trade_tab_button: Button
var _home_tab_buttons: Array[Button] = []
var _active_port_id: String = ""
var _building_catalog: Array = []
var _production_recipes: Array = []
var _goods: Dictionary = {}
var _goods_prices: Dictionary = {}
var _goods_categories: Dictionary = {}
var _base_demands: Array = []
var _selected_building_id: String = ""
var _last_home_port_id: String = ""
var _notice: String = ""
var _current_section: String = "construction"
var _shipyard_category: String = "trade"
var _close_button: Button
var _modernization_branch: String = "buildings"
var _market_view: String = "personal"
var _market_category: String = "all"
var _selected_market_resource_id: String = ""
var _selected_quantity: int = 1
var _selected_asking_price: float = 0.0
var _merchant_art: TextureRect
var _merchant_shade: TextureRect
var _port_scroll: Control
var _port_banner: Control
var _merchant_race: String = ""
var _encounter_signature: String = ""

func install_art_layout() -> void:
	var content: Control = _sheet.get_child(0)
	_sheet.remove_child(content)
	var canvas := Control.new()
	canvas.name = "PortArtLayout"
	canvas.clip_contents = true
	_sheet.add_child(canvas)
	_merchant_art = TextureRect.new()
	_merchant_art.name = "RacialMerchantArt"
	_merchant_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_merchant_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_merchant_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_merchant_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_merchant_art)
	_merchant_shade = TextureRect.new()
	_merchant_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merchant_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.43,.62,1])
	gradient.colors = PackedColorArray([Color(.02,.06,.09,.94),Color(.02,.06,.09,.88),Color(.02,.06,.09,0),Color(.02,.06,.09,0)])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_from = Vector2.ZERO
	shade.fill_to = Vector2.RIGHT
	_merchant_shade.texture = shade
	canvas.add_child(_merchant_shade)
	_port_scroll = Control.new()
	_port_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_port_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_port_scroll.add_child(column)
	_port_banner = preload("res://systems/ui/faction_window_banner.gd").new()
	var header := HBoxContainer.new()
	column.add_child(header)
	_port_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_port_banner)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	preload("res://systems/ui/brass_close_button.gd").apply(_close_button)
	header.add_child(_close_button)
	column.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_update_merchant_art()

func _update_merchant_art() -> void:
	if _merchant_art == null: return
	var market: bool = _current_section == "market"
	_merchant_art.visible = market
	_merchant_shade.visible = market
	# Fit the whole standing figure vertically; extend the quiet left side with shade.
	_merchant_art.anchor_left = 1.0
	_merchant_art.offset_left = -_merchant_art.get_parent().size.y * (16.0/9.0)
	_merchant_art.offset_right = 0
	var port_id: String = str(GameState.ship_state.get("docked_port_id",""))
	var race: String = str(GameState.player_state.get("origin_race_id","humans"))
	if port_id != str(GameState.world_state.get("home_port_id","")) and _port_system != null:
		var port: Dictionary = _port_system._world_ports.get(port_id,{"id":port_id}).duplicate()
		port["id"] = port_id
		race = preload("res://systems/world/port_faction_resolver.gd").new().resolve(port,int(GameState.world_state.get("seed",0)))
	if race != _merchant_race:
		_merchant_race = race
		var path: String = "res://assets/characters/merchants/%s_trade.png" % race
		_merchant_art.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
		_port_banner.set_faction(race)
	_port_scroll.anchor_right = .56 if market else 1.0
	_port_scroll.offset_right = 0
	_port_scroll.offset_bottom = -76 if market else 0
	if market:
		_compact_market_text(_port_scroll)
	# A full-height scroll keeps actions accessible on short screens.
	_content_scroll.custom_minimum_size.y = 80 if _current_section == "shipyard" else (140 if market else minf(300,maxf(80,get_viewport().get_visible_rect().size.y-420)))

func _compact_market_text(node: Node) -> void:
	if node is Label or node is Button:
		node.set_meta("compact_description",true)
		node.set_meta("ui_base_font_size",14)
		node.add_theme_font_size_override("font_size",int(round(12*float(GameState.settings_state.get("ui_scale",1.25)))))
		if node is Button: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child in node.get_children(): _compact_market_text(child)

func _ready() -> void:
	add_to_group("port_window")
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
	_cargo_tabs = HBoxContainer.new()
	_cargo_tabs.add_theme_constant_override("separation", 8)
	var load_tab: Button = Button.new()
	load_tab.text = "ПОГРУЗИТЬ НА КОРАБЛЬ"
	load_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_tab.custom_minimum_size.y = 42
	load_tab.pressed.connect(_set_cargo_action.bind("load"))
	_cargo_tabs.add_child(load_tab)
	var unload_tab: Button = Button.new()
	unload_tab.text = "ВЫГРУЗИТЬ НА СКЛАД"
	unload_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unload_tab.custom_minimum_size.y = 42
	unload_tab.pressed.connect(_set_cargo_action.bind("unload"))
	_cargo_tabs.add_child(unload_tab)
	column.add_child(_cargo_tabs)
	_content_scroll = ScrollContainer.new()
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.custom_minimum_size.y = 300
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content_scroll)
	_building_list = VBoxContainer.new()
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_list.add_theme_constant_override("separation", 6)
	_content_scroll.add_child(_building_list)
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
	# Market mode is the first decision in this screen. Keep the tabs above the
	# product list so the selected operation never gets buried below controls.
	column.move_child(_market_switches, 1)
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
			_goods_categories[resource_id] = str(resource.get("category", "raw_material"))
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
	var desktop_layout: bool = viewport_size.x >= 1000.0
	var sheet_max_width: float = 1480.0 if desktop_layout else 540.0
	var sheet_max_height: float = 1000.0 if desktop_layout else 840.0
	var sheet_bottom_margin: float = 124.0 if desktop_layout else 124.0
	_sheet.size = Vector2(minf(sheet_max_width, viewport_size.x - (48.0 if desktop_layout else 24.0)), minf(sheet_max_height, viewport_size.y - sheet_bottom_margin))
	_sheet.position = (viewport_size - _sheet.size) * 0.5 - Vector2(0.0, 38.0)
	_bottom_menu.size = Vector2(minf(1220.0 if desktop_layout else 920.0, viewport_size.x - 24.0), 82.0)
	if _content_scroll != null:
		_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _current_section == "shipyard" else ScrollContainer.SCROLL_MODE_AUTO
		_content_scroll.custom_minimum_size.y = 80 if _current_section == "shipyard" else (230.0 if _current_section == "market" else minf(300.0, maxf(80.0, viewport_size.y - 420.0)))
	_building_list.size_flags_vertical = Control.SIZE_EXPAND_FILL if _current_section == "shipyard" else Control.SIZE_FILL
	_details.visible = _current_section != "shipyard" or not _notice.is_empty()
	_save_button.visible = _current_section != "shipyard"
	_leave_button.visible = _current_section != "shipyard"
	_bottom_menu.position = Vector2((viewport_size.x - _bottom_menu.size.x) * 0.5, viewport_size.y - _bottom_menu.size.y - 14.0)
	var is_home: bool = docked_port == str(GameState.world_state.get("home_port_id", ""))
	if docked_port != _active_port_id:
		_active_port_id = docked_port
		if not is_home and docked_port != "":
			_current_section = "encounter"
			_rebuild_foreign_port_page(docked_port)
		elif is_home and _current_section == "encounter":
			_current_section = "construction"
	if is_home and docked_port != _last_home_port_id:
		_last_home_port_id = docked_port
		if _current_section == "shipyard" and _is_shipyard_active(docked_port):
			_rebuild_shipyard_list()
		else:
			_rebuild_building_list(docked_port)
	elif not is_home:
		_last_home_port_id = ""
	_bottom_menu.visible = true
	_building_list.visible = (is_home and (_current_section == "construction" or _current_section == "resources" or _current_section == "market" or _current_section == "shipyard")) or (not is_home and (_current_section == "market" or _current_section == "encounter")) or _current_section == "management"
	_cargo_tabs.visible = is_home and _current_section == "resources"
	_plan_button.visible = false
	for tab_button in _home_tab_buttons:
		tab_button.visible = is_home
	_trade_tab_button.visible = not is_home
	_encounter_tab_button.visible = not is_home
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
	_update_merchant_art()
	if not is_home and _current_section == "encounter":
		var military: Node = get_tree().get_first_node_in_group("military_transport_system")
		var signature: String = "%s:%s:%s" % [docked_port,str(military.raid_transports().size() if military != null else 0),str(GameState.port_state.get(docked_port,{}).get("captured_by_player",false))]
		if signature != _encounter_signature:
			_encounter_signature = signature
			_rebuild_foreign_port_page(docked_port)

func _refresh_text(port_id: String, is_home: bool) -> void:
	var ship: Dictionary = GameState.ship_state
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var port_name: String = _port_system.get_port_name(port_id)
	if _current_section == "management":
		_title.text = "УПРАВЛЕНИЕ: " + port_name
		_details.text = "Выберите действие. Улучшения зданий находятся в разделе «Строительство»."
		return
	if _current_section == "encounter":
		_title.text = "ПОРТ · ДИПЛОМАТИЯ И ПОЕДИНКИ: " + port_name
		var combat_systems: Array[Node] = get_tree().get_nodes_in_group("combat_system")
		var raid_status: Dictionary = combat_systems[0].get_player_raid_status() if not combat_systems.is_empty() else {}
		if not raid_status.is_empty():
			_details.text = "РЕЙД ИДЁТ · %s\nГотовность: %d%% · осталось %d сек.\n\n%s" % [str(raid_status.get("target", "Порт")), int(raid_status.get("percent", 0.0)), int(raid_status.get("seconds_left", 0)), _notice]
		else:
			_details.text = _notice if _notice != "" else "Купи и продавай товары в порту. Для рейда дождитесь транспорта сопровождения с десантом."
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
	if _current_section == "shipyard":
		_title.text = "ВЕРФЬ · УРОВЕНЬ %d" % int(port.get("buildings", {}).get("shipyard", {}).get("level", 0))
		_details.text = _notice
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
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_building_list.add_child(grid)
	var port: Dictionary = GameState.port_state.get(port_id, {})
	for raw_building in _building_catalog:
		var building: Dictionary = raw_building
		var building_id: String = str(building.get("building_id", ""))
		var icon_path: String = "res://assets/ui/ports/%s/%s.png" % [str(GameState.player_state.get("origin_race_id", "humans")), building_id]
		if not ResourceLoader.exists(icon_path): icon_path = str(building.get("ui_icon", ""))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 286)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.055, 0.075, 0.09, 0.96)
		card_style.border_color = Color(0.72, 0.58, 0.32, 0.85) if building_id == _selected_building_id else Color(0.20, 0.32, 0.38, 0.9)
		card_style.set_border_width_all(1)
		card_style.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", card_style)
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 5)
		card.add_child(card_content)
		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(0, 210)
		art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = load(icon_path) as Texture2D if icon_path != "" and ResourceLoader.exists(icon_path) else null
		card_content.add_child(art)
		var name_label := Label.new()
		name_label.text = _get_building_name(building_id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 15)
		card_content.add_child(name_label)
		var state_label := Label.new()
		state_label.text = _get_building_state(port, building_id)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.add_theme_font_size_override("font_size", 12)
		card_content.add_child(state_label)
		var select_button := Button.new()
		select_button.text = "Открыть"
		select_button.custom_minimum_size = Vector2(140, 32)
		select_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		select_button.add_theme_font_size_override("font_size", 13)
		select_button.pressed.connect(_open_building_card.bind(building_id))
		card_content.add_child(select_button)
		grid.add_child(card)
	if _selected_building_id == "" and not _building_catalog.is_empty():
		_selected_building_id = str(_building_catalog[0].get("building_id", ""))

func _is_shipyard_active(port_id: String) -> bool:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var raw_buildings: Variant = port.get("buildings", {})
	if not (raw_buildings is Dictionary):
		return false
	var buildings: Dictionary = raw_buildings
	var shipyard: Dictionary = buildings.get("shipyard", {})
	return int(shipyard.get("level", 0)) > 0 and str(shipyard.get("status", "")) == "active"

func _rebuild_shipyard_list() -> void:
	for child in _building_list.get_children():
		child.queue_free()
	var systems: Array[Node] = get_tree().get_nodes_in_group("fleet_system")
	if systems.is_empty():
		var unavailable: Label = Label.new()
		unavailable.text = "Система флота пока недоступна."
		_building_list.add_child(unavailable)
		return
	var fleet_system: Node = systems[0]
	var shipyard_systems: Array[Node] = get_tree().get_nodes_in_group("shipyard_system")
	var current_project: Dictionary = shipyard_systems[0].get_project() if not shipyard_systems.is_empty() else {}
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	_building_list.add_child(layout)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 235.0
	left.name = "ShipyardControls"
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	layout.add_child(left)
	var building_systems: Array[Node] = get_tree().get_nodes_in_group("building_project_system")
	var building_system: Node = building_systems[0] if not building_systems.is_empty() else null
	var info := Label.new()
	info.text = "Выберите судно справа.\nУлучшайте верфь для доступа к новым классам."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.set_meta("compact_description", true)
	info.set_meta("ui_base_font_size", 12)
	info.add_theme_font_size_override("font_size", 14)
	for category in [["trade", "Торговые корабли"], ["war", "Военные корабли"]]:
		var tab := Button.new()
		tab.text = category[1]
		tab.toggle_mode = true
		tab.button_pressed = _shipyard_category == category[0]
		tab.set_meta("compact_description", true)
		tab.set_meta("ui_base_font_size", 12)
		tab.set_meta("ui_base_min_height", 28)
		tab.custom_minimum_size.y = 32
		tab.pressed.connect(_set_shipyard_category.bind(str(category[0])))
		left.add_child(tab)
	left.add_child(info)
	var improve := Button.new()
	improve.text = "Улучшить верфь"
	improve.custom_minimum_size.y = 32
	improve.set_meta("compact_description", true)
	improve.set_meta("ui_base_font_size", 12)
	improve.set_meta("ui_base_min_height", 28)
	improve.pressed.connect(_open_building_card.bind("shipyard"))
	left.add_child(improve)
	var my_fleet := Button.new()
	my_fleet.text = "Мой флот и экипажи"
	my_fleet.custom_minimum_size.y = 32
	my_fleet.set_meta("compact_description", true)
	my_fleet.set_meta("ui_base_font_size", 12)
	my_fleet.set_meta("ui_base_min_height", 28)
	my_fleet.pressed.connect(_open_fleet_management)
	left.add_child(my_fleet)
	for action in [["Сохранить игру", _save_progress], ["Выйти в море [E]", _leave_port]]:
		var compact := Button.new()
		compact.text = action[0]
		compact.set_meta("compact_description", true)
		compact.set_meta("ui_base_font_size", 12)
		compact.set_meta("ui_base_min_height", 28)
		compact.custom_minimum_size.y = 28
		compact.pressed.connect(action[1])
		left.add_child(compact)
	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.name = "ShipCatalogScroll"
	catalog_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(catalog_scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	catalog_scroll.add_child(grid)
	for raw_ship in fleet_system.get_ship_types():
		var ship: Dictionary = raw_ship
		var military: bool = bool(ship.get("warship", false)) or str(ship.get("id", "")) == "ship_combat_cutter"
		if military != (_shipyard_category == "war"): continue
		var ship_id: String = str(ship.get("id", ""))
		var access: Dictionary = fleet_system.get_ship_access(ship_id)
		var can_continue: bool = current_project.is_empty() or str(current_project.get("ship_type_id", "")) == ship_id
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(250.0, 210.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 160)
		button.expand_icon = true
		var rank_text: String = "Ранг %d" % int(ship.get("command_rank_required", 1))
		button.text = "%s\nОрудий %d · скорость %d\n%s" % [str(ship.name), int(ship.gun_slots), int(ship.base_speed), rank_text] if bool(ship.get("warship", false)) else "%s\nГруз %d · скорость %d\n%s" % [str(ship.get("name", "Корабль")), int(ship.get("cargo_capacity", 0)), int(ship.get("base_speed", 0)), rank_text]
		var icon_path: String = str(ship.get("ui_icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			button.icon = load(icon_path) as Texture2D
		button.disabled = not bool(access.get("ok", false)) or not can_continue
		button.tooltip_text = "Сначала завершите или отмените текущий проект." if not can_continue else str(access.get("message", ""))
		button.pressed.connect(_open_ship_card.bind(ship_id))
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 250.0
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_theme_constant_override("separation", 5)
		grid.add_child(card)
		card.add_child(button)
		var inspect := Button.new()
		inspect.text = "Осмотреть в 3D"
		inspect.custom_minimum_size = Vector2(160, 34)
		inspect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inspect.add_theme_font_size_override("font_size", 13)
		inspect.pressed.connect(func(): preload("res://systems/ui/ship_inspection_window.gd").show_ship(self, ship_id))
		card.add_child(inspect)

func _set_shipyard_category(category: String) -> void:
	_shipyard_category = category
	_rebuild_shipyard_list()

func _open_building_card(building_id: String) -> void:
	_selected_building_id = building_id
	_notice = ""
	var windows: Array[Node] = get_tree().get_nodes_in_group("building_project_window")
	if not windows.is_empty():
		windows[0].open_for_building(building_id)

func _open_ship_card(ship_type_id: String) -> void:
	var windows: Array[Node] = get_tree().get_nodes_in_group("shipyard_window")
	if not windows.is_empty():
		windows[0].open_for_ship(ship_type_id)

func _open_fleet_management() -> void:
	var scene: Node = get_tree().current_scene
	var coordinator: Node = scene.get_node_or_null("WindowCoordinator")
	if coordinator != null:
		coordinator.set("_port_expanded", false)
	var fleet: Node = scene.get_node_or_null("FleetWindow")
	if fleet != null:
		fleet.call("_toggle")

func _rebuild_resource_list(port_id: String) -> void:
	for child in _building_list.get_children():
		child.queue_free()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_building_list.add_child(grid)
	var inventory: Dictionary = _get_inventory(GameState.port_state.get(port_id, {}))
	var ids: Array = inventory.keys() if _cargo_action == "load" else []
	if _cargo_action == "unload":
		for raw_item in GameState.ship_state.get("cargo", []):
			var cargo_item: Dictionary = raw_item
			var cargo_id: String = str(cargo_item.get("resource_id", ""))
			if cargo_id != "" and not ids.has(cargo_id):
				ids.append(cargo_id)
	for raw_id in ids:
		var resource_id: String = str(raw_id)
		var available: int = int(inventory.get(resource_id, 0)) if _cargo_action == "load" else _get_cargo_quantity(resource_id)
		if available <= 0:
			continue
		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var info: Label = Label.new()
		info.add_theme_font_size_override("font_size", 14)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.text = ("%s\nСклад %d · трюм %d" % [_get_resource_name(resource_id), int(inventory.get(resource_id, 0)), _get_cargo_quantity(resource_id)]) if _cargo_action == "load" else ("%s\nВ трюме %d" % [_get_resource_name(resource_id), available])
		row.add_child(info)
		var action_button: Button = Button.new()
		action_button.name = "Transfer_" + resource_id
		action_button.custom_minimum_size.y = 34
		action_button.add_theme_font_size_override("font_size", 13)
		action_button.text = "Загрузить" if _cargo_action == "load" else "Выгрузить"
		action_button.pressed.connect(_transfer_cargo_item.bind(_cargo_action, resource_id))
		row.add_child(action_button)
		grid.add_child(row)
	if _get_selected_resource_id() == "" and not ids.is_empty():
		_selected_market_resource_id = str(ids[0])
	if grid.get_child_count() == 0:
		var empty: Label = Label.new()
		empty.add_theme_font_size_override("font_size", 18)
		empty.text = "Нет доступных товаров в этом разделе."
		grid.add_child(empty)

func _set_cargo_action(action: String) -> void:
	_cargo_action = action
	_selected_market_resource_id = ""
	_selected_quantity = 1
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id != "":
		_rebuild_resource_list(port_id)

func _transfer_cargo_item(action: String, resource_id: String) -> void:
	_selected_market_resource_id = resource_id
	var available: int = _get_cargo_quantity(resource_id) if action == "unload" else int(_get_inventory(GameState.port_state.get(str(GameState.ship_state.get("docked_port_id", "")), {})).get(resource_id, 0))
	if action == "load":
		var merchant: Node = _get_merchant_system()
		if merchant != null:
			available -= int(merchant.get_reserved_quantity(resource_id))
	var quantity: int = mini(_selected_quantity, available)
	if action == "load":
		quantity = mini(quantity, int(GameState.ship_state.get("cargo_capacity", 0)) - _get_cargo_units())
	if quantity <= 0:
		_notice = "Недостаточно свободного места или товара."
		return
	var result: Dictionary = _transfers.execute(action, resource_id, quantity)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_rebuild_resource_list(str(GameState.ship_state.get("docked_port_id", "")))

func _rebuild_market_list(port_id: String) -> void:
	for child in _building_list.get_children():
		child.queue_free()
	_add_market_category_tabs(port_id)
	var items_grid := GridContainer.new()
	items_grid.columns = 2
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", 8)
	items_grid.add_theme_constant_override("v_separation", 8)
	_building_list.add_child(items_grid)
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		var port: Dictionary = GameState.port_state.get(port_id, {})
		var inventory: Dictionary = _get_inventory(port)
		var merchant: Node = _get_merchant_system()
		if _market_category == "orders":
			if merchant != null:
				var orders: Array = merchant.get_sell_orders()
				if orders.is_empty():
					_add_market_empty_message("Активных заявок пока нет. Выберите товар и выставьте его торговцам.")
				else:
					for raw_order in orders:
						var order: Dictionary = raw_order
						var cancel: Button = Button.new()
						cancel.custom_minimum_size.y = 38
						cancel.add_theme_font_size_override("font_size", 13)
						cancel.text = "Снять: %s %d ед. × %.0f — %s" % [
							_get_resource_name(str(order.get("resource_id", ""))), int(order.get("quantity_available", 0)), float(order.get("asking_price", 0.0)), str(order.get("last_feedback", ""))
						]
						cancel.pressed.connect(_cancel_sell_order.bind(str(order.get("id", ""))))
						_building_list.add_child(cancel)
			else:
				_add_market_empty_message("Биржа товаров сейчас недоступна.")
		else:
			for resource_id in inventory:
				if not _market_category_matches(str(resource_id)):
					continue
				var reserved: int = int(merchant.get_reserved_quantity(str(resource_id))) if merchant != null else 0
				var button: Button = _market_item_button("%s\nСвободно %d · резерв %d" % [_get_resource_name(str(resource_id)), maxi(0, int(inventory[resource_id]) - reserved), reserved], str(resource_id))
				items_grid.add_child(button)
		if _selected_market_resource_id == "" and not inventory.is_empty():
			for raw_id in inventory.keys():
				if _market_category_matches(str(raw_id)):
					_selected_market_resource_id = str(raw_id)
					break
		if _market_category != "orders" and items_grid.get_child_count() == 0:
			_add_market_empty_message("В этой категории на складе сейчас нет товаров.")
		return
	if _market_view == "port":
		var stock: Dictionary = _get_port_market_stock(port_id)
		for resource_id in stock:
			if int(stock[resource_id]) <= 0 or not _market_category_matches(str(resource_id)):
				continue
			var button: Button = _market_item_button("%s\n%d ед. · цена %.0f" % [
				_get_resource_name(str(resource_id)),
				int(stock[resource_id]),
				_get_purchase_price(str(resource_id))
			], str(resource_id))
			items_grid.add_child(button)
		if items_grid.get_child_count() == 0:
			var empty_buy: Label = Label.new()
			empty_buy.text = "В этом порту сейчас нечего покупать."
			empty_buy.add_theme_font_size_override("font_size", 14)
			items_grid.add_child(empty_buy)
		return
	var cargo_ids: Array[String] = []
	var cargo_quantities: Dictionary = {}
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if raw_cargo is Array:
		for raw_item in raw_cargo:
			var item: Dictionary = raw_item
			if str(item.get("contract_id", "")) != "":
				continue
			var cargo_id: String = str(item.get("resource_id", ""))
			if cargo_id == "":
				continue
			if not cargo_ids.has(cargo_id):
				cargo_ids.append(cargo_id)
			cargo_quantities[cargo_id] = int(cargo_quantities.get(cargo_id, 0)) + int(item.get("quantity", 0))
	if cargo_ids.is_empty():
		_add_market_empty_message("В трюме нет свободного товара для продажи.")
		return
	for resource_id in cargo_ids:
		if not _market_category_matches(resource_id):
			continue
		var button: Button = _market_item_button("%s\n%d ед. · цена %.0f" % [
			_get_resource_name(resource_id),
			int(cargo_quantities.get(resource_id, 0)),
			_get_sale_price(resource_id)
		], resource_id)
		items_grid.add_child(button)
	if items_grid.get_child_count() == 0:
		var empty_goods := Label.new()
		empty_goods.text = "В этой категории нет доступных товаров."
		empty_goods.add_theme_font_size_override("font_size", 14)
		items_grid.add_child(empty_goods)

func _add_market_category_tabs(port_id: String) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	_building_list.add_child(tabs)
	var categories: Array[String] = ["raw_material", "industrial_goods", "liquid_cargo"]
	var labels := {"raw_material": "Сырьё", "industrial_goods": "Промтовары", "liquid_cargo": "Жидкости"}
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		categories.append("orders")
		labels["orders"] = "Заявки"
	for category in categories:
		var tab := Button.new()
		tab.text = str(labels[category])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 32
		tab.add_theme_font_size_override("font_size", 13)
		tab.disabled = category == _market_category
		tab.pressed.connect(_set_market_category.bind(category))
		tabs.add_child(tab)

func _market_category_matches(resource_id: String) -> bool:
	return str(_goods_categories.get(resource_id, "raw_material")) == _market_category

func _market_item_button(label: String, resource_id: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 14)
	button.text = label
	button.pressed.connect(_select_market_resource.bind(resource_id))
	return button

func _add_market_empty_message(message: String) -> void:
	var empty := Label.new()
	empty.text = message
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.add_theme_font_size_override("font_size", 14)
	_building_list.add_child(empty)

func _set_market_category(category: String) -> void:
	_market_category = category
	_selected_market_resource_id = ""
	_rebuild_market_list(str(GameState.ship_state.get("docked_port_id", "")))

func _get_initial_market_category(port_id: String) -> String:
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		var inventory := _get_inventory(GameState.port_state.get(port_id, {}))
		for resource_id in inventory:
			return str(_goods_categories.get(str(resource_id), "raw_material"))
	elif _market_view == "port":
		var stock := _get_port_market_stock(port_id)
		for resource_id in stock:
			if int(stock[resource_id]) > 0:
				return str(_goods_categories.get(str(resource_id), "raw_material"))
	else:
		for raw_item in GameState.ship_state.get("cargo", []):
			var item: Dictionary = raw_item
			var resource_id := str(item.get("resource_id", ""))
			if resource_id != "" and str(item.get("contract_id", "")) == "":
				return str(_goods_categories.get(resource_id, "raw_material"))
	return "raw_material"

func _rebuild_foreign_port_page(port_id: String) -> void:
	for child in _building_list.get_children():
		child.queue_free()
	var raw_port: Dictionary = _port_system._world_ports.get(port_id, {})
	var faction_id: String = str(raw_port.get("owner_race_id", raw_port.get("faction_id", "")))
	if faction_id == "":
		faction_id = load("res://systems/world/port_faction_resolver.gd").new().resolve(raw_port, int(GameState.world_state.get("seed", 0)))
	var faction: Dictionary = GameData.get_faction(faction_id)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(210, 240)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = GameData.get_faction_portrait(faction_id)
	_building_list.add_child(portrait)
	var leader := Label.new()
	leader.text = "%s\n%s" % [str(faction.get("name", "Портовый совет")), str(faction.get("trade_identity", ["торговля"])[0])]
	leader.add_theme_font_size_override("font_size", 21)
	leader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_building_list.add_child(leader)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var trade := Button.new()
	trade.text = "ТОРГОВАТЬ"
	trade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade.custom_minimum_size.y = 56
	trade.pressed.connect(_open_section.bind("market"))
	actions.add_child(trade)
	var challenge := Button.new()
	var port_state: Dictionary = GameState.port_state.get(port_id, {})
	var support: Dictionary = _port_naval_support(port_id, int(port_state.get("level", 1)))
	var defense: int = _port_defense_power(port_id)
	var captured: bool = bool(port_state.get("captured_by_player", false))
	var tribute: bool = bool(port_state.get("tribute_active", false))
	var own_race: bool = str(port_state.get("owner_race_id", faction_id)) == str(GameState.player_state.get("origin_race_id", ""))
	var transports: Node = get_tree().get_first_node_in_group("military_transport_system")
	var combat_ship: bool = transports != null and not transports.raid_transports().is_empty()
	challenge.text = "ПОРТ ПОД ВАШИМ ФЛАГОМ" if captured else ("ПОРТ ПЛАТИТ ДАНЬ" if tribute else ("СВОЙ ПОРТ · АТАКА ЗАПРЕЩЕНА" if own_race else ("БОЙ · НУЖЕН ДЕСАНТ" if not combat_ship else "БОЙ / РЕЙД")))
	challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge.custom_minimum_size.y = 56
	challenge.pressed.connect(_challenge_port.bind(port_id, faction_id))
	actions.add_child(challenge)
	_building_list.add_child(actions)
	challenge.disabled = captured or tribute or own_race or not combat_ship
	challenge.tooltip_text = "Порт уже захвачен." if captured else ("Порт платит 10% ежедневной прибыли; повторный рейд возможен после восстания." if tribute else ("На порты своей расы нападать нельзя." if own_race else ("Погрузите войска из гарнизона в военный транспорт и дождитесь эскадры у порта." if not combat_ship else "Высадить десант с транспортов сопровождения.")))
	var hint := Label.new()
	hint.text = "Порт теперь под твоим флагом. Торговля продолжается." if captured else ("Порт платит дань: %d золота в день. Остров может объявить восстание." % int(port_state.get("tribute_daily_amount", 0)) if tribute else ("Это порт твоей расы." if own_race else "Торговля доступна любому кораблю. Победа установит дань; при отступлении потеряешь больше солдат и орудий."))
	if not captured and not tribute and not own_race:
		hint.text += "\nОценка обороны: %d." % defense
		if bool(support.get("active", false)):
			hint.text += " Морское превосходство: −%d%% к обороне." % roundi(float(support.reduction)*100.0)
		elif int(support.get("ships", 0)) > 0:
			hint.text += " Морской контроль есть, но для этого уровня нужны %d корабля." % int(support.required_ships)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	_building_list.add_child(hint)

func _challenge_port(port_id: String, faction_id: String) -> void:
	var combat: Array[Node] = get_tree().get_nodes_in_group("combat_system")
	if combat.is_empty():
		_notice = "Система боя не готова."
		return
	var faction: Dictionary = GameData.get_faction(faction_id)
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var base_power: int = 48 + int(port.get("level", 1)) * 34
	var support: Dictionary = _port_naval_support(port_id, int(port.get("level", 1)))
	var power: int = maxi(1, roundi(float(base_power)*(1.0-float(support.get("reduction", 0.0)))))
	var result: Dictionary = combat[0].start_port_raid(port_id, str(faction.get("name", "Порт")), power)
	_notice = str(result.get("message", ""))
	_rebuild_foreign_port_page(port_id)

func _port_naval_support(port_id: String, port_level: int) -> Dictionary:
	var naval: Node = get_tree().get_first_node_in_group("naval_combat_system")
	return naval.port_raid_support(port_id, port_level) if naval != null and naval.has_method("port_raid_support") else {"active": false, "reduction": 0.0, "required_ships": 1, "ships": 0}

func _port_defense_power(port_id: String) -> int:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var base_power: int = 48 + int(port.get("level", 1))*34
	var support: Dictionary = _port_naval_support(port_id, int(port.get("level", 1)))
	return maxi(1, roundi(float(base_power)*(1.0-float(support.get("reduction", 0.0)))))

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

func _on_building_activated(port_id: String, building_id: String) -> void:
	if port_id != str(GameState.ship_state.get("docked_port_id", "")):
		return
	_rebuild_building_list(port_id)
	if building_id == "shipyard" and _current_section == "shipyard":
		_rebuild_shipyard_list()

func _plan_selected_building() -> void:
	if _selected_building_id == "":
		return
	var windows: Array[Node] = get_tree().get_nodes_in_group("building_project_window")
	if not windows.is_empty():
		windows[0].open_for_building(_selected_building_id)

func _update_load_button(port_id: String, is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_load_button.visible = is_home and _current_section == "resources" and resource_id != "" and _cargo_action != "load"
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
	_quantity_label.text = "Количество операции: %d" % _selected_quantity

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
	var show: bool = is_home and _current_section == "market" and _market_category != "orders" and _get_selected_resource_id() != ""
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
	var quantity: int = _get_sellable_cargo_quantity(resource_id)
	var quote: Dictionary = _transfers._market.quote_sale(str(GameState.ship_state.get("docked_port_id", "")), resource_id, _selected_quantity)
	_sell_button.disabled = not bool(quote.get("ok", false)) or _selected_quantity > quantity
	_sell_button.text = "Продать %d ед.: %s (+%.0f)" % [_selected_quantity, _get_resource_name(resource_id), float(quote.get("revenue", 0.0))]

func _update_unload_button(is_home: bool) -> void:
	var resource_id: String = _get_selected_resource_id()
	_unload_button.visible = is_home and _current_section == "resources" and resource_id != "" and _cargo_action != "unload"
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
	_home_tab_buttons = [
		_add_navigation_button(row, "Строительство", "construction"),
		_add_navigation_button(row, "Ресурсы", "resources"),
		_add_navigation_button(row, "Рынок", "market"),
		_add_navigation_button(row, "Управление", "management")
	]
	_trade_tab_button = _add_navigation_button(row, "ТОРГОВАТЬ", "market")
	_encounter_tab_button = _add_navigation_button(row, "БОЙ", "encounter")
	_trade_tab_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_encounter_tab_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_trade_tab_button.custom_minimum_size.x = 220
	_encounter_tab_button.custom_minimum_size.x = 220
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_trade_tab_button.hide()
	_encounter_tab_button.hide()

func _add_navigation_button(row: HBoxContainer, label_text: String, section_id: String) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(_open_section.bind(section_id))
	row.add_child(button)
	return button

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
	if section_id == "garrison":
		var garrison_windows: Array[Node] = get_tree().get_nodes_in_group("garrison_window")
		if not garrison_windows.is_empty():
			garrison_windows[0].open()
		return
	_current_section = section_id
	if port_id == "":
		return
	if section_id == "management":
		for child in _building_list.get_children():
			child.queue_free()
		var action_grid := GridContainer.new()
		action_grid.columns = 2
		action_grid.add_theme_constant_override("h_separation", 8)
		action_grid.add_theme_constant_override("v_separation", 8)
		_building_list.add_child(action_grid)
		for action in [["Заказы на перевозку", "transport_contracts"], ["Персонал", "hiring"], ["Ремонт и заправка", "service"], ["Работа в найм", "contracts"], ["Рейсы и торговые линии", "logistics"]]:
			var button: Button = Button.new()
			button.text = action[0]
			button.custom_minimum_size.y = 42
			button.add_theme_font_size_override("font_size", 14)
			button.pressed.connect(_open_section.bind(str(action[1])))
			action_grid.add_child(button)
	elif section_id == "encounter":
		_rebuild_foreign_port_page(port_id)
	elif section_id == "construction":
		_selected_market_resource_id = ""
		_rebuild_building_list(port_id)
	elif section_id == "shipyard":
		_selected_market_resource_id = ""
		if _is_shipyard_active(port_id):
			_rebuild_shipyard_list()
		else:
			_notice = "Сначала постройте верфь на своей базе."
	elif section_id == "resources":
		_selected_market_resource_id = ""
		_rebuild_resource_list(port_id)
	elif section_id == "market":
		_market_view = "personal"
		_market_category = _get_initial_market_category(port_id)
		_selected_market_resource_id = ""
		_rebuild_market_list(port_id)

func open_cargo_clearance() -> void:
	var selected: String = ""
	for raw_item in GameState.ship_state.get("cargo", []):
		var item: Dictionary = raw_item
		if str(item.get("contract_id", "")) == "":
			selected = str(item.get("resource_id", ""))
			_selected_quantity = int(item.get("quantity", 1))
			break
	if selected == "":
		return
	var is_home: bool = str(GameState.ship_state.get("docked_port_id", "")) == str(GameState.world_state.get("home_port_id", ""))
	_open_section("resources" if is_home else "market")
	_selected_market_resource_id = selected
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if is_home:
		_rebuild_resource_list(port_id)
	else:
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
		_market_category = _get_initial_market_category(port_id)
		_rebuild_market_list(port_id)

func _select_market_resource(resource_id: String) -> void:
	_selected_market_resource_id = resource_id
	_notice = ""

func _set_modernization_branch(branch_id: String) -> void:
	_modernization_branch = branch_id

func _refresh_resources_page(_port: Dictionary, ship: Dictionary, port_name: String) -> void:
	_title.text = "СКЛАД И ТРЮМ: " + port_name
	_details.text = "Трюм: %d / %d\nВыберите вкладку и товар. Ползунок задаёт количество операции.\n%s" % [_get_cargo_units(), int(ship.get("cargo_capacity", 0)), _notice]

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
	var buying: bool = _market_view == "port"
	var selected_text: String = "Выберите товар из списка."
	if resource_id != "":
		selected_text = "%s · %s %.0f\n%s" % [_get_resource_name(resource_id),"Покупка:" if buying else "Продажа:",_get_purchase_price(resource_id) if buying else _get_sale_price(resource_id),"В продаже: %d ед." % int(port.get("market_stock",{}).get(resource_id,0)) if buying else _get_port_demand_text(docked_port_id,resource_id)]
	_title.text = "РЫНОК: " + port_name
	_details.text = "Трюм: %d / %d · Казна: %.0f\n%s%s" % [_get_cargo_units(),int(ship.get("cargo_capacity",0)),float(GameState.player_state.get("money",0)),selected_text,"\n"+_notice if _notice != "" else ""]

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

func _get_sellable_cargo_quantity(resource_id: String) -> int:
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return 0
	var total: int = 0
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		if str(item.get("resource_id", "")) == resource_id and str(item.get("contract_id", "")) == "":
			total += int(item.get("quantity", 0))
	return total

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
