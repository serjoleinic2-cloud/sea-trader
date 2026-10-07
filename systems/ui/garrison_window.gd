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
var _tower_slot_select: OptionButton
var _crystal_select: OptionButton
var _crystal_apply_button: Button
var _crystal_signature: String = ""
var _unit_grids: Dictionary = {}
var _recruitment_portrait_bars: Dictionary = {}
var _report_list: VBoxContainer
var _upgrade_button: Button
var _repair_button: Button
var _is_open: bool = false
var _cards_dirty: bool = true
var _last_refresh_second: int = -1
var _last_roster_signature: String = ""
var _last_card_columns: int = 0
var _origin_emblem: TextureRect
var _art_screen: Control
var _art_image: TextureRect
var _art_commander_portrait: TextureRect
var _art_slot_portrait: TextureRect
var _art_money: Label
var _art_shards: Label
var _art_squad_count: Label
var _art_slot_status: Label
var _art_unit_counts: Dictionary = {}
var _art_profile_labels: Dictionary = {}
var _art_hire_button: Button
var _art_notice: Label
var _art_selection_frame: Panel
var _art_mode: bool = true
var _inspected_faction_id: String = ""
var _art_hotspots: Array[Control] = []
const ART_REFERENCE_PATH := "res://assets/ui/garrison/garrison_commanders_reference.png"
const ART_DESIGN_SIZE := Vector2(1672.0, 944.0)
const ART_FACTION_IDS := ["nerids", "surr", "meridians", "aery", "crystari", "humans"]
const ART_PORTRAIT_REGIONS := {
	"nerids": Rect2(84, 706, 174, 155),
	"surr": Rect2(350, 706, 174, 155),
	"meridians": Rect2(614, 706, 174, 155),
	"aery": Rect2(880, 706, 174, 155),
	"crystari": Rect2(1134, 706, 174, 155),
	"humans": Rect2(1408, 706, 174, 155)
}
const ART_COMMANDERS := {
	"nerids": {"name": "Сирена Вальтэра", "title": "Хранительница приливов", "quote": "«Море защищает тех, кто умеет слушать.»", "attack": 6.0, "defense": 4.0, "expenses": 2.0},
	"surr": {"name": "Рагнар Келл", "title": "Повелитель кузниц", "quote": "«Твёрдая воля выдержит любой натиск.»", "attack": 8.0, "defense": 3.0, "expenses": 3.0},
	"meridians": {"name": "Лиора Вейн", "title": "Стратег торговых домов", "quote": "«Победа начинается с верного расчёта.»", "attack": 3.0, "defense": 4.0, "expenses": -2.0},
	"aery": {"name": "Элиан Саэр", "title": "Разведчик высотных кланов", "quote": "«Ветер открывает путь тем, кто смотрит вдаль.»", "attack": 5.0, "defense": 2.0, "expenses": -1.0},
	"crystari": {"name": "Тарен Нокс", "title": "Страж глубинного камня", "quote": "«Крепкая опора удержит весь строй.»", "attack": 2.0, "defense": 8.0, "expenses": 3.0},
	"humans": {"name": "Марек Торн", "title": "Адмирал вольных портов", "quote": "«Держим строй, пока стоит наш флаг.»", "attack": 5.0, "defense": 5.0, "expenses": 1.0}
}

