extends CanvasLayer

## Schematic ship status panel for active gameplay testing.

const PANEL_POSITION: Vector2 = Vector2(12, 12)
const PANEL_SIZE: Vector2 = Vector2(300, 190)

var _label: Label = null
var _port_system: Node = null


func _ready() -> void:
	layer = 20

	var panel := ColorRect.new()
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.color = Color(0.02, 0.03, 0.04, 0.72)
	add_child(panel)

	_label = Label.new()
	_label.position = PANEL_POSITION + Vector2(12, 10)
	_label.size = PANEL_SIZE - Vector2(24, 20)
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9, 1.0))
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)


func initialize(port_system: Node) -> void:
	_port_system = port_system


func _process(_delta: float) -> void:
	if _label == null:
		return

	var money: float = float(GameState.player_state.get("money", 0.0))
	var speed: float = GameState.ship_state.get("velocity", Vector2.ZERO).length()
	var fuel: float = float(GameState.ship_state.get("fuel", 0.0))
	var fuel_max: float = float(GameState.ship_state.get("fuel_max", 100.0))
	var hull: float = float(GameState.ship_state.get("hull", 0.0))
	var cargo: Array = GameState.ship_state.get("cargo", [])
	var cargo_capacity: int = int(GameState.ship_state.get("cargo_capacity", 0))
	var position: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	var discovered_count: int = GameState.player_state.get("discovered_port_ids", []).size()
	var nearest_port: String = ""
	var dock_candidate: String = ""

	if _port_system != null:
		nearest_port = _port_system.nearest_port_name
		if _port_system.has_method("get_dock_candidate"):
			dock_candidate = _port_system.get_dock_candidate()

	var dock_hint: String = ""
	if dock_candidate != "":
		dock_hint = "\nDock: press E"

	_label.text = (
		"SHIP STATUS\n"
		+ "Money: %d\n"
		+ "Speed: %.1f\n"
		+ "Fuel: %d / %d\n"
		+ "Hull: %d / 100\n"
		+ "Cargo: %d / %d\n"
		+ "Ports known: %d\n"
		+ "Nearest: %s\n"
		+ "Pos: %d, %d\n"
		+ "%s"
	) % [
		int(money),
		speed,
		int(fuel), int(fuel_max),
		int(hull),
		cargo.size(), cargo_capacity,
		discovered_count,
		nearest_port if nearest_port != "" else "-",
		int(position.x), int(position.y), dock_hint
	]


func _unhandled_key_input(event: InputEvent) -> void:
	if _port_system == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E or event.physical_keycode == KEY_E:
		var candidate: String = _port_system.get_dock_candidate()
		if candidate != "":
			_port_system.dock(candidate)
			get_viewport().set_input_as_handled()
