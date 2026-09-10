extends CanvasLayer

## Central port window. It displays state and forwards only port actions.

var _port_system: Node
var _root: Control
var _sheet: PanelContainer
var _title: Label
var _details: Label
var _leave_button: Button

func _ready() -> void:
	layer = 35
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.38)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	_sheet = PanelContainer.new()
	_sheet.size = Vector2(440, 380)
	_root.add_child(_sheet)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_sheet.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	column.add_child(_title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 16)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_details)
	var save_button := Button.new()
	save_button.text = "Save progress"
	save_button.custom_minimum_size.y = 42
	save_button.pressed.connect(_save_progress)
	column.add_child(save_button)
	_leave_button = Button.new()
	_leave_button.text = "Leave port [E]"
	_leave_button.custom_minimum_size.y = 42
	_leave_button.pressed.connect(_leave_port)
	column.add_child(_leave_button)
	_root.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _root == null or _port_system == null:
		return
	var docked_port: String = str(GameState.ship_state.get("docked_port_id", ""))
	_root.visible = docked_port != ""
	if docked_port == "":
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_sheet.size = Vector2(minf(440.0, viewport_size.x - 24.0), minf(380.0, viewport_size.y - 24.0))
	_sheet.position = (viewport_size - _sheet.size) * 0.5
	var ship: Dictionary = GameState.ship_state
	var port: Dictionary = GameState.port_state.get(docked_port, {})
	var port_name: String = _port_system.get_port_name(docked_port)
	_title.text = "PORT: " + port_name
	_details.text = (
		"Docked\n"
		+ "Port level: %d\n\n"
		+ "Money: %.0f\n"
		+ "Fuel: %.1f / %.0f\n"
		+ "Hull: %.0f / 100\n"
		+ "Cargo entries: %d\n\n"
		+ "Trade, refuel and repair will be added here."
	) % [
		int(port.get("level", 1)),
		float(GameState.player_state.get("money", 0.0)),
		float(ship.get("fuel", 0.0)), float(ship.get("fuel_max", 0.0)),
		float(ship.get("hull", 0.0)),
		ship.get("cargo", []).size()
	]

func _save_progress() -> void:
	SaveSystem.save_game()

func _leave_port() -> void:
	_port_system.undock()

func _unhandled_key_input(event: InputEvent) -> void:
	if _port_system == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E or event.physical_keycode == KEY_E:
		_leave_port()
		get_viewport().set_input_as_handled()
