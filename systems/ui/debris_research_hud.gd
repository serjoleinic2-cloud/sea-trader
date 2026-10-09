extends CanvasLayer

const TrainingScrolls = preload("res://systems/employees/training_scrolls.gd")

## Contextual sea-foundation research. Finds rare deterministic floating objects
## near the controlled ship and pays the reward directly into the home port.

class DebrisMarker extends Control:
	var progress: float = 0.0
	var kind: String = "Обломки"
	var active: bool = false

	func _draw() -> void:
		var center := Vector2(0, 0)
		var ring_color := Color("#e5c66a") if active else Color("#8daab6")
		draw_circle(center, 27.0, Color(0.02, 0.09, 0.12, 0.90))
		draw_arc(center, 34.0, -PI / 2.0, TAU - PI / 2.0, 40, Color(ring_color, 0.35), 3.0)
		if active:
			draw_arc(center, 34.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, ring_color, 5.0)
		var body_color := Color("#c29452") if kind == "Ящик" else Color("#8b5e3c") if kind == "Бочка" else Color("#6f8990")
		draw_rect(Rect2(-12, -10, 24, 20), body_color, true)
		draw_line(Vector2(-12, -10), Vector2(12, 10), Color("#30241c"), 2.0)
		draw_line(Vector2(12, -10), Vector2(-12, 10), Color("#30241c"), 2.0)

var _main: Node
var _root: Control
var _marker: DebrisMarker
var _status: Label
var _research_button: Button
var _nearest: Dictionary = {}
var _debris: Array = []
var _button_held: bool = false
var _progress: float = 0.0
var _notice_timer: float = 0.0

const RESEARCH_TIME: float = 3.0
const INTERACTION_RADIUS: float = 155.0

func _ready() -> void:
	layer = 42
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_marker = DebrisMarker.new()
	_marker.custom_minimum_size = Vector2(90, 90)
	_marker.size = Vector2(90, 90)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_marker)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color("#f3e5b1"))
	_status.add_theme_color_override("font_outline_color", Color("#07161c"))
	_status.add_theme_constant_override("outline_size", 6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_status)
	_research_button = Button.new()
	_research_button.text = "ИССЛЕДОВАТЬ [R]"
	_research_button.custom_minimum_size = Vector2(220, 42)
	_research_button.add_theme_font_size_override("font_size", 16)
	_research_button.button_down.connect(func(): _button_held = true)
	_research_button.button_up.connect(func(): _button_held = false)
	_research_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_research_button)
	_root.hide()

func initialize(main: Node) -> void:
	_main = main
	_rebuild_debris()

func _process(delta: float) -> void:
	if _main == null:
		return
	if _debris.is_empty():
		_rebuild_debris()
	var ship_position := Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	_nearest = _find_nearest(ship_position)
	var viewport := get_viewport().get_visible_rect().size
	var show_context: bool = not _nearest.is_empty() and str(GameState.ship_state.get("docked_port_id", "")) == ""
	_root.visible = show_context or _notice_timer > 0.0
	if _notice_timer > 0.0:
		_notice_timer = maxf(0.0, _notice_timer - delta)
	if not show_context:
		_progress = 0.0
		_button_held = false
		_marker.visible = false
		_status.visible = _notice_timer > 0.0
		_research_button.visible = false
		_marker.active = false
		_marker.queue_redraw()
		return
	_marker.visible = true
	_status.visible = true
	_research_button.visible = true
	_marker.position = Vector2(viewport.x * 0.5 - 45.0, viewport.y * 0.56 - 70.0)
	_status.position = Vector2(viewport.x * 0.5 - 190.0, viewport.y * 0.56 + 26.0)
	_status.size = Vector2(380.0, 52.0)
	_research_button.position = Vector2(viewport.x * 0.5 - 110.0, viewport.y * 0.56 + 78.0)
	_marker.kind = str(_nearest.get("kind", "Обломки"))
	var holding: bool = _button_held or Input.is_key_pressed(KEY_R)
	if holding:
		_progress = minf(1.0, _progress + delta / RESEARCH_TIME)
	else:
		_progress = maxf(0.0, _progress - delta * 1.8)
	_marker.progress = _progress
	_marker.active = holding
	_marker.queue_redraw()
	_status.text = "%s\n%s" % [str(_nearest.get("kind", "Обломки")), "Удерживайте R или кнопку, чтобы исследовать" if not holding else "Исследование: %d%%" % roundi(_progress * 100.0)]
	if _progress >= 1.0:
		_claim_nearest()

