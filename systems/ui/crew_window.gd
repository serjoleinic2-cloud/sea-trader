extends CanvasLayer

## World-of-Tanks-style schematic crew slots for the currently controlled ship.

var _system: Node
var _button: Button
var _panel: PanelContainer
var _summary: Label
var _list: VBoxContainer
var _scroll_list: VBoxContainer
var _notice: Label
var _is_open: bool = false
var _refresh_timer: float = 0.0
var _stat_labels: Dictionary = {}
var _requirements: Dictionary = {}
var _skill_catalog: Dictionary = {}
var _captain_portrait: TextureRect
var _crew_portrait_atlas: Texture2D
const CREW_ATLAS := "res://assets/characters/crew/crew_portrait_atlas.png"
const CharacterArtCatalog = preload("res://systems/characters/character_art_catalog.gd")

func _ready() -> void:
	layer = 30
	_button = Button.new()
	_button.text = "ЭКИПАЖ [C]"
	_button.custom_minimum_size = Vector2(180, 40)
	_button.add_theme_font_size_override("font_size", 17)
	_button.pressed.connect(_toggle)
	add_child(_button)
	_panel = PanelContainer.new()
	_panel.size = Vector2(1120, 680)
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
	_captain_portrait = TextureRect.new()
	_captain_portrait.custom_minimum_size = Vector2(0, 90)
	_captain_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_captain_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_captain_portrait)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 19)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", 18)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_notice)
	var content := HBoxContainer.new()
	content.custom_minimum_size.y = 390
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	box.add_child(content)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 620
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var scroll_panel := PanelContainer.new()
	scroll_panel.custom_minimum_size.x = 300
	var scroll_style := StyleBoxFlat.new()
	scroll_style.bg_color = Color(0.035, 0.055, 0.075, 0.98)
	scroll_style.border_color = Color(0.64, 0.48, 0.20, 1.0)
	scroll_style.set_border_width_all(2)
	scroll_style.set_content_margin_all(10)
	scroll_panel.add_theme_stylebox_override("panel", scroll_style)
	content.add_child(scroll_panel)
	_scroll_list = VBoxContainer.new()
	_scroll_list.add_theme_constant_override("separation", 7)
	scroll_panel.add_child(_scroll_list)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	preload("res://systems/ui/brass_close_button.gd").apply(close_button)
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_panel.hide()

func initialize(system: Node) -> void:
	_system = system
	_stat_labels = system.get_stat_labels()
	_skill_catalog = system.get_skill_catalog()
	_requirements = GameData.get_crew_requirements()
	_crew_portrait_atlas = load(CREW_ATLAS) as Texture2D if ResourceLoader.exists(CREW_ATLAS) else null

