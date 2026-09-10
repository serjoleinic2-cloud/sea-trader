extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _label: Label
var _slider: HSlider
var _quantity_label: Label
var _order_button: Button
var _open: bool = false
var _notice: String = ""

func _ready() -> void:
	layer = 50
	_panel = PanelContainer.new()
	_panel.size = Vector2(430, 360)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.85, 0.62, 0.18, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 19)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label)
	_quantity_label = Label.new()
	_quantity_label.add_theme_font_size_override("font_size", 19)
	box.add_child(_quantity_label)
	_slider = HSlider.new()
	_slider.min_value = 1
	_slider.max_value = 1
	_slider.step = 1
	_slider.value_changed.connect(_on_quantity_changed)
	box.add_child(_slider)
	_order_button = Button.new()
	_order_button.text = "Заказать поставку"
	_order_button.custom_minimum_size.y = 44
	_order_button.pressed.connect(_order)
	box.add_child(_order_button)
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
	_panel.position = (viewport - _panel.size) * 0.5
	var quote: Dictionary = _system.get_quote("resource_oil")
	if not bool(quote.get("ok", false)):
		_label.text = "ЗАКАЗ ПОСТАВКИ\n\nМасло\n" + str(quote.get("message", ""))
		_order_button.disabled = true
		return
	var source_id: String = str(quote.get("source_port_id", ""))
	var source: Dictionary = GameState.port_state.get(source_id, {})
	var stock: Dictionary = source.get("market_stock", {})
	var available: int = int(stock.get("resource_oil", 0))
	_slider.max_value = float(maxi(1, available))
	if _slider.value > _slider.max_value:
		_slider.value = _slider.max_value
	var quantity: int = int(_slider.value)
	var total: float = float(quote.get("delivery_price", 0.0)) * quantity
	_label.text = "ЗАКАЗ ПОСТАВКИ\n\nТовар: Масло\nПоставщик: %s\nЦена у поставщика: %.0f\nДоставка: +50%%\nПрибытие: %d сек.\nВаши деньги: %.0f\n%s" % [str(quote.get("source_name", "")), float(quote.get("source_price", 0.0)), int(quote.get("delivery_seconds", 0)), float(GameState.player_state.get("money", 0.0)), _notice]
	_quantity_label.text = "Количество: %d | Итого: %.0f" % [quantity, total]
	_order_button.disabled = quantity > available or float(GameState.player_state.get("money", 0.0)) < total

func _on_quantity_changed(_value: float) -> void:
	pass

func _order() -> void:
	var result: Dictionary = _system.place_order("resource_oil", int(_slider.value))
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_open = false
