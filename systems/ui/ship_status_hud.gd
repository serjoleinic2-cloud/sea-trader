extends CanvasLayer

## Read-only sailing instruments; cargo scrolls separately.
const PANEL_SIZE := Vector2(350, 340)
var _panel: PanelContainer
var _label: Label
var _port_system: Node
var _goods: Dictionary = {}
var _world_size: Vector2 = Vector2(4096, 4096)
var _title: Label
var _money: Label
var _course: Label
var _icon: TextureRect
var _bars: Dictionary = {}
var _meter_labels: Dictionary = {}
var _cargo_scroll: ScrollContainer
var _last_ship_id: String = ""

func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.name = "ShipInstruments"
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var crest := TextureRect.new()
	crest.texture = GameData.get_faction_emblem(str(GameState.player_state.get("origin_race_id", "humans")))
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.custom_minimum_size = Vector2(40, 48)
	header.add_child(crest)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 20)
	header.add_child(_title)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(72, 48)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_icon)
	_money = Label.new()
	stack.add_child(_money)
	for key in ["hull", "fuel", "cargo"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size.x = 86
		label.text = {"hull": "Корпус", "fuel": "Топливо", "cargo": "Трюм"}[key]
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(95, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		row.add_child(bar)
		var value := Label.new()
		value.custom_minimum_size.x = 62
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_bars[key] = bar
		_meter_labels[key] = value
		stack.add_child(row)
	_course = Label.new()
	_course.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_course)
	_cargo_scroll = ScrollContainer.new()
	_cargo_scroll.name = "CargoScroll"
	_cargo_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cargo_scroll.custom_minimum_size.y = 24
	_cargo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(_cargo_scroll)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color("aec4cb"))
	_cargo_scroll.add_child(_label)

func initialize(port_system: Node, goods_catalog: Dictionary = {}) -> void:
	_port_system = port_system
	if goods_catalog.is_empty():
		goods_catalog = GameData.read("res://data/resources/goods_catalog.json")
	for resource in goods_catalog.get("resources", []):
		_goods[str(resource.get("id", ""))] = str(resource.get("display_name", ""))

func set_world_size(world_size: Vector2) -> void:
	_world_size = world_size

func _process(_delta: float) -> void:
	if _label == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(12, 84)
	_panel.size = Vector2(minf(PANEL_SIZE.x, viewport.x - 24), minf(PANEL_SIZE.y, viewport.y - 130))
	var ship: Dictionary = GameState.ship_state
	var id: String = str(ship.get("ship_id", "ship_sloop"))
	if id != _last_ship_id:
		_last_ship_id = id
		var definition: Dictionary = GameData.get_ship(id)
		_title.text = str(ship.get("name", definition.get("name", "Корабль")))
		if _title.text == "":
			_title.text = str(definition.get("name", "Корабль"))
		var path: String = str(definition.get("ui_icon", ""))
		_icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var cargo: int = _get_cargo_units(ship)
	_meter("hull", float(ship.get("hull", 0)), float(ship.get("hull_max", 100)))
	_meter("fuel", float(ship.get("fuel", 0)), float(ship.get("fuel_max", 100)))
	_meter("cargo", cargo, float(ship.get("cargo_capacity", 0)))
	_money.text = "Казна  %s" % String.num(float(GameState.player_state.get("money", 0)), 0)
	var speed: float = Vector2(ship.get("velocity", Vector2.ZERO)).length()
	var gear: String = " · задний ход" if bool(ship.get("reverse_gear", false)) else ""
	_course.text = "Ход %.0f%s" % [speed, gear]
	var docked: String = str(ship.get("docked_port_id", ""))
	if docked != "":
		_course.text += " · E: выйти из порта"
	elif _port_system != null and _port_system.get_dock_candidate() != "":
		_course.text += " · E: швартовка"
	if bool(GameState.voyage_state.get("active_autopilot", false)) and _port_system != null:
		var target: String = str(GameState.voyage_state.get("autopilot_destination_id", ""))
		_course.text += "\nАвтопилот → " + _port_system.get_port_name(target)
	_label.text = _get_cargo_text(ship)

func _meter(key: String, value: float, capacity: float) -> void:
	var bar: ProgressBar = _bars[key]
	bar.max_value = maxf(1, capacity)
	bar.value = value
	_meter_labels[key].text = "%d/%d" % [int(value), int(capacity)]
	bar.modulate = Color("ff8c7d") if key == "hull" and value < capacity * 0.25 else Color.WHITE

func _get_cargo_units(ship: Dictionary) -> int:
	var total: int = 0
	for item in ship.get("cargo", []):
		total += int(item.get("quantity", 0))
	return total

func _get_cargo_text(ship: Dictionary) -> String:
	var entries: Array[String] = []
	for item in ship.get("cargo", []):
		var id: String = str(item.get("resource_id", ""))
		entries.append("%s × %d" % [str(_goods.get(id, id)), int(item.get("quantity", 0))])
	return "Трюм свободен" if entries.is_empty() else "\n".join(entries)

func _unhandled_key_input(event: InputEvent) -> void:
	if _port_system == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_E and event.physical_keycode != KEY_E:
		return
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_port_system.undock()
	else:
		var candidate: String = str(_port_system.get_dock_candidate())
		if candidate != "":
			_port_system.dock(candidate)
	get_viewport().set_input_as_handled()