func _process(delta: float) -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1120.0, viewport.x - 32.0), minf(680.0, viewport.y - 32.0))
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
	_refresh_scroll_sidebar()
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	_captain_portrait.texture = GameData.get_faction_portrait(str(GameState.player_state.get("origin_race_id", "humans")))
	var crew_ids: Array = raw_crew if raw_crew is Array else []
	var docked_in_port: bool = str(GameState.ship_state.get("docked_port_id", "")) != ""
	var scroll_count: int = _system.get_training_scroll_total()
	var ship_id: String = str(GameState.ship_state.get("ship_id", "default"))
	var limits: Dictionary = _requirements.get(ship_id, _requirements.get("default", {}))
	var totals: Dictionary = {"speed": 0, "loading": 0, "fuel": 0, "repair": 0, "navigation": 0}
	_add_player_captain_card()
	var assigned_count: int = 0
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		var is_assigned: bool = crew_ids.has(str(employee.get("employee_instance_id", "")))
		if not is_assigned and not docked_in_port:
			continue
		var stats: Dictionary = _system.get_effective_stats(employee)
		if is_assigned:
			assigned_count += 1
			for stat_id in totals:
				totals[stat_id] = int(totals[stat_id]) + int(stats.get(stat_id, 0))
		_add_employee_card(employee, stats, assigned_count, is_assigned, docked_in_port)
	var maximum_crew: int = int(limits.get("max_crew", 1))
	for slot_index in range(assigned_count, maximum_crew):
		_add_empty_slot(slot_index + 1)
	_summary.text = (
		"Занятые ячейки: %d / %d • штатные сотрудники остаются, пока вы их не замените или не уволите%s\n"
		+ "Итог: скорость %+d%% | погрузка %+d%% | топливо %+d%% | ремонт %+d%% | навигация %+d%%"
	) % [
		assigned_count,
		maximum_crew,
		(" • свитки обучения: %d — выберите навык сотрудника ниже" % scroll_count) if docked_in_port else "",
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

func _add_employee_card(employee: Dictionary, stats: Dictionary, slot_number: int, is_assigned: bool, docked_in_port: bool) -> void:
	var permanent: bool = str(employee.get("employment_type", "contract")) == "permanent"
	var border: Color = Color(0.78, 0.62, 0.24, 1.0) if permanent else Color(0.18, 0.42, 0.56, 1.0)
	var card: PanelContainer = _make_card(Color(0.08, 0.11, 0.15, 1.0), border)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)
	var profile := HBoxContainer.new()
	profile.add_theme_constant_override("separation", 12)
	box.add_child(profile)
	var portrait := TextureRect.new()
	portrait.texture = _get_employee_portrait(employee)
	portrait.custom_minimum_size = Vector2(112, 132)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	profile.add_child(portrait)
	var profile_text := VBoxContainer.new()
	profile_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile.add_child(profile_text)
	var header: Label = Label.new()
	var slot_label: String = "СЛОТ %d" % slot_number if is_assigned else "РЕЗЕРВ • ОБУЧЕНИЕ В ПОРТУ"
	header.text = "%s  •  %s\n%s — %s, ранг %d" % [
		slot_label,
		str(employee.get("race_name", "Экипаж")),
		str(employee.get("name", "")),
		str(employee.get("role_name", "")),
		int(employee.get("rank", 1))
	]
	header.add_theme_font_size_override("font_size", 20)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_text.add_child(header)
	var salary: Label = Label.new()
	salary.text = "Штатный член экипажа · %s за рейс" % str(round(float(employee.get("salary_per_voyage", 0.0))))
	salary.add_theme_font_size_override("font_size", 15)
	salary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_text.add_child(salary)
	if permanent:
		_add_permanent_progress(box, employee, docked_in_port)
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
	if is_assigned:
		var dismiss_button: Button = Button.new()
		dismiss_button.text = "Уволить"
		dismiss_button.custom_minimum_size.y = 36
		dismiss_button.pressed.connect(_dismiss_employee.bind(str(employee.get("employee_instance_id", ""))))
		box.add_child(dismiss_button)

func _get_employee_portrait(employee: Dictionary) -> Texture2D:
	var race_id: String = str(employee.get("race_id", "humans"))
	var role_id: String = str(employee.get("role_id", ""))
	if role_id.is_empty():
		role_id = str(employee.get("role_name", "")).to_lower()
	return CharacterArtCatalog.ship_officer_portrait(race_id, role_id, int(employee.get("portrait_id", 0)), _crew_portrait_atlas)

