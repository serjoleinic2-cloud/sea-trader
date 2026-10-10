extends CanvasLayer

## Central hub for ship crew hiring, assignment, and personnel overview.

const CREW_ATLAS := "res://assets/characters/crew/crew_portrait_atlas.png"
const CharacterArtCatalog = preload("res://systems/characters/character_art_catalog.gd")
const ROLE_HELP := {
	"captain": "Капитан судна — отвечает за экипаж и рейсы только назначенного корабля.",
	"bosun": "Боцман — помощник капитана; поддерживает порядок в экипаже этого корабля.",
	"sailor": "Моряк — занимает штатное место экипажа и помогает в рейсе.",
	"navigator": "Лоцман — улучшает навигацию и движение корабля.",
	"mechanic": "Механик — помогает обслуживать и ремонтировать корабль.",
	"quartermaster": "Квартирмейстер — помогает с запасами и перевозками.",
	"dock_worker": "Портовый рабочий — помогает с погрузкой на торговом судне."
}

var _system: Node
var _fleet_system: Node
var _naval_system: Node
var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer
var _details: Label
var _hire_button: Button
var _refresh_button: Button
var _close_button: Button
var _army_button: Button
var _ship_action_button: Button
var _commander_skills: HBoxContainer
var _selected_candidate_id: String = ""
var _selected_employee_id: String = ""
var _selected_ship_id: String = "active_ship"
var _notice: String = ""
var _mode: String = "trade"
var _view: String = "candidates"
var _is_open: bool = false
var _portrait: TextureRect
var _ship_selector: OptionButton
var _naval_commander_portrait: TextureRect
var _portrait_atlas: Texture2D
var _mode_buttons: Dictionary = {}
var _view_buttons: Dictionary = {}
var _employee_actions: VBoxContainer

func _ready() -> void:
	add_to_group("hiring_window")
	layer = 55
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.size = Vector2(1080, 840)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.98)
	style.border_color = Color(0.62, 0.48, 0.25, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	margin.add_child(shell)
	var heading := Label.new()
	heading.text = "ПЕРСОНАЛ КОМПАНИИ"
	heading.add_theme_font_size_override("font_size", 21)
	shell.add_child(heading)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	shell.add_child(mode_row)
	_mode_buttons["trade"] = _make_toggle(mode_row, "ТОРГОВЫЙ ПЕРСОНАЛ", func(): _set_mode("trade"))
	_mode_buttons["military"] = _make_toggle(mode_row, "ВОЕННЫЙ ПЕРСОНАЛ", func(): _set_mode("military"))
	var explanation := Label.new()
	explanation.name = "RoleGuide"
	explanation.text = "«Капитан» в меню — это вы. Нанятый капитан и боцман служат на одном корабле. Командир и заместитель в казармах усиливают всю армию."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 13)
	explanation.add_theme_color_override("font_color", Color("c8d6d4"))
	shell.add_child(explanation)
	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 8)
	shell.add_child(view_row)
	_view_buttons["candidates"] = _make_toggle(view_row, "КАНДИДАТЫ", func(): _set_view("candidates"))
	_view_buttons["roster"] = _make_toggle(view_row, "МОЙ ПЕРСОНАЛ", func(): _set_view("roster"))
	_army_button = Button.new()
	_army_button.text = "КАЗАРМЫ · КОМАНДИР И ЗАМЕСТИТЕЛЬ АРМИИ"
	_army_button.custom_minimum_size.y = 34
	_army_button.pressed.connect(_open_garrison)
	view_row.add_child(_army_button)
	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 16)
	shell.add_child(content_row)
	var candidates_column := VBoxContainer.new()
	candidates_column.custom_minimum_size.x = 420
	candidates_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidates_column.size_flags_stretch_ratio = 0.95
	candidates_column.add_theme_constant_override("separation", 7)
	content_row.add_child(candidates_column)
	var list_title := Label.new()
	list_title.text = "СПИСОК"
	list_title.add_theme_font_size_override("font_size", 16)
	candidates_column.add_child(list_title)
	var scroll := ScrollContainer.new()
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
	_refresh_button.pressed.connect(_refresh_candidates)
	candidates_column.add_child(_refresh_button)
	var profile_column := VBoxContainer.new()
	profile_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_column.size_flags_stretch_ratio = 1.05
	profile_column.add_theme_constant_override("separation", 9)
	content_row.add_child(profile_column)
	var profile_title := Label.new()
	profile_title.text = "РОЛЬ И НАЗНАЧЕНИЕ"
	profile_title.add_theme_font_size_override("font_size", 16)
	profile_column.add_child(profile_title)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 12)
	profile_column.add_child(profile_row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(185, 240)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_row.add_child(_portrait)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 14)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_child(_details)
	_employee_actions = VBoxContainer.new()
	_employee_actions.add_theme_constant_override("separation", 5)
	profile_column.add_child(_employee_actions)
	_ship_selector = OptionButton.new()
	_ship_selector.custom_minimum_size.y = 36
	_ship_selector.item_selected.connect(_on_ship_selected)
	profile_column.add_child(_ship_selector)
	_naval_commander_portrait = TextureRect.new()
	_naval_commander_portrait.custom_minimum_size = Vector2(116, 144)
	_naval_commander_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_naval_commander_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_naval_commander_portrait.hide()
	profile_column.add_child(_naval_commander_portrait)
	_ship_action_button = Button.new()
	_ship_action_button.text = "КОМАНДИР ВЫБРАННОГО ВОЕННОГО КОРАБЛЯ"
	_ship_action_button.custom_minimum_size.y = 36
	_ship_action_button.pressed.connect(_manage_ship_commander)
	profile_column.add_child(_ship_action_button)
	_commander_skills = HBoxContainer.new()
	_commander_skills.add_theme_constant_override("separation", 6)
	profile_column.add_child(_commander_skills)
	_hire_button = Button.new()
	_hire_button.text = "НАНЯТЬ И ПОСАДИТЬ НА КОРАБЛЬ"
	_hire_button.custom_minimum_size.y = 42
	_hire_button.pressed.connect(_hire)
	profile_column.add_child(_hire_button)
	_close_button = Button.new()
	_close_button.text = "ЗАКРЫТЬ"
	preload("res://systems/ui/brass_close_button.gd").apply(_close_button)
	_close_button.custom_minimum_size.y = 34
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_close_button.pressed.connect(_close)
	profile_column.add_child(_close_button)
	_root.hide()
	_update_tabs()

