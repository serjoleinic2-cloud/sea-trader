extends CanvasLayer

## One workspace panel at a time; existing windows retain their own actions/state.
var _entries: Array = []
var _game_theme = preload("res://systems/ui/game_ui_theme.gd").new()
var _main: Node
var _toolbar: HBoxContainer
var _more_button: Button
var _more_panel: PanelContainer
var _more_list: VBoxContainer
var _more_navigation: Array = []
var _status: Label
var _cancel: Button
var _text_scale_button: Button
var _accessibility: Node
var _readouts: Label
var _resource_bar: HBoxContainer
var _resource_values: Dictionary = {}
var _ship_strip: PanelContainer
var _ship_bar: HBoxContainer
var _ship_indicators: Dictionary = {}
var _extra_resources_button: Button
var _extra_resources_panel: PanelContainer
var _extra_resources_list: VBoxContainer
var _extra_resource_values: Dictionary = {}
var _goods_names: Dictionary = {}
var _port_button: Button
var _port_expanded: bool = false
var _details: String = ""
var _last_docked: String = ""
var _merchant_button: Button
var _encyclopedia: Node
var _top_height: float = 84.0
const HUD_ART := "res://assets/ui/styles/approved_hud/"

func initialize(main: Node) -> void:
	_main = main
	add_to_group("window_coordinator")
	# Keep the shared HUD and its dropdowns above every in-game window, including
	# the ship inspection overlay (layer 110).
	layer = 130
	process_priority = 1000
	for window in main.get_children():
		_enable_vertical_scrolling(window)
		if not window.has_meta("workspace_flag"):
			continue
		var panel: Control = window.get("_panel")
		if panel == null:
			continue
		var flag: String = str(window.get_meta("workspace_flag"))
		_entries.append({"window": window, "flag": flag, "was_open": false, "panel": panel})
		window.layer = 140 if str(window.name) == "GarrisonWindow" else 60
		if panel is PanelContainer:
			_wrap_panel(window, panel as PanelContainer, flag)
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 6)
	add_child(_toolbar)
	_readouts = Label.new()
	_readouts.name = "TopReadouts"
	_readouts.add_theme_font_size_override("font_size", 16)
	add_child(_readouts)
	_resource_bar = HBoxContainer.new()
	_resource_bar.name = "TopResourceBar"
	_resource_bar.add_theme_constant_override("separation", 8)
	_resource_bar.alignment = BoxContainer.ALIGNMENT_END
	_resource_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_resource_bar)
	for good in GameData.read("res://data/resources/goods_catalog.json").get("resources", []):
		_goods_names[str(good.get("id", ""))] = str(good.get("display_name", good.get("id", "")))
	_create_resource_chip("КАЗНА", "money", "Деньги игрока")
	_create_resource_chip("ДЕРЕВО", "resource_timber", "Древесина на домашнем складе")
	_create_resource_chip("ДЕТАЛИ", "resource_parts", "Запчасти на домашнем складе")
	_create_resource_chip("РЫБА", "resource_fish", "Рыба на домашнем складе")
	_create_resource_chip("ОСКОЛКИ", "magic_shards", "Магические осколки")
	_create_extra_resources_menu()
	var backdrop := TextureRect.new()
	backdrop.name = "TopMenuBackdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture = load(HUD_ART + "chart_backdrop.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(backdrop)
	move_child(backdrop, 0)
	_add_toolbar_button({"label": "КАРТА", "node_name": "NavigationHUD", "method": "_toggle_panel", "icon": "map"})
	_port_button = Button.new()
	_port_button.text = "ПОРТ"
	_style_primary_button(_port_button, "port")
	_port_button.pressed.connect(func(): _port_expanded = not _port_expanded; _details = ""; _close_all_workspaces())
	_toolbar.add_child(_port_button)
	_merchant_button = Button.new()
	_merchant_button.text = "ТОРГОВЕЦ"
	_merchant_button.pressed.connect(func(): _details = "" if _details == "MerchantOfferHUD" else "MerchantOfferHUD"; _main.get_node("MerchantOfferHUD")._is_open = _details == "MerchantOfferHUD"; _port_expanded = false; _close_all_workspaces())
	var fleet_hub := Button.new()
	fleet_hub.text = "ФЛОТ И ВЕРФЬ"
	fleet_hub.name = "Menu_FleetShipyard"
	_style_primary_button(fleet_hub, "fleet")
	fleet_hub.pressed.connect(_open_fleet_hub)
	_toolbar.add_child(fleet_hub)
	_add_toolbar_button({"label": "КАПИТАН", "node_name": "CaptainCabinet", "icon": "captain"})
	_add_toolbar_button({"label": "ЗАДАНИЯ", "node_name": "TransportContractWindow", "icon": "tasks"})
	var navigation: Array = []
	for window in main.get_children():
		if window.has_meta("navigation"):
			var item: Dictionary = window.get_meta("navigation").duplicate(true)
			item["node_name"] = str(window.name)
			navigation.append(item)
	navigation.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	for item in navigation:
		if str(item.get("node_name", "")) not in ["NavigationHUD", "CaptainCabinet", "FleetWindow"]:
			_more_navigation.append(item)
	_more_button = Button.new()
	_more_button.text = "⋮"
	_more_button.set_meta("compact_hud", true)
	_more_button.tooltip_text = "Другие разделы"
	_more_button.custom_minimum_size = Vector2(40, 48)
	_more_button.pressed.connect(_toggle_more)
	_toolbar.add_child(_more_button)
	_create_more_panel()
	_encyclopedia = load("res://systems/ui/encyclopedia_window.gd").new()
	_encyclopedia.name = "EncyclopediaWindow"
	add_child(_encyclopedia)
	var encyclopedia_button := Button.new()
	encyclopedia_button.text = "Энциклопедия"
	encyclopedia_button.pressed.connect(func(): _more_panel.hide(); _encyclopedia.open())
	_add_more_button(encyclopedia_button)
	_add_more_button(_merchant_button)
	for item in [["Корабль", "ShipStatusHUD"], ["Первый рейс", "FirstVoyageGuide"]]:
		if str(item[1]) == "ShipStatusHUD":
			continue
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(_toggle_details.bind(str(item[1])))
		_add_more_button(button)
	var accessibility_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_accessibility")
	if not accessibility_nodes.is_empty():
		_accessibility = accessibility_nodes[0]
		_text_scale_button = Button.new()
		_text_scale_button.custom_minimum_size = Vector2(105, 44)
		_text_scale_button.pressed.connect(_cycle_text_scale)
		_add_more_button(_text_scale_button)
		_refresh_text_scale_button()
	_cancel = Button.new()
	_cancel.text = "Ручное управление"
	_cancel.custom_minimum_size.y = 44
	_cancel.pressed.connect(_cancel_voyage)
	_add_more_button(_cancel)
	_create_ship_indicators()
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var port: Node = main.get_node_or_null("PortWindow")
	if port != null:
		_wrap_port(port)
		_enable_vertical_scrolling(port)
	# These two controls were useful during the first prototype, but duplicate
	# the one bottom navigation bar on a phone-sized screen.
	_hide_duplicate_floating_controls()
	# Apply one nautical palette to controls created by each menu.
	_apply_menu_style(_toolbar)
	_apply_menu_style(_more_panel)
	for window in main.get_children():
		_apply_menu_style(window)
	var town = load("res://systems/ui/harbor_town_view.gd").new()
	town.name = "HarborTownView"
	main.add_child(town)
	town.initialize(main)
	var debris = load("res://systems/ui/debris_research_hud.gd").new()
	debris.name = "DebrisResearchHUD"
	main.add_child(debris)
	debris.initialize(main)
	var debris_3d = load("res://systems/rendering/debris_3d_renderer.gd").new()
	debris_3d.name = "Debris3DRenderer"
	main.add_child(debris_3d)
	debris_3d.initialize(main)

