extends CanvasLayer

## Crystal workshop for the home island's Mage Guild.
var _system: Node
var _root: Control
var _panel: PanelContainer
var _title: Label
var _level: Label
var _shards: Label
var _status: Label
var _notice: Label
var _upgrade_button: Button
var _defense_button: Button
var _cards: Dictionary = {}
var _card_layout: BoxContainer
var _open: bool = false
var _last_refresh_second: int = -1

const CRYSTAL_ORDER := ["crystal_power", "crystal_guard", "crystal_luck"]

func _ready() -> void:
	add_to_group("mage_guild_window")
	layer = 58
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#0d1c2c")
	panel_style.border_color = Color("#4b9ba2")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	var emblem := TextureRect.new()
	emblem.custom_minimum_size = Vector2(54, 54)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.texture = load("res://assets/ui/cards/mage_guild.svg")
	heading.add_child(emblem)
	_title = Label.new()
	_title.text = "ГИЛЬДИЯ МАГОВ"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 29)
	_title.add_theme_color_override("font_color", Color("#f2e5c7"))
	heading.add_child(_title)
	var close_button := Button.new()
	close_button.text = "Закрыть"
	preload("res://systems/ui/brass_close_button.gd").apply(close_button)
	close_button.custom_minimum_size = Vector2(130, 46)
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	layout.add_child(heading)
	_level = Label.new()
	_level.add_theme_font_size_override("font_size", 20)
	layout.add_child(_level)
	_shards = Label.new()
	_shards.add_theme_font_size_override("font_size", 19)
	_shards.add_theme_color_override("font_color", Color("#72ddd2"))
	layout.add_child(_shards)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 18)
	layout.add_child(_status)
	_upgrade_button = Button.new()
	_upgrade_button.custom_minimum_size.y = 48
	_upgrade_button.add_theme_font_size_override("font_size", 17)
	_upgrade_button.tooltip_text = "Открыть проект постройки или улучшения гильдии."
	_upgrade_button.pressed.connect(_open_upgrade)
	layout.add_child(_upgrade_button)
	_defense_button = Button.new()
	_defense_button.text = "ОТКРЫТЬ ОБОРОНУ И БАШНИ"
	_defense_button.custom_minimum_size.y = 48
	_defense_button.add_theme_font_size_override("font_size", 17)
	_defense_button.tooltip_text = "После создания кристалла выберите башню и установите его в окне обороны."
	_defense_button.pressed.connect(_open_defense)
	layout.add_child(_defense_button)
	var cards := BoxContainer.new()
	_card_layout = cards
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 14)
	layout.add_child(cards)
	for crystal_id in CRYSTAL_ORDER:
		var card := _create_crystal_card(str(crystal_id))
		cards.add_child(card.panel)
		_cards[str(crystal_id)] = card
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_font_size_override("font_size", 18)
	layout.add_child(_notice)
	_root.hide()

func initialize(system: Node) -> void:
	_system = system

func open() -> void:
	_open = true
	_notice.text = ""
	_refresh()

func close() -> void:
	_open = false

