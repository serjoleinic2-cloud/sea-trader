extends VBoxContainer

const ItemArt = preload("res://systems/ui/resource_item_art.gd")
const ITEM_ART_WIDTH := 36

## A single market transaction workspace. Economic calculations and mutations
## remain in the existing market, merchant and supply-order services.
var owner_window: Node
var mode := "sell"
var category := "all"
var selected_resource := ""
var _port_id := ""
var _home := false
var _title: Label
var _modes: HBoxContainer
var _categories: HFlowContainer
var _search: LineEdit
var _products: GridContainer
var _body: HBoxContainer
var _product_scroll: ScrollContainer
var _transaction_panel: PanelContainer
var _product_name: Label
var _stock: Label
var _quantity: SpinBox
var _quantity_caption: Label
var _slider: HSlider
var _price: SpinBox
var _price_caption: Label
var _total: Label
var _reason: Label
var _notice: Label
var _receipt: PanelContainer
var _receipt_style: StyleBoxFlat
var _primary: Button
var _presets: HBoxContainer
var _unit_price := 0.0
var _available := 0
var _tick := 0.0
var _signature := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new()
	add_child(header)
	_title = _label("РЫНОК", 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.name = "MarketCloseButton"
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(owner_window._collapse_port_overlay)
	get_parent().add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -52
	close.offset_top = 12
	close.offset_right = -12
	close.offset_bottom = 52
	visibility_changed.connect(func():
		if is_instance_valid(close):
			close.visible = visible
	)
	_modes = HBoxContainer.new()
	add_child(_modes)
	for choice in [["buy", "КУПИТЬ"], ["sell", "ПРОДАТЬ"], ["orders", "ЗАЯВКИ И ДОСТАВКИ"]]:
		_modes.add_child(_button(str(choice[1]), _set_mode.bind(str(choice[0]))))
	_categories = HFlowContainer.new()
	add_child(_categories)
	for choice in [["all", "Все товары"], ["raw_material", "Сырьё"], ["industrial_goods", "Промтовары"], ["liquid_cargo", "Жидкости"]]:
		_categories.add_child(_button(str(choice[1]), _set_category.bind(str(choice[0]))))
	_search = LineEdit.new()
	_search.placeholder_text = "Найти товар…"
	_search.custom_minimum_size.y = 30
	_search.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_search.set_meta("compact_description", true)
	_search.set_meta("ui_base_font_size", 12)
	_search.text_changed.connect(func(_text: String): _refresh_products())
	add_child(_search)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	add_child(_body)
	_body.resized.connect(_update_layout)
	_product_scroll = ScrollContainer.new()
	_product_scroll.name = "MarketProducts"
	_product_scroll.size_flags_horizontal = Control.SIZE_FILL
	_product_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_product_scroll)
	_products = GridContainer.new()
	_products.columns = 1
	_products.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_products.add_theme_constant_override("h_separation", 6)
	_products.add_theme_constant_override("v_separation", 6)
	_product_scroll.add_child(_products)
	_transaction_panel = PanelContainer.new()
	_transaction_panel.name = "MarketTransactionPanel"
	_transaction_panel.size_flags_horizontal = Control.SIZE_FILL
	_transaction_panel.custom_minimum_size.x = 360
	_body.add_child(_transaction_panel)
	var art_space := Control.new()
	art_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(art_space)
	var action := VBoxContainer.new()
	action.add_theme_constant_override("separation", 4)
	_transaction_panel.add_child(action)
	_product_name = _label("Выберите товар", 17)
	action.add_child(_product_name)
	_stock = _label("", 12)
	action.add_child(_stock)
	_quantity_caption = _label("Количество, ед.", 12)
	var quantity_row := HBoxContainer.new()
	action.add_child(quantity_row)
	_quantity_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_row.add_child(_quantity_caption)
	_quantity = SpinBox.new()
	_quantity.name = "MarketQuantity"
	_quantity.min_value = 1
	_quantity.step = 1
	_quantity.value = 1
	_quantity.set_meta("compact_description", true)
	_quantity.set_meta("ui_base_font_size", 12)
	_quantity.get_line_edit().set_meta("compact_description", true)
	_quantity.get_line_edit().set_meta("ui_base_font_size", 12)
	_quantity.value_changed.connect(_set_quantity)
	_quantity.custom_minimum_size.x = 104
	quantity_row.add_child(_quantity)
	_slider = HSlider.new()
	_slider.min_value = 1
	_slider.step = 1
	_slider.value_changed.connect(_set_quantity)
	action.add_child(_slider)
	_presets = HBoxContainer.new()
	action.add_child(_presets)
	for choice in [["1", 1.0], ["10", 10.0], ["½", -0.5], ["МАКС", -1.0]]:
		_presets.add_child(_button(str(choice[0]), _preset.bind(float(choice[1]))))
	_price_caption = _label("Цена продажи за единицу", 12)
	var price_row := HBoxContainer.new()
	action.add_child(price_row)
	_price_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(_price_caption)
	_price = SpinBox.new()
	_price.step = 1
	_price.set_meta("compact_description", true)
	_price.set_meta("ui_base_font_size", 12)
	_price.get_line_edit().set_meta("compact_description", true)
	_price.get_line_edit().set_meta("ui_base_font_size", 12)
	_price.value_changed.connect(func(_value: float): _refresh_details())
	_price.custom_minimum_size.x = 104
	price_row.add_child(_price)
	_total = _label("", 18)
	action.add_child(_total)
	_primary = _button("Выберите товар", _transact)
	_primary.name = "MarketPrimaryAction"
	action.add_child(_primary)
	_receipt = PanelContainer.new()
	_receipt.name = "MarketTransactionReceipt"
	_receipt.set_meta("preserve_art_style", true)
	_receipt_style = StyleBoxFlat.new()
	_receipt_style.set_border_width_all(1)
	_receipt_style.set_content_margin_all(8)
	_receipt_style.set_corner_radius_all(5)
	_receipt.add_theme_stylebox_override("panel", _receipt_style)
	action.add_child(_receipt)
	_notice = _label("", 14)
	_notice.name = "MarketTransactionMessage"
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.custom_minimum_size.x = 220
	_receipt.add_child(_notice)
	_receipt.hide()
	_reason = _label("", 12)
	_reason.name = "MarketAvailability"
	action.add_child(_reason)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.add_child(spacer)

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("compact_description", true)
	label.set_meta("ui_base_font_size", font_size)
	return label

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 12)
	button.set_meta("compact_description", true)
	button.set_meta("ui_base_font_size", 12)
	button.set_meta("ui_base_min_height", 30)
	button.pressed.connect(callback)
	return button