func _add_toolbar_button(item: Dictionary) -> void:
	var button: Button = Button.new()
	button.text = str(item.get("label", ""))
	button.name = "Menu_" + str(item.get("node_name", ""))
	_style_primary_button(button, str(item.get("icon", "")))
	button.pressed.connect(_open_tool.bind(str(item.get("node_name", "")), str(item.get("method", ""))))
	_toolbar.add_child(button)

func _style_primary_button(button: Button, icon_name: String) -> void:
	button.set_meta("compact_hud", true)
	button.custom_minimum_size = Vector2(88, 42)
	button.add_theme_font_size_override("font_size", 12)
	if not icon_name.is_empty():
		button.icon = load(HUD_ART + icon_name + ".png")
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 24)

func _toggle_details(node_name: String) -> void:
	_details = "" if _details == node_name else node_name
	_port_expanded = false
	_more_panel.hide()
	_close_all_workspaces()

func _create_resource_chip(title: String, resource_id: String, tooltip: String) -> void:
	var chip := PanelContainer.new()
	chip.tooltip_text = tooltip
	chip.set_meta("preserve_art_style", true)
	var style := StyleBoxTexture.new()
	style.texture = load(HUD_ART + "button_frame.png")
	for side in ["left", "right"]:
		style.set("texture_margin_" + side, 17.0)
		style.set("content_margin_" + side, 9.0)
	for side in ["top", "bottom"]:
		style.set("texture_margin_" + side, 9.0)
		style.set("content_margin_" + side, 5.0)
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(HUD_ART + resource_id + ".png")
	icon.custom_minimum_size = Vector2(26, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.text = "%s  —" % title
	label.set_meta("compact_hud", true)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("e8d7a9"))
	row.add_child(label)
	_resource_bar.add_child(chip)
	_resource_values[resource_id] = label

