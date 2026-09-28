extends CanvasLayer

## Гарнизон, найм, оборона и сводки. Схематичный интерфейс без 3D-сцены боя.
var _system: Node
var _root: Control
var _panel: PanelContainer
var _details: Label
var _tabs: TabContainer
var _notice: Label
var _overview: VBoxContainer
var _recruitment_label: Label
var _recruitment_bar: ProgressBar
var _construction_label: Label
var _construction_bar: ProgressBar
var _raid_label: Label
var _raid_bar: ProgressBar
var _tower_label: Label
var _tower_buttons: Dictionary = {}
var _unit_grids: Dictionary = {}
var _report_list: VBoxContainer
var _upgrade_button: Button
var _repair_button: Button
var _is_open: bool = false
var _cards_dirty: bool = true
var _last_refresh_second: int = -1
var _last_roster_signature: String = ""

const CARD_MIN_SIZE := Vector2(330, 360)
const UNIT_PORTRAITS := {
	"coast_guard": "res://assets/characters/infantry_scout.jpg",
	"stone_warden": "res://assets/characters/infantry_guardian.jpg"
}

func _ready() -> void:
	add_to_group("garrison_window")
	layer = 55
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#101d28")
	panel_style.border_color = Color("#527e8c")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "ГАРНИЗОН"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	heading.add_child(title)
	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size = Vector2(130, 44)
	close_button.add_theme_font_size_override("font_size", 19)
	close_button.pressed.connect(_close)
	heading.add_child(close_button)

	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 18)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_details)

	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", 18)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_notice)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 18)
	layout.add_child(_tabs)

	_build_overview_tab()
	_build_unit_tab("ПЕХОТА")
	_build_unit_tab("ЛЕТУЧИЕ")
	_build_unit_tab("ТЕХНИКА")
	_build_defense_tab()
	_build_reports_tab()
	_root.hide()

func initialize(system: Node) -> void:
	_system = system

func open() -> void:
	_is_open = true
	_cards_dirty = true
	_notice.text = ""
	if _system != null:
		_system.mark_reports_seen()
	_refresh()

func _process(_delta: float) -> void:
	_root.visible = _is_open
	if not _is_open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1220.0, viewport.x - 24.0), minf(1480.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5
	var second: int = int(Time.get_unix_time_from_system())
	if second != _last_refresh_second:
		_last_refresh_second = second
		_refresh()

func _build_overview_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ОБЗОР"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	_overview = VBoxContainer.new()
	_overview.add_theme_constant_override("separation", 10)
	_overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_overview)

	var upgrade_title := Label.new()
	upgrade_title.text = "РАЗВИТИЕ ГАРНИЗОНА"
	upgrade_title.add_theme_font_size_override("font_size", 22)
	_overview.add_child(upgrade_title)
	_add_garrison_upgrade(_overview)

	_construction_label = Label.new()
	_construction_label.add_theme_font_size_override("font_size", 18)
	_overview.add_child(_construction_label)
	_construction_bar = ProgressBar.new()
	_construction_bar.custom_minimum_size.y = 24
	_construction_bar.show_percentage = true
	_overview.add_child(_construction_bar)

	var training_title := Label.new()
	training_title.text = "ОБУЧЕНИЕ ОТРЯДОВ"
	training_title.add_theme_font_size_override("font_size", 22)
	_overview.add_child(training_title)
	_recruitment_label = Label.new()
	_recruitment_label.add_theme_font_size_override("font_size", 18)
	_overview.add_child(_recruitment_label)
	_recruitment_bar = ProgressBar.new()
	_recruitment_bar.custom_minimum_size.y = 24
	_recruitment_bar.show_percentage = true
	_overview.add_child(_recruitment_bar)

	var operation_title := Label.new()
	operation_title.text = "ТЕКУЩАЯ ВЫЛАЗКА"
	operation_title.add_theme_font_size_override("font_size", 22)
	_overview.add_child(operation_title)
	_raid_label = Label.new()
	_raid_label.add_theme_font_size_override("font_size", 18)
	_overview.add_child(_raid_label)
	_raid_bar = ProgressBar.new()
	_raid_bar.custom_minimum_size.y = 24
	_raid_bar.show_percentage = true
	_overview.add_child(_raid_bar)

	if OS.is_debug_build():
		var test_row := HBoxContainer.new()
		var defense_test := Button.new()
		defense_test.text = "ТЕСТ: нападение"
		defense_test.add_theme_font_size_override("font_size", 16)
		defense_test.pressed.connect(_test_defense)
		test_row.add_child(defense_test)
		var raid_test := Button.new()
		raid_test.text = "ТЕСТ: вылазка 15 сек."
		raid_test.add_theme_font_size_override("font_size", 16)
		raid_test.pressed.connect(_test_raid)
		test_row.add_child(raid_test)
		_overview.add_child(test_row)

