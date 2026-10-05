extends CanvasLayer

## Small persistent toast; combat results never create a visible battle scene.
var _panel: PanelContainer
var _label: Label
var _system: Node
var _hide_at: float = 0.0
var _story_root: Control
var _story_background: TextureRect
var _story_title: Label
var _story_content: VBoxContainer
var _story_continue: Button
var _story_report: Dictionary = {}
var _story_phase: int = 0
var _occupation_sliders: Dictionary = {}
var _occupation_counts: Dictionary = {}
var _occupation_port_id: String = ""

const UNIT_NAMES := {
    "coast_guard": "Береговой дозорный", "rune_spearman": "Рунный копейщик",
    "stone_warden": "Каменный страж", "wind_rider": "Всадник ветра",
    "crystal_mortar": "Кристальная мортира", "storm_drake": "Грозовой дракончик"
}
const UNIT_PORTRAITS := {
    "coast_guard": "res://assets/characters/units/coast_guard.webp",
    "rune_spearman": "res://assets/characters/units/rune_spearman.webp",
    "stone_warden": "res://assets/characters/units/stone_warden.webp",
    "wind_rider": "res://assets/characters/units/wind_rider.webp",
    "crystal_mortar": "res://assets/characters/units/crystal_mortar.webp",
    "storm_drake": "res://assets/characters/units/storm_drake.webp"
}

func _ready() -> void:
    layer = 70
    _panel = PanelContainer.new()
    _panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    _panel.position = Vector2(-390.0, 80.0)
    _panel.custom_minimum_size = Vector2(370.0, 80.0)
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.055, 0.075, 0.98)
    style.border_color = Color(0.9, 0.63, 0.24, 1.0)
    style.set_border_width_all(2)
    _panel.add_theme_stylebox_override("panel", style)
    add_child(_panel)
    var row: HBoxContainer = HBoxContainer.new()
    _panel.add_child(row)
    _label = Label.new()
    _label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label.add_theme_font_size_override("font_size", 17)
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    row.add_child(_label)
    var open_button: Button = Button.new()
    open_button.text = "Сводка"
    open_button.add_theme_font_size_override("font_size", 17)
    open_button.pressed.connect(_open_reports)
    row.add_child(open_button)
    _panel.hide()
    _build_story_screen()

func _build_story_screen() -> void:
    _story_root = Control.new()
    _story_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _story_root.mouse_filter = Control.MOUSE_FILTER_STOP
    _story_root.hide()
    add_child(_story_root)
    _story_background = TextureRect.new()
    _story_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _story_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _story_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _story_root.add_child(_story_background)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.01, 0.025, 0.04, 0.38)
    _story_root.add_child(shade)
    var layout := VBoxContainer.new()
    layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout.add_theme_constant_override("separation", 12)
    _story_root.add_child(layout)
    var top_margin := MarginContainer.new()
    top_margin.add_theme_constant_override("margin_left", 48)
    top_margin.add_theme_constant_override("margin_right", 48)
    top_margin.add_theme_constant_override("margin_top", 26)
    top_margin.add_theme_constant_override("margin_bottom", 0)
    top_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_child(top_margin)
    var content_layout := VBoxContainer.new()
    content_layout.add_theme_constant_override("separation", 12)
    top_margin.add_child(content_layout)
    _story_title = Label.new()
    _story_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _story_title.add_theme_font_size_override("font_size", 38)
    _story_title.add_theme_color_override("font_color", Color("#f4dfae"))
    content_layout.add_child(_story_title)
    _story_content = VBoxContainer.new()
    _story_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _story_content.add_theme_constant_override("separation", 12)
    content_layout.add_child(_story_content)
    var footer := HBoxContainer.new()
    footer.alignment = BoxContainer.ALIGNMENT_CENTER
    footer.custom_minimum_size.y = 74
    _story_continue = Button.new()
    _story_continue.custom_minimum_size = Vector2(340, 62)
    _story_continue.add_theme_font_size_override("font_size", 23)
    _story_continue.pressed.connect(_advance_story)
    footer.add_child(_story_continue)
    layout.add_child(footer)
    var bottom_space := Control.new()
    bottom_space.custom_minimum_size.y = 20
    layout.add_child(bottom_space)
    _layout_story_below_top_menu()

