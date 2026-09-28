extends CanvasLayer

## Schematic home garrison, recruitment, tower and combat-report screen.
var _system: Node
var _root: Control
var _panel: PanelContainer
var _details: Label
var _roster: VBoxContainer
var _recruitment_label: Label
var _recruitment_bar: ProgressBar
var _tower_label: Label
var _raid_label: Label
var _raid_bar: ProgressBar
var _report_list: VBoxContainer
var _notice: Label
var _upgrade_button: Button
var _construction_label: Label
var _construction_bar: ProgressBar
var _tower_buttons: Dictionary = {}
var _repair_button: Button
var _is_open: bool = false
var _last_refresh_second: int = -1

func _ready() -> void:
    add_to_group("garrison_window")
    layer = 55
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_root)
    _panel = PanelContainer.new()
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.055, 0.075, 1.0)
    style.border_color = Color(0.38, 0.68, 0.82, 1.0)
    style.set_border_width_all(2)
    _panel.add_theme_stylebox_override("panel", style)
    _root.add_child(_panel)
    var margin: MarginContainer = MarginContainer.new()
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 16)
    _panel.add_child(margin)
    var box: VBoxContainer = VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    margin.add_child(box)
    var title: Label = Label.new()
    title.text = "ГАРНИЗОН И ОБОРОНА БАЗЫ"
    title.add_theme_font_size_override("font_size", 26)
    box.add_child(title)
    _details = Label.new()
    _details.add_theme_font_size_override("font_size", 19)
    _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_details)
    _notice = Label.new()
    _notice.add_theme_font_size_override("font_size", 18)
    _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_notice)
    _add_garrison_upgrade(box)
    _construction_label = Label.new()
    _construction_label.add_theme_font_size_override("font_size", 18)
    box.add_child(_construction_label)
    _construction_bar = ProgressBar.new()
    _construction_bar.custom_minimum_size.y = 20
    _construction_bar.show_percentage = true
    box.add_child(_construction_bar)
    _tower_label = Label.new()
    _tower_label.add_theme_font_size_override("font_size", 18)
    _tower_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_tower_label)
    var tower_buttons: HBoxContainer = HBoxContainer.new()
    tower_buttons.add_theme_constant_override("separation", 6)
    for tower in [["power", "Сила"], ["guard", "Защита"], ["wind", "Скорость"]]:
        var button: Button = Button.new()
        button.text = "Башня: " + str(tower[1])
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 16)
        button.pressed.connect(_build_tower.bind(str(tower[0])))
        tower_buttons.add_child(button)
        _tower_buttons[str(tower[0])] = button
    box.add_child(tower_buttons)
    var roster_title: Label = Label.new()
    roster_title.text = "ОТРЯДЫ"
    roster_title.add_theme_font_size_override("font_size", 21)
    box.add_child(roster_title)
    var roster_scroll: ScrollContainer = ScrollContainer.new()
    roster_scroll.custom_minimum_size.y = 250
    roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(roster_scroll)
    _roster = VBoxContainer.new()
    _roster.add_theme_constant_override("separation", 5)
    roster_scroll.add_child(_roster)
    _recruitment_label = Label.new()
    _recruitment_label.add_theme_font_size_override("font_size", 18)
    box.add_child(_recruitment_label)
    _recruitment_bar = ProgressBar.new()
    _recruitment_bar.custom_minimum_size.y = 20
    _recruitment_bar.show_percentage = true
    box.add_child(_recruitment_bar)
    var raid_title: Label = Label.new()
    raid_title.text = "ОПЕРАЦИЯ"
    raid_title.add_theme_font_size_override("font_size", 20)
    box.add_child(raid_title)
    _raid_label = Label.new()
    _raid_label.add_theme_font_size_override("font_size", 18)
    box.add_child(_raid_label)
    _raid_bar = ProgressBar.new()
    _raid_bar.custom_minimum_size.y = 20
    _raid_bar.show_percentage = true
    box.add_child(_raid_bar)
    if OS.is_debug_build():
        var test_row: HBoxContainer = HBoxContainer.new()
        var defense_test: Button = Button.new()
        defense_test.text = "ТЕСТ: нападение пиратов"
        defense_test.add_theme_font_size_override("font_size", 16)
        defense_test.pressed.connect(_test_defense)
        test_row.add_child(defense_test)
        var raid_test: Button = Button.new()
        raid_test.text = "ТЕСТ: бой 15 сек."
        raid_test.add_theme_font_size_override("font_size", 16)
        raid_test.pressed.connect(_test_raid)
        test_row.add_child(raid_test)
        box.add_child(test_row)
    var report_title: Label = Label.new()
    report_title.text = "ПОСЛЕДНИЕ СВОДКИ"
    report_title.add_theme_font_size_override("font_size", 20)
    box.add_child(report_title)
    var report_scroll: ScrollContainer = ScrollContainer.new()
    report_scroll.custom_minimum_size.y = 130
    report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(report_scroll)
    _report_list = VBoxContainer.new()
    _report_list.add_theme_constant_override("separation", 5)
    report_scroll.add_child(_report_list)
    var close_button: Button = Button.new()
    close_button.text = "Закрыть"
    close_button.custom_minimum_size.y = 42
    close_button.add_theme_font_size_override("font_size", 19)
    close_button.pressed.connect(_close)
    box.add_child(close_button)
    _root.hide()