func _supply() -> Node:
	return owner_window.get_parent().get_node_or_null("SupplyOrderSystem")

func open_for_port(port_id: String) -> void:
	if port_id != _port_id:
		_port_id = port_id
		_home = port_id == str(GameState.world_state.get("home_port_id", ""))
		mode = "sell" if _home else "buy"
		selected_resource = ""
		category = "all"
		_clear_notice()
	_title.text = "РЫНОК · " + owner_window._port_system.get_port_name(port_id)
	_refresh_products()

func _set_mode(value: String) -> void:
	mode = value
	selected_resource = ""
	_clear_notice()
	_refresh_products()

func _set_category(value: String) -> void:
	category = value
	selected_resource = ""
	_clear_notice()
	_refresh_products()

func _choose(resource: String, clear_notice: bool = true) -> void:
	if clear_notice:
		_clear_notice()
	selected_resource = resource
	owner_window._selected_market_resource_id = resource
	_quantity.set_value_no_signal(1)
	var base_price: float = maxf(1.0, float(owner_window._goods_prices.get(resource, 1)))
	_price.min_value = maxf(1, round(base_price * 0.50))
	_price.max_value = maxf(_price.min_value + 1, round(base_price * 1.70))
	_price.set_value_no_signal(round(base_price))
	_refresh_details()
	for child in _products.get_children():
		if child is Button:
			child.button_pressed = str(child.get_meta("resource_id", "")) == resource