func _layout_story_below_top_menu() -> void:
    if _story_root == null:
        return
    var inset: float = 0.0
    var coordinators: Array[Node] = get_tree().get_nodes_in_group("window_coordinator")
    if not coordinators.is_empty():
        inset = float(coordinators[0].get("_top_height"))
    _story_root.offset_top = inset

func initialize(system: Node) -> void:
    _system = system
    if not EventBus.combat_report_ready.is_connected(_on_report):
        EventBus.combat_report_ready.connect(_on_report)
    var reports: Array = _system.get_reports()
    if _system.get_unread_report_count() > 0 and not reports.is_empty():
        _on_report(reports[0])

func _process(_delta: float) -> void:
    _layout_story_below_top_menu()
    if visible and _hide_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _hide_at:
        _panel.hide()
        _hide_at = 0.0

func _on_report(report: Dictionary) -> void:
    var kind: String = str(report.get("kind", ""))
    _label.text = "Было нападение на базу. Отчёт готов." if kind == "defense" else "Операция завершена. Отчёт готов."
    _panel.show()
    _hide_at = Time.get_ticks_msec() / 1000.0 + 20.0
    if kind == "player_raid" or kind == "tribute_revolt":
        _story_report = report.duplicate(true)
        _story_phase = 0
        _story_root.show()
        _render_story_phase()

func _open_reports() -> void:
    _panel.hide()
    if _system == null:
        return
    var reports: Array = _system.get_reports()
    if reports.is_empty():
        return
    _story_report = reports[0]
    _story_phase = 0
    _story_root.show()
    _render_story_phase()

func _render_story_phase() -> void:
    for child in _story_content.get_children():
        child.queue_free()
    var report_kind := str(_story_report.get("kind", ""))
    if report_kind == "tribute_revolt":
        _story_phase = 2
        _story_background.texture = load("res://assets/ui/combat/emergency_revolt.webp")
        _story_title.text = "ПИСЬМО ЭКСТРЕННОЕ · %s" % str(_story_report.get("target", "Остров"))
        _add_story_text(str(_story_report.get("summary", "Остров поднял восстание.")), 25)
        _add_story_text("Потери гарнизона и мятежников: %s" % str(_story_report.get("casualties_text", "сводка приложена к отчёту")), 20)
        _story_continue.text = "ЗАКРЫТЬ ПИСЬМО"
        return
    if _story_phase == 0:
        _story_background.texture = load("res://assets/ui/combat/battle_result_backdrop.webp")
        _story_title.text = "%s · %s" % [str(_story_report.get("outcome", "ИТОГ БОЯ")).to_upper(), str(_story_report.get("target", _story_report.get("enemy", "Порт")))]
        _add_battle_card_rows()
        _story_continue.text = "ДАЛЕЕ"
    elif _story_phase == 1:
        _story_background.texture = load("res://assets/ui/combat/tribute_handover.webp")
        var captured_online: bool = bool(_story_report.get("online_island_captured", false))
        _story_title.text = "ОСТРОВ ПОД ВАШИМ ФЛАГОМ" if captured_online else "ПОРТ ПРИЗНАЁТ ВАШ ФЛАГ"
        var transfer_intro: String = "Выберите гарнизон захваченного порта." if captured_online else str(_story_report.get("tribute_transition", "Представитель острова приносит дань."))
        _add_story_text(transfer_intro, 20)
        if not captured_online:
            _add_story_text("Дань: %d золотых в день." % int(_story_report.get("tribute_daily_amount", 0)), 16)
        _add_story_text("Переместите бойцов между кораблём и островом; состав сохранится после нажатия «Готово»." , 16)
        _build_occupation_transfer()
        _update_occupation_button()
    else:
        _story_root.hide()

func _advance_story() -> void:
    if str(_story_report.get("kind", "")) == "tribute_revolt":
        _story_root.hide()
        return
    if _story_phase == 0 and (bool(_story_report.get("tribute_started", false)) or bool(_story_report.get("online_island_captured", false))):
        _story_phase = 1
        _render_story_phase()
        return
    if _story_phase == 1:
        _finish_occupation_transfer()
        return
    _story_root.hide()

