extends CanvasLayer

## Sea-faring staff market with faction-specific officer portraits.

var _system: Node
var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer
var _details: Label
var _voyage_label: Label
var _voyage_slider: HSlider
var _hire_button: Button
var _refresh_button: Button
var _close_button: Button
var _selected_candidate_id: String = ""
var _selected_voyages: int = 1
var _selected_ship_id: String = "active_ship"
var _notice: String = ""

const CREW_ATLAS := "res://assets/characters/crew/crew_portrait_atlas.png"
const RACE_ROWS := {"humans": 0, "nerids": 1, "surr": 2, "meridians": 3, "aery": 4, "crystari": 5}
var _is_open: bool = false
var _stat_labels: Dictionary = {}
var _portrait: TextureRect
var _ship_selector: OptionButton
var _portrait_atlas: Texture2D

func _ready() -> void:
	add_to_group("hiring_window")
	layer = 55
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.size = Vector2(1000, 820)
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
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 18)
	margin.add_child(content_row)
	var candidates_column := VBoxContainer.new()
	candidates_column.custom_minimum_size.x = 390
	candidates_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidates_column.size_flags_stretch_ratio = 0.9
	candidates_column.add_theme_constant_override("separation", 8)
	content_row.add_child(candidates_column)
	var title: Label = Label.new()
	title.text = "КАНДИДАТЫ · БИРЖА ПЕРСОНАЛА"
	title.add_theme_font_size_override("font_size", 17)
	candidates_column.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	candidates_column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_refresh_button = Button.new()
	_refresh_button.text = "Обновить кандидатов"
	_refresh_button.custom_minimum_size.y = 34
	_refresh_button.add_theme_font_size_override("font_size", 14)
	_refresh_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_refresh_button.pressed.connect(_refresh_candidates)
	candidates_column.add_child(_refresh_button)
	var profile_column := VBoxContainer.new()
	profile_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_column.size_flags_stretch_ratio = 1.1
	profile_column.add_theme_constant_override("separation", 8)
	content_row.add_child(profile_column)
	var profile_title := Label.new()
	profile_title.text = "ПРОФИЛЬ СОТРУДНИКА"
	profile_title.add_theme_font_size_override("font_size", 17)
	profile_column.add_child(profile_title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 14)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 12)
	profile_column.add_child(profile_row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(185, 245)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_row.add_child(_portrait)
	profile_row.add_child(_details)
	_ship_selector = OptionButton.new()
	_ship_selector.custom_minimum_size.y = 36
	_ship_selector.add_theme_font_size_override("font_size", 14)
	_ship_selector.item_selected.connect(_on_ship_selected)
	profile_column.add_child(_ship_selector)
	_hire_button = Button.new()
	_hire_button.text = "Нанять и назначить на текущий корабль"
	_hire_button.custom_minimum_size.y = 38
	_hire_button.add_theme_font_size_override("font_size", 14)
	_hire_button.pressed.connect(_hire)
	profile_column.add_child(_hire_button)
	_close_button = Button.new()
	_close_button.text = "Закрыть"
	_close_button.custom_minimum_size.y = 34
	_close_button.add_theme_font_size_override("font_size", 14)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_close_button.pressed.connect(_close)
	profile_column.add_child(_close_button)
	_root.hide()

func initialize(system: Node) -> void:
	_system = system
	_stat_labels = system.get_stat_labels()
	_portrait_atlas = load(CREW_ATLAS) as Texture2D if ResourceLoader.exists(CREW_ATLAS) else null

func open() -> void:
	_is_open = true
	_notice = ""
	_rebuild_ship_options()
	_rebuild_list()

func _rebuild_ship_options() -> void:
	if _ship_selector == null or _system == null:
		return
	_ship_selector.clear()
	var selected_index: int = 0
	for option in _system.get_ship_options():
		var id: String = str(option.get("id", "active_ship"))
		_ship_selector.add_item("%s · экипаж %d/%d" % [str(option.get("name", "Корабль")), int(option.get("crew_count", 0)), int(option.get("max_crew", 1))])
		_ship_selector.set_item_metadata(_ship_selector.item_count - 1, id)
		if id == _selected_ship_id:
			selected_index = _ship_selector.item_count - 1
	if _ship_selector.item_count > 0:
		_ship_selector.select(selected_index)
		_selected_ship_id = str(_ship_selector.get_item_metadata(selected_index))

func _on_ship_selected(index: int) -> void:
	_selected_ship_id = str(_ship_selector.get_item_metadata(index))
	_notice = ""
	_refresh_details()

func _process(_delta: float) -> void:
	_root.visible = _is_open
	if not _is_open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1000.0, viewport.x - 24.0), minf(820.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_refresh_details()

func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var candidates: Array = _system.get_candidates()
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_list.add_child(row)
		var portrait := TextureRect.new()
		portrait.texture = _get_candidate_portrait(candidate)
		portrait.custom_minimum_size = Vector2(62, 76)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		row.add_child(portrait)
		var button: Button = Button.new()
		button.custom_minimum_size.y = 76
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s · %s · %d р." % [
			str(candidate.get("name", "")),
			str(candidate.get("race_name", "")),
			str(candidate.get("role_name", "")),
			int(candidate.get("rank", 1))
		]
		button.toggle_mode = true
		button.button_pressed = str(candidate.get("candidate_id", "")) == _selected_candidate_id
		button.pressed.connect(_select_candidate.bind(str(candidate.get("candidate_id", ""))))
		row.add_child(button)
	if _selected_candidate_id == "" and not candidates.is_empty():
		var first: Dictionary = candidates[0]
		_selected_candidate_id = str(first.get("candidate_id", ""))

