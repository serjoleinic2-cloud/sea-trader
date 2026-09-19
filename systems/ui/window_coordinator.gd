extends CanvasLayer

## One workspace panel at a time; existing windows retain their own actions/state.
var _entries: Array = []
var _main: Node
var _toolbar: HBoxContainer
var _status: Label
var _cancel: Button

func initialize(main: Node) -> void:
	_main = main
	layer = 90
	process_priority = 1000
	var definitions: Dictionary = {
		"CaptainCabinet": "_open", "FleetWindow": "_is_open",
		"LogisticsWindow": "_open", "TradeLineWindow": "_open",
		"NavigationHUD": "_is_open", "HiringWindow": "_is_open",
		"CrewWindow": "_is_open", "ShipyardWindow": "_is_open",
		"BuildingProjectWindow": "_is_open", "SupplyOrderWindow": "_open",
		"PortServiceWindow": "_open", "WorkHireWindow": "_open",
		"MerchantOfferHUD": "_is_open"
	}
	for node_name in definitions:
		var window: Node = main.get_node_or_null(str(node_name))
		if window == null:
			continue
		var panel: PanelContainer = window.get("_panel")
		if panel == null:
			continue
		var flag: String = str(definitions[node_name])
		_entries.append({"window": window, "flag": flag, "was_open": false, "panel": panel})
		window.layer = 60
		_wrap_panel(window, panel, flag)
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 8)
	add_child(_toolbar)
	for item in [["Карта", "NavigationHUD", "_toggle_panel"], ["Флот", "FleetWindow", "_toggle"], ["Рейсы", "LogisticsWindow", "open"], ["Капитан", "CaptainCabinet", ""]]:
		var button: Button = Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(135, 44)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_open_tool.bind(str(item[1]), str(item[2])))
		_toolbar.add_child(button)
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
	for node_name in ["ShipStatusHUD", "MapStatusHUD", "WorldEventHUD"]:
		var hud: CanvasLayer = _main.get_node_or_null(node_name)
		if hud != null:
			hud.visible = not has_modal and not docked and node_name != "MapStatusHUD"
	_main.get_node("PortWindow").visible = not has_modal
	if has_modal:
		_main.get_node("MerchantOfferHUD").get("_button").hide()
	_main.get_node("FleetWindow").get("_button").hide()
	_main.get_node("CrewWindow").get("_button").hide()
	_main.get_node("NavigationHUD").get("_toggle_button").hide()
	_main.get_node("NavigationHUD").get("_course_label").visible = not has_modal and not docked
	_toolbar.position = Vector2(maxf(12.0, (viewport.x - _toolbar.size.x) * 0.5), viewport.y - 60.0 if has_modal or not docked else 12.0)
	_cancel.visible = bool(GameState.voyage_state.get("active_autopilot", false))
	_status.visible = not has_modal and not docked
	_status.position = Vector2(12, 320)
	_status.size.x = 350
	_status.text = str(GameState.world_state.get("autopilot_notice", ""))
	if docked and not has_modal:
		var port_panel: PanelContainer = _main.get_node("PortWindow").get("_sheet")
		port_panel.size = Vector2(minf(900.0, viewport.x - 32.0), maxf(200.0, viewport.y - 180.0))
		port_panel.position = Vector2((viewport.x - port_panel.size.x) * 0.5, 70.0)

func _cancel_voyage() -> void:
	var systems: Array[Node] = get_tree().get_nodes_in_group("active_route_autopilot_system")
	if not systems.is_empty():
		systems[0].cancel()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		for entry in _entries:
			_close_window(entry["window"], str(entry["flag"]))
		get_viewport().set_input_as_handled()