func _build_occupation_transfer() -> void:
    _occupation_sliders.clear()
    _occupation_counts.clear()
    _occupation_port_id = str(_story_report.get("target_port_id", ""))
    var participants: Dictionary = _story_report.get("participants", {})
    var losses: Dictionary = _story_report.get("unit_losses", {})
    var existing_port: Dictionary = GameState.port_state.get(_occupation_port_id, {})
    var already_stationed: Dictionary = existing_port.get("occupation_garrison", {})
    var port_icon_path := "res://assets/ui/ports/buildable_landscape.png"
    var banner := HBoxContainer.new()
    banner.alignment = BoxContainer.ALIGNMENT_CENTER
    banner.add_theme_constant_override("separation", 18)
    _story_content.add_child(banner)
    banner.add_child(_make_story_icon("res://assets/ui/ships/ship_combat_cutter.png", Vector2(84, 54)))
    var ship_caption := Label.new()
    ship_caption.text = "ЭСКАДРА"
    ship_caption.add_theme_color_override("font_color", Color("#79d8d2"))
    ship_caption.add_theme_font_size_override("font_size", 15)
    banner.add_child(ship_caption)
    banner.add_child(_make_story_icon(port_icon_path, Vector2(84, 54)))
    var island_caption := Label.new()
    island_caption.text = "ГАРНИЗОН ОСТРОВА"
    island_caption.add_theme_color_override("font_color", Color("#efc77d"))
    island_caption.add_theme_font_size_override("font_size", 15)
    banner.add_child(island_caption)
    var roster_scroll := ScrollContainer.new()
    roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _story_content.add_child(roster_scroll)
    var roster_rows := VBoxContainer.new()
    roster_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    roster_rows.add_theme_constant_override("separation", 5)
    roster_scroll.add_child(roster_rows)
    var unit_ids: Array = participants.keys()
    unit_ids.sort()
    for raw_id in unit_ids:
        var unit_id := str(raw_id)
        var saved: Variant = participants[raw_id]
        var count := int(saved.get("count", 0)) if saved is Dictionary else int(saved)
        var survivors := maxi(0, count - int(losses.get(unit_id, 0)))
        if survivors <= 0:
            continue
        var row := PanelContainer.new()
        row.custom_minimum_size.y = 72
        var row_style := StyleBoxFlat.new()
        row_style.bg_color = Color(0.015, 0.035, 0.055, 0.86)
        row_style.border_color = Color("#987746")
        row_style.set_border_width_all(1)
        row.add_theme_stylebox_override("panel", row_style)
        roster_rows.add_child(row)
        var columns := HBoxContainer.new()
        columns.add_theme_constant_override("separation", 10)
        row.add_child(columns)
        var ship_side := HBoxContainer.new()
        ship_side.custom_minimum_size.x = 142
        ship_side.add_child(_make_story_icon("res://assets/ui/ships/ship_combat_cutter.png", Vector2(56, 46)))
        ship_side.add_child(_make_story_icon(str(UNIT_PORTRAITS.get(unit_id, "")), Vector2(56, 56)))
        columns.add_child(ship_side)
        var center := VBoxContainer.new()
        center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        columns.add_child(center)
        var title := Label.new()
        title.text = "%s · %d выживших" % [str(UNIT_NAMES.get(unit_id, unit_id)), survivors]
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.add_theme_font_size_override("font_size", 15)
        center.add_child(title)
        var slider := HSlider.new()
        slider.min_value = 0
        slider.max_value = survivors
        slider.step = 1
        slider.value = clampi(int(already_stationed.get(unit_id, 0)), 0, survivors)
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slider.value_changed.connect(_on_occupation_slider_changed.bind(unit_id))
        center.add_child(slider)
        var counts := Label.new()
        counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        counts.add_theme_font_size_override("font_size", 14)
        center.add_child(counts)
        var island_side := HBoxContainer.new()
        island_side.custom_minimum_size.x = 142
        island_side.add_child(_make_story_icon(str(UNIT_PORTRAITS.get(unit_id, "")), Vector2(56, 56)))
        island_side.add_child(_make_story_icon(port_icon_path, Vector2(56, 46)))
        columns.add_child(island_side)
        _occupation_sliders[unit_id] = {"slider": slider, "label": counts, "available": survivors}
        _occupation_counts[unit_id] = int(slider.value)
        _on_occupation_slider_changed(float(slider.value), unit_id)