const CARD_MIN_SIZE := Vector2(280, 320)
const UNIT_PORTRAITS := {
	"coast_guard": "res://assets/characters/units/coast_guard.webp",
	"rune_spearman": "res://assets/characters/units/rune_spearman.webp",
	"stone_warden": "res://assets/characters/units/stone_warden.webp",
	"wind_rider": "res://assets/characters/units/wind_rider.webp",
	"crystal_mortar": "res://assets/characters/units/crystal_mortar.webp",
	"storm_drake": "res://assets/characters/units/storm_drake.webp"
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
	_origin_emblem = TextureRect.new()
	_origin_emblem.custom_minimum_size = Vector2(46, 46)
	_origin_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_origin_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(_origin_emblem)
	var title := Label.new()
	var faction: Dictionary = GameData.get_faction(str(GameState.player_state.get("origin_race_id", "")))
	_origin_emblem.texture = GameData.get_faction_emblem(str(GameState.player_state.get("origin_race_id", "")))
	title.text = "ГАРНИЗОН · %s" % str(faction.get("name", "Игрок"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	heading.add_child(title)
	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size = Vector2(100, 34)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.pressed.connect(_close)
	heading.add_child(close_button)

	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 14)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_details)

	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", 14)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_notice)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 14)
	layout.add_child(_tabs)

	_build_overview_tab()
	_build_unit_tab("ПЕХОТА")
	_build_unit_tab("ЛЕТУЧИЕ")
	_build_unit_tab("ТЕХНИКА")
	_build_defense_tab()
	_build_reports_tab()
	_build_art_screen()
	var header_return := Button.new()
	header_return.text = "КОМАНДИРЫ"
	header_return.custom_minimum_size = Vector2(128, 34)
	header_return.pressed.connect(_show_art_screen)
	var heading_row_return: HBoxContainer = _panel.get_child(0).get_child(0).get_child(0)
	heading_row_return.add_child(header_return)
	_root.hide()

func initialize(system: Node) -> void:
	_system = system
	_inspected_faction_id = str(GameState.player_state.get("origin_race_id", "nerids"))
	_origin_emblem.texture = GameData.get_faction_emblem(str(GameState.player_state.get("origin_race_id", "")))

func open() -> void:
	_is_open = true
	_art_mode = true
	_inspected_faction_id = str(GameState.player_state.get("origin_race_id", "nerids"))
	_cards_dirty = true
	_notice.text = ""
	if _system != null:
		_system.mark_reports_seen()
	_refresh()
	_refresh_art_screen()

func _process(_delta: float) -> void:
	_root.visible = _is_open
	if not _is_open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1120.0, viewport.x - 24.0), minf(840.0, viewport.y - 24.0))
	_panel.position = (viewport - _panel.size) * 0.5
	_art_screen.visible = _art_mode
	_panel.visible = not _art_mode
	_layout_art_screen(viewport)
	var second: int = int(Time.get_unix_time_from_system())
	if second != _last_refresh_second:
		_last_refresh_second = second
		_refresh()
		_refresh_art_screen()

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
	upgrade_title.add_theme_font_size_override("font_size", 17)
	_overview.add_child(upgrade_title)
	_add_garrison_upgrade(_overview)

	_construction_label = Label.new()
	_construction_label.add_theme_font_size_override("font_size", 14)
	_overview.add_child(_construction_label)
	_construction_bar = ProgressBar.new()
	_construction_bar.custom_minimum_size.y = 24
	_construction_bar.show_percentage = true
	_overview.add_child(_construction_bar)

	var training_title := Label.new()
	training_title.text = "ОБУЧЕНИЕ ОТРЯДОВ"
	training_title.add_theme_font_size_override("font_size", 17)
	_overview.add_child(training_title)
	_recruitment_label = Label.new()
	_recruitment_label.add_theme_font_size_override("font_size", 14)
	_overview.add_child(_recruitment_label)
	_recruitment_bar = ProgressBar.new()
	_recruitment_bar.custom_minimum_size.y = 24
	_recruitment_bar.show_percentage = true
	_overview.add_child(_recruitment_bar)

	var operation_title := Label.new()
	operation_title.text = "ТЕКУЩАЯ ВЫЛАЗКА"
	operation_title.add_theme_font_size_override("font_size", 17)
	_overview.add_child(operation_title)
	_raid_label = Label.new()
	_raid_label.add_theme_font_size_override("font_size", 14)
	_overview.add_child(_raid_label)
	_raid_bar = ProgressBar.new()
	_raid_bar.custom_minimum_size.y = 24
	_raid_bar.show_percentage = true
	_overview.add_child(_raid_bar)

	if OS.is_debug_build():
		var test_row := HBoxContainer.new()
		var defense_test := Button.new()
		defense_test.text = "ТЕСТ: нападение"
		defense_test.add_theme_font_size_override("font_size", 13)
		defense_test.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		defense_test.pressed.connect(_test_defense)
		test_row.add_child(defense_test)
		var raid_test := Button.new()
		raid_test.text = "ТЕСТ: вылазка 15 сек."
		raid_test.add_theme_font_size_override("font_size", 13)
		raid_test.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	intro.add_theme_font_size_override("font_size", 14)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var grid := GridContainer.new()
	grid.name = "UnitCards"
	var width: float = get_viewport().get_visible_rect().size.x
	grid.columns = 3 if width >= 1200.0 else (2 if width >= 820.0 else 1)
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
	title.text = "ОБОРОНА БАЗЫ · БАШНИ И КРИСТАЛЛЫ"
	title.add_theme_font_size_override("font_size", 17)
	content.add_child(title)
	_tower_label = Label.new()
	_tower_label.add_theme_font_size_override("font_size", 14)
	_tower_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_tower_label)

	var tower_buttons := HBoxContainer.new()
	tower_buttons.add_theme_constant_override("separation", 8)
	for tower in [["island", "Построить башню"]]:
		var button := Button.new()
		button.text = str(tower[1])
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.custom_minimum_size = Vector2(160, 36)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_build_tower.bind(str(tower[0])))
		tower_buttons.add_child(button)
		_tower_buttons[str(tower[0])] = button
	content.add_child(tower_buttons)
	var install_hint := Label.new()
	install_hint.text = "Шаг 1 — постройте башню. Шаг 2 — выберите её ниже. Шаг 3 — выберите кристалл из запаса и нажмите «Установить»."
	install_hint.add_theme_font_size_override("font_size", 15)
	install_hint.add_theme_color_override("font_color", Color("#72ddd2"))
	install_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(install_hint)

	var crystal_row := HBoxContainer.new()
	crystal_row.add_theme_constant_override("separation", 8)
	var tower_select_label := Label.new()
	tower_select_label.text = "Башня для настройки"
	tower_select_label.add_theme_font_size_override("font_size", 14)
	content.add_child(tower_select_label)
	_tower_slot_select = OptionButton.new()
	_tower_slot_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_slot_select.custom_minimum_size.y = 36
	_tower_slot_select.add_theme_font_size_override("font_size", 14)
	_tower_slot_select.item_selected.connect(_on_tower_slot_selected)
	crystal_row.add_child(_tower_slot_select)
	var crystal_select_label := Label.new()
	crystal_select_label.text = "Кристалл из запаса"
	crystal_select_label.add_theme_font_size_override("font_size", 14)
	content.add_child(crystal_select_label)
	_crystal_select = OptionButton.new()
	_crystal_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crystal_select.custom_minimum_size.y = 36
	_crystal_select.add_theme_font_size_override("font_size", 14)
	_crystal_select.item_selected.connect(_on_crystal_selected)
	crystal_row.add_child(_crystal_select)
	_crystal_apply_button = Button.new()
	_crystal_apply_button.text = "Установить"
	_crystal_apply_button.custom_minimum_size = Vector2(120, 36)
	_crystal_apply_button.add_theme_font_size_override("font_size", 14)
	_crystal_apply_button.pressed.connect(_set_tower_crystal)
	crystal_row.add_child(_crystal_apply_button)
	content.add_child(crystal_row)

	var note := Label.new()
	note.text = "Башни открываются на 2 и 4 уровне гарнизона. Всего две универсальные площадки; в каждую устанавливается кристалл атаки, брони или удачи. Кристалл можно снять и переставить. Крафт и уровень кристаллов — в гильдии магов."
	note.add_theme_font_size_override("font_size", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

	var fort_row := HBoxContainer.new()
	content.add_child(fort_row)
	_repair_button = Button.new()
	_repair_button.text = "Починить укрепления"
	_repair_button.custom_minimum_size = Vector2(190, 36)
	_repair_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_repair_button.add_theme_font_size_override("font_size", 14)
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
	_upgrade_button.custom_minimum_size = Vector2(190, 36)
	_upgrade_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_upgrade_button.add_theme_font_size_override("font_size", 14)
	_upgrade_button.pressed.connect(_upgrade_garrison)
	row.add_child(_upgrade_button)
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
	_refresh_recruitment_portrait(recruit_job)

	var raid: Dictionary = _system.get_player_raid_status()
	_raid_bar.value = float(raid.get("percent", 0.0))
	_raid_label.text = "Идёт вылазка к цели «%s»  •  %d%%  •  осталось %d сек." % [str(raid.get("target", "")), int(raid.get("percent", 0.0)), int(raid.get("seconds_left", 0))] if not raid.is_empty() else "Вылазок сейчас нет."

	var can_build_more: bool = _system.get_towers().size() < _system.get_tower_slot_limit()
	for tower_type in _tower_buttons:
		var tower_button: Button = _tower_buttons[tower_type]
		tower_button.disabled = not can_build_more or not _system.can_build_tower(str(tower_type))
	var tower_requirement: String = "Башня откроется на 2 уровне гарнизона." if level < 2 else ""
	if level >= 2 and _system.get_towers().size() == 1 and level < 4:
		tower_requirement = "Вторая башня откроется на 4 уровне гарнизона."
	if level >= 2 and can_build_more and not _system.can_build_tower("island"):
		var tower_inventory: Dictionary = GameState.port_state.get(_system.get_home_port_id(), {}).get("inventory", {})
		tower_requirement = "Стоимость башни: 450 монет, 10 дерева, 6 деталей. Сейчас: %d монет, %d дерева, %d деталей." % [int(GameState.player_state.get("money", 0)), int(tower_inventory.get("resource_timber", 0)), int(tower_inventory.get("resource_parts", 0))]
	if can_build_more and _system.can_build_tower("island"):
		tower_requirement = "Башня готова к строительству: 450 монет, 10 дерева, 6 деталей."
	_tower_buttons["island"].text = "ПОСТРОИТЬ БАШНУ"
	_tower_buttons["island"].tooltip_text = tower_requirement
	_tower_label.text = _format_towers(_system.get_tower_bonuses()) + ("\n" + tower_requirement if tower_requirement != "" else "")
	_refresh_crystal_controls()
	_repair_button.disabled = not _system.is_at_home() or integrity >= 100.0

	var roster_signature: String = ""
	for unit in _system.get_roster():
		roster_signature += "%s:%d:%d:%d:%d|" % [str(unit.get("id", "")), int(unit.get("count", 0)), int(unit.get("level", 1)), int(unit.get("experience", 0)), int(unit.get("unlocked", false))]
	var current_columns: int = 3 if get_viewport().get_visible_rect().size.x >= 1200.0 else (2 if get_viewport().get_visible_rect().size.x >= 820.0 else 1)
	if _cards_dirty or roster_signature != _last_roster_signature or current_columns != _last_card_columns:
		_last_roster_signature = roster_signature
		_last_card_columns = current_columns
		_rebuild_unit_cards()
		_cards_dirty = false
	_rebuild_reports()

func _format_towers(bonuses: Dictionary) -> String:
	var towers: Array = _system.get_towers()
	var slots: int = _system.get_tower_slot_limit()
	var contents: String = "Башен пока нет."
	if not towers.is_empty():
		contents = "Башни острова: "
		for index in range(towers.size()):
			if index > 0:
				contents += "  •  "
			var crystal_id: String = str(towers[index].get("crystal_id", ""))
			var crystal_name: String = "пустая" if crystal_id == "" else str(_system.get_crystal_name(crystal_id))
			contents += "%d — %s" % [index + 1, crystal_name]
	var inventory: Dictionary = _system.get_crystal_inventory()
	var available: int = 0
	for count in inventory.values():
		available += int(count)
	return "%s  Площадки: %d / %d. Кристаллов в запасе: %d. Бонусы: атака +%.1f%%, броня +%.1f%%, шанс удачи +%.1f п.п." % [contents, towers.size(), slots, available, float(bonuses.get("attack", 0.0)), float(bonuses.get("defense", 0.0)), float(bonuses.get("luck", 0.0))]

func _refresh_crystal_controls() -> void:
	if _tower_slot_select == null or _crystal_select == null or _crystal_apply_button == null:
		return
	var towers: Array = _system.get_towers()
	var inventory: Dictionary = _system.get_crystal_inventory()
	var signature: String = JSON.stringify(towers) + JSON.stringify(inventory)
	if signature == _crystal_signature:
		return
	_crystal_signature = signature
	var previously_selected: int = maxi(0, _tower_slot_select.selected)
	_tower_slot_select.clear()
	for index in range(towers.size()):
		_tower_slot_select.add_item("Башня %d" % (index + 1))
	if not towers.is_empty():
		_tower_slot_select.select(mini(previously_selected, towers.size() - 1))
	_crystal_select.clear()
	_crystal_select.add_item("Снять кристалл")
	_crystal_select.set_item_metadata(0, "")
	var current_id: String = ""
	if not towers.is_empty():
		current_id = str(towers[_tower_slot_select.selected].get("crystal_id", ""))
	for crystal_id in _system.get_crystal_order():
		var id: String = str(crystal_id)
		var count: int = int(inventory.get(id, 0))
		var item_index: int = _crystal_select.item_count
		_crystal_select.add_item("%s — %d шт." % [_system.get_crystal_name(id), count])
		_crystal_select.set_item_metadata(item_index, id)
		if count <= 0 and id != current_id:
			_crystal_select.set_item_disabled(item_index, true)
		if id == current_id:
			_crystal_select.select(item_index)
	if current_id == "":
		_crystal_select.select(0)
	_update_crystal_apply_button()

func _update_crystal_apply_button() -> void:
	if _tower_slot_select == null or _crystal_select == null or _crystal_apply_button == null:
		return
	var towers: Array = _system.get_towers()
	var inventory: Dictionary = _system.get_crystal_inventory()
	var has_tower: bool = not towers.is_empty() and _tower_slot_select.selected >= 0
	var current_id: String = ""
	if has_tower:
		current_id = str(towers[_tower_slot_select.selected].get("crystal_id", ""))
	var chosen_id: String = str(_crystal_select.get_item_metadata(_crystal_select.selected)) if _crystal_select.selected >= 0 else ""
	var can_change: bool = has_tower and chosen_id != current_id
	if chosen_id != "":
		can_change = can_change and int(inventory.get(chosen_id, 0)) > 0
	_crystal_apply_button.disabled = not can_change
	_crystal_apply_button.text = "Снять кристалл" if chosen_id == "" and current_id != "" else "Установить"

func _on_tower_slot_selected(_index: int) -> void:
	_crystal_signature = ""
	_refresh_crystal_controls()

func _on_crystal_selected(_index: int) -> void:
	_update_crystal_apply_button()

func _set_tower_crystal() -> void:
	if _tower_slot_select == null or _crystal_select == null:
		return
	var tower_index: int = _tower_slot_select.selected
	var crystal_id: String = str(_crystal_select.get_item_metadata(_crystal_select.selected))
	var result: Dictionary = _system.set_tower_crystal(tower_index, crystal_id)
	_notice.text = str(result.get("message", ""))
	_crystal_signature = ""
	_refresh()

func _rebuild_unit_cards() -> void:
	_recruitment_portrait_bars.clear()
	for grid in _unit_grids.values():
		for child in grid.get_children():
			child.queue_free()
	var max_batch: int = int(_system.get_catalog().get("rules", {}).get("max_recruitment_batch", 20))
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var columns: int = 3 if viewport_width >= 1200.0 else (2 if viewport_width >= 820.0 else 1)
	for grid_value in _unit_grids.values():
		var unit_grid: GridContainer = grid_value
		unit_grid.columns = columns
	for unit in _system.get_roster():
		var tab_name: String = _tab_for_branch(str(unit.get("branch", "")))
		var grid: GridContainer = _unit_grids.get(tab_name)
		if grid == null:
			continue
		grid.add_child(_create_unit_card(unit, max_batch))

func _refresh_recruitment_portrait(recruit_job: Dictionary) -> void:
	var training_unit_id: String = str(recruit_job.get("unit_id", ""))
	for unit_id in _recruitment_portrait_bars:
		var bar: ProgressBar = _recruitment_portrait_bars[unit_id]
		if not is_instance_valid(bar):
			continue
		bar.visible = not recruit_job.is_empty() and str(unit_id) == training_unit_id
		if bar.visible:
			bar.value = float(recruit_job.get("percent", 0.0))

func _tab_for_branch(branch: String) -> String:
	if branch.contains("Летуч"):
		return "ЛЕТУЧИЕ"
	if branch.contains("техник") or branch.contains("мортир"):
		return "ТЕХНИКА"
	return "ПЕХОТА"

func _create_unit_card(unit: Dictionary, max_batch: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var race_id: String = str(GameState.player_state.get("origin_race_id", "humans"))
	var faction: Dictionary = GameData.get_faction(race_id)
	var palette: Array = faction.get("palette", ["#142735", "#536e78", "#c49a58"])
	var race_accent := Color(str(palette[2])) if palette.size() > 2 else Color("#c49a58")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142735")
	style.border_color = race_accent if bool(unit.get("unlocked", false)) else Color("#46515a")
	style.set_border_width_all(1)
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
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(portrait_row)
	var portrait_path := _get_unit_portrait_path(str(unit.get("id", "")), race_id)
	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(144, 144)
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#0b141c") if portrait_path != "" and ResourceLoader.exists(portrait_path) else Color("#203d49")
	frame_style.border_color = race_accent if portrait_path != "" and ResourceLoader.exists(portrait_path) else Color("#497887")
	frame_style.set_border_width_all(2)
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	portrait_row.add_child(portrait_frame)
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait := TextureRect.new()
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 2
		portrait.offset_top = 2
		portrait.offset_right = -2
		portrait.offset_bottom = -2
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture = load(portrait_path) as Texture2D
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait)
	else:
		var emblem := Label.new()
		emblem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		emblem.text = "✦\n" + str(unit.get("branch", ""))
		emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emblem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		emblem.add_theme_font_size_override("font_size", 20)
		portrait_frame.add_child(emblem)
	var training_bar := ProgressBar.new()
	training_bar.name = "PortraitRecruitmentProgress"
	training_bar.min_value = 0
	training_bar.max_value = 100
	training_bar.show_percentage = true
	training_bar.visible = false
	training_bar.anchor_left = 0.06
	training_bar.anchor_right = 0.94
	training_bar.anchor_top = 1.0
	training_bar.anchor_bottom = 1.0
	training_bar.offset_top = -27
	training_bar.offset_bottom = -8
	training_bar.add_theme_font_size_override("font_size", 11)
	portrait_frame.add_child(training_bar)
	_recruitment_portrait_bars[str(unit.get("id", ""))] = training_bar

	var title := Label.new()
	title.text = str(unit.get("branch", "")).to_upper() + " · " + str(faction.get("name", "Игрок"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", race_accent)
	title.add_theme_font_size_override("font_size", 13)
	content.add_child(title)
	var name := Label.new()
	name.text = str(unit.get("name", ""))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 17)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name)

	var state := Label.new()
	state.add_theme_font_size_override("font_size", 14)
	if bool(unit.get("unlocked", false)):
		state.text = "%d в гарнизоне  •  уровень %d" % [int(unit.get("count", 0)), int(unit.get("level", 1))]
	else:
		state.text = "Откроется на %d уровне гарнизона" % int(unit.get("unlock_level", 1))
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(state)

	if bool(unit.get("unlocked", false)):
		var stats := Label.new()
		stats.text = "Сила %d  •  защита %d\nСкорость %d  •  удача %d" % [int(unit.get("attack", 0)), int(unit.get("defense", 0)), int(unit.get("speed", 0)), int(unit.get("luck", 0))]
		stats.add_theme_font_size_override("font_size", 14)
		content.add_child(stats)

		var growth := ProgressBar.new()
		growth.custom_minimum_size.y = 18
		growth.show_percentage = false
		growth.value = float(unit.get("experience_percent", 0))
		content.add_child(growth)
		var growth_label := Label.new()
		growth_label.text = "Развитие отряда: %d%%" % int(unit.get("experience_percent", 0))
		growth_label.add_theme_font_size_override("font_size", 13)
		content.add_child(growth_label)

		var quantity_label := Label.new()
		quantity_label.add_theme_font_size_override("font_size", 13)
		content.add_child(quantity_label)
		var quantity := HSlider.new()
		quantity.min_value = 1
		quantity.max_value = max_batch
		quantity.step = 1
		quantity.value = mini(5, max_batch)
		quantity.custom_minimum_size.y = 24
		content.add_child(quantity)

		var hire := Button.new()
		hire.text = "Нанять отряд"
		hire.custom_minimum_size = Vector2(150, 34)
		hire.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hire.add_theme_font_size_override("font_size", 13)
		hire.pressed.connect(_recruit.bind(str(unit.get("id", "")), quantity))
		content.add_child(hire)
		quantity.value_changed.connect(_update_recruit_preview.bind(str(unit.get("id", "")), quantity_label, hire))
		_update_recruit_preview(float(quantity.value), str(unit.get("id", "")), quantity_label, hire)

		if int(unit.get("count", 0)) > 0:
			var promote := Button.new()
			promote.text = "Повысить уровень отряда"
			promote.custom_minimum_size = Vector2(190, 32)
			promote.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			promote.add_theme_font_size_override("font_size", 13)
			promote.disabled = not _system.is_at_home() or int(unit.get("level", 1)) >= _system.get_garrison_level() or int(unit.get("experience", 0)) < int(unit.get("next_level_experience", 100))
			promote.pressed.connect(_promote.bind(str(unit.get("id", ""))))
			content.add_child(promote)

	return card

func _get_unit_portrait_path(unit_id: String, race_id: String) -> String:
	# Prefer a racial portrait when available; preserve existing unit art as fallback.
	var faction_path := "res://assets/characters/units/%s/%s.webp" % [race_id, unit_id]
	if ResourceLoader.exists(faction_path):
		return faction_path
	return str(UNIT_PORTRAITS.get(unit_id, ""))

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
	var total_cost: int = _system.get_recruitment_cost(unit_id, amount)
	var total_seconds: int = int(definition.get("seconds_per_unit", 10)) * amount
	preview.text = "%d отрядов: %d монет  •  обучение %d сек." % [amount, total_cost, total_seconds]
	hire_button.disabled = not _system.is_at_home() or not _system.get_recruitment_status().is_empty() or not _system.can_recruit(unit_id, amount)

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

func _build_art_screen() -> void:
	_art_screen = Control.new()
	_art_screen.name = "GarrisonArtScreen"
	_art_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_screen.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_art_screen)
	var letterbox := ColorRect.new()
	letterbox.color = Color("#07131c")
	letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_screen.add_child(letterbox)
	_art_image = TextureRect.new()
	_art_image.texture = load(ART_REFERENCE_PATH) as Texture2D
	_art_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_screen.add_child(_art_image)
	_art_commander_portrait = TextureRect.new()
	_art_commander_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_commander_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_commander_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_screen.add_child(_art_commander_portrait)
	_art_slot_portrait = TextureRect.new()
	_art_slot_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_slot_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_slot_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_register_art_rect(_art_slot_portrait, Rect2(104, 482, 125, 97))
	_art_screen.add_child(_art_slot_portrait)

	_art_money = _add_art_value("money", Rect2(1135, 29, 112, 38), 20, Color("#f2eee4"))
	_art_shards = _add_art_value("shards", Rect2(1320, 29, 100, 38), 20, Color("#f2eee4"))
	_art_squad_count = _add_art_value("squad_count", Rect2(480, 111, 70, 44), 23, Color("#f2eee4"))
	_art_slot_status = _add_art_value("commander_slot_status", Rect2(119, 587, 118, 36), 12, Color("#d6f5ee"))
	_art_unit_counts["coast_guard"] = _add_art_value("coast_guard_count", Rect2(137, 393, 58, 27), 17, Color("#f2eee4"))
	_art_unit_counts["crystal_mortar"] = _add_art_value("crystal_mortar_count", Rect2(314, 393, 58, 27), 17, Color("#f2eee4"))
	_art_unit_counts["wind_rider"] = _add_art_value("wind_rider_count", Rect2(491, 393, 58, 27), 17, Color("#f2eee4"))
	_art_profile_labels["faction"] = _add_art_value("profile_faction", Rect2(1201, 127, 375, 36), 23, Color("#e9f7f6"), HORIZONTAL_ALIGNMENT_LEFT)
	_art_profile_labels["rank"] = _add_art_value("profile_rank", Rect2(1530, 117, 94, 36), 19, Color("#f2eee4"))
	_art_profile_labels["name"] = _add_art_value("profile_name", Rect2(1200, 166, 414, 54), 29, Color("#f4e5c8"), HORIZONTAL_ALIGNMENT_LEFT)
	_art_profile_labels["title"] = _add_art_value("profile_title", Rect2(1200, 216, 414, 34), 17, Color("#d8e9e7"), HORIZONTAL_ALIGNMENT_LEFT)
	_art_profile_labels["quote"] = _add_art_value("profile_quote", Rect2(1200, 256, 414, 33), 15, Color("#cddbd9"), HORIZONTAL_ALIGNMENT_LEFT)
	_art_profile_labels["attack"] = _add_art_value("profile_attack", Rect2(1562, 305, 68, 38), 24, Color("#64eee1"))
	_art_profile_labels["defense"] = _add_art_value("profile_defense", Rect2(1562, 373, 68, 38), 24, Color("#64eee1"))
	_art_profile_labels["expenses"] = _add_art_value("profile_expenses", Rect2(1562, 440, 68, 38), 24, Color("#ff7465"))
	_art_profile_labels["description"] = _add_art_value("profile_description", Rect2(1142, 494, 487, 80), 15, Color("#d7dfdf"), HORIZONTAL_ALIGNMENT_LEFT)
	_art_notice = _add_art_value("notice", Rect2(580, 613, 520, 46), 15, Color("#fff2cc"))
	_art_notice.hide()
	(_art_screen.get_child(_art_notice.get_index() - 1) as Control).hide()
	_art_hire_button = _add_art_button(Rect2(1314, 594, 320, 75), _art_hire_or_dismiss)
	_art_hire_button.text = "НАНЯТЬ И НАЗНАЧИТЬ\n✦  610"
	_art_hire_button.add_theme_color_override("font_color", Color("#171b1e"))
	_art_hire_button.add_theme_font_size_override("font_size", 21)
	var hire_style := StyleBoxFlat.new()
	hire_style.bg_color = Color("#d7b66f")
	hire_style.border_color = Color("#f3d58c")
	hire_style.set_border_width_all(2)
	hire_style.set_corner_radius_all(7)
	_art_hire_button.add_theme_stylebox_override("normal", hire_style)
	_art_hire_button.add_theme_stylebox_override("hover", hire_style)
	_art_hire_button.add_theme_stylebox_override("pressed", hire_style)
	_add_art_button(Rect2(17, 12, 99, 73), _close)
	_add_art_button(Rect2(1133, 596, 166, 72), _close)
	_add_art_button(Rect2(35, 159, 164, 272), _open_infantry)
	_add_art_button(Rect2(209, 159, 167, 272), _open_tech)
	_add_art_button(Rect2(385, 159, 170, 272), _open_flying)
	_add_art_button(Rect2(80, 473, 162, 204), _art_commander_slot_pressed)
	_add_art_button(Rect2(323, 473, 164, 204), _art_reserve_pressed)
	_add_art_button(Rect2(1222, 20, 50, 47), _open_market_group)
	_add_art_button(Rect2(1422, 20, 51, 47), _open_crystal_group)
	_add_art_button(Rect2(1465, 8, 59, 60), _open_infantry)
	_add_art_button(Rect2(1531, 8, 60, 60), _open_defense)
	_add_art_button(Rect2(1597, 8, 60, 60), _cycle_ui_scale)
	for index in range(ART_FACTION_IDS.size()):
		var faction_id: String = ART_FACTION_IDS[index]
		var x_positions: Array[float] = [49.0, 303.0, 557.0, 838.0, 1098.0, 1370.0]
		var widths: Array[float] = [246.0, 252.0, 275.0, 255.0, 265.0, 250.0]
		_add_art_button(Rect2(x_positions[index], 690.0, widths[index], 242.0), _select_faction.bind(faction_id))
	_art_selection_frame = Panel.new()
	_art_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selection_style := StyleBoxFlat.new()
	selection_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	selection_style.border_color = Color("#ffd16f")
	selection_style.set_border_width_all(3)
	selection_style.set_corner_radius_all(11)
	_art_selection_frame.add_theme_stylebox_override("panel", selection_style)
	_art_screen.add_child(_art_selection_frame)
	_layout_art_screen(get_viewport().get_visible_rect().size)
	_refresh_art_screen()