func _process(_delta: float) -> void:
	_root.visible = _open
	if not _open:
		return
	var viewport := get_viewport().get_visible_rect().size
	_card_layout.vertical = viewport.x < 1200.0
	_panel.size = Vector2(minf(1120.0, viewport.x - 32.0), minf(690.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	var second := int(Time.get_unix_time_from_system())
	if second != _last_refresh_second:
		_last_refresh_second = second
		_refresh()

func _create_crystal_card(crystal_id: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142b3b")
	style.border_color = Color("#5d8590")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#f2e5c7"))
	content.add_child(title)
	var effect := Label.new()
	effect.custom_minimum_size.y = 65
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 19)
	effect.add_theme_color_override("font_color", Color("#72ddd2"))
	content.add_child(effect)
	var owned := Label.new()
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.add_theme_font_size_override("font_size", 18)
	content.add_child(owned)
	var cost := Label.new()
	cost.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.add_theme_font_size_override("font_size", 17)
	content.add_child(cost)
	var button := Button.new()
	button.text = "СОЗДАТЬ КРИСТАЛЛ"
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_create_crystal.bind(crystal_id))
	content.add_child(button)
	return {"panel": panel, "title": title, "effect": effect, "owned": owned, "cost": cost, "button": button}

func _refresh() -> void:
	if _system == null:
		return
	var guild_level: int = _system.get_mage_guild_level()
	_level.text = "УРОВЕНЬ ГИЛЬДИИ %d / 30" % guild_level
	_shards.text = "Осколки магии: %d  ·  они не продаются и не занимают груз" % _system.get_magic_shards()
	if guild_level <= 0:
		_status.text = "Сначала постройте гильдию магов через раздел «Строительство» в домашнем порту. Первый уровень откроет создание кристаллов."
	elif not _system.is_at_home():
		_status.text = "Гильдия действует на домашнем острове. Вернитесь в главный порт, чтобы создавать кристаллы."
	else:
		_status.text = "Уровень гильдии усиливает все кристаллы. Доступны кристаллы атаки, брони и удачи. При первом открытии выдано 3 стартовых осколка; новые осколки дают победы в бою: за первую и затем за каждую третью."
	var inventory: Dictionary = _system.get_crystal_inventory()
	var home_port: Dictionary = GameState.port_state.get(_system.get_home_port_id(), {})
	var home_inventory: Dictionary = home_port.get("inventory", {})
	var mounted: Dictionary = {}
	for raw_tower in _system.get_towers():
		var crystal_id: String = str(raw_tower.get("crystal_id", ""))
		if crystal_id != "":
			mounted[crystal_id] = int(mounted.get(crystal_id, 0)) + 1
	for crystal_id in CRYSTAL_ORDER:
		var card: Dictionary = _cards[crystal_id]
		var recipe: Dictionary = _system.get_crystal_recipe(crystal_id)
		var count: int = int(inventory.get(crystal_id, 0))
		card.title.text = _system.get_crystal_name(crystal_id)
		card.effect.text = "Уровень кристалла: %d\n%s" % [_system.get_crystal_level(), _system.get_crystal_effect_text(crystal_id)]
		card.owned.text = "В запасе: %d  ·  в башнях: %d" % [count, int(mounted.get(crystal_id, 0))]
		card.cost.text = "Создание: %d монет и %d запчастей\nУ вас: %d монет и %d запчастей\nОсколки магии: %d / %d" % [int(recipe.get("money", 0)), int(recipe.get("resource_parts", 0)), int(GameState.player_state.get("money", 0)), int(home_inventory.get("resource_parts", 0)), _system.get_magic_shards(), int(recipe.get("magic_shards", 0))]
		card.button.disabled = not _system.can_create_crystal(crystal_id)
		if guild_level <= 0:
			card.button.text = "НУЖНА ГИЛЬДИЯ"
		else:
			card.button.text = "СОЗДАТЬ КРИСТАЛЛ"
	_defense_button.disabled = guild_level <= 0 or not _system.is_at_home()
	_upgrade_button.text = "ПОСТРОИТЬ ГИЛЬДИЮ" if guild_level <= 0 else "УЛУЧШИТЬ ГИЛЬДИЮ · %d → %d" % [guild_level, guild_level + 1]
	_upgrade_button.disabled = not _system.is_at_home() or guild_level >= 30

func _open_upgrade() -> void:
	if _system == null or not _system.is_at_home():
		return
	var projects: Array[Node] = get_tree().get_nodes_in_group("building_project_window")
	if projects.is_empty() or not projects[0].has_method("open_for_building"):
		return
	var coordinators: Array[Node] = get_tree().get_nodes_in_group("window_coordinator")
	if not coordinators.is_empty():
		coordinators[0]._close_all_workspaces()
		coordinators[0].set("_port_expanded", false)
		coordinators[0].set("_details", "")
	_open = false
	projects[0].call("open_for_building", "mage_guild")

func _open_defense() -> void:
	if _system == null or not _system.is_at_home():
		return
	_open = false
	var coordinators: Array[Node] = get_tree().get_nodes_in_group("window_coordinator")
	if not coordinators.is_empty() and coordinators[0].has_method("_open_garrison"):
		coordinators[0].call("_open_garrison", true)

func _create_crystal(crystal_id: String) -> void:
	if _system == null:
		return
	var result: Dictionary = _system.create_crystal(crystal_id)
	_notice.text = str(result.get("message", ""))
	_refresh()
