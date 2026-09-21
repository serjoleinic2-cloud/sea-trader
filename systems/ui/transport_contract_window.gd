extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _label: Label
var _action: Button
var _notice: String = ""
var _open: bool = false

func _ready() -> void:
	add_to_group("transport_contract_window")
	layer = 53
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.95, 0.66, 0.26, 1.0)
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
	_action = Button.new()
	_action.add_theme_font_size_override("font_size", 22)
	_action.custom_minimum_size.y = 54
	_action.pressed.connect(_act)
	box.add_child(_action)
	var close: Button = Button.new()
	close.text = "Закрыть"
	close.add_theme_font_size_override("font_size", 20)
	close.custom_minimum_size.y = 46
	close.pressed.connect(func() -> void: _open = false)
	box.add_child(close)
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
	_panel.size = Vector2(minf(760.0, viewport.x - 32.0), minf(610.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	var active: Dictionary = _system.get_active()
	if active.is_empty():
		var offer: Dictionary = _system.offer()
		_label.text = "ЗАКАЗЫ НА ПЕРЕВОЗКУ\n\n%s\n%s" % [str(offer.get("message", "")), _notice]
		if bool(offer.get("ok", false)):
			_label.text = "ЗАКАЗЫ НА ПЕРЕВОЗКУ\n\n%s → %s\nГруз: %s × %d\nНаграда: %.0f\n\n%s\n%s" % [
				str(offer.origin_name), str(offer.destination_name), str(offer.resource_name), int(offer.quantity), float(offer.reward), str(offer.message), _notice
			]
		_action.text = "ПРИНЯТЬ ЗАКАЗ"
		_action.disabled = not bool(offer.get("ok", false))
		return
	_label.text = "АКТИВНЫЙ ЗАКАЗ\n\n%s → %s\nГруз: %s × %d\nНаграда: %.0f\n\n%s" % [
		str(active.origin_name), str(active.destination_name), str(active.resource_name), int(active.quantity), float(active.reward), _notice
	]
	if not bool(active.get("loaded", false)):
		_action.text = "ЗАГРУЗИТЬ ОПЕЧАТАННЫЙ ГРУЗ"
		_action.disabled = str(GameState.ship_state.get("docked_port_id", "")) != str(active.origin_port_id)
	elif str(GameState.ship_state.get("docked_port_id", "")) == str(active.destination_port_id):
		_action.text = "СДАТЬ ЗАКАЗ И ПОЛУЧИТЬ НАГРАДУ"
		_action.disabled = false
	else:
		_action.text = "ВЕДИТЕ ВРУЧНУЮ В «%s»" % str(active.destination_name)
		_action.disabled = true

func _act() -> void:
	var active: Dictionary = _system.get_active()
	var result: Dictionary = _system.accept() if active.is_empty() else (_system.load() if not bool(active.get("loaded", false)) else _system.complete())
	_notice = str(result.get("message", ""))
