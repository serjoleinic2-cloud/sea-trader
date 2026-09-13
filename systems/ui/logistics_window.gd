extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _details: Label
var _origin: OptionButton
var _destination: OptionButton
var _goods: OptionButton
var _quantity: HSlider
var _quantity_label: Label
var _open: bool = false
var _port_ids: Array[String] = []
var _good_ids: Array[String] = []

func _ready() -> void:
	add_to_group("logistics_window")
	layer = 54
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.45, 0.78, 0.95, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "ЛОГИСТИКА И ПРИБЫЛЬ"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_origin = _add_select(box, "Откуда")
	_destination = _add_select(box, "Куда")
	_goods = _add_select(box, "Товар")
	_quantity_label = Label.new()
	_quantity_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_quantity_label)
	_quantity = HSlider.new()
	_quantity.min_value = 1.0
	_quantity.max_value = 50.0
	_quantity.step = 1.0
	_quantity.value = 10.0
	_quantity.value_changed.connect(_on_changed)
	box.add_child(_quantity)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 20)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.custom_minimum_size.y = 46
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_panel.hide()

func _add_select(box: VBoxContainer, title: String) -> OptionButton:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	box.add_child(label)
	var select: OptionButton = OptionButton.new()
	select.add_theme_font_size_override("font_size", 20)
	select.custom_minimum_size.y = 42
	select.item_selected.connect(_on_changed.bind(0.0))
	box.add_child(select)
	return select

func initialize(system: Node) -> void:
	_system = system

func open() -> void:
	_open = true
	_fill_options()

func _fill_options() -> void:
	if _system == null:
		return
	_origin.clear()
	_destination.clear()
	_goods.clear()
	_port_ids.clear()
	_good_ids.clear()
	var ports: Array = _system.get_known_ports()
	for raw_port in ports:
		var port: Dictionary = raw_port
		var port_id: String = str(port.get("id", ""))
		_port_ids.append(port_id)
		_origin.add_item(str(port.get("name", port_id)))
		_destination.add_item(str(port.get("name", port_id)))
	var goods: Array = _system.get_goods()
	for raw_good in goods:
		var good: Dictionary = raw_good
		_good_ids.append(str(good.get("id", "")))
		_goods.add_item(str(good.get("display_name", "")))

func _process(_delta: float) -> void:
	_panel.visible = _open
	if not _open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(800.0, viewport.x - 32.0), minf(980.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_quantity_label.text = "Количество: %d" % int(_quantity.value)
	_refresh()

func _refresh() -> void:
	var origin_id: String = _get_selected(_origin, _port_ids)
	var destination_id: String = _get_selected(_destination, _port_ids)
	var good_id: String = _get_selected(_goods, _good_ids)
	var quote: Dictionary = _system.evaluate(origin_id, destination_id, good_id, int(_quantity.value))
	if not bool(quote.get("ok", false)):
		_details.text = str(quote.get("message", ""))
		return
	_details.text = "Цена покупки: %.0f\nЦена продажи: %.0f\nДистанция: %.0f\nТопливо: %.1f (≈ %.0f)\nРезерв ремонта: %.0f\nВаловая прибыль: %.0f\n\nЧИСТАЯ ПРИБЫЛЬ: %.0f" % [
		float(quote.get("buy_price", 0.0)),
		float(quote.get("sell_price", 0.0)),
		float(quote.get("distance", 0.0)),
		float(quote.get("fuel_needed", 0.0)),
		float(quote.get("fuel_cost", 0.0)),
		float(quote.get("repair_reserve", 0.0)),
		float(quote.get("gross", 0.0)),
		float(quote.get("net", 0.0))
	]

func _get_selected(select: OptionButton, ids: Array[String]) -> String:
	var index: int = select.selected
	if index < 0 or index >= ids.size():
		return ""
	return ids[index]

func _on_changed(_value: float = 0.0, _unused: float = 0.0) -> void:
	pass

func _close() -> void:
	_open = false