func _add_art_value(key: String, rect: Rect2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var cover := ColorRect.new()
	cover.color = Color(0.025, 0.055, 0.075, 0.93)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_art_rect(cover, rect)
	_art_screen.add_child(cover)
	var label := Label.new()
	label.name = key
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_art_rect(label, rect)
	_art_screen.add_child(label)
	label.set_meta("design_font_size", font_size)
	return label

func _add_art_button(rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.08, 0.12, 0.0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.55, 0.60, 0.28)
	hover.border_color = Color("#e6b85f")
	hover.set_border_width_all(1)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.78, 0.54, 0.19, 0.38)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	_register_art_rect(button, rect)
	_art_screen.add_child(button)
	_art_hotspots.append(button)
	return button

func _register_art_rect(node: Control, rect: Rect2) -> void:
	node.set_meta("design_rect", rect)

func _layout_art_screen(viewport: Vector2) -> void:
	if not is_instance_valid(_art_screen):
		return
	# Keep the reference proportions intact on ultrawide, portrait, and resized windows.
	var scale := minf(viewport.x / ART_DESIGN_SIZE.x, viewport.y / ART_DESIGN_SIZE.y)
	var offset := (viewport - ART_DESIGN_SIZE * scale) * 0.5
	for child in _art_screen.get_children():
		if child.has_meta("design_rect"):
			var rect: Rect2 = child.get_meta("design_rect")
			child.position = offset + rect.position * scale
			child.size = rect.size * scale
			if child.has_meta("design_font_size"):
				child.add_theme_font_size_override("font_size", maxi(10, int(float(child.get_meta("design_font_size")) * scale)))
	if is_instance_valid(_art_commander_portrait):
		_art_commander_portrait.position = offset + Vector2(561.0, 87.0) * scale
		_art_commander_portrait.size = Vector2(552.0, 604.0) * scale

