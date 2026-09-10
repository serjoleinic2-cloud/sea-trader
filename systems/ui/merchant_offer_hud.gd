extends CanvasLayer

## Right-edge notification and purchase window for visiting merchant offers.

var _merchant_system: Node
var _button: Button
var _panel: PanelContainer
var _label: Label
var _quantity_label: Label
var _slider: HSlider
var _buy_button: Button
var _notice: String = ""
var _is_open: bool = false
var _selected_quantity: int = 1
var _goods: Dictionary = {}

func _ready() -> void:
	layer = 45
	_button = Button.new()
	_button.text = "▣\nГРУЗ"
	_button.custom_minimum_size = Vector2(76, 76)
	_button.add_theme_font_size_override("font_size", 15)
	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.bg_color = Color(0.08, 0.52, 0.20, 1.0)
	button_style.border_color = Color(0.55, 1.0, 0.62, 1.0)
	button_style.set_border_width_all(2)
	_button.add_theme_stylebox_override("normal", button_style)
	_button.pressed.connect(_toggle_window)
	add_child(_button)
	_panel = PanelContainer.new()
	_panel.size = Vector2(410, 330)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	panel_style.border_color = Color(0.20, 0.75, 0.34, 1.0)
	panel_style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 19)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_label)
	_quantity_label = Label.new()
	_quantity_label.add_theme_font_size_override("font_size", 19)
	column.add_child(_quantity_label)
	_slider = HSlider.new()
	_slider.min_value = 1.0
	_slider.max_value = 1.0
	_slider.step = 1.0
	_slider.custom_minimum_size.y = 30
	_slider.value_changed.connect(_on_quantity_changed)
	column.add_child(_slider)
	_buy_button = Button.new()
	_buy_button.text = "Купить"
	_buy_button.custom_minimum_size.y = 44
	_buy_button.pressed.connect(_purchase)
	column.add_child(_buy_button)
	_panel.hide()
	var goods_catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	var raw_resources: Variant = goods_catalog.get("resources", [])
	if raw_resources is Array:
		for raw_resource in raw_resources:
			var resource: Dictionary = raw_resource
			_goods[str(resource.get("id", ""))] = str(resource.get("display_name", ""))

func initialize(merchant_system: Node) -> void:
	_merchant_system = merchant_system

func _process(_delta: float) -> void:
	if _merchant_system == null:
		return
	var offer: Dictionary = _merchant_system.get_active_offer()
	var has_offer: bool = not offer.is_empty() and int(offer.get("quantity_available", 0)) > 0
	_button.visible = has_offer
	if not has_offer:
		_is_open = false
		_panel.hide()
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_button.position = Vector2(viewport_size.x - 88.0, 300.0)
	_panel.position = Vector2(viewport_size.x - _panel.size.x - 12.0, 388.0)
	_panel.visible = _is_open
	if not _is_open:
		return
	var available: int = int(offer.get("quantity_available", 0))
	_slider.max_value = float(available)
	if _selected_quantity > available:
		_selected_quantity = available
	_slider.max_value = float(available)
	_slider.value = float(_selected_quantity)
	var resource_id: String = str(offer.get("resource_id", ""))
	var resource_name: String = str(_goods.get(resource_id, resource_id))
	var unit_price: float = float(offer.get("unit_price", 0.0))
	_label.text = (
		"ПРИБЫВШИЙ ТОРГОВЕЦ\n"
		+ "Товар: %s\n"
		+ "В наличии: %d\n"
		+ "Цена за единицу: %.0f\n"
		+ "Ваши деньги: %.0f\n"
		+ "%s"
	) % [
		resource_name,
		available,
		unit_price,
		float(GameState.player_state.get("money", 0.0)),
		_notice
	]
	_quantity_label.text = "Количество: %d | Итого: %.0f" % [_selected_quantity, unit_price * _selected_quantity]
	_buy_button.disabled = float(GameState.player_state.get("money", 0.0)) < unit_price * _selected_quantity

func _toggle_window() -> void:
	_is_open = not _is_open
	_notice = ""

func _on_quantity_changed(value: float) -> void:
	_selected_quantity = maxi(1, int(round(value)))

func _purchase() -> void:
	if _merchant_system == null:
		return
	var result: Dictionary = _merchant_system.purchase(_selected_quantity)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_selected_quantity = 1
