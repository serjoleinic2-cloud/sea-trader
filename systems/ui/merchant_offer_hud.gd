extends CanvasLayer

## Persistent passive/active merchant badge; opening an offer keeps the current workspace.
var _merchant_system: Node
var _button: Button
var _panel: PanelContainer
var _label: Label
var _quantity_label: Label
var _slider: HSlider
var _buy_button: Button
var _decline_button: Button
var _close_button: Button
var _notice_label: Label
var _notice := ""
var _is_open := false
var _selected_quantity := 1
var _goods: Dictionary = {}
var _offer_key := ""
var _top_height := 84.0

func _ready() -> void:
	layer = 145
	_button = Button.new()
	_button.name = "MerchantOfferBadge"
	_button.theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	_button.set_meta("compact_hud", true)
	_button.add_theme_font_size_override("font_size", 12)
	_button.custom_minimum_size = Vector2(164, 46)
	_button.pressed.connect(_toggle_window)
	add_child(_button)
	_panel = PanelContainer.new()
	_panel.name = "VisitingMerchantPanel"
	_panel.theme = _button.theme
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = _make_label("ТОРГОВЕЦ", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = Button.new()
	preload("res://systems/ui/brass_close_button.gd").apply(_close_button)
	_close_button.pressed.connect(close_window)
	header.add_child(_close_button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 80
	column.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	_label = _make_label("", 12)
	details.add_child(_label)
	_notice_label = _make_label("", 12)
	_notice_label.name = "MerchantTransactionResult"
	details.add_child(_notice_label)
	_quantity_label = _make_label("", 12)
	column.add_child(_quantity_label)
	_slider = HSlider.new()
	_slider.min_value = 1
	_slider.max_value = 1
	_slider.step = 1
	_slider.custom_minimum_size.y = 26
	_slider.value_changed.connect(_on_quantity_changed)
	column.add_child(_slider)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	_buy_button = _make_button("Купить", _purchase)
	actions.add_child(_buy_button)
	_decline_button = _make_button("Отказаться", _decline)
	_decline_button.tooltip_text = "Отклонить это предложение. Деньги не списываются, ваши заявки на продажу остаются."
	actions.add_child(_decline_button)
	_panel.hide()
	for good in GameData.read("res://data/resources/goods_catalog.json").get("resources", []):
		_goods[str(good.get("id", ""))] = str(good.get("display_name", ""))

func _make_label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("compact_description", true)
	label.set_meta("ui_base_font_size", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _make_button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(130, 34)
	button.set_meta("compact_description", true)
	button.set_meta("ui_base_font_size", 13)
	button.set_meta("ui_base_min_height", 34)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	return button

func initialize(merchant_system: Node) -> void:
	_merchant_system = merchant_system

func has_active_offer() -> bool:
	if _merchant_system == null:
		return false
	var offer: Dictionary = _merchant_system.get_active_offer()
	return not offer.is_empty() and int(offer.get("quantity_available", 0)) > 0 and int(offer.get("expires_at", 0)) > int(Time.get_unix_time_from_system())

func layout_for_viewport(viewport_size: Vector2, top_height: float) -> void:
	_top_height = top_height
	_button.size = Vector2(164, 46)
	# Leave the far-right corner free for the current workspace's close button.
	_button.position = Vector2(maxf(8, viewport_size.x - _button.size.x - 96), _top_height + 8)
	var panel_y: float = _button.position.y + _button.size.y + 8
	var desired_height: float = 420 if has_active_offer() else 280
	_panel.size = Vector2(minf(400, viewport_size.x - 16), minf(desired_height, viewport_size.y - panel_y - 8))
	_panel.position = Vector2(maxf(8, viewport_size.x - _panel.size.x - 12), panel_y)

func _process(_delta: float) -> void:
	if _merchant_system == null:
		return
	var offer: Dictionary = _merchant_system.get_active_offer()
	var active: bool = has_active_offer()
	var now: int = int(Time.get_unix_time_from_system())
	var wait: int = maxi(0, int(_merchant_system.get_next_offer_at()) - now)
	_button.show()
	_button.text = "ТОРГОВЕЦ · !\nЕсть предложение" if active else "ТОРГОВЕЦ\nОжидание %s" % _clock(wait)
	_button.modulate = Color("fff0b4") if active else Color("9daeb7")
	_button.set_meta("offer_active", active)
	_button.tooltip_text = "Прибыл торговец. Открыть предложение: купить или отказаться." if active else "Предложения пока нет. Нажмите, чтобы посмотреть время ожидания."
	var key: String = str([offer.get("expires_at", 0), offer.get("resource_id", ""), offer.get("direction", ""), offer.get("order_id", ""), offer.get("visitor_index", 0)])
	if active and key != _offer_key:
		_offer_key = key
		_selected_quantity = 1
		_notice = ""
	_panel.visible = _is_open
	layout_for_viewport(get_viewport().get_visible_rect().size, _top_height)
	if not _is_open:
		return
	_quantity_label.visible = active
	_slider.visible = active
	_buy_button.visible = active
	_decline_button.visible = active
	_notice_label.text = _notice
	_notice_label.visible = not _notice.is_empty()
	if not active:
		var has_home: bool = str(GameState.world_state.get("home_port_id", "")) != ""
		_label.text = "Сейчас торговца на базе нет.\nСледующее предложение через %s.\n\nПоставщики привозят товары на склад базы. Покупатели рассматривают ваши заявки на продажу." % _clock(wait) if has_home else "Торговцы начнут прибывать после основания вашей базы."
		return
	var available: int = int(offer.get("quantity_available", 0))
	_selected_quantity = clampi(_selected_quantity, 1, available)
	_slider.set_block_signals(true)
	_slider.max_value = available
	_slider.set_value_no_signal(_selected_quantity)
	_slider.set_block_signals(false)
	var resource_name: String = str(_goods.get(str(offer.get("resource_id", "")), "Товар"))
	var unit_price: float = float(offer.get("unit_price", 0))
	var is_buyer: bool = str(offer.get("direction", "supplier")) == "buyer"
	_label.text = "%s\n%s · %s\n%s: %s\nДоступно: %d ед. · %.0f монет/ед.\nУедет через %s · Казна: %.0f\n%s" % ["ТОРГОВЕЦ ПОКУПАЕТ У ВАС" if is_buyer else "ПРИБЫЛО НОВОЕ ПРЕДЛОЖЕНИЕ", str(offer.get("merchant_name", "Торговец")), str(offer.get("vessel_name", "Торговое судно")), "Покупает" if is_buyer else "Предлагает", resource_name, available, unit_price, _clock(maxi(0, int(offer.get("expires_at", 0)) - now)), float(GameState.player_state.get("money", 0)), "Продажа по вашей заявке со склада базы." if is_buyer else "Купленный товар сразу поступит на склад базы."]
	_quantity_label.text = "Количество: %d · %s: %.0f монет" % [_selected_quantity, "Получите" if is_buyer else "К оплате", unit_price * _selected_quantity]
	_buy_button.text = "Продать торговцу" if is_buyer else "Купить"
	_buy_button.disabled = not is_buyer and float(GameState.player_state.get("money", 0)) < unit_price * _selected_quantity
	_buy_button.tooltip_text = "Недостаточно монет. Уменьшите количество." if _buy_button.disabled else ""

func _clock(seconds: int) -> String:
	return "%d:%02d" % [int(seconds / 60.0), seconds % 60]

func _toggle_window() -> void:
	_is_open = not _is_open

func close_window() -> void:
	_is_open = false
	_panel.hide()

func _on_quantity_changed(value: float) -> void:
	_selected_quantity = maxi(1, int(round(value)))

func _purchase() -> void:
	if _merchant_system == null:
		return
	var offer: Dictionary = _merchant_system.get_active_offer()
	var quantity: int = _selected_quantity
	var is_buyer: bool = str(offer.get("direction", "supplier")) == "buyer"
	var result: Dictionary = _merchant_system.sell_to_merchant(quantity) if is_buyer else _merchant_system.purchase(quantity)
	_notice = str(result.get("message", ""))
	_notice_label.modulate = Color("c7efd3") if bool(result.get("ok", false)) else Color("ffc7b5")
	if bool(result.get("ok", false)):
		_notice = "%s: %s × %d\n%s: %.0f монет. %s" % ["Продано" if is_buyer else "Куплено", str(_goods.get(str(offer.get("resource_id", "")), "Товар")), quantity, "Получено" if is_buyer else "Списано", float(offer.get("unit_price", 0)) * quantity, "Деньги в казне." if is_buyer else "Товар на складе базы."]
		_selected_quantity = 1

func _decline() -> void:
	var result: Dictionary = _merchant_system.decline_offer()
	_notice = str(result.get("message", ""))
	_notice_label.modulate = Color("c7efd3") if bool(result.get("ok", false)) else Color("ffc7b5")
	if bool(result.get("ok", false)):
		close_window()
