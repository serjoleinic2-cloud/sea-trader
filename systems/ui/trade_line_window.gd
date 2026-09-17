extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _details: Label
var _ship: OptionButton
var _origin: OptionButton
var _destination: OptionButton
var _goods: OptionButton
var _quantity: HSlider
var _min_profit: HSlider
var _quantity_label: Label
var _profit_label: Label
var _open: bool = false
var _ship_ids: Array[String] = []
var _port_ids: Array[String] = []
var _good_ids: Array[String] = []

func _ready() -> void:
	add_to_group("trade_line_window")
	layer = 55
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.85, 0.66, 0.25, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "ПОСТОЯННАЯ ТОРГОВАЯ ЛИНИЯ"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_ship = _select(box, "Корабль")
	_origin = _select(box, "Порт закупки")
	_destination = _select(box, "Порт продажи")
	_goods = _select(box, "Товар")
	_quantity_label = _label(box)
	_quantity = HSlider.new()
	_quantity.min_value = 1.0
	_quantity.max_value = 50.0
	_quantity.step = 1.0
	_quantity.value = 10.0
	box.add_child(_quantity)
	_profit_label = _label(box)
	_min_profit = HSlider.new()
	_min_profit.min_value = 0.0
	_min_profit.max_value = 500.0
	_min_profit.step = 10.0
	_min_profit.value = 40.0
	box.add_child(_min_profit)
	var start: Button = Button.new()
	start.text = "ЗАПУСТИТЬ ЛИНИЮ"
	start.add_theme_font_size_override("font_size", 21)
	start.custom_minimum_size.y = 50
	start.pressed.connect(_start)
	box.add_child(start)
	var stop: Button = Button.new()
	stop.text = "Остановить все линии"
	stop.custom_minimum_size.y = 42
	stop.pressed.connect(_stop_all)
	box.add_child(stop)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 18)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	var close: Button = Button.new()
	close.text = "Закрыть"
	close.custom_minimum_size.y = 42
	close.pressed.connect(_close)
	box.add_child(close)
	_panel.hide()

func _select(box: VBoxContainer, name: String) -> OptionButton:
	var label: Label = _label(box)
	label.text = name
	var select: OptionButton = OptionButton.new()
	select.add_theme_font_size_override("font_size", 19)
	select.custom_minimum_size.y = 40
	box.add_child(select)
	return select

func _label(box: VBoxContainer) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	return label

func initialize(system: Node) -> void:
	_system = system

func open() -> void:
	_open = true
	_fill()

func _fill() -> void:
	if _system == null:
		return
	_ship.clear()
	_origin.clear()
	_destination.clear()
	_goods.clear()
	_ship_ids.clear()
	_port_ids.clear()
	_good_ids.clear()
	var fleets: Array[Node] = get_tree().get_nodes_in_group("fleet_system")
	if not fleets.is_empty():
		for raw_ship in fleets[0].get_auxiliary_ships():
			var ship: Dictionary = raw_ship
			if str(ship.get("status", "")).begins_with("В пути"):
				continue
			_ship_ids.append(str(ship.get("instance_id", "")))
			_ship.add_item(str(ship.get("name", "Корабль")))
	for raw_port in _system.get_known_ports():
		var port: Dictionary = raw_port
		_port_ids.append(str(port.get("id", "")))
		_origin.add_item(str(port.get("name", "")))
		_destination.add_item(str(port.get("name", "")))
	for raw_good in _system.get_goods():
		var good: Dictionary = raw_good
		_good_ids.append(str(good.get("id", "")))
		_goods.add_item(str(good.get("name", "")))

func _process(_delta: float) -> void:
	_panel.visible = _open
	if not _open:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(820.0, viewport.x - 24.0), minf(1120.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_quantity_label.text = "Количество: %d" % int(_quantity.value)
	_profit_label.text = "Минимальная прибыль за рейс: %.0f" % _min_profit.value
	_details.text = _lines_text()

func _start() -> void:
	var result: Dictionary = _system.create_line(
		_id(_ship, _ship_ids),
		_id(_origin, _port_ids),
		_id(_destination, _port_ids),
		_id(_goods, _good_ids),
		int(_quantity.value),
		_min_profit.value
	)
	_details.text = str(result.get("message", ""))

func _stop_all() -> void:
	for raw_line in _system.get_lines():
		var line: Dictionary = raw_line
		_system.stop_line(str(line.get("id", "")))

func _lines_text() -> String:
	var lines: Array[String] = ["ЛИНИИ:"]
	for raw_line in _system.get_lines():
		var line: Dictionary = raw_line
		lines.append("%s: %s | циклов %d | доход %.0f" % [
			str(line.get("id", "")),
			str(line.get("status", "")),
			int(line.get("cycles", 0)),
			float(line.get("earned", 0.0))
		])
	return "\n".join(lines)

func _id(select: OptionButton, ids: Array[String]) -> String:
	var index: int = select.selected
	return ids[index] if index >= 0 and index < ids.size() else ""

func _close() -> void:
	_open = false
