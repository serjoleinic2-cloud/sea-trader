extends CanvasLayer

## Редактор постоянной линии: одна строка = один переход с товаром.

var _system: Node
var _panel: PanelContainer
var _legs_box: VBoxContainer
var _details: Label
var _empty_notice: Label
var _ship: OptionButton
var _min_profit: HSlider
var _profit_label: Label
var _open: bool = false
var _ship_ids: Array[String] = []
var _port_ids: Array[String] = []
var _port_names: Dictionary = {}
var _good_ids: Array[String] = []
var _good_names: Dictionary = {}
var _leg_rows: Array[Dictionary] = []
var _notice: String = ""

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
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "РЕДАКТОР ТОРГОВОЙ ЛИНИИ"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Добавьте переходы по порядку. Последний переход должен вернуть корабль в первый порт."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 17)
	box.add_child(hint)
	_ship = _select(box, "Корабль линии")
	_empty_notice = _label(box)
	_empty_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_notice.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35, 1.0))
	var header: Label = Label.new()
	header.text = "ОТКУДА → ДЕЙСТВИЕ / ТОВАР → КУДА → КОЛИЧЕСТВО"
	header.add_theme_font_size_override("font_size", 18)
	box.add_child(header)
	_legs_box = VBoxContainer.new()
	_legs_box.add_theme_constant_override("separation", 6)
	box.add_child(_legs_box)
	var add_leg: Button = Button.new()
	add_leg.text = "+ ДОБАВИТЬ ПЕРЕХОД"
	add_leg.custom_minimum_size.y = 44
	add_leg.pressed.connect(_add_leg_row)
	box.add_child(add_leg)
	_profit_label = _label(box)
	_min_profit = HSlider.new()
	_min_profit.min_value = 0.0
	_min_profit.max_value = 500.0
	_min_profit.step = 10.0
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
	var retry: Button = Button.new()
	retry.text = "Повторить остановленные линии"
	retry.custom_minimum_size.y = 42
	retry.pressed.connect(_retry)
	box.add_child(retry)
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

func _select(box: VBoxContainer, label_text: String) -> OptionButton:
	var label: Label = _label(box)
	label.text = label_text
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
	_ship_ids.clear()
	_port_ids.clear()
	_port_names.clear()
	_good_ids.clear()
	_good_names.clear()
	_notice = ""
	for child in _legs_box.get_children():
		child.queue_free()
	_leg_rows.clear()
	var fleets: Array[Node] = get_tree().get_nodes_in_group("fleet_system")
	if not fleets.is_empty():
		for raw_ship in fleets[0].get_auxiliary_ships():
			var ship: Dictionary = raw_ship
			if not str(ship.get("status", "")).begins_with("В пути"):
				_ship_ids.append(str(ship.get("instance_id", "")))
				_ship.add_item(str(ship.get("name", "Корабль")))
	for raw_port in _system.get_known_ports():
		var port: Dictionary = raw_port
		var port_id: String = str(port.get("id", ""))
		_port_ids.append(port_id)
		_port_names[port_id] = str(port.get("name", port_id))
	for raw_good in _system.get_goods():
		var good: Dictionary = raw_good
		var good_id: String = str(good.get("id", ""))
		_good_ids.append(good_id)
		_good_names[good_id] = str(good.get("name", good_id))
	if not _ship_ids.is_empty():
		_ship.select(0)
	_add_leg_row()
	if not _leg_rows.is_empty() and not _port_ids.is_empty():
		var first: Dictionary = _leg_rows[0]
		var available_ships: Array = fleets[0].get_auxiliary_ships() if not fleets.is_empty() else []
		var first_ship: Dictionary = available_ships[0] if not available_ships.is_empty() else {}
		var current_port: String = str(first_ship.get("current_port_id", ""))
		var current_index: int = _port_ids.find(current_port)
		first["source"].select(maxi(0, current_index))
		first["target"].select(posmod(first["source"].selected + 1, _port_ids.size()))
		_on_leg_changed(0, first)
		_add_leg_row()
		if _leg_rows.size() > 1:
			var second: Dictionary = _leg_rows[1]
			second["target"].select(first["source"].selected)
			_on_leg_changed(0, second)
	_empty_notice.text = "" if not _ship_ids.is_empty() else "Нет дополнительных кораблей. Постройте второй корабль во вкладке «Флот и верфь», чтобы создать постоянную линию. Текущий корабль отправляется через «Начать рейс»."

func _add_leg_row() -> void:
	if _legs_box == null or _port_ids.is_empty():
		return
	var row_box: VBoxContainer = VBoxContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row_box.add_child(row)
	var number: Label = Label.new()
	number.custom_minimum_size.x = 28
	number.add_theme_font_size_override("font_size", 17)
	row.add_child(number)
	var source: OptionButton = _leg_select(row, 190)
	var action: Label = Label.new()
	action.custom_minimum_size.x = 116
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 16)
	row.add_child(action)
	var good: OptionButton = _leg_select(row, 190)
	var arrow: Label = Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", 20)
	row.add_child(arrow)
	var target: OptionButton = _leg_select(row, 190)
	var quantity: SpinBox = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 999
	quantity.value = 10
	quantity.step = 1
	quantity.custom_minimum_size.x = 90
	quantity.add_theme_font_size_override("font_size", 16)
	row.add_child(quantity)
	var remove: Button = Button.new()
	remove.text = "×"
	remove.tooltip_text = "Удалить переход"
	remove.custom_minimum_size = Vector2(38, 38)
	row.add_child(remove)
	for index in range(_port_ids.size()):
		source.add_item(_port_names[_port_ids[index]])
		target.add_item(_port_names[_port_ids[index]])
	for good_id in _good_ids:
		good.add_item(_good_names[good_id])
	var data: Dictionary = {"box": row_box, "source": source, "target": target,
		"good": good, "action": action, "quantity": quantity, "number": number}
	_leg_rows.append(data)
	_legs_box.add_child(row_box)
	source.item_selected.connect(_on_leg_changed.bind(data))
	target.item_selected.connect(_on_leg_changed.bind(data))
	good.item_selected.connect(_on_leg_changed.bind(data))
	remove.pressed.connect(_remove_leg_row.bind(data))
	if _leg_rows.size() > 1:
		var previous: Dictionary = _leg_rows[_leg_rows.size() - 2]
		source.select(int(previous["target"].selected))
		target.select(posmod(source.selected + 1, _port_ids.size()))
	_on_leg_changed(0, data)
	_update_row_numbers()

