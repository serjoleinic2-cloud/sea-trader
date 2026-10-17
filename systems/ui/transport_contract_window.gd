extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _label: Label
var _action: Button
var _offer_scroll: ScrollContainer
var _offer_list: VBoxContainer
var _notice: String = ""
var _open: bool = false
var _offer_signature: String = ""

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
	_offer_scroll = ScrollContainer.new()
	_offer_scroll.name = "AvailableOrders"
	_offer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_offer_scroll)
	_offer_list = VBoxContainer.new()
	_offer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_list.add_theme_constant_override("separation", 5)
	_offer_scroll.add_child(_offer_list)
	_action = Button.new()
	_action.add_theme_font_size_override("font_size", 16)
	_action.custom_minimum_size.y = 42
	_action.pressed.connect(_act)
	box.add_child(_action)
	var close: Button = Button.new()
	close.text = "Закрыть"
	preload("res://systems/ui/brass_close_button.gd").apply(close)
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
	_offer_signature = ""

func _process(_delta: float) -> void:
	_panel.visible = _open
	if not _open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1180.0, viewport.x - 32.0), minf(740.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	var active: Dictionary = _system.get_active()
	if active.is_empty():
		_offer_scroll.visible = true
		_action.visible = false
		_label.text = "ЗАКАЗЫ НА ПЕРЕВОЗКУ\nВыберите маршрут и сравните груз с оплатой.%s" % ("\n" + _notice if _notice != "" else "")
		var offers: Array[Dictionary] = _system.get_offers()
		var signature: String = str(offers)
		if signature != _offer_signature:
			_render_offers(offers)
			_offer_signature = signature
		return
	_offer_scroll.visible = false
	_action.visible = true
	_label.text = "АКТИВНЫЙ ЗАКАЗ\n\n%s → %s\nГруз: %s × %d\nНаграда: %.0f\n\n%s" % [
		str(active.origin_name), str(active.destination_name), str(active.resource_name), int(active.quantity), float(active.reward), _notice
	]
	if not bool(active.get("loaded", false)):
		var free_space: int = _free_space()
		var needed: int = int(active.get("quantity", 0))
		_label.text += "\nСвободно в трюме: %d из %d" % [free_space, int(GameState.ship_state.get("cargo_capacity", 0))]
		if free_space < needed:
			_action.text = "ОСВОБОДИТЬ ТРЮМ — НУЖНО %d" % [needed - free_space]
			_action.disabled = false
		else:
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
	if not active.is_empty() and not bool(active.get("loaded", false)) and _free_space() < int(active.get("quantity", 0)):
		_open_cargo_clearance()
		return
	var result: Dictionary = _system.accept() if active.is_empty() else (_system.load() if not bool(active.get("loaded", false)) else _system.complete())
	_notice = str(result.get("message", ""))

func _render_offers(offers: Array[Dictionary]) -> void:
	for child in _offer_list.get_children():
		_offer_list.remove_child(child)
		child.queue_free()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_offer_list.add_child(header)
	for column in [
		{"text": "МАРШРУТ", "width": 330},
		{"text": "ГРУЗ", "width": 220},
		{"text": "ДИСТАНЦИЯ", "width": 120},
		{"text": "ОПЛАТА", "width": 120},
		{"text": "", "width": 140}
	]:
		var heading := Label.new()
		heading.text = str(column.text)
		heading.custom_minimum_size.x = int(column.width)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_theme_color_override("font_color", Color("e8bd78"))
		heading.add_theme_font_size_override("font_size", 12)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(heading)
	if offers.is_empty():
		var unavailable: Dictionary = _system.offer()
		var message := Label.new()
		message.text = str(unavailable.get("message", "Сейчас нет доступных заказов."))
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.custom_minimum_size.y = 90
		message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		message.add_theme_font_size_override("font_size", 16)
		_offer_list.add_child(message)
		return
	for offer in offers:
		var row_panel := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("101e2a")
		row_style.border_color = Color("8b642e")
		row_style.set_border_width_all(1)
		row_style.set_content_margin_all(7)
		row_panel.add_theme_stylebox_override("panel", row_style)
		_offer_list.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)
		_add_table_cell(row, "%s → %s" % [str(offer.get("origin_name", "")), str(offer.get("destination_name", ""))], 330, HORIZONTAL_ALIGNMENT_LEFT)
		_add_table_cell(row, "%s × %d" % [str(offer.get("resource_name", "Груз")), int(offer.get("quantity", 0))], 220, HORIZONTAL_ALIGNMENT_CENTER)
		_add_table_cell(row, "%.1f км" % (float(offer.get("distance", 0.0)) / 1000.0), 120, HORIZONTAL_ALIGNMENT_CENTER)
		_add_table_cell(row, "%s монет" % _format_amount(float(offer.get("reward", 0.0))), 120, HORIZONTAL_ALIGNMENT_CENTER)
		var accept_button := Button.new()
		accept_button.text = "ВЫБРАТЬ"
		accept_button.custom_minimum_size = Vector2(140, 36)
		accept_button.add_theme_font_size_override("font_size", 12)
		accept_button.pressed.connect(_accept_selected.bind(str(offer.get("id", ""))))
		row.add_child(accept_button)

func _add_table_cell(row: HBoxContainer, value: String, minimum_width: int, alignment: int) -> void:
	var cell := Label.new()
	cell.text = value
	cell.custom_minimum_size.x = minimum_width
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.horizontal_alignment = alignment
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.add_theme_font_size_override("font_size", 14)
	cell.add_theme_color_override("font_color", Color("f1e4cb"))
	row.add_child(cell)

func _accept_selected(offer_id: String) -> void:
	var result: Dictionary = _system.accept_offer(offer_id)
	_notice = str(result.get("message", ""))
	_offer_signature = ""

func _format_amount(value: float) -> String:
	return "%.0f" % value

func _free_space() -> int:
	var used: int = 0
	for raw_item in GameState.ship_state.get("cargo", []):
		var item: Dictionary = raw_item
		used += int(item.get("quantity", 0))
	return maxi(0, int(GameState.ship_state.get("cargo_capacity", 0)) - used)

func _open_cargo_clearance() -> void:
	var ports: Array[Node] = get_tree().get_nodes_in_group("port_window")
	if ports.is_empty():
		_notice = "Не найдено окно трюма."
		return
	_open = false
	ports[0].open_cargo_clearance()