func initialize(system: Node) -> void:
    _system = system

func open() -> void:
    _is_open = true
    _notice.text = ""
    if _system != null:
        _system.mark_reports_seen()
    _refresh()

func _process(_delta: float) -> void:
    _root.visible = _is_open
    if not _is_open or _system == null:
        return
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    _panel.size = Vector2(minf(980.0, viewport.x - 20.0), minf(1080.0, viewport.y - 20.0))
    _panel.position = (viewport - _panel.size) * 0.5
    var second: int = int(Time.get_unix_time_from_system())
    if second != _last_refresh_second:
        _last_refresh_second = second
        _refresh()

func _add_garrison_upgrade(box: VBoxContainer) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    _upgrade_button = Button.new()
    _upgrade_button.text = "Запустить улучшение"
    _upgrade_button.add_theme_font_size_override("font_size", 19)
    _upgrade_button.pressed.connect(_upgrade_garrison)
    row.add_child(_upgrade_button)
    _repair_button = Button.new()
    _repair_button.text = "Починить укрепления"
    _repair_button.add_theme_font_size_override("font_size", 19)
    _repair_button.pressed.connect(_repair)
    row.add_child(_repair_button)
    box.add_child(row)

func _refresh() -> void:
    if _system == null:
        return
    var level: int = _system.get_garrison_level()
    var bonuses: Dictionary = _system.get_tower_bonuses()
    var home_id: String = _system.get_home_port_id()
    var inventory: Dictionary = GameState.port_state.get(home_id, {}).get("inventory", {})
    var upgrade_cost: Dictionary = _system.get_garrison_upgrade_cost()
    var cost_text: String = "Максимальный уровень" if upgrade_cost.is_empty() else "Улучшение: %d денег, дерево %d, детали %d" % [int(upgrade_cost.get("money", 0)), int(upgrade_cost.get("resource_timber", 0)), int(upgrade_cost.get("resource_parts", 0))]
    var integrity: float = float(GameState.combat_state.get("fort_integrity", 100.0))
    _details.text = "Уровень %d / 5  •  сила %d  •  оборона %d  •  укрепления %.0f%%\n%s\nСклад базы: дерево %d, детали %d. Найм доступен только дома." % [level, _system.get_attack_power(), _system.get_defense_power(), integrity, cost_text, int(inventory.get("resource_timber", 0)), int(inventory.get("resource_parts", 0))]
    var construction: Dictionary = _system.get_construction_status()
    _construction_bar.value = float(construction.get("percent", 0.0))
    _construction_label.text = "Стройка: %s  •  %d%%  •  осталось %d сек." % [str(construction.get("action", "")), int(construction.get("percent", 0.0)), int(construction.get("seconds_left", 0))] if not construction.is_empty() else "Стройка: нет активных работ."
    _upgrade_button.disabled = not _system.can_upgrade_garrison()
    _upgrade_button.text = "Максимальный уровень" if upgrade_cost.is_empty() else "Запустить улучшение"
    _repair_button.disabled = not _system.is_at_home() or integrity >= 100.0
    var can_build_more: bool = _system.get_towers().size() < mini(level, 5)
    for tower_type in _tower_buttons:
        var button: Button = _tower_buttons[tower_type]
        button.disabled = not can_build_more or not _system.can_build_tower(str(tower_type))
    _tower_label.text = _format_towers(bonuses)
    _rebuild_roster()
    var job: Dictionary = _system.get_recruitment_status()
    _recruitment_bar.value = float(job.get("percent", 0.0))
    if job.is_empty():
        _recruitment_label.text = "Обучение: нет активных отрядов."
    else:
        _recruitment_label.text = "Обучается: %s × %d  •  осталось %d сек." % [_system.get_unit_name(str(job.get("unit_id", ""))), int(job.get("amount", 0)), int(job.get("seconds_left", 0))]
    var raid: Dictionary = _system.get_player_raid_status()
    _raid_bar.value = float(raid.get("percent", 0.0))
    _raid_label.text = "Бой начат: %s  •  %d%%  •  %d сек." % [str(raid.get("target", "")), int(raid.get("percent", 0.0)), int(raid.get("seconds_left", 0))] if not raid.is_empty() else "Операций сейчас нет."
    _rebuild_reports()