func _build_unit_tab(tab_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var intro := Label.new()
	intro.text = "Выберите отряд. Численность и развитие сохраняются в гарнизоне."
	intro.add_theme_font_size_override("font_size", 18)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var grid := GridContainer.new()
	grid.name = "UnitCards"
	grid.columns = 2 if get_viewport().get_visible_rect().size.x >= 820.0 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	_unit_grids[tab_name] = grid

func _build_defense_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ОБОРОНА"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var title := Label.new()
	title.text = "КРИСТАЛЛИЧЕСКИЕ БАШНИ"
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	_tower_label = Label.new()
	_tower_label.add_theme_font_size_override("font_size", 18)
	_tower_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_tower_label)

	var tower_buttons := HBoxContainer.new()
	tower_buttons.add_theme_constant_override("separation", 8)
	for tower in [["power", "Башня силы"], ["guard", "Башня защиты"], ["wind", "Башня ветра"]]:
		var button := Button.new()
		button.text = str(tower[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_build_tower.bind(str(tower[0])))
		tower_buttons.add_child(button)
		_tower_buttons[str(tower[0])] = button
	content.add_child(tower_buttons)

	var note := Label.new()
	note.text = "Каждая башня занимает ячейку гарнизона. Эффекты башен усиливают защиту базы или выбранные боевые показатели."
	note.add_theme_font_size_override("font_size", 17)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

	var fort_row := HBoxContainer.new()
	content.add_child(fort_row)
	_repair_button = Button.new()
	_repair_button.text = "Починить укрепления"
	_repair_button.custom_minimum_size = Vector2(240, 48)
	_repair_button.add_theme_font_size_override("font_size", 18)
	_repair_button.pressed.connect(_repair)
	fort_row.add_child(_repair_button)

func _build_reports_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "СВОДКИ"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	_report_list = VBoxContainer.new()
	_report_list.add_theme_constant_override("separation", 10)
	_report_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_report_list)

