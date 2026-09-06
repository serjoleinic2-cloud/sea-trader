extends CanvasLayer

# PortDebugHUD — Phase 05
# Показывает: кол-во обнаруженных портов и имя ближайшего.
# Только для отладки. Не финальный UI.

var _label: Label = null
var _port_system: Node = null


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(10, 80)   # ниже существующего debug HUD
	_label.add_theme_color_override("font_color", Color.CYAN)
	add_child(_label)


func initialize(port_system: Node) -> void:
	_port_system = port_system


func _process(_delta: float) -> void:
	if _port_system == null:
		_label.text = ""
		return

	var discovered: int = _port_system.discovered_count
	var total: int      = _port_system.total_port_count
	var nearest: String = _port_system.nearest_port_name

	var text := "Ports: %d / %d" % [discovered, total]
	if nearest != "":
		text += "\nNear: %s" % nearest
	_label.text = text
