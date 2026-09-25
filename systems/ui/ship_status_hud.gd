extends CanvasLayer

## Read-only ship state shown while sailing.

const PANEL_SIZE := Vector2(390, 370)

var _panel: PanelContainer
var _label: Label
var _port_system: Node
var _goods: Dictionary = {}
var _world_size: Vector2 = Vector2(4096.0, 4096.0)

func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.size = PANEL_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 1.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9, 1.0))
	_label.add_theme_font_size_override("font_size", 19)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_label)

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var goods_catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
	var raw_resources: Variant = goods_catalog.get("resources", [])
	if raw_resources is Array:
		for raw_resource in raw_resources:
			var resource: Dictionary = raw_resource
			var resource_id: String = str(resource.get("id", ""))
			_goods[resource_id] = str(resource.get("display_name", resource_id))

func set_world_size(world_size: Vector2) -> void:
	_world_size = world_size

func _process(_delta: float) -> void:
	if _label == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_position: Vector2 = Vector2(maxf(12.0, (viewport_size.x - PANEL_SIZE.x) * 0.5), 12.0)
	_panel.position = panel_position
	_panel.size = Vector2(minf(PANEL_SIZE.x, viewport_size.x - 24.0), minf(PANEL_SIZE.y, viewport_size.y - 150.0))
	var ship: Dictionary = GameState.ship_state
	var cargo_units: int = _get_cargo_units(ship)
	var gear_text: String = " | задний ход" if bool(ship.get("reverse_gear", false)) else ""
	var docked_port: String = str(ship.get("docked_port_id", ""))
	var dock_hint: String = ""
	if docked_port != "":
		dock_hint = "
E: выйти из порта"
	elif _port_system != null and _port_system.has_method("get_dock_candidate") and _port_system.get_dock_candidate() != "":
		dock_hint = "
E: пришвартоваться"
	var autopilot_text: String = ""
	if bool(GameState.voyage_state.get("active_autopilot", false)) and _port_system != null:
		var destination_id: String = str(GameState.voyage_state.get("autopilot_destination_id", ""))
		var distance_left: float = ship.get("position", Vector2.ZERO).distance_to(_port_system.get_port_position(destination_id))
		var speed: float = ship.get("velocity", Vector2.ZERO).length()
		var eta: String = "—" if speed <= 0.1 else "%d сек" % int(ceil(distance_left / speed))
		autopilot_text = "\nАВТОПИЛОТ: %s\nДо порта: %.0f | прибытие: %s" % [_port_system.get_port_name(destination_id), distance_left, eta]
	_label.text = (
		"КОРАБЛЬ
"
		+ "Деньги: %.0f
"
		+ "Скорость: %.1f%s
"
		+ "Топливо: %.1f / %.0f
"
		+ "Корпус: %.0f / 100
"
		+ "Трюм: %d / %d
"
		+ "Груз:
%s
"
		+ "Координаты: %d, %d
"
		+ "Стоянка: %s"
		+ "%s"
		+ "%s"
	) % [
		float(GameState.player_state.get("money", 0.0)),
		ship.get("velocity", Vector2.ZERO).length(), gear_text,
		float(ship.get("fuel", 0.0)), float(ship.get("fuel_max", 0.0)),
		float(ship.get("hull", 0.0)),
		cargo_units, int(ship.get("cargo_capacity", 0)),
		_get_cargo_text(ship),
		int(ship.get("position", Vector2.ZERO).x), int(ship.get("position", Vector2.ZERO).y),
		docked_port if docked_port != "" else "в море", dock_hint, autopilot_text
	]

func _get_cargo_units(ship: Dictionary) -> int:
	var raw_cargo: Variant = ship.get("cargo", [])
	if not (raw_cargo is Array):
		return 0
	var total: int = 0
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		total += int(item.get("quantity", 0))
	return total

func _get_cargo_text(ship: Dictionary) -> String:
	var raw_cargo: Variant = ship.get("cargo", [])
	if not (raw_cargo is Array) or raw_cargo.is_empty():
		return "— пусто"
	var entries: Array[String] = []
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		var resource_id: String = str(item.get("resource_id", ""))
		var resource_name: String = str(_goods.get(resource_id, resource_id))
		entries.append("• %s: %d" % [resource_name, int(item.get("quantity", 0))])
	return "
".join(entries)

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