func _make_toggle(parent: Control, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.toggle_mode = true
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func initialize(system: Node) -> void:
	_system = system
	_fleet_system = get_tree().get_first_node_in_group("fleet_system")
	_naval_system = get_tree().get_first_node_in_group("naval_combat_system")
	_portrait_atlas = load(CREW_ATLAS) as Texture2D if ResourceLoader.exists(CREW_ATLAS) else null

func open() -> void:
	open_for_ship("active_ship", "trade")

func open_for_ship(ship_id: String, personnel_mode: String = "trade") -> void:
	_is_open = true
	_mode = "military" if personnel_mode == "military" else "trade"
	_view = "candidates"
	_selected_ship_id = ship_id
	_notice = ""
	_update_tabs()
	_rebuild_ship_options()
	_rebuild_list()
	_refresh_details()

func _set_mode(value: String) -> void:
	_mode = value
	_selected_candidate_id = ""
	_notice = ""
	_update_tabs()
	_rebuild_ship_options()
	_rebuild_list()
	_refresh_details()

func _set_view(value: String) -> void:
	_view = value
	_notice = ""
	_update_tabs()
	_rebuild_list()
	_refresh_details()

func _update_tabs() -> void:
	for key in _mode_buttons:
		(_mode_buttons[key] as Button).set_pressed_no_signal(key == _mode)
	for key in _view_buttons:
		(_view_buttons[key] as Button).set_pressed_no_signal(key == _view)
	if _army_button != null:
		_army_button.visible = _mode == "military"
	if _ship_action_button != null:
		_ship_action_button.visible = _mode == "military"
	if _commander_skills != null:
		_commander_skills.visible = _mode == "military"
	if _refresh_button != null:
		_refresh_button.visible = _view == "candidates"
	if _employee_actions != null:
		_employee_actions.visible = _view == "roster"
	if _hire_button != null:
		_hire_button.visible = _view == "candidates"
	if _ship_selector != null:
		_ship_selector.visible = true

func _ship_options_for_mode() -> Array:
	var result: Array = []
	if _system == null:
		return result
	for option in _system.get_ship_options():
		var is_warship := bool(option.get("warship", false))
		if is_warship == (_mode == "military"):
			result.append(option)
	return result

func _rebuild_ship_options() -> void:
	if _ship_selector == null or _system == null:
		return
	_ship_selector.clear()
	var options := _ship_options_for_mode()
	var selected_index := -1
	for option in options:
		var id := str(option.get("id", "active_ship"))
		var marker := " · военный" if bool(option.get("warship", false)) else " · торговый"
		var text_value := "%s%s · экипаж %d/%d" % [str(option.get("name", "Корабль")), marker, int(option.get("crew_count", 0)), int(option.get("max_crew", 1))]
		_ship_selector.add_item(text_value)
		_ship_selector.set_item_metadata(_ship_selector.item_count - 1, id)
		if id == _selected_ship_id:
			selected_index = _ship_selector.item_count - 1
	if options.is_empty():
		_ship_selector.add_item("Нет подходящего корабля")
		_ship_selector.set_item_disabled(0, true)
		_selected_ship_id = ""
		return
	if selected_index < 0:
		selected_index = 0
	_ship_selector.select(selected_index)
	_selected_ship_id = str(_ship_selector.get_item_metadata(selected_index))

func _on_ship_selected(index: int) -> void:
	if _ship_selector.item_count == 0 or _ship_selector.is_item_disabled(index):
		return
	_selected_ship_id = str(_ship_selector.get_item_metadata(index))
	_notice = ""
	_rebuild_list()
	_refresh_details()

func _process(_delta: float) -> void:
	_root.visible = _is_open
	if not _is_open or _system == null:
		return
	var viewport := get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1080.0, viewport.x - 24.0), minf(840.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5

func _rebuild_list() -> void:
	if _list == null or _system == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if _view == "roster":
		_build_roster()
	else:
		_build_candidates()

func _build_candidates() -> void:
	var candidates: Array = _system.get_candidates()
	if _selected_candidate_id == "" or _get_selected_candidate().is_empty():
		_selected_candidate_id = ""
		for raw_candidate in candidates:
			var candidate: Dictionary = raw_candidate
			if _mode == "military" and str(candidate.get("role_id", "")) == "dock_worker":
				continue
			_selected_candidate_id = str(candidate.get("candidate_id", ""))
			break
	var shown := 0
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		var role_id := str(candidate.get("role_id", ""))
		if role_id == "dock_worker" and _mode == "military":
			continue
		_add_person_row(candidate, true)
		shown += 1
	if shown == 0:
		_add_empty_message("Кандидатов для этого раздела нет. Обновите биржу или проверьте свой флот.")

func _build_roster() -> void:
	var employee_ids: Array[String] = []
	for raw_ship in _system.get_ship_options():
		var ship: Dictionary = raw_ship
		if bool(ship.get("warship", false)) != (_mode == "military"):
			continue
		var crew: Array = _crew_for_ship(str(ship.get("id", "")))
		for employee_id in crew:
			if str(employee_id) not in employee_ids:
				employee_ids.append(str(employee_id))
	if _selected_employee_id == "" or not employee_ids.has(_selected_employee_id):
		_selected_employee_id = employee_ids[0] if not employee_ids.is_empty() else ""
	for employee_id in employee_ids:
		var employee: Dictionary = _fleet_system.get_employee(employee_id) if _fleet_system != null else {}
		if not employee.is_empty():
			_add_person_row(employee, false)
	if employee_ids.is_empty():
		_add_empty_message("Пока нет сотрудников на кораблях в этом разделе. Перейдите в «Кандидаты», чтобы нанять и сразу назначить персонал.")

func _add_empty_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	_list.add_child(label)

func _add_person_row(person: Dictionary, candidate_mode: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_list.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = _get_person_portrait(person)
	portrait.custom_minimum_size = Vector2(58, 70)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(portrait)
	var button := Button.new()
	button.custom_minimum_size.y = 70
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var role_id := str(person.get("role_id", ""))
	var role_name := str(person.get("role_name", "Сотрудник"))
	var role_help := str(ROLE_HELP.get(role_id, "Сотрудник входит в экипаж выбранного корабля."))
	if candidate_mode:
		var id := str(person.get("candidate_id", ""))
		button.text = "%s\n%s · %s · ранг %d" % [str(person.get("name", "")), str(person.get("race_name", "")), role_name, int(person.get("rank", 1))]
		button.toggle_mode = true
		button.button_pressed = id == _selected_candidate_id
		button.tooltip_text = role_help
		button.pressed.connect(_select_candidate.bind(id))
	else:
		var ship_name := _ship_name_for_employee(person)
		button.text = "%s\n%s · %s · %s" % [str(person.get("name", "")), str(person.get("race_name", "")), role_name, ship_name]
		button.tooltip_text = role_help
		button.toggle_mode = true
		button.button_pressed = str(person.get("employee_instance_id", "")) == _selected_employee_id
		button.pressed.connect(_select_employee.bind(str(person.get("employee_instance_id", ""))))
	row.add_child(button)
	if not candidate_mode:
		var transfer := Button.new()
		transfer.text = "Перевести"
		transfer.custom_minimum_size.y = 34
		transfer.tooltip_text = "Перевести в выбранный корабль. Оба судна должны стоять в одном порту."
		var employee_id := str(person.get("employee_instance_id", ""))
		var transfer_status: Dictionary = _fleet_system.get_employee_assignment_status(employee_id, _selected_ship_id) if _fleet_system != null and _selected_ship_id != "" else {"ok": false, "message": "Сначала выберите корабль."}
		transfer.disabled = not bool(transfer_status.get("ok", false))
		transfer.pressed.connect(_transfer_employee.bind(employee_id))
		row.add_child(transfer)
		var dismiss := Button.new()
		dismiss.text = "Уволить"
		dismiss.custom_minimum_size.y = 34
		dismiss.tooltip_text = "Уволить сотрудника и освободить место экипажа."
		dismiss.pressed.connect(_dismiss_employee.bind(employee_id))
		row.add_child(dismiss)

func _refresh_details() -> void:
	if _details == null or _system == null:
		return
	var ship := _selected_ship()
	if _view == "roster":
		var employee: Dictionary = _fleet_system.get_employee(_selected_employee_id) if _fleet_system != null else {}
		_portrait.texture = _get_person_portrait(employee) if not employee.is_empty() else null
		var assigned_count := _crew_for_ship(_selected_ship_id).size()
		if employee.is_empty():
			_details.text = "%s\n%s\n\nЭкипаж: %d / %d мест. Выберите сотрудника слева, чтобы увидеть навыки и обучение.%s" % [str(ship.get("name", "Выберите корабль")), "Военный экипаж конкретного судна." if _mode == "military" else "Экипаж торгового судна.", assigned_count, int(ship.get("max_crew", 0)), ("\n\n" + _notice) if _notice != "" else ""]
		else:
			_details.text = "%s · %s · ранг %d\n%s\n\nНазначен на: %s\nВладение профессией: %d%% · рейсов: %d\nНавыки и свитки обучения доступны здесь.%s" % [str(employee.get("name", "")), str(employee.get("role_name", "сотрудник")), int(employee.get("rank", 1)), str(ROLE_HELP.get(str(employee.get("role_id", "")), "Член экипажа конкретного корабля.")), _ship_name_for_employee(employee), int(employee.get("mastery_percent", 0)), int(employee.get("experience", 0)), ("\n\n" + _notice) if _notice != "" else ""]
			_build_employee_training(employee)
		_hire_button.disabled = true
		_ship_action_button.disabled = ship.is_empty()
		_refresh_commander_controls(ship)
		return
	var candidate := _get_selected_candidate()
	if candidate.is_empty():
		_portrait.texture = null
		_details.text = "Выберите кандидата.\n\nДля назначения выберите корабль в списке ниже."
		_hire_button.disabled = true
		_ship_action_button.disabled = ship.is_empty()
		_refresh_commander_controls(ship)
		return
	var role_id := str(candidate.get("role_id", ""))
	var stats: Dictionary = candidate.get("stats", {})
	var stat_labels: Dictionary = _system.get_stat_labels()
	var parts: Array[String] = []
	for stat_id in ["speed", "loading", "fuel", "repair", "navigation"]:
		parts.append("%s %+d%%" % [str(stat_labels.get(stat_id, stat_id)), int(stats.get(stat_id, 0))])
	var role_explanation := str(ROLE_HELP.get(role_id, "Сотрудник занимает постоянное место экипажа выбранного корабля."))
	if role_id == "captain":
		role_explanation = "Это нанимаемый капитан одного судна. Он не командует армией и не заменяет военного командира."
	var assigned := _crew_for_ship(_selected_ship_id).size()
	var salary := float(candidate.get("hire_price", 0.0))
	var lines: Array[String] = [
		"%s · %s · ранг %d" % [str(candidate.get("name", "")), str(candidate.get("race_name", "")), int(candidate.get("rank", 1))],
		"РОЛЬ: %s" % str(candidate.get("role_name", "Сотрудник")),
		role_explanation,
		"Корабль: %s" % str(ship.get("name", "нет подходящего судна")),
		"Занято мест: %d / %d" % [assigned, int(ship.get("max_crew", 0))],
		"Сильная сторона: %s · изъян: %s" % [str(candidate.get("strength_trait", "—")), str(candidate.get("flaw_trait", "—"))],
		"Навыки: " + " · ".join(parts),
		"Найм: %.0f монет · содержание: %.0f за переход" % [salary, float(candidate.get("salary_per_voyage", 0.0))]
	]
	if _mode == "military":
		lines.append("Военный командир корабля назначается отдельно и усиливает орудия только этого судна. Командир армии и заместитель находятся в казармах.")
	if _notice != "":
		lines.append(_notice)
	_portrait.texture = _get_person_portrait(candidate)
	_details.text = "\n\n".join(lines)
	var ship_available := _ship_is_available(ship)
	_hire_button.text = "НАНЯТЬ И НАЗНАЧИТЬ НА «%s» · %.0f" % [str(ship.get("name", "КОРАБЛЬ")).to_upper(), salary]
	_hire_button.disabled = ship.is_empty() or not ship_available or assigned >= int(ship.get("max_crew", 0)) or int(candidate.get("rank", 1)) > _system.get_hiring_rank_limit() or float(GameState.player_state.get("money", 0.0)) < salary
	_ship_action_button.disabled = ship.is_empty() or not _ship_is_available(ship)
	_refresh_commander_controls(ship)

func _refresh_commander_controls(ship: Dictionary) -> void:
	for child in _commander_skills.get_children():
		child.queue_free()
	if _mode != "military" or ship.is_empty():
		_naval_commander_portrait.hide()
		_ship_action_button.text = "КОМАНДИР ВЫБРАННОГО ВОЕННОГО КОРАБЛЯ"
		_ship_action_button.disabled = true
		return
	var vessel: Dictionary = {}
	var ship_id := str(ship.get("id", ""))
	for raw_ship in GameState.fleet_state:
		if str(raw_ship.get("instance_id", "")) == ship_id:
			vessel = raw_ship
			break
	if vessel.is_empty():
		_naval_commander_portrait.hide()
		_ship_action_button.text = "КОМАНДИР: ВЫБЕРИТЕ ВОЕННЫЙ КОРАБЛЬ"
		_ship_action_button.disabled = true
		return
	var commander: Dictionary = vessel.get("commander", {})
	if commander.is_empty():
		_naval_commander_portrait.hide()
		_ship_action_button.text = "НАНЯТЬ КОМАНДИРА ЭТОГО КОРАБЛЯ · %d МОНЕТ" % int(_naval_system._rules.commander_cost) if _naval_system != null else "НАНЯТЬ КОМАНДИРА КОРАБЛЯ"
		return
	_naval_commander_portrait.texture = _naval_commander_portrait_for(str(commander.get("race_id", GameState.player_state.get("origin_race_id", "humans"))), int(commander.get("portrait_variant", 0)))
	_naval_commander_portrait.show()
	_ship_action_button.text = "КОМАНДИР: %s · УР. %d · НАВЫКИ %d" % [str(commander.get("name", "")), int(commander.get("level", 1)), int(commander.get("skill_points", 0))]
	_ship_action_button.disabled = true
	for skill in ["gunnery", "accuracy", "reload"]:
		var label: String = {"gunnery": "Урон", "accuracy": "Точность", "reload": "Перезарядка"}[skill]
		var button := Button.new()
		button.text = "%s %d +" % [label, int(commander.get("skills", {}).get(skill, 0))]
		button.custom_minimum_size.y = 32
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not _ship_is_available(ship) or int(commander.get("skill_points", 0)) <= 0
		button.pressed.connect(_train_ship_commander.bind(ship_id, skill))
		_commander_skills.add_child(button)

func _naval_commander_portrait_for(race_id: String, variant: int) -> Texture2D:
	var safe_race: String = race_id if race_id in ["humans", "nerids", "surr", "meridians", "aery", "crystari"] else "humans"
	var path: String = "res://assets/characters/commanders/%s/portrait_%02d.png" % [safe_race, posmod(variant, 3)+1]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _build_employee_training(employee: Dictionary) -> void:
	for child in _employee_actions.get_children():
		child.queue_free()
	if employee.is_empty():
		return
	var employee_id := str(employee.get("employee_instance_id", ""))
	var catalog: Dictionary = _system.get_skill_catalog()
	var learned: Array = employee.get("skills", [])
	var living := _system.is_living_employee(employee)
	var scroll_inventory: Dictionary = _system.get_training_scroll_inventory()
	for entry in learned:
		var skill_id := str(entry.get("id", ""))
		var definition: Dictionary = catalog.get(skill_id, {})
		var progress := int(entry.get("progress", 0))
		var label := Label.new()
		label.text = "%s · %d%% · %s" % [str(definition.get("name", skill_id)), progress, str(definition.get("description", ""))]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		_employee_actions.add_child(label)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = progress
		bar.custom_minimum_size.y = 12
		_employee_actions.add_child(bar)
		var scroll_type := _system.get_training_scroll_type_for_skill(skill_id)
		var scroll_definition: Dictionary = _system.get_training_scroll_catalog().get(scroll_type, {})
		var scroll_count := int(scroll_inventory.get(scroll_type, 0))
		if scroll_count > 0 and progress < 100:
			var scroll_button := Button.new()
			scroll_button.text = "Применить свиток «%s» · осталось %d" % [str(scroll_definition.get("short_name", scroll_type)), scroll_count]
			scroll_button.disabled = not living
			scroll_button.tooltip_text = "Свиток подходит этому навыку и обучает только живого сотрудника."
			scroll_button.pressed.connect(_use_scroll.bind(employee_id, skill_id, scroll_type))
			_employee_actions.add_child(scroll_button)
	if int(employee.get("mastery_percent", 0)) >= 100 and str(employee.get("active_skill_id", "")) == "" and learned.size() < _system.get_maximum_skill_slots(employee):
		var choose_label := Label.new()
		choose_label.text = "Профессия освоена. Выберите следующий навык:"
		choose_label.add_theme_font_size_override("font_size", 12)
		_employee_actions.add_child(choose_label)
		for skill_id in catalog:
			var already_learned := false
			for entry in learned:
				if str(entry.get("id", "")) == str(skill_id):
					already_learned = true
					break
			if already_learned:
				continue
			var definition: Dictionary = catalog[skill_id]
			var skill_button := Button.new()
			skill_button.text = "%s · %s" % [str(definition.get("name", skill_id)), str(definition.get("description", ""))]
			skill_button.disabled = not living
			skill_button.pressed.connect(_choose_employee_skill.bind(employee_id, str(skill_id)))
			_employee_actions.add_child(skill_button)
	if not living:
		var note := Label.new()
		note.text = "Обучать можно только живого и дееспособного персонажа."
		note.add_theme_font_size_override("font_size", 12)
		_employee_actions.add_child(note)

func _ship_is_available(ship: Dictionary) -> bool:
	if ship.is_empty():
		return false
	if str(ship.get("id", "")) == "active_ship":
		return str(GameState.ship_state.get("docked_port_id", "")) != ""
	return Dictionary(ship.get("autopilot", {})).is_empty() and str(ship.get("current_port_id", "")) == str(GameState.ship_state.get("docked_port_id", "")) and str(GameState.ship_state.get("docked_port_id", "")) != ""

func _selected_ship() -> Dictionary:
	for option in _ship_options_for_mode():
		if str(option.get("id", "")) == _selected_ship_id:
			return option
	return {}

func _crew_for_ship(ship_id: String) -> Array:
	if ship_id == "active_ship":
		return GameState.ship_state.get("crew", [])
	for raw_ship in GameState.fleet_state:
		if str(raw_ship.get("instance_id", "")) == ship_id:
			return raw_ship.get("crew", [])
	return []

func _ship_name_for_employee(employee: Dictionary) -> String:
	var employee_id := str(employee.get("employee_instance_id", ""))
	for option in _system.get_ship_options():
		if _crew_for_ship(str(option.get("id", ""))).has(employee_id):
			return str(option.get("name", "корабль"))
	return "без корабля"

func _get_person_portrait(person: Dictionary) -> Texture2D:
	var race_id := str(person.get("race_id", "humans"))
	var role_id := str(person.get("role_id", str(person.get("role_name", "")).to_lower()))
	return CharacterArtCatalog.ship_officer_portrait(race_id, role_id, int(person.get("portrait_id", 0)), _portrait_atlas)

func _get_selected_candidate() -> Dictionary:
	for raw_candidate in _system.get_candidates():
		if str(raw_candidate.get("candidate_id", "")) == _selected_candidate_id:
			return raw_candidate
	return {}

func _select_candidate(candidate_id: String) -> void:
	_selected_candidate_id = candidate_id
	_notice = ""
	_rebuild_list()
	_refresh_details()

func _select_employee(employee_id: String) -> void:
	_selected_employee_id = employee_id
	_notice = ""
	_rebuild_list()
	_refresh_details()

func _choose_employee_skill(employee_id: String, skill_id: String) -> void:
	var result: Dictionary = _system.choose_skill(employee_id, skill_id)
	_notice = str(result.get("message", ""))
	_refresh_details()

func _use_scroll(employee_id: String, skill_id: String, scroll_type: String) -> void:
	var result: Dictionary = _system.use_training_scroll(employee_id, skill_id, scroll_type)
	_notice = str(result.get("message", ""))
	_refresh_details()

func _hire() -> void:
	if _view != "candidates":
		return
	var result: Dictionary = _system.hire(_selected_candidate_id, 1, _selected_ship_id)
	_notice = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_selected_candidate_id = ""
		_rebuild_ship_options()
		_rebuild_list()
	_refresh_details()

func _refresh_candidates() -> void:
	var result: Dictionary = _system.refresh_candidates()
	_notice = str(result.get("message", ""))
	_selected_candidate_id = ""
	_rebuild_list()
	_refresh_details()

func _transfer_employee(employee_id: String) -> void:
	if _fleet_system == null or _selected_ship_id == "":
		return
	var result: Dictionary = _fleet_system.assign_employee(employee_id, _selected_ship_id)
	_notice = str(result.get("message", ""))
	_rebuild_list()
	_refresh_details()

func _dismiss_employee(employee_id: String) -> void:
	var result: Dictionary = _system.dismiss(employee_id)
	_notice = str(result.get("message", ""))
	_rebuild_list()
	_refresh_details()

func _open_garrison() -> void:
	var windows: Array[Node] = get_tree().get_nodes_in_group("garrison_window")
	if not windows.is_empty() and windows[0].has_method("open"):
		windows[0].call("open")

func _manage_ship_commander() -> void:
	var ship := _selected_ship()
	if ship.is_empty() or _naval_system == null:
		return
	var ship_id := str(ship.get("id", ""))
	var status: Dictionary = _naval_system.management_status(ship_id)
	if not bool(status.get("ok", false)):
		_notice = str(status.get("message", "Командование можно менять только в порту."))
		_refresh_details()
		return
	var vessel: Dictionary = {}
	for raw_ship in GameState.fleet_state:
		if str(raw_ship.get("instance_id", "")) == ship_id:
			vessel = raw_ship
			break
	if vessel.is_empty():
		return
	var commander: Dictionary = vessel.get("commander", {})
	var result: Dictionary
	if commander.is_empty():
		result = _naval_system.hire_commander(ship_id)
	else:
		result = {"ok": false, "message": "Командир %s назначен этому кораблю. Повышайте его навыки кнопками ниже." % str(commander.get("name", ""))}
	_notice = str(result.get("message", ""))
	_refresh_details()

func _train_ship_commander(ship_id: String, skill_id: String) -> void:
	if _naval_system == null:
		return
	var result: Dictionary = _naval_system.train_skill(ship_id, skill_id)
	_notice = str(result.get("message", ""))
	_refresh_details()

func _close() -> void:
	_is_open = false