func _format_towers(bonuses: Dictionary) -> String:
    var names: Array[String] = []
    for tower in _system.get_towers():
        names.append(str(_system.get_tower_name(str(tower.get("type", "")))))
    var slots: int = mini(_system.get_garrison_level(), 5)
    var contents: String = "нет"
    if not names.is_empty():
        contents = ""
        for index in range(names.size()):
            if index > 0:
                contents += ", "
            contents += names[index]
    return "Башни %d / %d: %s   •   бонусы: сила +%.0f%%, защита +%.0f%%, скорость +%.0f%%" % [names.size(), slots, contents, float(bonuses.attack), float(bonuses.defense), float(bonuses.speed)]

func _rebuild_roster() -> void:
    for child in _roster.get_children():
        child.queue_free()
    for unit in _system.get_roster():
        var row: HBoxContainer = HBoxContainer.new()
        var label: Label = Label.new()
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.custom_minimum_size.x = 280
        label.add_theme_font_size_override("font_size", 17)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        if not bool(unit.get("unlocked", false)):
            label.text = "%s — откроется на %d уровне гарнизона" % [str(unit.get("name", "")), int(unit.get("unlock_level", 1))]
        else:
            label.text = "%s / %s • %d шт. • ур. %d • развитие %d%% • сила %d / защита %d / скорость %d / удача %d" % [str(unit.get("branch", "")), str(unit.get("name", "")), int(unit.get("count", 0)), int(unit.get("level", 1)), int(unit.get("experience_percent", 0)), int(unit.get("attack", 0)), int(unit.get("defense", 0)), int(unit.get("speed", 0)), int(unit.get("luck", 0))]
        row.add_child(label)
        if bool(unit.get("unlocked", false)):
            var recruit: Button = Button.new()
            recruit.text = "Нанять 5 · %d" % (int(unit.get("hire_cost", 0)) * 5)
            recruit.custom_minimum_size.x = 150
            recruit.add_theme_font_size_override("font_size", 16)
            recruit.disabled = not _system.is_at_home() or not _system.get_recruitment_status().is_empty() or not _system.can_recruit(str(unit.get("id", "")), 5)
            recruit.pressed.connect(_recruit.bind(str(unit.get("id", ""))))
            row.add_child(recruit)
            if int(unit.get("count", 0)) > 0:
                var promote: Button = Button.new()
                promote.text = "Улучшить"
                promote.custom_minimum_size.x = 115
                promote.add_theme_font_size_override("font_size", 16)
                promote.disabled = not _system.is_at_home() or int(unit.get("level", 1)) >= _system.get_garrison_level() or int(unit.get("experience", 0)) < int(unit.get("next_level_experience", 100))
                promote.pressed.connect(_promote.bind(str(unit.get("id", ""))))
                row.add_child(promote)
        _roster.add_child(row)

func _rebuild_reports() -> void:
    for child in _report_list.get_children():
        child.queue_free()
    var reports: Array = _system.get_reports()
    if reports.is_empty():
        var empty: Label = Label.new()
        empty.text = "Сводок пока нет."
        empty.add_theme_font_size_override("font_size", 17)
        _report_list.add_child(empty)
        return
    for report in reports.slice(0, 8):
        var label: Label = Label.new()
        label.add_theme_font_size_override("font_size", 16)
        var time_text: String = Time.get_datetime_string_from_unix_time(int(report.get("timestamp", 0)), true)
        var losses_text: String = _format_unit_losses(report.get("unit_losses", {}))
        var detail_text: String = "Потери по вашим отрядам: " + losses_text if losses_text != "" else "Потерь по вашим отрядам нет."
        detail_text += "\nОтряды противника потеряны: %d." % int(report.get("enemy_unit_losses", 0))
        label.text = "%s  •  %s — %s\n%s\n%s" % [time_text, str(report.get("enemy", "Противник")), str(report.get("outcome", "")), detail_text, str(report.get("summary", ""))]
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _report_list.add_child(label)

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

func _recruit(unit_id: String) -> void:
    var result: Dictionary = _system.recruit(unit_id, 5)
    _notice.text = str(result.get("message", ""))
    _refresh()

func _promote(unit_id: String) -> void:
    var result: Dictionary = _system.promote_unit(unit_id)
    _notice.text = str(result.get("message", ""))
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