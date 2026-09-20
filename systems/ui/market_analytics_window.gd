extends CanvasLayer

## Readable offline exchange: only data from personally visited ports is shown.

var _panel: PanelContainer
var _content: VBoxContainer
var _open: bool = false
var _system: Node
var _port_index: int = 0
var _good_index: int = 0
var _timer: float = 0.0

func _ready() -> void:
	layer = 60
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.22, 0.45, 0.62, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_panel.add_child(_content)
	_panel.hide()

func initialize(system: Node) -> void:
	_system = system

func open() -> void:
	_open = true
	if _system != null:
		_system.record_snapshot()
	_refresh()

func _process(delta: float) -> void:
	_panel.visible = _open
	if not _open:
		return
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		_refresh()

func _refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_label("БИРЖЕВАЯ СВОДКА", 28)
	_label("Цены, спрос и запасы известны только по портам, где вы уже пришвартовались. Показания обновляются раз в 30 секунд.")
	if _system == null:
		_label("Биржа загружается.")
		return
	var ports: Array = _system.get_known_ports()
	var goods: Array = _system.get_goods()
	if ports.is_empty():
		_label("Посетите и пришвартуйтесь хотя бы к одному порту, чтобы получить первые данные.", 22)
		return
	if goods.is_empty():
		_label("Каталог товаров ещё не загружен.")
		return
	_port_index = posmod(_port_index, ports.size())
	_good_index = posmod(_good_index, goods.size())
	var port: Dictionary = ports[_port_index]
	var good: Dictionary = goods[_good_index]
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	_button(row, "‹ Порт", _previous_port)
	var port_label: Label = Label.new()
	port_label.text = "Порт: " + str(port.get("name", port.get("id", "")))
	port_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_label.add_theme_font_size_override("font_size", 21)
	row.add_child(port_label)
	_button(row, "Порт ›", _next_port)
	var goods_row: HBoxContainer = HBoxContainer.new()
	goods_row.add_theme_constant_override("separation", 8)
	_content.add_child(goods_row)
	_button(goods_row, "‹ Товар", _previous_good)
	var good_label: Label = Label.new()
	good_label.text = "Товар: " + str(good.get("name", good.get("id", "")))
	good_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	good_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	good_label.add_theme_font_size_override("font_size", 21)
	goods_row.add_child(good_label)
	_button(goods_row, "Товар ›", _next_good)
	var data: Dictionary = _system.get_snapshot(str(port.get("id", "")), str(good.get("id", "")))
	var state: String = "принимает" if bool(data.get("accepted", false)) else "не принимает"
	_label("Цена продажи: %.0f   |   Спрос: %d ед.   |   Запас на рынке: %d ед.\nСтатус: порт %s этот товар." % [float(data.get("price", 0.0)), int(data.get("demand", 0)), int(data.get("stock", 0)), state], 23)
	var history: Array = data.get("history", [])
	_label("ЦЕНА (последние замеры)", 21)
	_label(_sparkline(history, "price") + "  " + _trend_text(history, "price"), 26)
	_label("СПРОС (последние замеры)", 21)
	_label(_sparkline(history, "demand") + "  " + _trend_text(history, "demand"), 26)
	_label("ЗАПАС (избыток снижает цену)", 21)
	_label(_sparkline(history, "stock") + "  " + _trend_text(history, "stock"), 26)
	_label("Подсказка: покупайте там, где цена ниже, и продавайте в портах с высоким спросом и небольшим запасом. Заявки на выкуп вашего склада создаются на рынке базы.")

func _sparkline(history: Array, key: String) -> String:
	if history.size() < 2:
		return "Пока мало данных: подождите следующий замер."
	var values: Array[float] = []
	for raw_point in history:
		var point: Dictionary = raw_point
		values.append(float(point.get(key, 0.0)))
	var low: float = values.min()
	var high: float = values.max()
	var symbols: Array[String] = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
	var line: String = ""
	for value in values:
		var fraction: float = 0.5 if is_equal_approx(low, high) else (value - low) / (high - low)
		line += symbols[clampi(int(round(fraction * float(symbols.size() - 1))), 0, symbols.size() - 1)]
	return line

func _trend_text(history: Array, key: String) -> String:
	if history.size() < 2:
		return "нет тренда"
	var first: Dictionary = history[0]
	var last: Dictionary = history[history.size() - 1]
	var change: float = float(last.get(key, 0.0)) - float(first.get(key, 0.0))
	if is_zero_approx(change):
		return "без изменений"
	return "рост" if change > 0.0 else "снижение"

func _previous_port() -> void:
	_port_index -= 1
	_refresh()

func _next_port() -> void:
	_port_index += 1
	_refresh()

func _previous_good() -> void:
	_good_index -= 1
	_refresh()

func _next_good() -> void:
	_good_index += 1
	_refresh()

func _label(value: String, font_size: int = 20) -> void:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)

func _button(parent: Container, label_text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(120, 44)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	parent.add_child(button)
