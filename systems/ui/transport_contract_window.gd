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
	_label.add_theme_font_size_override("font_size", 14)
	_label.set_meta("fixed_font_size", 14)
	_label.set_meta("compact_description", true)
	_label.set_meta("ui_base_font_size", 15)
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
	_offer_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_panel.size = Vector2(minf(1180.0, viewport.x - 32.0), viewport.y - 32.0)
	_panel.position = (viewport - _panel.size) * 0.5
	var active: Dictionary = _system.get_active()
	if active.is_empty():
		_offer_scroll.visible = true
		_action.visible = false
		var offers: Array[Dictionary] = _system.get_offers()
		_label.text = "ЗАДАНИЯ НА ПЕРЕВОЗКУ · %d ВАРИАНТОВ\nВыберите маршрут, груз и оплату. Одновременно выполняется один заказ.%s" % [offers.size(), "\n" + _notice if _notice != "" else ""]
		var signature: String = str(offers)
		if signature != _offer_signature:
			_render_offers(offers)
			_offer_signature = signature
		return
	_offer_scroll.visible = true
	_action.visible = true
	var previews: Array[Dictionary] = _system.get_offers(true)
	var preview_signature: String = str(previews) + str(active.get("id", ""))
	if _offer_signature != preview_signature:
		_render_offers(previews, str(active.get("id", "")))
		_offer_signature = preview_signature
	_label.text = "АКТИВНЫЙ ЗАКАЗ · ЗАБРАТЬ: %s → РАЗГРУЗИТЬ: %s\nГруз: %s × %d · Награда: %.0f монет\n%s" % [
		str(active.get("origin_name", "порт отправления")), str(active.get("destination_name", "порт назначения")), str(active.get("resource_name", "груз")), int(active.get("quantity", 0)), float(active.get("reward", 0.0)), _notice
	]
	if not bool(active.get("loaded", false)):
		var origin_id: String = str(active.get("origin_port_id", ""))
		var at_pickup_port: bool = str(GameState.ship_state.get("docked_port_id", "")) == origin_id
		var free_space: int = _free_space()
		var needed: int = int(active.get("quantity", 0))
		_label.text += "\nСвободно в трюме: %d из %d" % [free_space, int(GameState.ship_state.get("cargo_capacity", 0))]
		if not at_pickup_port:
			_action.text = "КУРС К ЗАБОРУ ГРУЗА: %s" % str(active.get("origin_name", "порт отправления"))
			_action.disabled = false
		elif free_space < needed:
			_action.text = "ОСВОБОДИТЬ ТРЮМ — НУЖНО %d" % [needed - free_space]
			_action.disabled = false
		else:
			_action.text = "ЗАБРАТЬ ГРУЗ · ЗАГРУЗИТЬ В ТРЮМ"
			_action.disabled = false
	elif str(GameState.ship_state.get("docked_port_id", "")) == str(active.destination_port_id):
		_action.text = "РАЗГРУЗИТЬ ГРУЗ · СДАТЬ ЗАКАЗ"
		_action.disabled = false
	else:
		_action.text = "КУРС К РАЗГРУЗКЕ: %s" % str(active.destination_name)
		_action.disabled = false

func _act() -> void:
	var active: Dictionary = _system.get_active()
	if not active.is_empty():
		var step_port_id: String = str(active.get("destination_port_id", "")) if bool(active.get("loaded", false)) else str(active.get("origin_port_id", ""))
		if str(GameState.ship_state.get("docked_port_id", "")) != step_port_id:
			var course_result: Dictionary = _system.set_course_for_active_step()
			_notice = str(course_result.get("message", ""))
			return
	if not active.is_empty() and not bool(active.get("loaded", false)) and _free_space() < int(active.get("quantity", 0)):
		_open_cargo_clearance()
		return
	var result: Dictionary = _system.accept() if active.is_empty() else (_system.load() if not bool(active.get("loaded", false)) else _system.complete())
	_notice = str(result.get("message", ""))

func _render_offers(offers: Array[Dictionary], active_id: String = "") -> void:
	for child in _offer_list.get_children():
		_offer_list.remove_child(child)
		child.queue_free()
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 7)
	header_margin.add_theme_constant_override("margin_right", 7)
	_offer_list.add_child(header_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header_margin.add_child(header)
	for column in [
		{"text": "МАРШРУТ", "width": 280},
		{"text": "ГРУЗ", "width": 180},
		{"text": "ДИСТАНЦИЯ", "width": 100},
		{"text": "ОПЛАТА", "width": 100},
		{"text": "", "width": 100}
	]:
		var heading := Label.new()
		heading.text = str(column.text)
		heading.custom_minimum_size.x = int(column.width)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL if str(column.text) != "" else Control.SIZE_FILL
		heading.add_theme_color_override("font_color", Color("e8bd78"))
		heading.add_theme_font_size_override("font_size", 12)
		heading.set_meta("fixed_font_size", 12)
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
		row_style.set_content_margin_all(5)
		row_panel.add_theme_stylebox_override("panel", row_style)
		row_panel.set_meta("preserve_art_style", true)
		row_panel.custom_minimum_size.y = 42
		_offer_list.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)
		_add_table_cell(row, "%s → %s" % [str(offer.get("origin_name", "")), str(offer.get("destination_name", ""))], 280, HORIZONTAL_ALIGNMENT_LEFT)
		_add_table_cell(row, "%s × %d" % [str(offer.get("resource_name", "Груз")), int(offer.get("quantity", 0))], 180, HORIZONTAL_ALIGNMENT_CENTER)
		_add_table_cell(row, "%.1f км" % (float(offer.get("distance", 0.0)) / 1000.0), 100, HORIZONTAL_ALIGNMENT_CENTER)
		_add_table_cell(row, "%s монет" % _format_amount(float(offer.get("reward", 0.0))), 100, HORIZONTAL_ALIGNMENT_CENTER)
		var action_cell := CenterContainer.new()
		action_cell.custom_minimum_size.x = 100
		row.add_child(action_cell)
		var accept_button := Button.new()
		accept_button.text = "В РАБОТЕ" if str(offer.get("id", "")) == active_id else "ВЫБРАТЬ"
		accept_button.disabled = active_id != ""
		accept_button.tooltip_text = "Сначала завершите активный заказ." if active_id != "" else "Принять этот заказ"
		accept_button.custom_minimum_size = Vector2(100, 36)
		accept_button.add_theme_font_size_override("font_size", 12)
		accept_button.set_meta("fixed_font_size", 12)
		accept_button.pressed.connect(_accept_selected.bind(str(offer.get("id", ""))))
		action_cell.add_child(accept_button)

func _add_table_cell(row: HBoxContainer, value: String, minimum_width: int, alignment: int) -> void:
	var cell := Label.new()
	cell.text = value
	cell.custom_minimum_size.x = minimum_width
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.horizontal_alignment = alignment
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.add_theme_font_size_override("font_size", 14)
	cell.set_meta("fixed_font_size", 14)
	cell.set_meta("compact_description", true)
	cell.set_meta("ui_base_font_size", 14)
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