func _create_ship_indicators() -> void:
	_ship_strip = PanelContainer.new()
	_ship_strip.name = "SailingShipStatusStrip"
	_ship_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_strip.set_meta("preserve_art_style", true)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0b1922eF")
	background.border_color = Color("574b35")
	background.border_width_bottom = 1
	background.content_margin_left = 14
	background.content_margin_right = 14
	background.content_margin_top = 2
	background.content_margin_bottom = 2
	_ship_strip.add_theme_stylebox_override("panel", background)
	add_child(_ship_strip)
	_ship_bar = HBoxContainer.new()
	_ship_bar.name = "SailingShipIndicators"
	_ship_bar.add_theme_constant_override("separation", 10)
	_ship_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_ship_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_strip.add_child(_ship_bar)
	var items: Array[Dictionary] = [
		{"id":"hull", "label":"Корпус", "tip":"Прочность корпуса корабля"},
		{"id":"fuel", "label":"Топливо", "tip":"Топливо в баке корабля"},
		{"id":"cargo", "label":"Трюм", "tip":"Занято в грузовом трюме"},
		{"id":"speed", "label":"Скорость", "tip":"Текущая скорость корабля"},
	]
	for index in items.size():
		var item: Dictionary = items[index]
		var segment := HBoxContainer.new()
		segment.add_theme_constant_override("separation", 6)
		segment.tooltip_text = str(item.tip)
		var label := Label.new()
		label.text = str(item.label)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color("f1f3f3"))
		segment.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(72, 7)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _meter_style(Color("132c36")))
		bar.add_theme_stylebox_override("fill", _meter_style(Color("56c9d2")))
		segment.add_child(bar)
		_ship_bar.add_child(segment)
		_ship_indicators[str(item.id)] = {"label":label,"bar":bar,"segment":segment}
		if index < items.size() - 1:
			var separator := ColorRect.new()
			separator.color = Color("81909a66")
			separator.custom_minimum_size = Vector2(1, 16)
			_ship_bar.add_child(separator)

func _meter_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style

func _refresh_ship_indicators() -> void:
	var ship: Dictionary = GameState.ship_state
	var hull: float = float(ship.get("hull", 0))
	var hull_max: float = maxf(1.0, float(ship.get("hull_max", 100)))
	var fuel: float = float(ship.get("fuel", 0))
	var fuel_max: float = maxf(1.0, float(ship.get("fuel_max", 100)))
	var cargo: int = 0
	for item in ship.get("cargo", []):
		cargo += int(item.get("quantity", 0))
	var cargo_max: float = maxf(1.0, float(ship.get("cargo_capacity", 0)))
	var speed: float = Vector2(ship.get("velocity", Vector2.ZERO)).length()
	_set_ship_indicator("hull", "Корпус %d/%d" % [roundi(hull), roundi(hull_max)], hull, hull_max, Color("e77668") if hull / hull_max < .3 else Color("56c9d2"))
	_set_ship_indicator("fuel", "Топливо %d%%" % roundi(fuel / fuel_max * 100.0), fuel, fuel_max, Color("e6ae54"))
	_set_ship_indicator("cargo", "Трюм %d/%d" % [cargo, int(cargo_max)], cargo, cargo_max, Color("8dc8de"))
	_set_ship_indicator("speed", "Скорость %d уз" % roundi(speed), speed, maxf(1.0, float(GameData.get_ship(str(ship.get("ship_id", "ship_sloop"))).get("base_speed", 100))), Color("e8c36b"))

