extends CanvasLayer

## Captain's cabinet: read-only record of player knowledge.

var _port_system: Node
var _panel: PanelContainer
var _label: Label
var _open := false

func _ready() -> void:
	layer = 40
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.size = Vector2(520, 620)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_label)
	_panel.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _label == null or _port_system == null:
		return
	_panel.visible = _open
	if not _open:
		return
	var ship: Dictionary = GameState.ship_state
	var lines: PackedStringArray = ["CAPTAIN'S CABINET", "Press M to close", ""]
	lines.append("SHIP")
	lines.append("Position: %d, %d" % [int(ship.get("position", Vector2.ZERO).x), int(ship.get("position", Vector2.ZERO).y)])
	lines.append("Fuel: %.1f / %.0f" % [float(ship.get("fuel", 0.0)), float(ship.get("fuel_max", 0.0))])
	lines.append("Hull: %.0f" % float(ship.get("hull", 0.0)))
	lines.append("Docked: " + (str(ship.get("docked_port_id", "")) if ship.get("docked_port_id", "") != "" else "at sea"))
	lines.append("")
	lines.append("DISCOVERED PORTS: %d" % GameState.player_state.discovered_port_ids.size())
	for port_id in GameState.player_state.discovered_port_ids:
		var name := _port_system.get_port_name(port_id) if _port_system.has_method("get_port_name") else str(port_id)
		lines.append("- " + (name if name != "" else str(port_id)))
	lines.append("")
	lines.append("KNOWN ROUTES: %d" % GameState.known_routes_state.size())
	for route_key in GameState.known_routes_state:
		lines.append("- " + str(route_key))
	_label.text = "\n".join(lines)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M or event.physical_keycode == KEY_M:
		_open = not _open
		get_viewport().set_input_as_handled()
