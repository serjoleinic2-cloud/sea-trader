extends HBoxContainer

signal purchase_requested(id: String)
signal selection_changed(category: String, id: String)

var _shop: Node
var _category: String = "all"
var _selected: String = ""
var _products: GridContainer
var _detail_title: Label
var _detail_image: TextureRect
var _detail_text: Label
var _detail_price: Label
var _detail_reason: Label
var _buy: Button
var _cards: Dictionary = {}
var _filters: Dictionary = {}

func _ready() -> void:
	name = "CompanyShopView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)

func _process(_delta: float) -> void:
	if is_instance_valid(_detail_image):
		_detail_image.custom_minimum_size.y = clampf(size.y * 0.42, 128, 256)

func configure(shop: Node, category: String = "all", selected: String = "") -> void:
	_shop = shop
	_category = category
	_selected = selected
	var categories := VBoxContainer.new()
	categories.name = "ShopCategories"
	categories.custom_minimum_size.x = 148
	add_child(categories)
	for entry in [["all", "Все товары", "shop"], ["boost_pack", "Бусты", "boost"], ["premium", "Премиум", "money"], ["unique_crew", "Персонал", "crew"], ["port_module", "База клана", "port"], ["local_model", "Облики", "fleet"]]:
		var button := Button.new()
		button.text = str(entry[1])
		button.name = "Category_" + str(entry[0])
		button.set_meta("fixed_font_size", 12)
		button.set_meta("compact_hud", true)
		button.toggle_mode = true
		button.custom_minimum_size.y = 36
		button.icon = _category_icon(str(entry[2]))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
		button.pressed.connect(_choose_category.bind(str(entry[0])))
		categories.add_child(button)
		_filters[str(entry[0])] = button
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)
	_label(center, "МАГАЗИН КОМПАНИИ", 18)
	_label(center, "Выберите товар. Покупка за игровые монеты, после подтверждения.", 12)
	var scroll := ScrollContainer.new()
	scroll.name = "ShopCatalogScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(scroll)
	_products = preload("res://systems/ui/boost_tile_grid.gd").new()
	_products.name = "ShopProductTiles"
	_products.tile_width = 200
	_products.maximum_columns = 3
	scroll.add_child(_products)
	var detail := PanelContainer.new()
	detail.name = "ShopSelectedProduct"
	detail.custom_minimum_size.x = 286
	add_child(detail)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	detail.add_child(stack)
	_detail_title = _label(stack, "", 18)
	_detail_title.max_lines_visible = 2
	_detail_image = TextureRect.new()
	_detail_image.name = "SelectedProductArt"
	_detail_image.custom_minimum_size = Vector2(250, 128)
	_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(_detail_image)
	var details_scroll := ScrollContainer.new()
	details_scroll.name = "ProductDescriptionScroll"
	details_scroll.custom_minimum_size.y = 32
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(details_scroll)
	_detail_text = _label(details_scroll, "", 13)
	_detail_price = _label(stack, "", 16)
	_detail_reason = _label(stack, "", 12)
	_buy = Button.new()
	_buy.name = "ShopBuySelected"
	_buy.set_meta("fixed_font_size", 14)
	_buy.custom_minimum_size.y = 36
	_buy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_buy.pressed.connect(func() -> void: purchase_requested.emit(_selected))
	stack.add_child(_buy)
	_choose_category(_category)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_meta("fixed_font_size", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _choose_category(category: String) -> void:
	_category = category
	for key in _filters: _filters[key].set_pressed_no_signal(str(key) == category)
	for node in _products.get_children(): _products.remove_child(node); node.queue_free()
	_cards.clear()
	var visible_products: Array = []
	for item in _shop.catalog():
		if category == "all" or str(item.kind) == category: visible_products.append(item)
	var selection_visible: bool = false
	for item in visible_products:
		if str(item.id) == _selected: selection_visible = true
	if not selection_visible: _selected = str(visible_products[0].id) if not visible_products.is_empty() else ""
	for item in visible_products: _card(item)
	_select(_selected)

func _card(item: Dictionary) -> void:
	var card := Button.new()
	card.name = "Product_" + str(item.id)
	card.custom_minimum_size = Vector2(200, 216)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("selection_card", true)
	card.toggle_mode = true
	card.pressed.connect(_select.bind(str(item.id)))
	_products.add_child(card)
	_cards[str(item.id)] = card
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var image := TextureRect.new()
	image.texture = product_art(item)
	image.custom_minimum_size.y = 116
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(image)
	var title: Label = _label(column, str(item.name), 14)
	title.max_lines_visible = 2
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price: Label = _label(column, "%.0f монет" % float(item.price) if bool(item.get("available", true)) else "СКОРО", 13)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_color_override("font_color", Color("f0cd7d"))
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _select(id: String) -> void:
	_selected = id
	for key in _cards: _cards[key].set_pressed_no_signal(str(key) == id)
	var quote: Dictionary = _shop.quote(id)
	_detail_title.text = str(quote.get("name", "Выберите товар"))
	_detail_image.texture = product_art(quote)
	_detail_text.text = str(quote.get("description", ""))
	_detail_price.text = "Цена: %.0f монет" % float(quote.get("price", 0))
	_detail_reason.text = str(quote.get("message", ""))
	_detail_reason.visible = _detail_reason.text != ""
	_buy.text = "Купить · %.0f" % float(quote.get("price", 0)) if str(quote.get("kind", "")) != "local_model" else "Модель ещё не установлена"
	_buy.disabled = not bool(quote.get("ok", false))
	selection_changed.emit(_category, id)

func _category_icon(id: String) -> Texture2D:
	if id == "boost": return preload("res://systems/ui/boost_item_art.gd").texture("speed")
	if id == "money": return preload("res://systems/ui/resource_item_art.gd").texture("money")
	if id == "shop": return load("res://assets/ui/social/shop.svg")
	return load("res://assets/ui/styles/approved_hud/%s.png" % ("captain" if id == "crew" else id))

func product_art(item: Dictionary) -> Texture2D:
	match str(item.get("kind", "")):
		"boost_pack": return preload("res://systems/ui/boost_item_art.gd").texture("damage" if str(item.get("id", "")) == "artillery_scrolls" else "speed")
		"premium": return preload("res://systems/ui/boost_item_art.gd").texture("sale")
		"unique_crew": return preload("res://systems/characters/character_art_catalog.gd").ship_officer_portrait(str(GameState.player_state.get("origin_race_id", "humans")), "mechanic", 2, load("res://assets/characters/crew/crew_portrait_atlas.png"))
		"port_module": return load("res://assets/ui/styles/approved_hud/port.png")
		"local_model": return load("res://assets/ui/styles/approved_hud/%s.png" % ("fleet" if str(item.get("id", "")) == "ship_skin" else "port"))
	return null