func _set_ship_indicator(id: String, text: String, value: float, capacity: float, color: Color) -> void:
	var item: Dictionary = _ship_indicators[id]
	item.label.text = text
	item.bar.max_value = maxf(1.0, capacity)
	item.bar.value = clampf(value, 0.0, item.bar.max_value)
	if item.segment.get_meta("fill_color", Color.TRANSPARENT) != color:
		item.segment.set_meta("fill_color", color)
		item.bar.add_theme_stylebox_override("fill", _meter_style(color))

func _refresh_resource_bar() -> void:
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	var home: Dictionary = GameState.port_state.get(home_id, {})
	var inventory: Dictionary = home.get("inventory", {})
	var values: Dictionary = {
		"money": int(GameState.player_state.get("money", 0)),
		"resource_timber": int(inventory.get("resource_timber", 0)),
		"resource_parts": int(inventory.get("resource_parts", 0)),
		"resource_fish": int(inventory.get("resource_fish", 0)),
		"magic_shards": int(GameState.combat_state.get("magic_shards", 0))
	}
	for key in _resource_values:
		var label: Label = _resource_values[key]
		var amount: int = int(values.get(key, 0))
		var number: String = String.num_int64(amount) if amount < 10000 else "%.1fk" % (float(amount) / 1000.0)
		label.text = "%s\n%s" % [{"money": "КАЗНА", "resource_timber": "ДЕРЕВО", "resource_parts": "ДЕТАЛИ", "resource_fish": "РЫБА", "magic_shards": "ОСКОЛКИ"}[key], number]
		label.get_parent().get_parent().tooltip_text = "%s: %d" % [_goods_names.get(key, {"money": "Казна", "magic_shards": "Осколки"}.get(key, key)), amount]
	var extras: Array[String] = []
	for key in inventory:
		if int(inventory[key]) > 0 and not _resource_values.has(str(key)):
			extras.append(str(key))
	extras.sort()
	var current_ids: Array = _extra_resource_values.keys()
	current_ids.sort()
	var listed_ids: Array = extras.duplicate()
	listed_ids.sort()
	if current_ids != listed_ids:
		_rebuild_extra_resource_rows(extras)
	for key in extras:
		var label: Label = _extra_resource_values[key]
		label.text = "%s  %s" % [_goods_names.get(key, key), _format_resource_amount(int(inventory[key]))]
	_extra_resources_button.visible = not extras.is_empty()
	_extra_resources_button.text = "ЕЩЁ  +%d" % extras.size()

func _format_resource_amount(amount: int) -> String:
	return String.num_int64(amount) if amount < 10000 else "%.1fk" % (float(amount) / 1000.0)