func _refresh_art_screen() -> void:
	if not is_instance_valid(_art_money) or _system == null:
		return
	var faction := GameData.get_faction(_inspected_faction_id)
	var candidate := _commander_profile(_inspected_faction_id)
	_art_money.text = _format_number(int(GameState.player_state.get("money", 0.0)))
	_art_shards.text = _format_number(_system.get_magic_shards())
	var unit_counts := {"coast_guard": 0, "crystal_mortar": 0, "wind_rider": 0}
	var active_groups := 0
	for unit in _system.get_roster():
		var unit_id := str(unit.get("id", ""))
		if unit_counts.has(unit_id):
			unit_counts[unit_id] = int(unit.get("count", 0))
			if int(unit.get("count", 0)) > 0:
				active_groups += 1
	_art_squad_count.text = "%d/4" % mini(4, active_groups + (1 if not _system.get_commander().is_empty() else 0))
	for unit_id in _art_unit_counts:
		(_art_unit_counts[unit_id] as Label).text = _format_number(int(unit_counts.get(unit_id, 0)))
	(_art_profile_labels["faction"] as Label).text = str(faction.get("name", "Гарнизон")).to_upper()
	(_art_profile_labels["rank"] as Label).text = "%d РАНГ" % int(candidate.get("rank", 3))
	(_art_profile_labels["name"] as Label).text = str(candidate.get("name", "Командир гарнизона"))
	(_art_profile_labels["title"] as Label).text = str(candidate.get("title", "Тактик обороны"))
	(_art_profile_labels["quote"] as Label).text = str(candidate.get("quote", "«Гарнизон готов к приказу.»"))
	var saved_commander: Dictionary = _system.get_commander()
	var showing_hired: bool = not saved_commander.is_empty() and str(saved_commander.get("race_id", "")) == _inspected_faction_id
	_art_slot_status.text = "КОМАНДИР\nНАЗНАЧЕН" if not saved_commander.is_empty() else "ГОТОВ К\nНАЗНАЧЕНИЮ"
	var attack := float(saved_commander.get("attack_bonus", candidate.get("attack", 0.0))) if showing_hired else float(candidate.get("attack", 0.0))
	var defense := float(saved_commander.get("defense_bonus", candidate.get("defense", 0.0))) if showing_hired else float(candidate.get("defense", 0.0))
	var expenses := float(saved_commander.get("expenses_bonus", candidate.get("expenses", 0.0))) if showing_hired else float(candidate.get("expenses", 0.0))
	(_art_profile_labels["attack"] as Label).text = "%+.0f%%" % attack
	(_art_profile_labels["defense"] as Label).text = "%+.0f%%" % defense
	(_art_profile_labels["expenses"] as Label).text = "%+.0f%%" % expenses
	(_art_profile_labels["expenses"] as Label).add_theme_color_override("font_color", Color("#61dfb3") if expenses < 0.0 else Color("#ff7465"))
	(_art_profile_labels["description"] as Label).text = str(candidate.get("description", "Полевой стратег. Усиливает войска и помогает удерживать остров."))
	_art_hire_button.text = "УВОЛИТЬ И СНЯТЬ С ДОЛЖНОСТИ" if showing_hired else "НАНЯТЬ И НАЗНАЧИТЬ\n✦  %s" % _format_number(int(candidate.get("cost", 610)))
	_art_hire_button.disabled = not _system.is_at_home() or (not showing_hired and (_inspected_faction_id != str(GameState.player_state.get("origin_race_id", "")) or not saved_commander.is_empty() or float(GameState.player_state.get("money", 0.0)) < int(candidate.get("cost", 610))))
	var faction_index := ART_FACTION_IDS.find(_inspected_faction_id)
	var frame_x: Array[float] = [49.0, 303.0, 557.0, 838.0, 1098.0, 1370.0]
	var frame_width: Array[float] = [246.0, 252.0, 275.0, 255.0, 265.0, 250.0]
	if faction_index >= 0:
		_register_art_rect(_art_selection_frame, Rect2(frame_x[faction_index], 690.0, frame_width[faction_index], 242.0))
		_art_selection_frame.visible = _inspected_faction_id != "nerids"
	if _art_commander_portrait != null:
		_art_commander_portrait.visible = _inspected_faction_id != "nerids"
		if _inspected_faction_id != "nerids":
			var atlas := AtlasTexture.new()
			atlas.atlas = _art_image.texture
			atlas.region = ART_PORTRAIT_REGIONS.get(_inspected_faction_id, ART_PORTRAIT_REGIONS["humans"])
			_art_commander_portrait.texture = atlas
		var slot_race: String = str(saved_commander.get("race_id", _inspected_faction_id))
		_art_slot_portrait.visible = slot_race != "nerids"
		if slot_race != "nerids":
			var slot_atlas := AtlasTexture.new()
			slot_atlas.atlas = _art_image.texture
			slot_atlas.region = ART_PORTRAIT_REGIONS.get(slot_race, ART_PORTRAIT_REGIONS["humans"])
			_art_slot_portrait.texture = slot_atlas
	_art_notice.text = _notice.text if not _notice.text.is_empty() else ""
	_art_notice.visible = not _notice.text.is_empty()
	(_art_screen.get_child(_art_notice.get_index() - 1) as Control).visible = not _notice.text.is_empty()

