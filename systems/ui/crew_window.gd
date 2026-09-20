extends CanvasLayer

## World-of-Tanks-style schematic crew slots for the currently controlled ship.

var _system: Node
var _button: Button
var _panel: PanelContainer
var _summary: Label
var _list: VBoxContainer
var _notice: Label
var _is_open: bool = false
var _refresh_timer: float = 0.0
var _stat_labels: Dictionary = {}
var _requirements: Dictionary = {}
var _skill_catalog: Dictionary = {}

func _ready() -> void:
	layer = 30
	_button = Button.new()
	_button.text = "ЭКИПАЖ [C]"
	_button.custom_minimum_size = Vector2(180, 40)
	_button.add_theme_font_size_override("font_size", 17)
	_button.pressed.connect(_toggle)
	add_child(_button)
	_panel = PanelContainer.new()
	_panel.size = Vector2(820, 780)
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
	title.text = "ЭКИПАЖ ТЕКУЩЕГО КОРАБЛЯ"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 19)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", 18)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_notice)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 470
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_panel.hide()

func initialize(system: Node) -> void:
	_system = system
	_stat_labels = system.get_stat_labels()
	_skill_catalog = system.get_skill_catalog()
	_requirements = GameData.get_crew_requirements()

func _process(delta: float) -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_button.position = Vector2((viewport.x - _button.size.x) * 0.5, 395.0)
	_panel.position = (viewport - _panel.size) * 0.5
	_panel.visible = _is_open
	if not _is_open:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.5:
		_refresh_timer = 0.0
		_refresh()

func _toggle() -> void:
	_is_open = not _is_open
	if _is_open:
		_refresh()

func _close() -> void:
	_is_open = false

func _refresh() -> void:
	if _system == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	var crew_ids: Array = raw_crew if raw_crew is Array else []
	var ship_id: String = str(GameState.ship_state.get("ship_id", "default"))
	var limits: Dictionary = _requirements.get(ship_id, _requirements.get("default", {}))
	var totals: Dictionary = {"speed": 0, "loading": 0, "fuel": 0, "repair": 0, "navigation": 0}
	_add_player_captain_card()
	var assigned_count: int = 0
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		if not crew_ids.has(str(employee.get("employee_instance_id", ""))):
			continue
		assigned_count += 1
		var stats: Dictionary = _system.get_effective_stats(employee)
		for stat_id in totals:
			totals[stat_id] = int(totals[stat_id]) + int(stats.get(stat_id, 0))
		_add_employee_card(employee, stats)
	var maximum_crew: int = int(limits.get("max_crew", 1))
	for slot_index in range(assigned_count, maximum_crew):
		_add_empty_slot(slot_index + 1)
	_summary.text = (
		"Назначено: %d / %d • постоянные сотрудники развиваются в рейсах\n"
		+ "Итог: скорость %+d%% | погрузка %+d%% | топливо %+d%% | ремонт %+d%% | навигация %+d%%"
	) % [
		assigned_count,
		maximum_crew,
		int(totals.get("speed", 0)),
		int(totals.get("loading", 0)),
		int(totals.get("fuel", 0)),
		int(totals.get("repair", 0)),
		int(totals.get("navigation", 0))
	]

func _add_player_captain_card() -> void:
	var card: PanelContainer = _make_card(Color(0.08, 0.16, 0.20, 1.0), Color(0.32, 0.76, 0.94, 1.0))
	var label: Label = Label.new()
	label.text = "⚓ КОМАНДИРСКИЙ СЛОТ — ВЫ\nЛичная морская карьера развивается отдельно от наёмного экипажа."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 19)
	card.add_child(label)

func _add_empty_slot(slot_number: int) -> void:
	var card: PanelContainer = _make_card(Color(0.06, 0.07, 0.08, 1.0), Color(0.24, 0.27, 0.30, 1.0))
	var label: Label = Label.new()
	label.text = "СЛОТ %d — свободен\nНаймите сотрудника в любом порту." % slot_number
	label.add_theme_font_size_override("font_size", 18)
	card.add_child(label)