func _create_extra_resources_menu() -> void:
	_extra_resources_button = Button.new()
	_extra_resources_button.name = "MoreResourcesButton"
	_extra_resources_button.text = "ЕЩЁ"
	_extra_resources_button.set_meta("compact_hud", true)
	_extra_resources_button.add_theme_font_size_override("font_size", 12)
	_extra_resources_button.tooltip_text = "Другие товары домашнего склада"
	_extra_resources_button.pressed.connect(_toggle_extra_resources)
	_resource_bar.add_child(_extra_resources_button)
	_extra_resources_panel = PanelContainer.new()
	_extra_resources_panel.name = "MoreResourcesPanel"
	_extra_resources_panel.custom_minimum_size = Vector2(280, 0)
	add_child(_extra_resources_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "ResourceScroll"
	scroll.custom_minimum_size = Vector2(280, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_extra_resources_panel.add_child(scroll)
	_extra_resources_list = VBoxContainer.new()
	_extra_resources_list.name = "ResourceList"
	_extra_resources_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_extra_resources_list)
	_extra_resources_panel.hide()

func _rebuild_extra_resource_rows(resource_ids: Array[String]) -> void:
	for row in _extra_resources_list.get_children():
		row.queue_free()
	_extra_resource_values.clear()
	for resource_id in resource_ids:
		var label := Label.new()
		label.name = "Resource_" + resource_id
		label.text = "%s  —" % _goods_names.get(resource_id, resource_id)
		label.custom_minimum_size = Vector2(250, 28)
		label.add_theme_font_size_override("font_size", 15)
		_extra_resources_list.add_child(label)
		_extra_resource_values[resource_id] = label

func _create_more_panel() -> void:
	_more_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.32, 0.55, 0.72, 1.0)
	style.set_border_width_all(2)
	_more_panel.add_theme_stylebox_override("panel", style)
	add_child(_more_panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "MoreMargin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_more_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var banner: Control = load("res://systems/ui/faction_window_banner.gd").new()
	banner.call("set_faction", str(GameState.player_state.get("origin_race_id", "humans")))
	stack.add_child(banner)
	_more_list = VBoxContainer.new()
	_more_list.name = "MoreList"
	_more_list.add_theme_constant_override("separation", 7)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	_more_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_more_list)
	for item in _more_navigation:
		var button: Button = Button.new()
		var node_name: String = str(item.get("node_name", ""))
		button.name = "More_" + node_name
		button.text = "Флот и верфь" if node_name == "FleetWindow" else str(item.get("label", ""))
		button.custom_minimum_size = Vector2(230, 46)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_open_more_tool.bind(node_name, str(item.get("method", ""))))
		_more_list.add_child(button)
	_more_panel.hide()

func _add_more_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(230, 44)
	button.add_theme_font_size_override("font_size", 18)
	_more_list.add_child(button)

func _toggle_more() -> void:
	_more_panel.visible = not _more_panel.visible
	_extra_resources_panel.hide()
	if _more_panel.visible:
		_more_panel.z_index = 4096
		_more_panel.move_to_front()

func _toggle_extra_resources() -> void:
	_extra_resources_panel.visible = not _extra_resources_panel.visible
	_more_panel.hide()
	if _extra_resources_panel.visible:
		_extra_resources_panel.z_index = 4096
		_extra_resources_panel.move_to_front()

func _open_more_tool(node_name: String, method: String) -> void:
	_more_panel.hide()
	_open_tool(node_name, method)

func _open_fleet_hub() -> void:
	var docked_id := str(GameState.ship_state.get("docked_port_id", ""))
	var home_id := str(GameState.world_state.get("home_port_id", ""))
	if docked_id == home_id and home_id != "":
		var port: Node = _main.get_node_or_null("PortWindow")
		if port != null:
			_close_all_workspaces()
			_details = ""
			_port_expanded = true
			port.call("_open_section", "shipyard")
		return
	_open_tool("FleetWindow", "_toggle")

func _hide_duplicate_floating_controls() -> void:
	var fleet: Node = _main.get_node_or_null("FleetWindow")
	if fleet != null:
		var fleet_button: Button = fleet.get("_button")
		if fleet_button != null:
			fleet_button.hide()
	var navigation: Node = _main.get_node_or_null("NavigationHUD")
	if navigation != null:
		var navigation_button: Button = navigation.get("_toggle_button")
		if navigation_button != null:
			navigation_button.hide()