func _rebuild_debris() -> void:
	_debris.clear()
	var world: Dictionary = _main.get("_world_data") if _main != null else {}
	var world_size := Vector2(world.get("world_size", Vector2i(4096, 4096)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:drift-foundations:v1" % int(GameState.world_state.get("seed", 0)))
	var islands: Array = world.get("islands", [])
	var ports: Dictionary = world.get("ports", {})
	for index in range(22):
		var position := Vector2.ZERO
		var valid := false
		for attempt in range(40):
			position = Vector2(rng.randf_range(180.0, maxf(181.0, world_size.x - 180.0)), rng.randf_range(180.0, maxf(181.0, world_size.y - 180.0)))
			valid = true
			for raw_island in islands:
				var island: Dictionary = raw_island
				if position.distance_to(Vector2(island.get("position", Vector2.ZERO))) < float(island.get("radius", 0)) + 150.0:
					valid = false
					break
			if not valid:
				continue
			for raw_port_id in ports:
				var port: Dictionary = ports[raw_port_id]
				if position.distance_to(Vector2(port.get("position", Vector2.ZERO))) < 180.0:
					valid = false
					break
			if valid:
				break
		if not valid:
			continue
		var kinds: Array[String] = ["Ящик", "Бочка", "Обломки"]
		_debris.append({"id": "drift_%03d" % index, "position": position, "kind": kinds[rng.randi_range(0, kinds.size() - 1)]})
	var home_id := str(GameState.world_state.get("home_port_id", ""))
	var home: Dictionary = ports.get(home_id, {})
	if not home.is_empty():
		var home_position := Vector2(home.get("position", Vector2.ZERO))
		_debris.append({"id": "drift_home_00", "position": home_position + Vector2(260.0, 0.0), "kind": "Ящик"})

func _find_nearest(ship_position: Vector2) -> Dictionary:
	var collected: Array = GameState.world_state.get("collected_debris_ids", [])
	var nearest: Dictionary = {}
	var distance := INTERACTION_RADIUS
	for raw_entry in _debris:
		var entry: Dictionary = raw_entry
		if collected.has(str(entry.get("id", ""))):
			continue
		var current_distance: float = ship_position.distance_to(Vector2(entry.get("position", Vector2.ZERO)))
		if current_distance <= distance:
			distance = current_distance
			nearest = entry
	return nearest

func _claim_nearest() -> void:
	if _nearest.is_empty():
		return
	var collected: Array = GameState.world_state.get("collected_debris_ids", [])
	var debris_id := str(_nearest.get("id", ""))
	if collected.has(debris_id):
		return
	collected.append(debris_id)
	GameState.world_state["collected_debris_ids"] = collected
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(debris_id + ":" + str(GameState.world_state.get("seed", 0)))
	var money: int = rng.randi_range(25, 75)
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + money
	var home_id := str(GameState.world_state.get("home_port_id", ""))
	var home: Dictionary = GameState.port_state.get(home_id, {})
	var inventory: Dictionary = home.get("inventory", {})
	var material_ids: Array[String] = ["resource_timber", "resource_parts", "resource_fish"]
	var material_id: String = material_ids[rng.randi_range(0, material_ids.size() - 1)]
	var material_amount: int = rng.randi_range(2, 7)
	inventory[material_id] = int(inventory.get(material_id, 0)) + material_amount
	home["inventory"] = inventory
	if home_id != "":
		GameState.port_state[home_id] = home
	var scroll_ids: Array = TrainingScrolls.ordered_ids()
	var scroll_id: String = str(scroll_ids[rng.randi_range(0, scroll_ids.size() - 1)]) if not scroll_ids.is_empty() else ""
	TrainingScrolls.grant(scroll_id)
	SaveSystem.save_game()
	var material_names := {"resource_timber": "древесины", "resource_parts": "деталей", "resource_fish": "рыбы"}
	var scroll_name: String = str(TrainingScrolls.definitions().get(scroll_id, {}).get("name", "Свиток обучения"))
	_status.text = "Исследовано: +%d монет, +%d %s, +1 «%s»\nНаграда отправлена на склад базы." % [money, material_amount, material_names.get(material_id, material_id), scroll_name]
	_notice_timer = 3.5
	_progress = 0.0
	_nearest = {}