func _make_story_icon(path: String, icon_size: Vector2) -> TextureRect:
    var icon := TextureRect.new()
    icon.custom_minimum_size = icon_size
    icon.size = icon_size
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    if path != "" and ResourceLoader.exists(path):
        icon.texture = load(path)
    return icon

func _on_occupation_slider_changed(value: float, unit_id: String) -> void:
    _occupation_counts[unit_id] = int(value)
    if _occupation_sliders.has(unit_id):
        var entry: Dictionary = _occupation_sliders[unit_id]
        entry.label.text = "На кораблях: %d     →     На острове: %d" % [int(entry.available) - int(value), int(value)]
    _update_occupation_button()

func _update_occupation_button() -> void:
    var total := 0
    for count in _occupation_counts.values():
        total += int(count)
    _story_continue.text = "ГОТОВО · оставить %d бойцов" % total

func _finish_occupation_transfer() -> void:
    var result: Dictionary = {}
    if _system != null and _system.has_method("set_tribute_occupation_roster"):
        result = _system.call("set_tribute_occupation_roster", _occupation_port_id, _occupation_counts)
    if not bool(result.get("ok", false)):
        _add_story_text(str(result.get("message", "Не удалось сохранить распределение гарнизона.")), 17)
        return
    var stationed: Dictionary = result.get("stationed", {})
    _story_phase = 2
    for child in _story_content.get_children():
        child.queue_free()
    var lines := 0
    for raw_id in stationed.keys():
        if int(stationed[raw_id]) > 0:
            _add_story_text("%s — %d" % [str(UNIT_NAMES.get(str(raw_id), str(raw_id))), int(stationed[raw_id])], 18)
            lines += 1
    if lines == 0:
        _add_story_text("Боевой контингент не оставлен. Все выжившие остались на кораблях.", 20)
    else:
        _add_story_text("Контингент высажен и сохранён в гарнизоне порта:", 20)
    _story_title.text = "НА ОСТРОВЕ ОСТАВЛЕНО: %d БОЙЦОВ" % int(result.get("total", 0))
    _story_continue.text = "ЗАКРЫТЬ"

func _add_story_text(value: String, font_size: int) -> void:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("#f3ead4"))
    _story_content.add_child(label)

func _add_battle_card_rows() -> void:
    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation", 20)
    _story_content.add_child(columns)
    _add_side_cards(columns, "ВАШ ДЕСАНТ", _story_report.get("participants", {}), _story_report.get("unit_losses", {}), Color("#4bd5d1"))
    _add_side_cards(columns, "ЗАЩИТНИКИ", _story_report.get("enemy_roster", {}), _story_report.get("enemy_unit_loss_roster", {}), Color("#ef9a71"))

func _add_side_cards(parent: HBoxContainer, heading: String, counts: Dictionary, losses: Dictionary, accent: Color) -> void:
    var side := VBoxContainer.new()
    side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(side)
    var title := Label.new()
    title.text = heading
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", accent)
    side.add_child(title)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    side.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    scroll.add_child(grid)
    for raw_id in counts.keys():
        var unit_id := str(raw_id)
        var saved_count: Variant = counts[raw_id]
        var number: int = int(saved_count.get("count", 0)) if saved_count is Dictionary else int(saved_count)
        if number <= 0:
            continue
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(190, 190)
        var panel_style := StyleBoxFlat.new()
        panel_style.bg_color = Color(0.015, 0.04, 0.065, 0.91)
        panel_style.border_color = accent
        panel_style.set_border_width_all(2)
        card.add_theme_stylebox_override("panel", panel_style)
        grid.add_child(card)
        var box := VBoxContainer.new()
        card.add_child(box)
        var portrait := TextureRect.new()
        portrait.custom_minimum_size = Vector2(184, 118)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        portrait.texture = load(str(UNIT_PORTRAITS.get(unit_id, "")))
        box.add_child(portrait)
        var label := Label.new()
        label.text = "%s\nУчаствовало: %d · Потеряно: %d" % [str(UNIT_NAMES.get(unit_id, unit_id)), number, int(losses.get(unit_id, 0))]
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.add_theme_font_size_override("font_size", 15)
        label.add_theme_color_override("font_color", Color("#f4ead5"))
        box.add_child(label)