func _wrap_panel(window: Node, panel: PanelContainer, flag: String) -> void:
	if panel.get_child_count() == 0:
		return
	var content: Control = panel.get_child(0)
	panel.remove_child(content)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	var banner: Control = load("res://systems/ui/faction_window_banner.gd").new()
	banner.call("set_faction", str(GameState.player_state.get("origin_race_id", "humans")))
	column.add_child(banner)
	var header := HBoxContainer.new()
	column.add_child(header)
	var emblem := TextureRect.new()
	emblem.texture = GameData.get_faction_emblem(str(GameState.player_state.get("origin_race_id", "humans")))
	emblem.custom_minimum_size = Vector2(36, 42)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(emblem)
	var title := Label.new()
	var navigation: Dictionary = window.get_meta("navigation", {})
	title.text = str(navigation.get("label", str(window.name)))
	if title.text == str(window.name):
		title.text = {"ShipyardWindow": "Верфь", "BuildingProjectWindow": "Строительство", "GarrisonWindow": "Гарнизон", "MageGuildWindow": "Гильдия магов", "PortServiceWindow": "Обслуживание корабля"}.get(str(window.name), "Sea Trader")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	var close: Button = Button.new()
	close.name = "CloseButton"
	close.text = "×"
	close.tooltip_text = "Закрыть · Esc"
	close.custom_minimum_size = Vector2(48, 46)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_window.bind(window, flag))
	header.add_child(close)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if str(window.name) in ["NavigationHUD", "BuildingProjectWindow", "ShipyardWindow"] or _contains_scroll_container(content):
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(content)
	else:
		# Keep the close button visible while long workspace content scrolls.
		var scroll := ScrollContainer.new()
		scroll.name = "WorkspaceScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		column.add_child(scroll)
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
	_hide_duplicate_close(content)

func _contains_scroll_container(node: Node) -> bool:
	for child in node.get_children():
		if child is ScrollContainer or _contains_scroll_container(child):
			return true
	return false

func _wrap_port(port: Node) -> void:
	port.install_art_layout()

func _apply_menu_style(node: Node) -> void:
	if node is Control:
		_game_theme.apply_control(node)
	for child in node.get_children():
		_apply_menu_style(child)


func _enable_vertical_scrolling(node: Node) -> void:
	if node is ScrollContainer:
		var scroll: ScrollContainer = node
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	for child in node.get_children():
		_enable_vertical_scrolling(child)


func _hide_duplicate_close(node: Node) -> void:
	if node is Button and str(node.text).to_lower() == "закрыть":
		node.hide()
	for child in node.get_children():
		_hide_duplicate_close(child)

func _close_window(window: Node, flag: String) -> void:
	window.set(flag, false)

func _open_garrison() -> void:
	if str(GameState.ship_state.get("docked_port_id", "")) != str(GameState.world_state.get("home_port_id", "")):
		return
	var windows: Array[Node] = get_tree().get_nodes_in_group("garrison_window")
	if not windows.is_empty() and windows[0].has_method("open"):
		windows[0].call("open")

func _open_tool(node_name: String, method: String) -> void:
	var window: Node = _main.get_node_or_null(node_name)
	if window == null:
		return
	for entry in _entries:
		if entry["window"] == window:
			if bool(window.get(str(entry["flag"]))):
				_close_window(window, str(entry["flag"]))
			elif method != "":
				window.call(method)
			else:
				window.set(str(entry["flag"]), true)
			return