func _commander_profile(race_id: String) -> Dictionary:
	var faction := GameData.get_faction(race_id)
	var profile: Dictionary = ART_COMMANDERS.get(race_id, ART_COMMANDERS["humans"]).duplicate(true)
	profile["race_id"] = race_id
	profile["faction_name"] = str(faction.get("name", race_id))
	profile["rank"] = 3
	profile["cost"] = 610
	profile["description"] = str(faction.get("origin_description", "Опытный командир гарнизона."))
	return profile

func _select_faction(race_id: String) -> void:
	_inspected_faction_id = race_id
	_notice.text = ""
	_refresh_art_screen()

func _art_hire_or_dismiss() -> void:
	var commander: Dictionary = _system.get_commander()
	var result: Dictionary
	if not commander.is_empty() and str(commander.get("race_id", "")) == _inspected_faction_id:
		result = _system.dismiss_commander()
	else:
		result = _system.hire_commander(_commander_profile(_inspected_faction_id))
	_notice.text = str(result.get("message", ""))
	_refresh()
	_refresh_art_screen()

func _art_commander_slot_pressed() -> void:
	var commander: Dictionary = _system.get_commander()
	if commander.is_empty():
		_notice.text = "Выберите расу внизу, затем наймите доступного командира."
	else:
		_inspected_faction_id = str(commander.get("race_id", _inspected_faction_id))
		_notice.text = "%s уже командует вашим гарнизоном." % str(commander.get("name", "Командир"))
	_refresh_art_screen()

