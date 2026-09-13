extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _label: Label
var _notice: String = ""
var _open: bool = false

func _ready() -> void:
	add_to_group("port_service_window")
	layer = 52
	_panel = PanelContainer.new()
	_panel.size = Vector2(680, 540)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.30, 0.76, 0.92, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label)
	var fuel_button: Button = Button.new()
	fuel_button.text = "Заправить бак полностью"
	fuel_button.add_theme_font_size_override("font_size", 22)
	fuel_button.custom_minimum_size.y = 54
	fuel_button.pressed.connect(_refuel)
	box.add_child(fuel_button)
	var repair_button: Button = Button.new()
	repair_button.text = "Отремонтировать корпус полностью"
	repair_button.add_theme_font_size_override("font_size", 22)
	repair_button.custom_minimum_size.y = 54
	repair_button.pressed.connect(_repair)
	box.add_child(repair_button)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.custom_minimum_size.y = 46
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_panel.hide()

func initialize(system: Node) -> void:
	_system = system

func open() -> void:
	_open = true
	_notice = ""

func _process(_delta: float) -> void:
	_panel.visible = _open
	if not _open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(680.0, viewport.x - 32.0), minf(540.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_label.text = "ПОРТОВЫЙ СЕРВИС\n\nТопливо: %.0f / %.0f\nКорпус: %.0f / 100\nДеньги: %.0f\n\n%s\n%s" % [
		float(GameState.ship_state.get("fuel", 0.0)),
		float(GameState.ship_state.get("fuel_max", 0.0)),
		float(GameState.ship_state.get("hull", 0.0)),
		float(GameState.player_state.get("money", 0.0)),
		_system.get_service_text(),
		_notice
	]

func _refuel() -> void:
	var missing: float = float(GameState.ship_state.get("fuel_max", 0.0)) - float(GameState.ship_state.get("fuel", 0.0))
	var result: Dictionary = _system.refuel(missing)
	_notice = str(result.get("message", ""))

func _repair() -> void:
	var missing: float = 100.0 - float(GameState.ship_state.get("hull", 100.0))
	var result: Dictionary = _system.repair(missing)
	_notice = str(result.get("message", ""))

func _close() -> void:
	_open = false