func _process(_delta: float) -> void:
	if _main == null:
		return
	for entry in _entries:
		if bool(entry["window"].get(str(entry["flag"]))):
			_apply_menu_style(entry["window"])
	var port_controls: Node = _main.get_node_or_null("PortWindow")
	if port_controls != null:
		_apply_menu_style(port_controls)
	_apply_menu_style(self)
	_more_panel.z_index = 4096
	_extra_resources_panel.z_index = 4096
	var selected: Node = null
	for entry in _entries:
		var window: Node = entry["window"]
		var opened: bool = bool(window.get(str(entry["flag"])))
		if opened and not bool(entry["was_open"]):
			selected = window
	if selected != null:
		for entry in _entries:
			if entry["window"] != selected:
				_close_window(entry["window"], str(entry["flag"]))
	var has_modal: bool = false
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_refresh_resource_bar()
	_refresh_ship_indicators()
	_layout_top_bar(viewport)
	for entry in _entries:
		var opened: bool = bool(entry["window"].get(str(entry["flag"])))
		entry["was_open"] = opened
		var panel: Control = entry["panel"]
		panel.visible = opened
		if opened:
			has_modal = true
			if str(entry["window"].name) == "NavigationHUD":
				panel.position = Vector2(0, _top_height + 4)
				panel.size = Vector2(viewport.x, maxf(120.0, viewport.y - panel.position.y - 12.0))
			else:
				var natural_size := panel.get_combined_minimum_size()
				var available := Vector2(maxf(120.0, viewport.x - 40.0), maxf(120.0, viewport.y - _top_height - 20.0))
				var target_size := Vector2(maxf(natural_size.x, minf(1440.0, available.x)), maxf(natural_size.y, available.y))
				var shrink := minf(1.0, minf(available.x / maxf(1.0, target_size.x), available.y / maxf(1.0, target_size.y)))
				panel.scale = Vector2.ONE * shrink
				panel.size = target_size
				panel.position = Vector2((viewport.x - target_size.x * shrink) * 0.5, _top_height + 4.0)
	var docked_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var docked: bool = docked_port_id != ""
	if docked_port_id != _last_docked:
		_last_docked = docked_port_id
		_port_expanded = false
		_details = ""
	_port_button.disabled = not docked
	var ship: Dictionary = GameState.ship_state
	var cargo: int = 0
	for item in ship.get("cargo", []):
		cargo += int(item.get("quantity", 0))
	_readouts.text = ""
	_readouts.position = Vector2(12, 4)
	_readouts.size = Vector2(viewport.x - 24, 24)
	_readouts.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_extra_resources_panel.size = Vector2(280.0, minf(320.0, viewport.y - 100.0))
	_extra_resources_panel.position = Vector2(
		viewport.x - _extra_resources_panel.size.x - 12.0,
		_top_height + 4.0
	)
	if _extra_resources_panel.visible:
		_extra_resources_panel.move_to_front()
	var guide: CanvasLayer = _main.get_node_or_null("FirstVoyageGuide")
	if guide != null:
		guide.visible = not has_modal and _details == "FirstVoyageGuide"
	var at_home: bool = docked and docked_port_id == home_port_id
	_refresh_more_availability(docked)
	for node_name in ["ShipStatusHUD", "MapStatusHUD", "WorldEventHUD", "MerchantOfferHUD"]:
		var hud: CanvasLayer = _main.get_node_or_null(node_name)
		if hud != null:
			hud.visible = not has_modal and _details == node_name and node_name != "ShipStatusHUD"
	_merchant_button.visible = bool(_main.get_node("MerchantOfferHUD").get("_button").visible)
	_main.get_node("MerchantOfferHUD").get("_panel").position = Vector2(maxf(12, viewport.x - 435), _top_height + 4)
	_main.get_node("PortWindow").visible = not has_modal and docked and _port_expanded
	if has_modal:
		_extra_resources_panel.hide()
		_main.get_node("MerchantOfferHUD").get("_button").hide()
	_main.get_node("FleetWindow").get("_button").hide()
	_main.get_node("MerchantOfferHUD").get("_button").hide()
	_main.get_node("CrewWindow").get("_button").hide()
	_main.get_node("NavigationHUD").get("_toggle_button").hide()
	_main.get_node("NavigationHUD").get("_course_label").hide()
	_toolbar.visible = true
	_more_panel.size = Vector2(260.0, minf(330.0, viewport.y - 100.0))
	_more_panel.position = Vector2(
		clampf(_toolbar.position.x + _toolbar.size.x * _toolbar.scale.x - _more_panel.size.x, 12.0, viewport.x - _more_panel.size.x - 12.0),
		_top_height + 4.0
	)
	if _more_panel.visible:
		_more_panel.move_to_front()
	_cancel.visible = bool(GameState.voyage_state.get("active_autopilot", false))
	_status.visible = false
	_readouts.tooltip_text = str(GameState.world_state.get("autopilot_notice", ""))
	_status.position = Vector2(maxf(12, viewport.x - 330), 37)
	_status.size.x = 315
	_status.text = str(GameState.world_state.get("autopilot_notice", ""))
	if docked and not has_modal:
		var port_panel: PanelContainer = _main.get_node("PortWindow").get("_sheet")
		port_panel.size = Vector2(minf(1480.0, viewport.x - 40.0), maxf(200.0, viewport.y - _top_height - 24.0))
		port_panel.position = Vector2((viewport.x - port_panel.size.x) * 0.5, _top_height + 4.0)