func _art_reserve_pressed() -> void:
	_notice.text = "Слот резерва закрыт. В гарнизоне пока предусмотрен один назначенный командир."
	_refresh_art_screen()

func _open_infantry() -> void:
	_show_art_tab(1)

func _open_flying() -> void:
	_show_art_tab(2)

func _open_tech() -> void:
	_show_art_tab(3)

func _open_defense() -> void:
	_show_art_tab(4)

func _open_reports() -> void:
	_show_art_tab(5)

func _cycle_ui_scale() -> void:
	var access_nodes := get_tree().get_nodes_in_group("ui_accessibility")
	if access_nodes.is_empty() or not access_nodes[0].has_method("cycle_scale"):
		_notice.text = "Масштаб интерфейса пока недоступен."
		_refresh_art_screen()
		return
	var percent: int = int(access_nodes[0].call("cycle_scale"))
	_notice.text = "Масштаб текста интерфейса: %d%%" % percent
	_refresh_art_screen()

func _show_art_tab(tab_index: int) -> void:
	_art_mode = false
	_tabs.current_tab = tab_index
	_refresh()

func _show_art_screen() -> void:
	_art_mode = true
	_refresh_art_screen()

func _open_market_group() -> void:
	var nodes := get_tree().get_nodes_in_group("port_window")
	if not nodes.is_empty() and nodes[0].has_method("_open_section"):
		nodes[0].call("_open_section", "market")
	else:
		_notice.text = "Рынок доступен после швартовки."
		_refresh_art_screen()

func _open_crystal_group() -> void:
	_open_first_group("mage_guild_window")

func _open_first_group(group_name: String) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	if not nodes.is_empty() and nodes[0].has_method("open"):
		nodes[0].call("open")
	else:
		_notice.text = "Раздел пока недоступен из этого порта."
		_refresh_art_screen()

func _format_number(value: int) -> String:
	var raw := str(maxi(0, value))
	var result := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			result += " "
		result += raw.substr(index, 1)
	return result
