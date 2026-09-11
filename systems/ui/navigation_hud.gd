extends CanvasLayer

## Selects a known destination and shows a compact sailing compass.

var _port_system: Node
var _toggle_button: Button
var _panel: PanelContainer
var _destination_list: VBoxContainer
var _course_label: Label
var _is_open: bool = false
var _last_destination_id: String = ""

func _ready() -> void:
	layer = 25
	_toggle_button = Button.new()
	_toggle_button.text = "НАВИГАЦИЯ [N]"
	_toggle_button.custom_minimum_size = Vector2(210, 42)
	_toggle_button.add_theme_font_size_override("font_size", 17)
	_toggle_button.pressed.connect(_toggle_panel)
	add_child(_toggle_button)
	_course_label = Label.new()
	_course_label.add_theme_font_size_override("font_size", 18)
	_course_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.75, 1.0))
	add_child(_course_label)
	_panel = PanelContainer.new()
	_panel.size = Vector2(390, 430)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.75, 0.75, 0.3, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "НАВИГАЦИЯ"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Выберите посещённый порт."
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 290
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_destination_list = VBoxContainer.new()
	_destination_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_destination_list)
	_panel.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_toggle_button.position = Vector2(12.0, 205.0)
	_course_label.position = Vector2(12.0, 255.0)
	_panel.position = Vector2(12.0, 305.0)
	_panel.visible = _is_open
	var destination_id: String = str(GameState.world_state.get("destination_port_id", ""))
	if destination_id != _last_destination_id:
		_last_destination_id = destination_id
		_rebuild_destinations()
	_update_course(destination_id)

func _toggle_panel() -> void:
	_is_open = not _is_open
	if _is_open:
		_rebuild_destinations()

func _rebuild_destinations() -> void:
	if _destination_list == null:
		return
	for child in _destination_list.get_children():
		child.queue_free()
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id != "":
		_add_destination_button(home_port_id, "★ База: ")
	for port_id in GameState.player_state.get("discovered_port_ids", []):
		var id: String = str(port_id)
		if id != "" and id != home_port_id:
			_add_destination_button(id, "")

func _add_destination_button(port_id: String, prefix: String) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size.y = 42
	button.text = prefix + _port_system.get_port_name(port_id)
	button.pressed.connect(_select_destination.bind(port_id))
	_destination_list.add_child(button)

func _select_destination(port_id: String) -> void:
	GameState.world_state["destination_port_id"] = port_id
	EventBus.navigation_destination_set.emit(port_id)
	_is_open = false
	SaveSystem.save_game()

func _update_course(destination_id: String) -> void:
	if destination_id == "" or _port_system == null:
		_course_label.text = "Курс не выбран"
		return
	var target: Vector2 = _port_system.get_port_position(destination_id)
	var ship_position: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	var direction: Vector2 = target - ship_position
	var distance: int = int(direction.length())
	var angle: float = direction.angle()
	var arrows: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var index: int = posmod(int(round(angle / (PI / 4.0))), 8)
	_course_label.text = "КУРС %s  %s\nРасстояние: %d" % [
		arrows[index],
		_port_system.get_port_name(destination_id),
		distance
	]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_N or event.physical_keycode == KEY_N:
		_toggle_panel()
		get_viewport().set_input_as_handled()