func _layout_top_bar(viewport: Vector2) -> void:
	var full_width: float = viewport.x
	if bool(GameState.combat_state.get("naval_battle", {}).get("active", false)): viewport.x *= 0.75
	var menu_min: Vector2 = _toolbar.get_combined_minimum_size()
	var stock_min: Vector2 = _resource_bar.get_combined_minimum_size()
	var available: float = maxf(1.0, viewport.x - 24.0)
	_toolbar.size = Vector2(menu_min.x, maxf(48, menu_min.y))
	_resource_bar.size = Vector2(stock_min.x, maxf(42, stock_min.y))
	var menu_scale: float = minf(1.0, available / maxf(1.0, menu_min.x))
	var stock_scale: float = minf(1.0, available / maxf(1.0, stock_min.x))
	_toolbar.scale = Vector2.ONE * menu_scale
	_resource_bar.scale = Vector2.ONE * stock_scale
	_toolbar.position = Vector2(12, 8)
	var sailing: bool = str(GameState.ship_state.get("docked_port_id", "")) == ""
	_ship_strip.visible = sailing
	if not sailing:
		if menu_min.x + stock_min.x + 24.0 <= available:
			_resource_bar.position = Vector2(viewport.x - stock_min.x - 12, 11)
			_top_height = maxf(_toolbar.size.y, _resource_bar.size.y) + 16.0
		else:
			var second_row_y: float = 12.0 + _toolbar.size.y * menu_scale
			_resource_bar.position = Vector2(viewport.x - stock_min.x * stock_scale - 12, second_row_y)
			_top_height = second_row_y + _resource_bar.size.y * stock_scale + 8.0
	elif menu_min.x + stock_min.x + 24.0 <= available:
		_resource_bar.position = Vector2(viewport.x - stock_min.x - 12, 11)
		var strip_y: float = maxf(8.0 + _toolbar.size.y * menu_scale, 11.0 + _resource_bar.size.y * stock_scale) + 2.0
		_ship_strip.position = Vector2(0, strip_y)
		_ship_strip.size = Vector2(full_width, 36)
		_top_height = strip_y + 40.0
	else:
		var row_y: float = 12.0 + _toolbar.size.y * menu_scale
		_resource_bar.position = Vector2(viewport.x - stock_min.x * stock_scale - 12, row_y)
		var strip_y: float = row_y + _resource_bar.size.y * stock_scale + 2.0
		_ship_strip.position = Vector2(0, strip_y)
		_ship_strip.size = Vector2(full_width, 36)
		_top_height = strip_y + 40.0
	get_node("TopMenuBackdrop").size = Vector2(viewport.x, _top_height)

func _refresh_more_availability(docked: bool) -> void:
	if _more_panel == null:
		return
	var fleet_button: Button = _more_list.get_node_or_null("More_FleetWindow")
	if fleet_button != null:
		var home_id: String = str(GameState.world_state.get("home_port_id", ""))
		var home: Dictionary = GameState.port_state.get(home_id, {})
		var shipyard: Dictionary = home.get("buildings", {}).get("shipyard", {})
		fleet_button.visible = not GameState.fleet_state.is_empty() or (docked and int(shipyard.get("level", 0)) >= 1 and str(shipyard.get("status", "")) == "active")
	var any_visible: bool = false
	for child in _more_list.get_children():
		if child is Control and child.visible:
			any_visible = true
	_more_button.visible = any_visible

func _cancel_voyage() -> void:
	var systems: Array[Node] = get_tree().get_nodes_in_group("active_route_autopilot_system")
	if not systems.is_empty():
		systems[0].cancel()

func _cycle_text_scale() -> void:
	if _accessibility == null:
		return
	_accessibility.cycle_scale()
	_refresh_text_scale_button()

func _refresh_text_scale_button() -> void:
	if _text_scale_button != null and _accessibility != null:
		_text_scale_button.text = "ТЕКСТ %d%%" % int(_accessibility.get_scale_percent())

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_more_panel.hide()
		_extra_resources_panel.hide()
		_port_expanded = false
		_details = ""
		for entry in _entries:
			_close_window(entry["window"], str(entry["flag"]))
		get_viewport().set_input_as_handled()

func _close_all_workspaces() -> void:
	for entry in _entries:
		_close_window(entry["window"], str(entry["flag"]))
