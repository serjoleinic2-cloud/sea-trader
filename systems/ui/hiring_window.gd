extends CanvasLayer

## Home-port hiring console. Portraits are schematic placeholders until final art.

var _system: Node
var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer
var _details: Label
var _voyage_label: Label
var _voyage_slider: HSlider
var _hire_button: Button
var _close_button: Button
var _selected_candidate_id: String = ""
var _selected_voyages: int = 1
var _notice: String = ""
var _is_open: bool = false
var _stat_labels: Dictionary = {}

func _ready() -> void:
	layer = 55
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.size = Vector2(620, 820)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.35, 0.72, 0.9, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "НАЙМ ПЕРСОНАЛА"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 19)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 360
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_voyage_label = Label.new()
	_voyage_label.add_theme_font_size_override("font_size", 19)
	box.add_child(_voyage_label)
	_voyage_slider = HSlider.new()
	_voyage_slider.min_value = 1
	_voyage_slider.max_value = 12
	_voyage_slider.step = 1
	_voyage_slider.value_changed.connect(_on_voyages_changed)
	box.add_child(_voyage_slider)
	_hire_button = Button.new()
	_hire_button.text = "Нанять и назначить на текущий корабль"
	_hire_button.custom_minimum_size.y = 44
	_hire_button.pressed.connect(_hire)
	box.add_child(_hire_button)
	_close_button = Button.new()
	_close_button.text = "Закрыть"
	_close_button.custom_minimum_size.y = 40
	_close_button.pressed.connect(_close)
	box.add_child(_close_button)
	_root.hide()

func initialize(system: Node) -> void:
	_system = system
	_stat_labels = system.get_stat_labels()

func open() -> void:
	_is_open = true
	_notice = ""
	_rebuild_list()

func _process(_delta: float) -> void:
	_root.visible = _is_open
	if not _is_open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(620.0, viewport.x - 24.0), minf(820.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_refresh_details()

func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var candidates: Array = _system.get_candidates()
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		var button: Button = Button.new()
		button.custom_minimum_size.y = 48
		button.text = "◉ %s — %s %d ранга" % [
			str(candidate.get("name", "")),
			str(candidate.get("role_name", "")),
			int(candidate.get("rank", 1))
		]
		button.pressed.connect(_select_candidate.bind(str(candidate.get("candidate_id", ""))))
		_list.add_child(button)
	if _selected_candidate_id == "" and not candidates.is_empty():
		var first: Dictionary = candidates[0]
		_selected_candidate_id = str(first.get("candidate_id", ""))

func _select_candidate(candidate_id: String) -> void:
	_selected_candidate_id = candidate_id
	_notice = ""

func _refresh_details() -> void:
	var candidate: Dictionary = _get_selected_candidate()
	var ship: Dictionary = _system.get_active_ship_option()
	if candidate.is_empty():
		_details.text = "Кандидатов пока нет."
		_hire_button.disabled = true
		return
	var stats: Dictionary = candidate.get("stats", {})
	var lines: Array[String] = [
		"Портрет №%d  |  %s" % [int(candidate.get("portrait_id", 0)) + 1, str(candidate.get("name", ""))],
		"%s, %d ранг" % [str(candidate.get("role_name", "")), int(candidate.get("rank", 1))],
		""
	]
	for stat_id in ["speed", "loading", "fuel", "repair", "navigation"]:
		var value: int = int(stats.get(stat_id, 0))
		lines.append("%s: %+d%%" % [str(_stat_labels.get(stat_id, stat_id)), value])
	var salary: float = float(candidate.get("salary_per_voyage", 0.0)) * _selected_voyages
	lines.append("")
	lines.append("Корабль: %s | экипаж %d / %d" % [str(ship.get("name", "")), int(ship.get("crew_count", 0)), int(ship.get("max_crew", 1))])
	lines.append("Контракт: %d рейс. | зарплата: %.0f" % [_selected_voyages, salary])
	lines.append(_notice)
	_details.text = "\n".join(lines)
	_hire_button.disabled = int(ship.get("crew_count", 0)) >= int(ship.get("max_crew", 1)) or float(GameState.player_state.get("money", 0.0)) < salary

func _get_selected_candidate() -> Dictionary:
	for raw_candidate in _system.get_candidates():
		var candidate: Dictionary = raw_candidate
		if str(candidate.get("candidate_id", "")) == _selected_candidate_id:
			return candidate
	return {}

func _on_voyages_changed(value: float) -> void:
	_selected_voyages = int(round(value))

func _hire() -> void:
	var result: Dictionary = _system.hire(_selected_candidate_id, _selected_voyages)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_selected_candidate_id = ""
		_rebuild_list()

func _close() -> void:
	_is_open = false