func _add_permanent_progress(box: VBoxContainer, employee: Dictionary, docked_in_port: bool) -> void:
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
	var living: bool = _system.is_living_employee(employee)
	if not living:
		var unavailable := Label.new()
		unavailable.text = "Обучение недоступно: персонаж погиб или недееспособен."
		unavailable.add_theme_color_override("font_color", Color("e66d68"))
		box.add_child(unavailable)
	var active_skill_id: String = str(employee.get("active_skill_id", ""))
	if active_skill_id != "":
		var active_skill: Dictionary = _skill_catalog.get(active_skill_id, {})
		var action_stat: String = str(active_skill.get("stat", ""))
		var action_label: String = str(_stat_labels.get(action_stat, action_stat))
		var action_hint: Label = Label.new()
		action_hint.text = "Навык развивается медленно от действия «%s». Нужны сотни профильных действий для полного бонуса." % action_label
		action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_hint.add_theme_font_size_override("font_size", 15)
		box.add_child(action_hint)
	if skills.is_empty():
		var empty_skills: Label = Label.new()
		empty_skills.text = "Навыки: ещё не выбраны. Первый выбор откроется при 100% профессии."
		empty_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(empty_skills)
		if docked_in_port and _system.get_training_scroll_total() > 0:
			var scroll_hint := Label.new()
			scroll_hint.text = "Свиток появится для применения после выбора навыка."
			scroll_hint.add_theme_font_size_override("font_size", 14)
			box.add_child(scroll_hint)
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
			if docked_in_port and progress < 100:
				var scroll_type_id: String = _system.get_training_scroll_type_for_skill(skill_id)
				var scroll_catalog: Dictionary = _system.get_training_scroll_catalog()
				var scroll_definition: Dictionary = scroll_catalog.get(scroll_type_id, {})
				var scroll_inventory: Dictionary = _system.get_training_scroll_inventory()
				var available: int = int(scroll_inventory.get(scroll_type_id, 0))
				var scroll_button := Button.new()
				var scroll_points: int = mini(int(scroll_definition.get("progress_points", 2)), 100 - progress)
				var bonus_gain: float = float(definition.get("max_bonus", 0)) * float(scroll_points) / 100.0
				var bonus_text: String = ("%.2f" % bonus_gain).replace(".", ",")
				scroll_button.text = "Применить «%s» · %d шт. • +%d%% навыка (≈ +%s%% к бонусу)" % [str(scroll_definition.get("short_name", "свиток")), available, scroll_points, bonus_text]
				scroll_button.disabled = available <= 0 or not living
				scroll_button.custom_minimum_size.y = 34
				scroll_button.pressed.connect(_use_training_scroll.bind(str(employee.get("employee_instance_id", "")), skill_id, scroll_type_id))
				box.add_child(scroll_button)
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

func _refresh_scroll_sidebar() -> void:
	if _scroll_list == null: return
	for child in _scroll_list.get_children(): child.queue_free()
	var title := Label.new()
	title.text = "СВИТКИ ОБУЧЕНИЯ"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("e5c472"))
	_scroll_list.add_child(title)
	var hint := Label.new()
	hint.text = "Редкие знания для живых персонажей. Каждый свиток подходит только своему навыку."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	_scroll_list.add_child(hint)
	var catalog: Dictionary = _system.get_training_scroll_catalog()
	var inventory: Dictionary = _system.get_training_scroll_inventory()
	for raw_id in _system.get_training_scroll_order():
		var scroll_id: String = str(raw_id)
		var definition: Dictionary = catalog.get(scroll_id, {})
		var card := PanelContainer.new()
		card.set_meta("training_scroll_id", scroll_id)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.065, 0.09, 0.115, 1.0)
		style.border_color = Color(0.42, 0.34, 0.18, 1.0)
		style.set_border_width_all(1)
		style.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", style)
		_scroll_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.set_meta("training_scroll_icon", scroll_id)
		var icon_path: String = str(definition.get("icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path): icon.texture = load(icon_path) as Texture2D
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var name := Label.new()
		name.text = "%s · %d" % [str(definition.get("short_name", scroll_id)), int(inventory.get(scroll_id, 0))]
		name.add_theme_font_size_override("font_size", 14)
		name.add_theme_color_override("font_color", Color("f0d893"))
		copy.add_child(name)
		var description := Label.new()
		description.text = str(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 11)
		copy.add_child(description)

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

func _use_training_scroll(employee_id: String, skill_id: String, scroll_type_id: String) -> void:
	var result: Dictionary = _system.use_training_scroll(employee_id, skill_id, scroll_type_id)
	_notice.text = str(result.get("message", ""))
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_C or event.physical_keycode == KEY_C:
		_toggle()
		get_viewport().set_input_as_handled()