func _select_candidate(candidate_id: String) -> void:
	_selected_candidate_id = candidate_id
	_notice = ""
	_rebuild_list()
	_refresh_details()

func _refresh_details() -> void:
	var candidate: Dictionary = _get_selected_candidate()
	var ship: Dictionary = {}
	for option in _system.get_ship_options():
		if str(option.get("id", "")) == _selected_ship_id:
			ship = option
			break
	if candidate.is_empty():
		_portrait.texture = null
		_details.text = "Кандидатов пока нет."
		_hire_button.disabled = true
		return
	var stats: Dictionary = candidate.get("stats", {})
	_portrait.texture = _get_candidate_portrait(candidate)
	var lines: Array[String] = [
		"%s · %s · %s · ранг %d" % [str(candidate.get("name", "")), str(candidate.get("race_name", "")), str(candidate.get("role_name", "")), int(candidate.get("rank", 1))],
		"Сильная сторона: %s · изъян: %s" % [str(candidate.get("strength_trait", "")), str(candidate.get("flaw_trait", ""))],
		"Навыки медленно растут в рейсах; штат получает зарплату.",
	]
	var stat_parts: Array[String] = []
	for stat_id in ["speed", "loading", "fuel", "repair", "navigation"]:
		stat_parts.append("%s %+d%%" % [str(_stat_labels.get(stat_id, stat_id)), int(stats.get(stat_id, 0))])
	lines.append("Навыки: " + " · ".join(stat_parts))
	var salary: float = float(candidate.get("hire_price", 0.0))
	lines.append("Ваш допуск: сотрудник до %d ранга" % _system.get_hiring_rank_limit())
	lines.append("Корабль: %s | ячейки экипажа %d / %d (минимум для рейса: %d)" % [str(ship.get("name", "")), int(ship.get("crew_count", 0)), int(ship.get("max_crew", 1)), int(ship.get("min_crew", 1))])
	lines.append("Владение: %d%% | найм: %.0f | зарплата: %.0f за переход" % [int(candidate.get("mastery_percent", 0)), salary, float(candidate.get("salary_per_voyage", 0.0))])
	var ship_available: bool = not ship.is_empty() and (str(ship.get("id", "")) == "active_ship" or (Dictionary(ship.get("autopilot", {})).is_empty() and str(ship.get("current_port_id", "")) == str(GameState.ship_state.get("docked_port_id", ""))))
	if not ship_available:
		_notice = "Для посадки сотрудника корабль должен находиться в этом порту и стоять у причала."
	lines.append(_notice)
	_details.text = "\n".join(lines)
	if _voyage_label != null:
		_voyage_label.hide()
	if _voyage_slider != null:
		_voyage_slider.hide()
	_hire_button.text = "Нанять в выбранный корабль"
	_hire_button.disabled = int(candidate.get("rank", 1)) > _system.get_hiring_rank_limit() or int(ship.get("crew_count", 0)) >= int(ship.get("max_crew", 1)) or float(GameState.player_state.get("money", 0.0)) < salary or not ship_available

func _get_candidate_portrait(candidate: Dictionary) -> Texture2D:
	if _portrait_atlas == null:
		return null
	var race_id: String = str(candidate.get("race_id", "humans"))
	var column: int = posmod(int(candidate.get("portrait_id", 0)), 3)
	var row: int = int(RACE_ROWS.get(race_id, 0))
	var cell_width: float = float(_portrait_atlas.get_width()) / 3.0
	var cell_height: float = float(_portrait_atlas.get_height()) / 6.0
	var atlas := AtlasTexture.new()
	atlas.atlas = _portrait_atlas
	atlas.region = Rect2(column * cell_width + 2.0, row * cell_height + 2.0, cell_width - 4.0, cell_height - 4.0)
	return atlas

func _get_selected_candidate() -> Dictionary:
	for raw_candidate in _system.get_candidates():
		var candidate: Dictionary = raw_candidate
		if str(candidate.get("candidate_id", "")) == _selected_candidate_id:
			return candidate
	return {}

func _on_voyages_changed(value: float) -> void:
	_selected_voyages = int(round(value))

func _hire() -> void:
	var result: Dictionary = _system.hire(_selected_candidate_id, _selected_voyages, _selected_ship_id)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_selected_candidate_id = ""
		_rebuild_ship_options()
		_rebuild_list()

func _refresh_candidates() -> void:
	var result: Dictionary = _system.refresh_candidates()
	_notice = str(result.get("message", ""))
	_selected_candidate_id = ""
	_rebuild_list()

func _close() -> void:
	_is_open = false