func _leg_select(row: HBoxContainer, width: float) -> OptionButton:
	var select: OptionButton = OptionButton.new()
	select.custom_minimum_size = Vector2(width, 38)
	select.add_theme_font_size_override("font_size", 16)
	row.add_child(select)
	return select

func _remove_leg_row(data: Dictionary) -> void:
	if _leg_rows.size() <= 2:
		_notice = "В линии должно остаться минимум два перехода."
		return
	var box: VBoxContainer = data.get("box")
	if is_instance_valid(box):
		box.queue_free()
	_leg_rows.erase(data)
	_update_row_numbers()

func _update_row_numbers() -> void:
	for index in range(_leg_rows.size()):
		var data: Dictionary = _leg_rows[index]
		var number: Label = data.get("number")
		number.text = "%d." % (index + 1)

func _on_leg_changed(_index: int, data: Dictionary) -> void:
	var source: OptionButton = data.get("source")
	var target: OptionButton = data.get("target")
	var action: Label = data.get("action")
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	var source_id: String = _selected_id(source, _port_ids)
	var target_id: String = _selected_id(target, _port_ids)
	action.text = ("Загрузить" if source_id == home_id else "Купить") + " →\n" + ("Выгрузить" if target_id == home_id else "Продать")

func _process(_delta: float) -> void:
	_panel.visible = _open
	if not _open:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1120.0, viewport.x - 24.0), minf(900.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_profit_label.text = "Минимум чистыми за переход: %.0f" % _min_profit.value
	_details.text = _notice + ("\n" if _notice != "" else "") + _lines_text()

func _start() -> void:
	if _ship_ids.is_empty():
		_notice = "Сначала постройте дополнительный корабль."
		return
	var legs: Array = []
	for data in _leg_rows:
		legs.append({"source_id": _selected_id(data["source"], _port_ids),
			"target_id": _selected_id(data["target"], _port_ids),
			"resource_id": _selected_id(data["good"], _good_ids),
			"quantity": int(data["quantity"].value)})
	var result: Dictionary = _system.create_route_line(_selected_id(_ship, _ship_ids), legs, _min_profit.value)
	_notice = str(result.get("message", ""))

func _retry() -> void:
	for raw_line in _system.get_lines():
		var line: Dictionary = raw_line
		if str(line.get("status", "")).begins_with("Остановлена"):
			var result: Dictionary = _system.resume_line(str(line.get("id", "")))
			_notice = str(result.get("message", ""))

func _stop_all() -> void:
	for raw_line in _system.get_lines():
		var line: Dictionary = raw_line
		_system.stop_line(str(line.get("id", "")))

func _lines_text() -> String:
	var lines: Array[String] = ["ЛИНИИ:"]
	if _system.get_lines().is_empty():
		return "ЛИНИИ:\nПока нет созданных линий. Добавьте переходы выше и нажмите «Запустить линию»."
	for raw_line in _system.get_lines():
		var line: Dictionary = raw_line
		var route_text: String = ""
		if str(line.get("mode", "")) == "multi_stop":
			var route_parts: Array[String] = []
			for raw_leg in line.get("legs", []):
				var leg: Dictionary = raw_leg
				var goods: Array = leg.get("items", [])
				if goods.is_empty() and str(leg.get("resource_id", "")) != "":
					goods = [{"resource_id": str(leg.get("resource_id", "")), "quantity": int(leg.get("quantity", 0))}]
				var goods_text: Array[String] = []
				for raw_good in goods:
					var good: Dictionary = raw_good
					goods_text.append("%s × %d" % [_good_name(str(good.get("resource_id", ""))), int(good.get("quantity", 0))])
				route_parts.append("%s — %s → %s" % [_port_name(str(leg.get("source_id", ""))),
					", ".join(goods_text), _port_name(str(leg.get("target_id", "")))])
			route_text = "\n" + "\n".join(route_parts)
		lines.append("%s: %s | кругов %d | заработано %.0f%s\n%s" % [
			str(line.get("id", "")), str(line.get("status", "")), int(line.get("cycles", 0)),
			float(line.get("earned", 0.0)), route_text, str(line.get("last_message", ""))])
	return "\n\n".join(lines)

func _selected_id(select: OptionButton, ids: Array[String]) -> String:
	var index: int = select.selected
	return ids[index] if index >= 0 and index < ids.size() else ""

func _port_name(port_id: String) -> String:
	return str(_port_names.get(port_id, port_id))

func _good_name(good_id: String) -> String:
	return str(_good_names.get(good_id, good_id))

func _close() -> void:
	_open = false