func _refresh_products() -> void:
	_products.columns = 1
	for child in _products.get_children():
		_products.remove_child(child)
		child.queue_free()
	for index in _modes.get_child_count():
		_modes.get_child(index).toggle_mode = true
		_modes.get_child(index).button_pressed = mode == ["buy", "sell", "orders"][index]
		_modes.get_child(index).visible = index != 2 or _home
	for index in _categories.get_child_count():
		_categories.get_child(index).toggle_mode = true
		_categories.get_child(index).button_pressed = category == ["all", "raw_material", "industrial_goods", "liquid_cargo"][index]
	_categories.visible = mode != "orders"
	_search.visible = mode != "orders"
	if mode == "orders":
		_orders()
		_refresh_details()
		_update_layout()
		return
	var first := ""
	var found := false
	for resource in owner_window._goods:
		if category != "all" and str(owner_window._goods_categories.get(resource, "")) != category:
			continue
		var name_value: String = owner_window._get_resource_name(str(resource))
		if not _search.text.strip_edges().is_empty() and not name_value.to_lower().contains(_search.text.to_lower()):
			continue
		var available: int = _resource_stock(str(resource))
		if mode == "sell" and available <= 0:
			continue
		var price_text: String = ""
		if not _home:
			price_text = " · %.0f мон./ед." % (owner_window._get_purchase_price(str(resource)) if mode == "buy" else owner_window._get_sale_price(str(resource)))
		var button: Button = _button("%s\n%d ед." % [name_value, available], _choose.bind(str(resource)))
		button.tooltip_text = "%s · %d ед.%s" % [name_value, available, price_text]
		button.name = "Good_" + str(resource)
		button.toggle_mode = true
		button.button_pressed = selected_resource == str(resource)
		button.set_meta("resource_id", str(resource))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 48
		button.icon = ItemArt.texture(str(resource))
		if button.icon != null:
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", ITEM_ART_WIDTH)
		button.theme_changed.connect(_update_layout, CONNECT_DEFERRED)
		_products.add_child(button)
		if first == "":
			first = str(resource)
		found = found or selected_resource == str(resource)
	if not found:
		_choose(first, false)
	if first == "":
		_products.add_child(_label("Нет свободных товаров для продажи." if mode == "sell" else "Нет товаров по выбранному фильтру.", 13))
	_refresh_details()
	_update_layout()
	_signature = _state_signature()

