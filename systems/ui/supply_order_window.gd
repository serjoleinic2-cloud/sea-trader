extends CanvasLayer

## Remote supply order window. Goods are read automatically from the shared catalog.

var _system: Node
var _panel: PanelContainer
var _label: Label
var _resource_select: OptionButton
var _slider: HSlider
var _quantity_label: Label
var _order_button: Button
var _open: bool = false
var _notice: String = ""
var _resource_ids: Array[String] = []

func _ready() -> void:
	add_to_group("supply_order_window")
	layer = 50
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.85, 0.62, 0.18, 1.0)
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
	var title: Label = Label.new()
	title.text = "ЗАКАЗ ПОСТАВКИ"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var choice_label: Label = Label.new()
	choice_label.text = "Выберите товар"
	choice_label.add_theme_font_size_override("font_size", 22)
	box.add_child(choice_label)
	_resource_select = OptionButton.new()
	_resource_select.add_theme_font_size_override("font_size", 22)
	_resource_select.custom_minimum_size.y = 46
	_resource_select.item_selected.connect(_on_resource_selected)
	box.add_child(_resource_select)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label)
	_quantity_label = Label.new()
	_quantity_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_quantity_label)
	_slider = HSlider.new()
	_slider.min_value = 1.0
	_slider.max_value = 1.0
	_slider.step = 1.0
	_slider.custom_minimum_size.y = 34
	_slider.value_changed.connect(_on_quantity_changed)
	box.add_child(_slider)
	_order_button = Button.new()
	_order_button.text = "Заказать поставку"
	_order_button.add_theme_font_size_override("font_size", 22)
	_order_button.custom_minimum_size.y = 52
	_order_button.pressed.connect(_order)
	box.add_child(_order_button)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.custom_minimum_size.y = 46
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_panel.hide()

func initialize(system: Node) -> void:
	_system = system
	_fill_goods()

func _fill_goods() -> void:
	if _system == null:
		return
	_resource_select.clear()
	_resource_ids.clear()
	var goods: Array = _system.get_available_goods()
	for raw_good in goods:
		var good: Dictionary = raw_good
		var resource_id: String = str(good.get("id", ""))
		_resource_ids.append(resource_id)
		_resource_select.add_item(str(good.get("display_name", resource_id)))

func open() -> void:
	if _resource_ids.is_empty():
		_fill_goods()
	_open = true
	_notice = ""

func _process(_delta: float) -> void:
	_panel.visible = _open
	if not _open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(760.0, viewport.x - 32.0), minf(760.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_refresh_quote()

func _refresh_quote() -> void:
	var resource_id: String = _get_selected_resource_id()
	if resource_id == "":
		_label.text = "Нет товаров в каталоге."
		_order_button.disabled = true
		return
	var orders: Array = _system.get_active_orders()
	var capacity: int = _system.get_delivery_capacity()
	var deliveries_text: String = _get_deliveries_text(orders, capacity)
	var quote: Dictionary = _system.get_quote(resource_id)
	if not bool(quote.get("ok", false)):
		_label.text = "Выбранный товар: " + _resource_select.get_item_text(_resource_select.selected) + "\n\n" + str(quote.get("message", ""))
		_quantity_label.text = ""
		_order_button.disabled = true
		return
	var source_id: String = str(quote.get("source_port_id", ""))
	var source: Dictionary = GameState.port_state.get(source_id, {})
	var stock: Dictionary = source.get("market_stock", {})
	var available: int = int(stock.get(resource_id, 0))
	_slider.max_value = float(maxi(1, available))
	if _slider.value > _slider.max_value:
		_slider.value = _slider.max_value
	var quantity: int = int(_slider.value)
	quote = _system.get_quote(resource_id, quantity)
	var total: float = float(quote.get("delivery_price", 0.0)) * quantity
	_label.text = "Товар: %s\nПоставщик: %s\nЦена у поставщика: %.0f\nДоставка: +50%%\nПрибытие: %d сек.\nВаши деньги: %.0f\n%s\n%s" % [
		_resource_select.get_item_text(_resource_select.selected),
		str(quote.get("source_name", "")),
		float(quote.get("source_price", 0.0)),
		int(quote.get("delivery_seconds", 0)),
		float(GameState.player_state.get("money", 0.0)),
		_notice,
		deliveries_text
	]
	_quantity_label.text = "Количество: %d | Итого: %.0f" % [quantity, total]
	_order_button.disabled = orders.size() >= capacity or quantity > available or float(GameState.player_state.get("money", 0.0)) < total

func _get_deliveries_text(orders: Array, capacity: int) -> String:
	var lines: Array[String] = ["Торговцы в пути: %d / %d" % [orders.size(), capacity]]
	for raw_order in orders:
		var order: Dictionary = raw_order
		var remaining: int = maxi(0, int(order.get("arrives_at", 0)) - int(Time.get_unix_time_from_system()))
		lines.append("• %s × %d — %d сек." % [
			_system.get_goods_name(str(order.get("resource_id", ""))),
			int(order.get("quantity", 0)),
			remaining
		])
	if orders.size() >= capacity:
		lines.append("Все торговые места заняты.")
	return "\n".join(lines)

func _get_selected_resource_id() -> String:
	var index: int = _resource_select.selected
	if index < 0 or index >= _resource_ids.size():
		return ""
	return _resource_ids[index]

func _close() -> void:
	_open = false
	_notice = ""

func _on_resource_selected(_index: int) -> void:
	_slider.value = 1.0
	_notice = ""

func _on_quantity_changed(_value: float) -> void:
	pass

func _order() -> void:
	var result: Dictionary = _system.place_order(_get_selected_resource_id(), int(_slider.value))
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_open = false
