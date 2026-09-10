extends CanvasLayer

## Read-only ship state shown while sailing.

const PANEL_SIZE := Vector2(300, 210)

var _panel: ColorRect
var _label: Label
var _port_system: Node

func _ready() -> void:
	layer = 20
	_panel = ColorRect.new()
	_panel.size = PANEL_SIZE
	_panel.color = Color(0.02, 0.03, 0.04, 0.72)
	add_child(_panel)
	_label = Label.new()
	_label.size = PANEL_SIZE - Vector2(24, 20)
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9, 1.0))
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _label == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_position := Vector2(maxf(12.0, (viewport_size.x - PANEL_SIZE.x) * 0.5), 12.0)
	_panel.position = panel_position
	_label.position = panel_position + Vector2(12, 10)
	var ship: Dictionary = GameState.ship_state
	var cargo_units := 0
	for item in ship.get("cargo", []):
		cargo_units += int(item.get("quantity", 0))
	var docked_port := str(ship.get("docked_port_id", ""))
	var dock_hint := ""
	if docked_port != "":
		dock_hint = "\nE: leave port"
	elif _port_system != null and _port_system.has_method("get_dock_candidate") and _port_system.get_dock_candidate() != "":
		dock_hint = "\nE: dock"
	_label.text = (
		"SHIP STATUS\n"
		+ "Money: %.0f\n"
		+ "Speed: %.1f\n"
		+ "Fuel: %.1f / %.0f\n"
		+ "Hull: %.0f / 100\n"
		+ "Cargo: %d / %d\n"
		+ "Pos: %d, %d\n"
		+ "Docked: %s"
		+ "%s"
	) % [
		float(GameState.player_state.get("money", 0.0)),
		ship.get("velocity", Vector2.ZERO).length(),
		float(ship.get("fuel", 0.0)), float(ship.get("fuel_max", 0.0)),
		float(ship.get("hull", 0.0)),
		cargo_units, int(ship.get("cargo_capacity", 0)),
		int(ship.get("position", Vector2.ZERO).x), int(ship.get("position", Vector2.ZERO).y),
		docked_port if docked_port != "" else "at sea", dock_hint
	]

func _unhandled_key_input(event: InputEvent) -> void:
	if _port_system == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_E and event.physical_keycode != KEY_E:
		return
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_port_system.undock()
	else:
		var candidate := _port_system.get_dock_candidate()
		if candidate != "":
			_port_system.dock(candidate)
	get_viewport().set_input_as_handled()