func _update_layout() -> void:
	if _transaction_panel == null:
		return
	# Measure the whole catalog so filtering never shifts the purchase panel.
	var sample: Button = _modes.get_child(0)
	for child in _products.get_children():
		if child is Button and child.has_meta("resource_id"):
			sample = child
			break
	var font: Font = sample.get_theme_font("font")
	var font_size: int = sample.get_theme_font_size("font_size")
	var name_width := 0.0
	for resource in owner_window._goods:
		name_width = maxf(name_width, font.get_string_size(owner_window._get_resource_name(str(resource)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var padding: float = sample.get_theme_stylebox("normal").get_minimum_size().x
	var list_width: float = ceilf(name_width + padding + ITEM_ART_WIDTH + sample.get_theme_constant("h_separation") + _product_scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	var panel_width: float = clampf(_body.size.x - list_width - 12, 260, 360)
	_transaction_panel.custom_minimum_size.x = panel_width
	_product_scroll.custom_minimum_size.x = maxf(list_width, minf(400, _body.size.x - panel_width - 12)) if mode == "orders" else list_width
	_search.custom_minimum_size.x = list_width

func _resource_stock(resource: String) -> int:
	if _home:
		if mode == "buy":
			var supply: Node = _supply()
			if supply == null:
				return 0
			var quote: Dictionary = supply.get_quote(resource)
			return int(GameState.port_state.get(str(quote.get("source_port_id", "")), {}).get("market_stock", {}).get(resource, 0)) if bool(quote.get("ok", false)) else 0
		var merchant: Node = owner_window._get_merchant_system()
		var reserved: int = int(merchant.get_reserved_quantity(resource)) if merchant != null else 0
		return maxi(0, int(GameState.port_state.get(_port_id, {}).get("inventory", {}).get(resource, 0)) - reserved)
	if mode == "buy":
		return int(owner_window._get_port_market_stock(_port_id).get(resource, 0))
	return int(owner_window._get_sellable_cargo_quantity(resource))

func _refresh_details() -> void:
	var selected: bool = selected_resource != "" and mode != "orders"
	for control in [_quantity, _quantity_caption, _presets]:
		control.visible = selected
	_quantity_caption.get_parent().visible = selected
	_slider.hide()
	_price.visible = selected and _home and mode == "sell"
	_price_caption.visible = _price.visible
	_price_caption.get_parent().visible = _price.visible
	_product_name.text = owner_window._get_resource_name(selected_resource) if selected else ("Заявки и доставки" if mode == "orders" else "Выберите товар")
	_primary.disabled = true
	_primary.visible = mode != "orders"
	_total.text = ""
	_reason.text = ""
	_stock.text = ""
	if not selected:
		_primary.text = "Выберите товар"
		return
	_available = _resource_stock(selected_resource)
	_quantity.max_value = maxi(1, _available)
	_quantity.set_value_no_signal(clampf(_quantity.value, 1, _quantity.max_value))
	_slider.max_value = _quantity.max_value
	_slider.set_value_no_signal(_quantity.value)
	var quantity: int = int(_quantity.value)
	var money: float = float(GameState.player_state.get("money", 0))
	var ready: bool = _available >= quantity
	_unit_price = 0
	var total: float = 0
	var explanation := ""
	if _home and mode == "buy":
		var supply: Node = _supply()
		var quote: Dictionary = supply.get_quote(selected_resource, quantity) if supply != null else {"ok": false, "message": "Поставка недоступна."}
		_unit_price = float(quote.get("delivery_price", 0))
		total = _unit_price * quantity
		ready = ready and bool(quote.get("ok", false))
		explanation = "Поставщик: %s\nПрибытие: %d сек. Доставка включена." % [str(quote.get("source_name", "—")), int(quote.get("delivery_seconds", 0))] if bool(quote.get("ok", false)) else str(quote.get("message", "Нет поставщика."))
		if supply != null and supply.get_active_orders().size() >= supply.get_delivery_capacity():
			ready = false
			explanation = "Все места доставки заняты. Дождитесь груза или улучшите рынок."
	elif _home:
		_unit_price = _price.value
		total = _unit_price * quantity
		ready = ready and owner_window._get_merchant_system() != null
		explanation = "Товар резервируется в заявке. Монеты поступят, когда его купит прибывший торговец."
	else:
		var quote: Dictionary = owner_window._transfers._market.quote_purchase(_port_id, selected_resource, quantity) if mode == "buy" else owner_window._transfers._market.quote_sale(_port_id, selected_resource, quantity)
		_unit_price = float(quote.get("unit_price", 0))
		total = _unit_price * quantity if mode == "buy" else float(quote.get("revenue", 0))
		ready = ready and bool(quote.get("ok", false))
		explanation = str(quote.get("message", "")) if not bool(quote.get("ok", false)) else ("Покупка поступит в трюм корабля." if mode == "buy" else "Монеты поступят в казну сразу.")
		if mode == "buy" and quantity > int(GameState.ship_state.get("cargo_capacity", 0)) - owner_window._get_cargo_units():
			ready = false
			explanation = "В трюме не хватает места для этого количества."
	if mode == "buy" and money < total:
		ready = false
		explanation = "Не хватает %.0f монет. Уменьшите количество." % (total - money)
	if _available <= 0:
		ready = false
		if not (_home and mode == "buy"):
			explanation = "Свободного товара нет."
	_stock.text = "Доступно %d ед. · цена %.0f/ед.\nКазна %.0f · трюм %d / %d" % [_available, _unit_price, money, owner_window._get_cargo_units(), int(GameState.ship_state.get("cargo_capacity", 0))]
	_total.text = "%s: %.0f монет" % ["Ожидаемая выручка" if _home and mode == "sell" else ("Получите" if mode == "sell" else "К оплате"), total]
	_primary.text = ("ЗАКАЗАТЬ НА БАЗУ" if _home else "КУПИТЬ") if mode == "buy" else ("ВЫСТАВИТЬ ЗАЯВКУ" if _home else "ПРОДАТЬ")
	_primary.disabled = not ready
	_reason.text = explanation
	_reason.modulate = Color.WHITE if ready else Color("ffc3b0")

func _set_quantity(value: float) -> void:
	_quantity.set_value_no_signal(value)
	_slider.set_value_no_signal(value)
	_refresh_details()

func _preset(value: float) -> void:
	var maximum: int = _available
	if mode == "buy":
		maximum = mini(maximum, int(float(GameState.player_state.get("money", 0)) / maxf(1, _unit_price)))
		if not _home:
			maximum = mini(maximum, int(GameState.ship_state.get("cargo_capacity", 0)) - owner_window._get_cargo_units())
	_set_quantity(maxf(1, floor(maximum * absf(value))) if value < 0 else minf(value, _quantity.max_value))

func _transact() -> void:
	_refresh_details()
	if _primary.disabled:
		_show_notice("ОПЕРАЦИЯ НЕ ВЫПОЛНЕНА\n" + (_reason.text if _reason.text != "" else "Сначала выберите товар."), false)
		return
	var quantity: int = int(_quantity.value)
	var resource: String = selected_resource
	var resource_name: String = owner_window._get_resource_name(resource)
	var action: String = mode
	var result: Dictionary
	if _home:
		result = _supply().place_order(selected_resource, quantity) if mode == "buy" else owner_window._get_merchant_system().create_sell_order(selected_resource, quantity, _price.value)
	else:
		result = owner_window._transfers.execute(mode, selected_resource, quantity)
	_refresh_products()
	var success: bool = bool(result.get("ok", false))
	var message: String = "ОПЕРАЦИЯ НЕ ВЫПОЛНЕНА\n" + str(result.get("message", "Повторите операцию."))
	if success:
		var balance: float = float(GameState.player_state.get("money", 0))
		if action == "buy":
			var cost: float = float(result.get("cost", 0))
			if _home:
				var seconds: int = maxi(0, int(result.get("arrives_at", 0)) - int(Time.get_unix_time_from_system()))
				message = "ДОСТАВКА ОПЛАЧЕНА · %s × %d\nСписано: %.0f монет · В казне: %.0f\nНа склад базы «%s» через %d сек." % [resource_name, quantity, cost, balance, owner_window._port_system.get_port_name(_port_id), seconds]
			else:
				message = "КУПЛЕНО · %s × %d\nСписано: %.0f монет · В казне: %.0f\nТовар в трюме. Всего: %d ед." % [resource_name, quantity, cost, balance, owner_window._get_sellable_cargo_quantity(resource)]
		elif _home:
			message = "ЗАЯВКА РАЗМЕЩЕНА · %s × %d\nТовар зарезервирован на складе.\nМонеты поступят после выкупа торговцем." % [resource_name, quantity]
		else:
			message = "ПРОДАНО · %s × %d\nПолучено: %.0f монет · В казне: %.0f\nВ трюме осталось: %d ед." % [resource_name, quantity, float(result.get("revenue", 0)), balance, owner_window._get_sellable_cargo_quantity(resource)]
	_show_notice(message, success)
	owner_window._notice = message

func _clear_notice() -> void:
	_notice.text = ""
	_receipt.hide()

func _show_notice(message: String, success: bool) -> void:
	_notice.text = message
	_notice.modulate = Color("d2f3df") if success else Color("ffccc3")
	_receipt_style.bg_color = Color("0b3025") if success else Color("381b20")
	_receipt_style.border_color = Color("63b98a") if success else Color("d97d6d")
	_receipt.tooltip_text = message
	_receipt.show()

func _orders() -> void:
	var count := 0
	var merchant: Node = owner_window._get_merchant_system()
	if merchant != null:
		for order in merchant.get_sell_orders():
			count += 1
			var label: Label = _label("%s × %d · %.0f/ед.\n%s" % [owner_window._get_resource_name(str(order.resource_id)), int(order.get("quantity_available", 0)), float(order.get("asking_price", 0)), str(order.get("last_feedback", "Ждёт торговца"))], 12)
			_products.add_child(label)
			_products.add_child(_button("Снять заявку и освободить товар", _cancel_order.bind(str(order.id))))
	var supply: Node = _supply()
	if supply != null:
		for order in supply.get_active_orders():
			count += 1
			var remaining: int = maxi(0, int(order.get("arrives_at", 0)) - int(Time.get_unix_time_from_system()))
			_products.add_child(_label("В пути: %s × %d · %d сек." % [owner_window._get_resource_name(str(order.resource_id)), int(order.quantity), remaining], 13))
	if count == 0:
		_products.add_child(_label("Заявок и доставок пока нет.", 13))

func _cancel_order(id: String) -> void:
	var result: Dictionary = owner_window._get_merchant_system().cancel_sell_order(id)
	_refresh_products()
	_show_notice(str(result.get("message", "")), bool(result.get("ok", false)))

func _state_signature() -> String:
	return str(hash([GameState.port_state.get(_port_id, {}).get("inventory", {}), GameState.port_state.get(_port_id, {}).get("market_stock", {}), GameState.ship_state.get("cargo", []), GameState.player_state.get("money", 0), GameState.economy_state.get("supply_orders", []), GameState.economy_state.get("merchant", {}).get("sell_orders", [])]))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0
	_update_layout()
	if mode == "orders" or _signature != _state_signature():
		_refresh_products()
	else:
		_refresh_details()
