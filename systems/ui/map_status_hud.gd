extends CanvasLayer

## Read-only map knowledge summary.

var _port_system: Node
var _panel: ColorRect
var _label: Label

func _ready() -> void:
	layer = 20
	_panel = ColorRect.new()
	_panel.position = Vector2(12, 12)
	_panel.size = Vector2(260, 150)
	_panel.color = Color(0.02, 0.03, 0.04, 0.72)
	add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(24, 22)
	_label.size = Vector2(236, 130)
	_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 1.0))
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _label == null:
		return
	var nearest := "-"
	if _port_system != null and str(_port_system.nearest_port_name) != "":
		nearest = str(_port_system.nearest_port_name)
	_label.text = (
		"MAP DATA\n"
		+ "Ports known: %d\n"
		+ "Routes known: %d\n"
		+ "Nearest: %s\n"
		+ "Captain cabinet: M"
	) % [
		GameState.player_state.get("discovered_port_ids", []).size(),
		GameState.known_routes_state.size(),
		nearest
	]
