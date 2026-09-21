extends CanvasLayer

## One workspace panel at a time; existing windows retain their own actions/state.
var _entries: Array = []
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

func initialize(main: Node) -> void:
	_main = main
	layer = 90
	process_priority = 1000
	for window in main.get_children():
		if not window.has_meta("workspace_flag"):
			continue
		var panel: PanelContainer = window.get("_panel")
		if panel == null:
			continue
		var flag: String = str(window.get_meta("workspace_flag"))
		_entries.append({"window": window, "flag": flag, "was_open": false, "panel": panel})
		window.layer = 60
		_wrap_panel(window, panel, flag)
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 8)
	add_child(_toolbar)
	var navigation: Array = []
	for window in main.get_children():
		if window.has_meta("navigation"):
			var item: Dictionary = window.get_meta("navigation").duplicate(true)
			item["node_name"] = str(window.name)
			navigation.append(item)
	navigation.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	for item in navigation:
		if str(item.get("node_name", "")) in ["NavigationHUD", "LogisticsWindow", "CaptainCabinet"]:
			_add_toolbar_button(item)
		else:
			_more_navigation.append(item)
	_more_button = Button.new()
	_more_button.text = "ЕЩЁ  ⋮"
	_more_button.custom_minimum_size = Vector2(135, 44)
	_more_button.add_theme_font_size_override("font_size", 20)
	_more_button.pressed.connect(_toggle_more)
	_toolbar.add_child(_more_button)
	_create_more_panel()
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
	_toolbar.add_child(_cancel)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var port: Node = main.get_node_or_null("PortWindow")
	if port != null:
		_wrap_port(port)
	# These two controls were useful during the first prototype, but duplicate
	# the one bottom navigation bar on a phone-sized screen.
	_hide_duplicate_floating_controls()

func _add_toolbar_button(item: Dictionary) -> void:
	var button: Button = Button.new()
	button.text = str(item.get("label", ""))
	button.custom_minimum_size = Vector2(135, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_open_tool.bind(str(item.get("node_name", "")), str(item.get("method", ""))))
	_toolbar.add_child(button)

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
	_more_list = VBoxContainer.new()
	_more_list.name = "MoreList"
	_more_list.add_theme_constant_override("separation", 7)
	margin.add_child(_more_list)
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

func _open_more_tool(node_name: String, method: String) -> void:
	_more_panel.hide()
	_open_tool(node_name, method)

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
	var close: Button = Button.new()
	close.text = "Закрыть  ×  [Esc]"
	close.custom_minimum_size.y = 46
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_window.bind(window, flag))
	column.add_child(close)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_hide_duplicate_close(content)

func _wrap_port(port: Node) -> void:
	var panel: PanelContainer = port.get("_sheet")
	var content: Control = panel.get_child(0)
	panel.remove_child(content)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

func _hide_duplicate_close(node: Node) -> void:
	if node is Button and str(node.text).to_lower() == "закрыть":
		node.hide()
	for child in node.get_children():
		_hide_duplicate_close(child)

func _close_window(window: Node, flag: String) -> void:
	window.set(flag, false)

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
	for entry in _entries:
		var opened: bool = bool(entry["window"].get(str(entry["flag"])))
		entry["was_open"] = opened
		var panel: PanelContainer = entry["panel"]
		panel.visible = opened
		if opened:
			has_modal = true
			panel.size = Vector2(minf(900.0, viewport.x - 32.0), maxf(200.0, viewport.y - 156.0))
			panel.position = Vector2((viewport.x - panel.size.x) * 0.5, 20.0)
	var docked: bool = str(GameState.ship_state.get("docked_port_id", "")) != ""
	_refresh_more_availability(docked)
	for node_name in ["ShipStatusHUD", "MapStatusHUD", "WorldEventHUD"]:
		var hud: CanvasLayer = _main.get_node_or_null(node_name)
		if hud != null:
			hud.visible = not has_modal and not docked and node_name != "MapStatusHUD"
	_main.get_node("PortWindow").visible = not has_modal
	if has_modal:
		_more_panel.hide()
		_main.get_node("MerchantOfferHUD").get("_button").hide()
	_main.get_node("FleetWindow").get("_button").hide()
	_main.get_node("CrewWindow").get("_button").hide()
	_main.get_node("NavigationHUD").get("_toggle_button").hide()
	_main.get_node("NavigationHUD").get("_course_label").visible = not has_modal and not docked
	_toolbar.position = Vector2(maxf(12.0, (viewport.x - _toolbar.size.x) * 0.5), viewport.y - _toolbar.size.y - 12.0 if has_modal or not docked else 12.0)
	_more_panel.size = Vector2(260.0, minf(330.0, viewport.y - 100.0))
	_more_panel.position = Vector2(
		clampf(_toolbar.position.x + _toolbar.size.x - _more_panel.size.x, 12.0, viewport.x - _more_panel.size.x - 12.0),
		_toolbar.position.y - _more_panel.size.y - 10.0 if not docked else _toolbar.position.y + _toolbar.size.y + 10.0
	)
	if has_modal or docked:
		_more_panel.hide()
	_cancel.visible = bool(GameState.voyage_state.get("active_autopilot", false))
	_status.visible = not has_modal and not docked
	_status.position = Vector2(12, 320)
	_status.size.x = 350
	_status.text = str(GameState.world_state.get("autopilot_notice", ""))
	if docked and not has_modal:
		var port_panel: PanelContainer = _main.get_node("PortWindow").get("_sheet")
		port_panel.size = Vector2(minf(900.0, viewport.x - 32.0), maxf(200.0, viewport.y - 180.0))
		port_panel.position = Vector2((viewport.x - port_panel.size.x) * 0.5, 70.0)

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
		for entry in _entries:
			_close_window(entry["window"], str(entry["flag"]))
		get_viewport().set_input_as_handled()
