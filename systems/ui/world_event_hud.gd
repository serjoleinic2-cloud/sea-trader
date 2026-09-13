extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	layer = 46
	_panel = PanelContainer.new()
	_panel.size = Vector2(430, 130)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.08, 0.04, 1.0)
	style.border_color = Color(1.0, 0.62, 0.20, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_label)
	_panel.hide()

func initialize(system: Node) -> void:
	_system = system

func _process(_delta: float) -> void:
	if _system == null:
		return
	var active: Dictionary = _system.get_active_event()
	_panel.visible = not active.is_empty()
	if active.is_empty():
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(viewport.x - _panel.size.x - 12.0, 92.0)
	var left: int = maxi(0, int(active.get("expires_at", 0)) - int(Time.get_unix_time_from_system()))
	_label.text = "⚠ СОБЫТИЕ\n%s\nОсталось: %d:%02d" % [
		str(active.get("message", "")),
		left / 60,
		left % 60
	]