func _add_employee_card(employee: Dictionary, stats: Dictionary) -> void:
	var permanent: bool = str(employee.get("employment_type", "contract")) == "permanent"
	var border: Color = Color(0.78, 0.62, 0.24, 1.0) if permanent else Color(0.18, 0.42, 0.56, 1.0)
	var card: PanelContainer = _make_card(Color(0.08, 0.11, 0.15, 1.0), border)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)
	var employment_name: String = "ПОСТОЯННЫЙ" if permanent else "КОНТРАКТНЫЙ"
	var header: Label = Label.new()
	header.text = "ПОРТРЕТ %d  •  %s\n%s — %s %d ранга" % [
		int(employee.get("portrait_id", 0)) + 1,
		employment_name,
		str(employee.get("name", "")),
		str(employee.get("role_name", "")),
		int(employee.get("rank", 1))
	]
	header.add_theme_font_size_override("font_size", 20)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(header)
	if permanent:
		_add_permanent_progress(box, employee)
	else:
		var contract: Label = Label.new()
		contract.text = "Осталось рейсов: %d / %d • параметры фиксированы • опыт не начисляется" % [
			int(employee.get("contract_voyages_remaining", 0)),
			int(employee.get("contract_voyages_total", 0))
		]
		contract.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(contract)
	var stat_text: Label = Label.new()
	stat_text.text = (
		"Скорость %+d%% | Погрузка %+d%% | Топливо %+d%%\n"
		+ "Ремонт %+d%% | Навигация %+d%%"
	) % [
		int(stats.get("speed", 0)), int(stats.get("loading", 0)), int(stats.get("fuel", 0)),
		int(stats.get("repair", 0)), int(stats.get("navigation", 0))
	]
	stat_text.add_theme_font_size_override("font_size", 18)
	box.add_child(stat_text)
	var dismiss_button: Button = Button.new()
	dismiss_button.text = "Уволить"
	dismiss_button.custom_minimum_size.y = 36
	dismiss_button.pressed.connect(_dismiss_employee.bind(str(employee.get("employee_instance_id", ""))))
	box.add_child(dismiss_button)

func _add_permanent_progress(box: VBoxContainer, employee: Dictionary) -> void:
	var mastery: int = int(employee.get("mastery_percent", 0))
	var mastery_label: Label = Label.new()
	mastery_label.text = "Владение профессией: %d%% • пройдено рейсов: %d" % [mastery, int(employee.get("experience", 0))]
	box.add_child(mastery_label)
	var mastery_bar: ProgressBar = ProgressBar.new()
	mastery_bar.max_value = 100
	mastery_bar.value = mastery
	mastery_bar.custom_minimum_size.y = 24
	box.add_child(mastery_bar)
	var skills: Array = employee.get("skills", [])
	if skills.is_empty():
		var empty_skills: Label = Label.new()
		empty_skills.text = "Навыки: ещё не выбраны. Первый выбор откроется при 100% профессии."
		empty_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(empty_skills)
	else:
		for entry in skills:
			var skill_id: String = str(entry.get("id", ""))
			var definition: Dictionary = _skill_catalog.get(skill_id, {})
			var progress: int = int(entry.get("progress", 0))
			var skill_label: Label = Label.new()
			skill_label.text = "%s: %d%% • %s" % [str(definition.get("name", skill_id)), progress, str(definition.get("description", ""))]
			box.add_child(skill_label)
			var skill_bar: ProgressBar = ProgressBar.new()
			skill_bar.max_value = 100
			skill_bar.value = progress
			skill_bar.custom_minimum_size.y = 22
			box.add_child(skill_bar)
	var can_choose: bool = mastery >= 100 and str(employee.get("active_skill_id", "")) == "" and skills.size() < int(_system.get_maximum_skill_slots(employee))
	if can_choose:
		var prompt: Label = Label.new()
		prompt.text = "Выберите следующий навык:"
		box.add_child(prompt)
		for skill_id in _skill_catalog:
			if _has_skill(skills, str(skill_id)):
				continue
			var definition: Dictionary = _skill_catalog[skill_id]
			var button: Button = Button.new()
			button.text = "%s — %s" % [str(definition.get("name", skill_id)), str(definition.get("description", ""))]
			button.pressed.connect(_choose_skill.bind(str(employee.get("employee_instance_id", "")), str(skill_id)))
			box.add_child(button)

func _make_card(background: Color, border: Color) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	_list.add_child(card)
	return card

func _has_skill(skills: Array, skill_id: String) -> bool:
	for entry in skills:
		if str(entry.get("id", "")) == skill_id:
			return true
	return false

func _dismiss_employee(employee_id: String) -> void:
	var result: Dictionary = _system.dismiss(employee_id)
	_notice.text = str(result.get("message", ""))
	_refresh()

func _choose_skill(employee_id: String, skill_id: String) -> void:
	var result: Dictionary = _system.choose_skill(employee_id, skill_id)
	_notice.text = str(result.get("message", ""))
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_C or event.physical_keycode == KEY_C:
		_toggle()
		get_viewport().set_input_as_handled()
