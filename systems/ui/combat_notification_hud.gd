extends CanvasLayer

## Small persistent toast; combat results never create a visible battle scene.
var _panel: PanelContainer
var _label: Label
var _system: Node
var _hide_at: float = 0.0

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

func initialize(system: Node) -> void:
    _system = system
    if not EventBus.combat_report_ready.is_connected(_on_report):
        EventBus.combat_report_ready.connect(_on_report)
    var reports: Array = _system.get_reports()
    if _system.get_unread_report_count() > 0 and not reports.is_empty():
        _on_report(reports[0])

func _process(_delta: float) -> void:
    if visible and _hide_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _hide_at:
        _panel.hide()
        _hide_at = 0.0

func _on_report(report: Dictionary) -> void:
    var kind: String = str(report.get("kind", ""))
    _label.text = "Было нападение на базу. Отчёт готов." if kind == "defense" else "Операция завершена. Отчёт готов."
    _panel.show()
    _hide_at = Time.get_ticks_msec() / 1000.0 + 20.0

func _open_reports() -> void:
    _panel.hide()
    var windows: Array[Node] = get_tree().get_nodes_in_group("garrison_window")
    if not windows.is_empty():
        windows[0].open()