func _add_garrison_upgrade(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	_upgrade_button = Button.new()
	_upgrade_button.text = "Улучшить гарнизон"
	_upgrade_button.custom_minimum_size = Vector2(230, 48)
	_upgrade_button.add_theme_font_size_override("font_size", 18)
	_upgrade_button.pressed.connect(_upgrade_garrison)
	row.add_child(_upgrade_button)
	_repair_button = _repair_button if _repair_button != null else Button.new()
	parent.add_child(row)

func _refresh() -> void:
	if _system == null:
		return
	var level: int = _system.get_garrison_level()
	var upgrade_cost: Dictionary = _system.get_garrison_upgrade_cost()
	var inventory: Dictionary = GameState.port_state.get(_system.get_home_port_id(), {}).get("inventory", {})
	var integrity: float = float(GameState.combat_state.get("fort_integrity", 100.0))
	var cost_text: String = "Гарнизон достиг максимального уровня." if upgrade_cost.is_empty() else "Следующий уровень: %d монет, %d дерева, %d деталей." % [int(upgrade_cost.get("money", 0)), int(upgrade_cost.get("resource_timber", 0)), int(upgrade_cost.get("resource_parts", 0))]
	_details.text = "Уровень гарнизона %d / 5  •  сила отрядов %d  •  оборона %d  •  прочность базы %.0f%%\n%s  •  на складе: дерево %d, детали %d" % [level, _system.get_attack_power(), _system.get_defense_power(), integrity, cost_text, int(inventory.get("resource_timber", 0)), int(inventory.get("resource_parts", 0))]

	var construction: Dictionary = _system.get_construction_status()
	_construction_bar.value = float(construction.get("percent", 0.0))
	_construction_label.text = "Работа: %s  •  %d%%  •  осталось %d сек." % [str(construction.get("action", "")), int(construction.get("percent", 0.0)), int(construction.get("seconds_left", 0))] if not construction.is_empty() else "Нет активного улучшения или строительства."
	_upgrade_button.disabled = not _system.can_upgrade_garrison()
	_upgrade_button.text = "Максимальный уровень" if upgrade_cost.is_empty() else "Улучшить гарнизон"

	var recruit_job: Dictionary = _system.get_recruitment_status()
	_recruitment_bar.value = float(recruit_job.get("percent", 0.0))
	if recruit_job.is_empty():
		_recruitment_label.text = "Сейчас отряды не обучаются."
	else:
		_recruitment_label.text = "Обучается: %s × %d  •  осталось %d сек." % [_system.get_unit_name(str(recruit_job.get("unit_id", ""))), int(recruit_job.get("amount", 0)), int(recruit_job.get("seconds_left", 0))]

	var raid: Dictionary = _system.get_player_raid_status()
	_raid_bar.value = float(raid.get("percent", 0.0))
	_raid_label.text = "Идёт вылазка к цели «%s»  •  %d%%  •  осталось %d сек." % [str(raid.get("target", "")), int(raid.get("percent", 0.0)), int(raid.get("seconds_left", 0))] if not raid.is_empty() else "Вылазок сейчас нет."

	var can_build_more: bool = _system.get_towers().size() < mini(level, 5)
	for tower_type in _tower_buttons:
		var tower_button: Button = _tower_buttons[tower_type]
		tower_button.disabled = not can_build_more or not _system.can_build_tower(str(tower_type))
	_tower_label.text = _format_towers(_system.get_tower_bonuses())
	_repair_button.disabled = not _system.is_at_home() or integrity >= 100.0

	var roster_signature: String = ""
	for unit in _system.get_roster():
		roster_signature += "%s:%d:%d:%d:%d|" % [str(unit.get("id", "")), int(unit.get("count", 0)), int(unit.get("level", 1)), int(unit.get("experience", 0)), int(unit.get("unlocked", false))]
	if _cards_dirty or roster_signature != _last_roster_signature:
		_last_roster_signature = roster_signature
		_rebuild_unit_cards()
		_cards_dirty = false
	_rebuild_reports()

func _format_towers(bonuses: Dictionary) -> String:
	var names: Array[String] = []
	for tower in _system.get_towers():
		names.append(str(_system.get_tower_name(str(tower.get("type", "")))))
	var slots: int = mini(_system.get_garrison_level(), 5)
	var contents: String = "Нет построенных башен."
	if not names.is_empty():
		contents = "Построены: "
		for index in range(names.size()):
			if index > 0:
				contents += ", "
			contents += names[index]
		contents += "."
	return "%s Ячеек занято: %d / %d. Бонусы: сила +%.0f%%, защита +%.0f%%, скорость +%.0f%%." % [contents, names.size(), slots, float(bonuses.get("attack", 0.0)), float(bonuses.get("defense", 0.0)), float(bonuses.get("speed", 0.0))]

func _rebuild_unit_cards() -> void:
	for grid in _unit_grids.values():
		for child in grid.get_children():
			child.queue_free()
	var max_batch: int = int(_system.get_catalog().get("rules", {}).get("max_recruitment_batch", 20))
	var columns: int = 2 if get_viewport().get_visible_rect().size.x >= 820.0 else 1
	for grid_value in _unit_grids.values():
		var unit_grid: GridContainer = grid_value
		unit_grid.columns = columns
	for unit in _system.get_roster():
		var tab_name: String = _tab_for_branch(str(unit.get("branch", "")))
		var grid: GridContainer = _unit_grids.get(tab_name)
		if grid == null:
			continue
		grid.add_child(_create_unit_card(unit, max_batch))

func _tab_for_branch(branch: String) -> String:
	if branch.contains("Летуч"):
		return "ЛЕТУЧИЕ"
	if branch.contains("техник") or branch.contains("мортир"):
		return "ТЕХНИКА"
	return "ПЕХОТА"

func _create_unit_card(unit: Dictionary, max_batch: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142735")
	style.border_color = Color("#536e78") if bool(unit.get("unlocked", false)) else Color("#46515a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var portrait_row := HBoxContainer.new()
	content.add_child(portrait_row)
	var portrait_path: String = str(UNIT_PORTRAITS.get(str(unit.get("id", "")), ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(150, 116)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture = load(portrait_path) as Texture2D
		portrait_row.add_child(portrait)
	else:
		var placeholder := PanelContainer.new()
		placeholder.custom_minimum_size = Vector2(150, 116)
		placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var placeholder_style := StyleBoxFlat.new()
		placeholder_style.bg_color = Color("#203d49")
		placeholder_style.border_color = Color("#497887")
		placeholder_style.set_border_width_all(1)
		placeholder.add_theme_stylebox_override("panel", placeholder_style)
		var emblem := Label.new()
		emblem.text = "✦\n" + str(unit.get("branch", ""))
		emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emblem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		emblem.add_theme_font_size_override("font_size", 20)
		placeholder.add_child(emblem)
		portrait_row.add_child(placeholder)

	var title := Label.new()
	title.text = str(unit.get("branch", "")).to_upper()
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	var name := Label.new()
	name.text = str(unit.get("name", ""))
	name.add_theme_font_size_override("font_size", 22)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name)

	var state := Label.new()
	state.add_theme_font_size_override("font_size", 17)
	if bool(unit.get("unlocked", false)):
		state.text = "%d в гарнизоне  •  уровень %d" % [int(unit.get("count", 0)), int(unit.get("level", 1))]
	else:
		state.text = "Откроется на %d уровне гарнизона" % int(unit.get("unlock_level", 1))
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(state)

	if bool(unit.get("unlocked", false)):
		var stats := Label.new()
		stats.text = "Сила %d  •  защита %d\nСкорость %d  •  удача %d" % [int(unit.get("attack", 0)), int(unit.get("defense", 0)), int(unit.get("speed", 0)), int(unit.get("luck", 0))]
		stats.add_theme_font_size_override("font_size", 17)
		content.add_child(stats)

		var growth := ProgressBar.new()
		growth.custom_minimum_size.y = 18
		growth.show_percentage = false
		growth.value = float(unit.get("experience_percent", 0))
		content.add_child(growth)
		var growth_label := Label.new()
		growth_label.text = "Развитие отряда: %d%%" % int(unit.get("experience_percent", 0))
		growth_label.add_theme_font_size_override("font_size", 16)
		content.add_child(growth_label)

		var quantity_label := Label.new()
		quantity_label.add_theme_font_size_override("font_size", 16)
		content.add_child(quantity_label)
		var quantity := HSlider.new()
		quantity.min_value = 1
		quantity.max_value = max_batch
		quantity.step = 1
		quantity.value = mini(5, max_batch)
		quantity.custom_minimum_size.y = 28
		content.add_child(quantity)

		var hire := Button.new()
		hire.text = "Нанять отряд"
		hire.custom_minimum_size.y = 42
		hire.add_theme_font_size_override("font_size", 18)
		hire.pressed.connect(_recruit.bind(str(unit.get("id", "")), quantity))
		content.add_child(hire)
		quantity.value_changed.connect(_update_recruit_preview.bind(str(unit.get("id", "")), quantity_label, hire))
		_update_recruit_preview(float(quantity.value), str(unit.get("id", "")), quantity_label, hire)

		if int(unit.get("count", 0)) > 0:
			var promote := Button.new()
			promote.text = "Повысить уровень отряда"
			promote.custom_minimum_size.y = 40
			promote.add_theme_font_size_override("font_size", 16)
			promote.disabled = not _system.is_at_home() or int(unit.get("level", 1)) >= _system.get_garrison_level() or int(unit.get("experience", 0)) < int(unit.get("next_level_experience", 100))
			promote.pressed.connect(_promote.bind(str(unit.get("id", ""))))
			content.add_child(promote)

	return card

func _update_recruit_preview(amount_value: float, unit_id: String, preview: Label, hire_button: Button) -> void:
	if _system == null or not is_instance_valid(preview) or not is_instance_valid(hire_button):
		return
	var amount: int = maxi(1, int(round(amount_value)))
	var unit: Dictionary = {}
	for candidate in _system.get_roster():
		if str(candidate.get("id", "")) == unit_id:
			unit = candidate
			break
	var catalog: Dictionary = _system.get_catalog()
	var definitions: Dictionary = catalog.get("units", {})
	var definition: Dictionary = definitions.get(unit_id, {})
	var total_cost: int = int(unit.get("hire_cost", 0)) * amount
	var total_seconds: int = int(definition.get("seconds_per_unit", 10)) * amount
	preview.text = "%d отрядов: %d монет  •  обучение %d сек." % [amount, total_cost, total_seconds]
	hire_button.disabled = not _system.is_at_home() or not _system.get_recruitment_status().is_empty() or not _system.can_recruit(unit_id, amount)

func _add_garrison_upgrade(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	_upgrade_button = Button.new()
	_upgrade_button.text = "Улучшить гарнизон"
	_upgrade_button.custom_minimum_size = Vector2(230, 48)
	_upgrade_button.add_theme_font_size_override("font_size", 18)
	_upgrade_button.pressed.connect(_upgrade_garrison)
	row.add_child(_upgrade_button)
	parent.add_child(row)

func _rebuild_reports() -> void:
	for child in _report_list.get_children():
		child.queue_free()
	var reports: Array = _system.get_reports()
	if reports.is_empty():
		var empty := Label.new()
		empty.text = "Сводок пока нет."
		empty.add_theme_font_size_override("font_size", 18)
		_report_list.add_child(empty)
		return
	for report in reports.slice(0, 8):
		var entry := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#142735")
		style.border_color = Color("#536e78")
		style.set_border_width_all(1)
		entry.add_theme_stylebox_override("panel", style)
		var margin := MarginContainer.new()
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
		entry.add_child(margin)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 17)
		var time_text: String = Time.get_datetime_string_from_unix_time(int(report.get("timestamp", 0)), true)
		var losses_text: String = _format_unit_losses(report.get("unit_losses", {}))
		var detail_text: String = "Потери по нашим отрядам: " + losses_text if losses_text != "" else "Наши потери: нет."
		detail_text += "\nПотери противника: %d." % int(report.get("enemy_unit_losses", 0))
		label.text = "%s  •  %s — %s\n%s\n%s" % [time_text, str(report.get("enemy", "Противник")), str(report.get("outcome", "")), detail_text, str(report.get("summary", ""))]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		margin.add_child(label)
		_report_list.add_child(entry)

func _format_unit_losses(losses: Dictionary) -> String:
	var entries: Array[String] = []
	for unit_id in losses:
		entries.append("%s × %d" % [str(_system.get_unit_name(str(unit_id))), int(losses[unit_id])])
	var result: String = ""
	for index in range(entries.size()):
		if index > 0:
			result += ", "
		result += entries[index]
	return result

func _recruit(unit_id: String, quantity: HSlider) -> void:
	var result: Dictionary = _system.recruit(unit_id, int(round(quantity.value)))
	_notice.text = str(result.get("message", ""))
	_cards_dirty = true
	_refresh()

func _promote(unit_id: String) -> void:
	var result: Dictionary = _system.promote_unit(unit_id)
	_notice.text = str(result.get("message", ""))
	_cards_dirty = true
	_refresh()

func _upgrade_garrison() -> void:
	var result: Dictionary = _system.upgrade_garrison()
	_notice.text = str(result.get("message", ""))
	_refresh()

func _build_tower(tower_type: String) -> void:
	var result: Dictionary = _system.build_tower(tower_type)
	_notice.text = str(result.get("message", ""))
	_refresh()

func _repair() -> void:
	var result: Dictionary = _system.repair_fortification()
	_notice.text = str(result.get("message", ""))
	_refresh()

func _test_defense() -> void:
	var enemy_power: int = maxi(20, int(_system.get_defense_power()) + 5)
	var result: Dictionary = _system.resolve_hidden_attack(enemy_power, "Тестовый пиратский отряд")
	_notice.text = str(result.get("message", ""))
	_refresh()

func _test_raid() -> void:
	var enemy_power: int = maxi(10, int(float(_system.get_attack_power()) / 2.0))
	var result: Dictionary = _system.start_player_raid("Лагерь пиратов", enemy_power, 15)
	_notice.text = str(result.get("message", ""))
	_refresh()

func _close() -> void:
	_is_open = false
