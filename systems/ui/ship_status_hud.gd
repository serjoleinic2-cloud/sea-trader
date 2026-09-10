extends CanvasLayer

## Read-only ship status with actions forwarded to the port UI.

signal dock_requested(port_id: String)
signal save_requested()

var _panel: PanelContainer
var _column: VBoxContainer
var _label: Label
var _dock_button: Button
var _notice: Label
var _retry_button: Button
var _port_system: Node
var _ship_data: Dictionary = {}


func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 8)
	scroll.add_child(_column)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 16)
	_column.add_child(_label)
	_dock_button = Button.new()
	_dock_button.text = "Dock [E]"
	_dock_button.custom_minimum_size.y = 40
	_dock_button.pressed.connect(_request_dock)
	_dock_button.hide()
	_column.add_child(_dock_button)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.hide()
	_column.add_child(_notice)
	_retry_button = Button.new()
	_retry_button.text = "Retry save"
	_retry_button.custom_minimum_size.y = 40
	_retry_button.pressed.connect(func(): save_requested.emit())
	_retry_button.hide()
	_column.add_child(_retry_button)


func initialize(port_system: Node, ship_data: Dictionary = {}) -> void:
	_port_system = port_system
	_ship_data = ship_data


func _process(_delta: float) -> void:
	if _label == null:
		return
	visible = GameState.ship_state.get("docked_port_id", "") == ""
	var ship: Dictionary = GameState.ship_state
	var velocity: Vector2 = ship.get("velocity", Vector2.ZERO)
	var ship_position: Vector2 = ship.get("position", Vector2.ZERO)
	var cargo_units: int = 0
	for item in ship.get("cargo", []):
		cargo_units += int(item.get("quantity", 0))
	var nearest_port: String = ""
	var candidate: String = ""
	if _port_system != null:
		candidate = _port_system.get_dock_candidate()
		nearest_port = _port_system.get_port_name(candidate)
	_dock_button.visible = candidate != ""
	_label.text = (
		"SHIP STATUS\nMoney: %.0f\nSpeed: %.1f\nFuel: %.1f / %.0f\n"
		+ "Hull: %.0f / %.0f\nCargo: %d / %d\nPorts known: %d\n"
		+ "Near: %s\nPos: %d, %d"
	) % [
		float(GameState.player_state.get("money", 0.0)), velocity.length(),
		float(ship.get("fuel", 0.0)), float(ship.get("fuel_max", 0.0)),
		float(ship.get("hull", 0.0)), float(_ship_data.get("hull_max", 100.0)),
		cargo_units, int(ship.get("cargo_capacity", 0)),
		GameState.player_state.discovered_port_ids.size(),
		nearest_port if nearest_port != "" else "-", int(ship_position.x), int(ship_position.y)
	]
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(
		minf(320.0, maxf(1.0, viewport_size.x - 24.0)),
		minf(_column.get_combined_minimum_size().y + 24.0, maxf(1.0, viewport_size.y - 24.0)))


func show_save_result(saved: bool) -> void:
	_notice.text = "Progress saved." if saved else "Save failed. Progress is only in this session."
	_notice.visible = true
	_retry_button.visible = not saved


func _request_dock() -> void:
	if _port_system != null:
		dock_requested.emit(_port_system.get_dock_candidate())
