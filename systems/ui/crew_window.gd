extends CanvasLayer

## Active crew table for the currently controlled ship.

var _button: Button
var _panel: PanelContainer
var _summary: Label
var _list: VBoxContainer
var _is_open: bool = false
var _stat_labels: Dictionary = {}
var _requirements: Dictionary = {}

func _ready() -> void:
	layer = 30
	_button = Button.new()
	_button.text = "ЭКИПАЖ [C]"
	_button.custom_minimum_size = Vector2(180, 40)
	_button.add_theme_font_size_override("font_size", 17)
	_button.pressed.connect(_toggle)
	add_child(_button)
	_panel = PanelContainer.new()
	_panel.size = Vector2(760, 700)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.22, 0.65, 0.85, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "АКТИВНЫЙ ЭКИПАЖ"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 19)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 430
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	var hiring: Dictionary = SaveSystem._read_json("res://data/employees/hiring_rules.json")
	_stat_labels = hiring.get("stat_labels", {})
	var crew_config: Dictionary = SaveSystem._read_json("res://data/ships/crew_requirements.json")
	_requirements = crew_config.get("requirements", {})
	_panel.hide()

func _process(_delta: float) -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_button.position = Vector2((viewport.x - _button.size.x) * 0.5, 395.0)
	_panel.position = (viewport - _panel.size) * 0.5
	_panel.visible = _is_open
	if _is_open:
		_refresh()

func _toggle() -> void:
	_is_open = not _is_open

func _close() -> void:
	_is_open = false

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	var crew_ids: Array = raw_crew if raw_crew is Array else []
	var ship_id: String = str(GameState.ship_state.get("ship_id", "default"))
	var limits: Dictionary = _requirements.get(ship_id, _requirements.get("default", {}))
	var totals: Dictionary = {"speed": 0, "loading": 0, "fuel": 0, "repair": 0, "navigation": 0}
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		if not crew_ids.has(str(employee.get("employee_instance_id", ""))):
			continue
		var stats: Dictionary = employee.get("stats", {})
		for stat_id in totals:
			totals[stat_id] = int(totals[stat_id]) + int(stats.get(stat_id, 0))
		_add_employee_row(employee)
	_summary.text = (
		"Экипаж: %d / %d\n"
		+ "Итоговые бонусы: скорость %+d%% | погрузка %+d%% | топливо %+d%% | ремонт %+d%% | навигация %+d%%"
	) % [
		crew_ids.size(),
		int(limits.get("max_crew", 1)),
		int(totals.get("speed", 0)),
		int(totals.get("loading", 0)),
		int(totals.get("fuel", 0)),
		int(totals.get("repair", 0)),
		int(totals.get("navigation", 0))
	]
	if crew_ids.is_empty():
		var empty: Label = Label.new()
		empty.text = "На корабль ещё никто не назначен."
		empty.add_theme_font_size_override("font_size", 19)
		_list.add_child(empty)

func _add_employee_row(employee: Dictionary) -> void:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.15, 1.0)
	style.border_color = Color(0.18, 0.34, 0.46, 1.0)
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	_list.add_child(card)
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stats: Dictionary = employee.get("stats", {})
	label.text = (
		"%s — %s %d ранга\n"
		+ "Контракт: осталось рейсов %d / %d\n"
		+ "Скорость %+d%% | Погрузка %+d%% | Топливо %+d%%\n"
		+ "Ремонт %+d%% | Навигация %+d%%"
	) % [
		str(employee.get("name", "")),
		str(employee.get("role_name", "")),
		int(employee.get("rank", 1)),
		int(employee.get("contract_voyages_remaining", 0)),
		int(employee.get("contract_voyages_total", 0)),
		int(stats.get("speed", 0)),
		int(stats.get("loading", 0)),
		int(stats.get("fuel", 0)),
		int(stats.get("repair", 0)),
		int(stats.get("navigation", 0))
	]
	card.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_C or event.physical_keycode == KEY_C:
		_toggle()
		get_viewport().set_input_as_handled()
